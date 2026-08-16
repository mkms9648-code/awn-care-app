import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// بينسخ نص للحافظة ويوري تأكيد بسيط (SnackBar).
Future<void> copyToClipboard(BuildContext context, String text, {String label = 'Copied'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label: $text'), duration: const Duration(seconds: 2)),
  );
}
