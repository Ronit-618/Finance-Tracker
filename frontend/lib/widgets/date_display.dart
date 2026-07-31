import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../providers/settings_providers.dart';

String formatDate(WidgetRef ref, Entry entry) {
  final mode = ref.watch(dateFormatProvider);
  if (mode == DateFormatMode.bs && entry.bsDate != null) {
    return entry.bsDate!;
  }
  return DateFormat('MMM dd, yyyy').format(entry.date);
}

String formatDateShort(WidgetRef ref, Entry entry) {
  final mode = ref.watch(dateFormatProvider);
  if (mode == DateFormatMode.bs && entry.bsDate != null) {
    return entry.bsDate!;
  }
  return DateFormat('MMM dd').format(entry.date);
}

class DateDisplay extends ConsumerWidget {
  final Entry entry;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const DateDisplay({super.key, required this.entry, this.style, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(formatDate(ref, entry), style: style, maxLines: maxLines, overflow: overflow);
  }
}
