import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../providers/settings_providers.dart';

/// Formats any record's date honouring the app-wide AD/BS setting.
/// [bsDate] is the backend's pre-rendered Bikram Sambat label (e.g. "14 Ashwin 2083").
String formatDateParts(WidgetRef ref, DateTime date, String? bsDate) {
  final mode = ref.watch(dateFormatProvider);
  if (mode == DateFormatMode.bs && bsDate != null && bsDate.isNotEmpty) {
    return bsDate;
  }
  return DateFormat('MMM dd, yyyy').format(date);
}

String formatDate(WidgetRef ref, Entry entry) =>
    formatDateParts(ref, entry.date, entry.bsDate);

String formatDateShort(WidgetRef ref, Entry entry) {
  final mode = ref.watch(dateFormatProvider);
  if (mode == DateFormatMode.bs && entry.bsDate != null) {
    return entry.bsDate!;
  }
  return DateFormat('MMM dd').format(entry.date);
}

/// Displays a date from any v1 or v2 record. Pass [entry] for a v1 Entry, or
/// [date] + [bsDate] for Saving/Loan records.
class DateDisplay extends ConsumerWidget {
  final Entry? entry;
  final DateTime? date;
  final String? bsDate;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const DateDisplay({
    super.key,
    this.entry,
    this.date,
    this.bsDate,
    this.style,
    this.maxLines,
    this.overflow,
  }) : assert(entry != null || date != null,
            'Provide either an Entry or a date');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = entry?.date ?? date!;
    final bs = entry?.bsDate ?? bsDate;
    return Text(
      formatDateParts(ref, d, bs),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
