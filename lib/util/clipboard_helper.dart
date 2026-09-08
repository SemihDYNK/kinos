import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/util/localization_helper.dart';

extension ClipboardHelper on BuildContext {
  Future<void> copyToClipboard(String value, {String? customMessage}) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      KinosSnack.show(
        customMessage ?? localized.copiedToClipboard,
        context: this,
      );
    }
  }
}
