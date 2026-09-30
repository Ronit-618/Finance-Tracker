import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'date_display.dart';

/// Formats a v2 record's date honouring the AD/BS setting.
String formatRecordDate(
    BuildContext context, WidgetRef ref, DateTime date, String? bsDate) {
  return formatDateParts(ref, date, bsDate);
}

/// A label/value row for detail cards (Saving / Loan).
class RecordDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const RecordDetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// Screenshot preview for v2 records, with the runtime-permission prompt that
/// Android 11+ requires (bug #29 lesson) and a full-screen viewer callback.
class RecordScreenshot extends StatelessWidget {
  final String? path;
  final void Function(String path) onView;

  const RecordScreenshot({super.key, required this.path, required this.onView});

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return Row(
        children: [
          Icon(Icons.image_not_supported,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            'No screenshot attached',
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return StatefulBuilder(
      builder: (ctx, setInnerState) => FutureBuilder<bool>(
        future: Permission.manageExternalStorage.isGranted,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }

          final granted = snap.data ?? false;
          if (!granted) {
            return Container(
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestureDetector(
                onTap: () async {
                  final status =
                      await Permission.manageExternalStorage.request();
                  if (status.isGranted) setInnerState(() {});
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Tap to grant file access to view screenshot',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return GestureDetector(
            onTap: () => onView(path!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(path!),
                height: 240,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, error, _) {
                  debugPrint('Image.file error: $error');
                  return Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('Screenshot unavailable',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13)),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
