class PendingCapture {
  final String path;
  final DateTime capturedAt;

  PendingCapture({required this.path, required this.capturedAt});
}

class PendingStore {
  static final PendingStore _instance = PendingStore._();
  factory PendingStore() => _instance;
  PendingStore._();

  final List<PendingCapture> _items = [];

  List<PendingCapture> get items => List.unmodifiable(_items);
  int get length => _items.length;

  void add(PendingCapture capture) {
    _items.insert(0, capture);
  }

  void remove(String path) {
    _items.removeWhere((item) => item.path == path);
  }

  void clear() {
    _items.clear();
  }
}
