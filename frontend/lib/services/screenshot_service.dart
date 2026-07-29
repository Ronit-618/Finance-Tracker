import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ScreenshotService {
  static const String _baseDir = '/storage/emulated/0/FinanceTracker/Transaction/Screenshot';

  static Future<bool> checkAndRequestPermission(BuildContext context) async {
    if (await Permission.manageExternalStorage.isGranted) return true;

    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('File Access Required'),
          content: const Text(
            'FinanceTracker needs file access to save your transaction screenshots.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }

    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  static Future<String> saveScreenshotToPublicFolder(File sourceFile) async {
    final folder = Directory(_baseDir);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = sourceFile.path.split('.').last;
    final destPath = '$_baseDir/$timestamp.$ext';
    await sourceFile.copy(destPath);
    return destPath;
  }
}