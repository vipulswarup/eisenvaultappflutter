import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ShareUtils {
  static Future<void> shareXFiles(
    BuildContext context, {
    required List<XFile> files,
    String? text,
    String? subject,
  }) async {
    await Share.shareXFiles(
      files,
      text: text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin(context),
    );
  }

  static Future<void> share(
    BuildContext context, {
    required String text,
    String? subject,
  }) async {
    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin(context),
    );
  }

  /// iOS and iPadOS require a non-zero anchor rect for the share sheet.
  static Rect sharePositionOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final origin = box.localToGlobal(Offset.zero);
      final size = box.size;
      if (size.width > 0 && size.height > 0) {
        return origin & size;
      }
    }

    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final top = mediaQuery.padding.top;
    return Rect.fromCenter(
      center: Offset(size.width - 24, top + kToolbarHeight / 2),
      width: 1,
      height: 1,
    );
  }
}
