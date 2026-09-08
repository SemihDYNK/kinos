import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kinos/screens/shared/fladder_notification_overlay.dart';
import 'package:kinos/util/localization_helper.dart';

extension ClipboardHelper on BuildContext {
  Future<void> copyToClipboard(String value, {String? customMessage}) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      FladderSnack.show(
        customMessage ?? localized.copiedToClipboard,
        context: this,
      );
    }
  }
}
