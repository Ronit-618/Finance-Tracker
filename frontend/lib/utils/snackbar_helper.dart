import 'package:flutter/material.dart';

void showSuccessSnackBar(BuildContext context, String message, {Color backgroundColor = Colors.green}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: backgroundColor,
      content: Text(message, style: const TextStyle(color: Colors.white)),
      duration: const Duration(seconds: 2),
    ),
  );
}
