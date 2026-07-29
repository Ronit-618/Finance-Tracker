import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../models/entry.dart';
import '../models/entry_summary.dart';
import '../models/entry_group.dart';

class ApiService {
  final String baseUrl;

  ApiService(this.baseUrl);

  Future<List<Entry>> getEntries({
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

    final uri = Uri.parse('$baseUrl/api/Entry').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load entries');

    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => Entry.fromJson(e)).toList();
  }

  Future<Entry> getEntry(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/Entry/$id'));
    if (res.statusCode != 200) throw Exception('Failed to load entry');
    return Entry.fromJson(jsonDecode(res.body));
  }

  Future<Entry> createEntry(Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/Entry'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 201) {
      dev.log('createEntry failed: ${res.statusCode} ${res.body}', name: 'ApiService');
      throw Exception('Failed to create entry');
    }
    return Entry.fromJson(jsonDecode(res.body));
  }

  Future<Entry> updateEntry(int id, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/Entry/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) throw Exception('Failed to update entry');
    return Entry.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteEntry(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/Entry/$id'));
    if (res.statusCode != 204) throw Exception('Failed to delete entry');
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
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load summary');
    return EntrySummary.fromJson(jsonDecode(res.body));
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
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load groups');
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => EntryGroup.fromJson(e)).toList();
  }
}
