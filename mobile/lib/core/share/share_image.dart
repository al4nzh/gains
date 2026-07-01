import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Rect shareOriginFromContext(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  return const Rect.fromLTWH(0, 0, 1, 1);
}

Future<void> sharePngBytes(
  Uint8List bytes, {
  required String fileName,
  String? text,
  Rect? sharePositionOrigin,
}) async {
  final origin = sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 1, 1);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png')],
      fileNameOverrides: [fileName],
      text: text,
      sharePositionOrigin: origin,
    ),
  );
}
