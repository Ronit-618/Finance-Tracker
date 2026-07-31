# finance_tracker

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## Bug Fix Log

### `ref.listen` assertion failure (`ConsumerWidget.build` restriction)

**Symptom:** Runtime crash at app startup:

```
Error: "ref.listen can only be used within the build method of a
ConsumerWidget" — 'package:flutter_riverpod/src/consumer.dart' assertion
failure.
```

**Root cause:** `ref.listen` was being called inside `initState()` of the
Reports screen's `ConsumerState`, which is forbidden. Riverpod requires
`ref.listen` to be called during `build()`, every build (it internally only
re-subscribes when the listener changes).

**Invalid call location:**

`lib/screens/reports_screen.dart:56` (original)

```dart
@override
void initState() {
  super.initState();
  _tabController = TabController(length: 2, vsync: this);
  final now = DateTime.now();
  _adYear = now.year;
  _adMonth = now.month;
  final nowBs = now.toNepaliDateTime();
  _bsYear = nowBs.year;
  _bsMonth = nowBs.month;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(currentDrawerDestinationProvider.notifier).state = DrawerDestination.reports;
  });
  ref.listen<DateFormatMode>(dateFormatProvider, (prev, next) {   // BUG
    if (prev != next) _loadData();
  });
  _loadData();
}
```

**Fix:** Move the `ref.listen` call out of `initState()` into `build()`,
right after the existing `ref.watch(dateFormatProvider)`. The enclosing
widget is already a `ConsumerStatefulWidget`, so `build()` has direct
access to `ref`.

**Fixed:** `lib/screens/reports_screen.dart:117-120`

```dart
@override
Widget build(BuildContext context) {
  ref.watch(dateFormatProvider);
  ref.listen<DateFormatMode>(dateFormatProvider, (prev, next) {   // FIXED
    if (prev != next) _loadData();
  });
  return Scaffold(...);
}
```

**Verification:** `flutter analyze` passes with no issues. The listener
re-fires on every date-format toggle in Settings and the Reports BS/AD
selector, reloading report data as intended — but now without the
assertion crash.
