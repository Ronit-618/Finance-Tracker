import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../config/api_config.dart';
import '../models/entry.dart';
import '../models/entry_summary.dart';
import '../models/category_total.dart';
import '../models/entry_group.dart';
import '../models/trial_balance_item.dart';

const String networkErrorMessage = 'No internet connection, please check your network';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

String friendlyError(Object e) =>
    e is ApiException ? e.message : 'Something went wrong. Please try again.';

class ApiService {
  final String baseUrl;
  static const _timeout = Duration(seconds: 45);

  ApiService(this.baseUrl);

  Map<String, String> get _headers => {'X-Api-Key': ApiConfig.apiKey};

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'X-Api-Key': ApiConfig.apiKey,
      };

  String get _host => Uri.parse(baseUrl).host;

  bool get _hasFallbackIps =>
      (ApiConfig.fallbackAddresses[_host]?.isNotEmpty) ?? false;

  http.Client? _pinnedClient;

  http.Client get _fallbackClient =>
      _pinnedClient ??= IOClient(HttpClient()..connectionFactory = _pinnedConnectionFactory);

  Future<ConnectionTask<Socket>> _pinnedConnectionFactory(
      Uri url, String? proxyHost, int? proxyPort) {
    final addresses = ApiConfig.fallbackAddresses[url.host];
    final isHttps = url.scheme == 'https';
    final port = url.hasPort ? url.port : (isHttps ? 443 : 80);
    if (addresses == null || addresses.isEmpty) {
      return Socket.startConnect(url.host, port);
    }
    final socketFuture = _connectToFirstAvailable(
      addresses.map(InternetAddress.new).toList(),
      port,
      isHttps ? url.host : null,
    );
    return Future.value(ConnectionTask.fromSocket(socketFuture, () {}));
  }

  Future<Socket> _connectToFirstAvailable(
      List<InternetAddress> ips, int port, String? tlsHost) async {
    Object? lastError;
    for (final ip in ips) {
      try {
        final socket = await Socket.connect(ip, port);
        if (tlsHost == null) return socket;
        try {
          return await SecureSocket.secure(socket, host: tlsHost);
        } catch (e) {
          socket.destroy();
          rethrow;
        }
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError as Object;
  }

  bool _isDnsFailure(SocketException e) {
    final code = e.osError?.errorCode;
    if (code != null && (code == 7 || code == -7)) return true;
    final message = e.message.toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('no address associated with hostname') ||
        message.contains('nodename nor servname provided');
  }

  Future<http.Response> _guard(
      Future<http.Response> Function(http.Client? client) request) async {
    try {
      return await request(null).timeout(_timeout);
    } on SocketException catch (e) {
      if (_isDnsFailure(e) && _hasFallbackIps) {
        dev.log('DNS lookup failed for $_host; retrying via pinned IP',
            name: 'ApiService');
        try {
          return await request(_fallbackClient).timeout(_timeout);
        } on SocketException {
          throw ApiException(networkErrorMessage);
        } on http.ClientException {
          throw ApiException(networkErrorMessage);
        } on TimeoutException {
          throw ApiException(networkErrorMessage);
        }
      }
      throw ApiException(networkErrorMessage);
    } on http.ClientException catch (_) {
      throw ApiException(networkErrorMessage);
    } on TimeoutException catch (_) {
      throw ApiException(networkErrorMessage);
    }
  }

  Future<http.Response> _get(Uri uri) => _guard(
      (client) => client != null
          ? client.get(uri, headers: _headers)
          : http.get(uri, headers: _headers));

  Future<http.Response> _post(Uri uri, String body) => _guard(
      (client) => client != null
          ? client.post(uri, headers: _jsonHeaders, body: body)
          : http.post(uri, headers: _jsonHeaders, body: body));

  Future<http.Response> _put(Uri uri, String body) => _guard(
      (client) => client != null
          ? client.put(uri, headers: _jsonHeaders, body: body)
          : http.put(uri, headers: _jsonHeaders, body: body));

  Future<http.Response> _delete(Uri uri) => _guard(
      (client) => client != null
          ? client.delete(uri, headers: _headers)
          : http.delete(uri, headers: _headers));

  Future<List<Entry>> getEntries({
    DateTime? from,
    DateTime? to,
    int? category,
    int? type,
    int? paymentType,
    int? bsYear,
    int? bsMonth,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from.toIso8601String().split('T')[0];
    if (to != null) params['to'] = to.toIso8601String().split('T')[0];
    if (category != null) params['category'] = category.toString();
    if (type != null) params['type'] = type.toString();
    if (paymentType != null) params['paymentType'] = paymentType.toString();
    if (bsYear != null) params['bsYear'] = bsYear.toString();
    if (bsMonth != null) params['bsMonth'] = bsMonth.toString();

    final uri = Uri.parse('$baseUrl/api/Entry').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await _get(uri);
    if (res.statusCode != 200) throw ApiException('Failed to load entries (${res.statusCode})');

    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => Entry.fromJson(e)).toList();
  }

  Future<Entry> getEntry(int id) async {
    final res = await _get(Uri.parse('$baseUrl/api/Entry/$id'));
    if (res.statusCode != 200) throw ApiException('Failed to load entry (${res.statusCode})');
    return Entry.fromJson(jsonDecode(res.body));
  }

  Future<Entry> createEntry(Map<String, dynamic> body) async {
    final res = await _post(Uri.parse('$baseUrl/api/Entry'), jsonEncode(body));
    if (res.statusCode != 201) {
      dev.log('createEntry failed: ${res.statusCode} ${res.body}', name: 'ApiService');
      throw ApiException('Failed to create entry (${res.statusCode})');
    }
    return Entry.fromJson(jsonDecode(res.body));
  }

  Future<Entry> updateEntry(int id, Map<String, dynamic> body) async {
    final res = await _put(Uri.parse('$baseUrl/api/Entry/$id'), jsonEncode(body));
    if (res.statusCode != 200) throw ApiException('Failed to update entry (${res.statusCode})');
    return Entry.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteEntry(int id) async {
    final res = await _delete(Uri.parse('$baseUrl/api/Entry/$id'));
    if (res.statusCode != 204) throw ApiException('Failed to delete entry (${res.statusCode})');
  }

  Future<EntrySummary> getSummary({
    DateTime? from,
    DateTime? to,
    int? category,
    int? type,
    int? paymentType,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from.toIso8601String().split('T')[0];
    if (to != null) params['to'] = to.toIso8601String().split('T')[0];
    if (category != null) params['category'] = category.toString();
    if (type != null) params['type'] = type.toString();
    if (paymentType != null) params['paymentType'] = paymentType.toString();

    final uri = Uri.parse('$baseUrl/api/Entry/summary').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await _get(uri);
    if (res.statusCode != 200) throw ApiException('Failed to load summary (${res.statusCode})');
    return EntrySummary.fromJson(jsonDecode(res.body));
  }

  Future<TrialBalanceResponse> getTrialBalance({int? year, int? month, int? bsYear, int? bsMonth}) async {
    final params = <String, String>{};
    if (year != null && month != null) {
      params['year'] = year.toString();
      params['month'] = month.toString();
    }
    if (bsYear != null) params['bsYear'] = bsYear.toString();
    if (bsMonth != null) params['bsMonth'] = bsMonth.toString();
    final uri = Uri.parse('$baseUrl/api/Entry/trial-balance').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await _get(uri);
    if (res.statusCode != 200) throw ApiException('Failed to load trial balance (${res.statusCode})');
    return TrialBalanceResponse.fromJson(jsonDecode(res.body));
  }

  Future<List<CategoryTotal>> getCategoryTotals({int? type}) async {
    final params = <String, String>{};
    if (type != null) params['type'] = type.toString();

    final uri = Uri.parse('$baseUrl/api/Entry/by-category').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await _get(uri);
    if (res.statusCode != 200) throw ApiException('Failed to load category totals (${res.statusCode})');
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => CategoryTotal.fromJson(e)).toList();
  }

  Future<List<EntryGroup>> getGrouped({
    String period = 'month',
    DateTime? from,
    DateTime? to,
int? category,
    int? type,
    int? paymentType,
  }) async {
    final params = <String, String>{'period': period};
    if (from != null) params['from'] = from.toIso8601String().split('T')[0];
    if (to != null) params['to'] = to.toIso8601String().split('T')[0];
    if (category != null) params['category'] = category.toString();
    if (type != null) params['type'] = type.toString();
    if (paymentType != null) params['paymentType'] = paymentType.toString();

    final uri = Uri.parse('$baseUrl/api/Entry/grouped').replace(queryParameters: params);
    final res = await _get(uri);
    if (res.statusCode != 200) throw ApiException('Failed to load groups (${res.statusCode})');
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => EntryGroup.fromJson(e)).toList();
  }
}
