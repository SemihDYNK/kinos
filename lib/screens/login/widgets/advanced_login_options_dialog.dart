import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/screens/login/widgets/login_focus_action.dart';
import 'package:kinos/screens/settings/widgets/settings_message_box.dart';
import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

Future<String?> showAdvancedLoginOptionsDialog(BuildContext context,
    {String? initialSeerrUrl}) async {
  return await showDialog<String>(
    context: context,
    builder: (context) =>
        _AdvancedLoginOptionsDialog(initialSeerrUrl: initialSeerrUrl),
  );
}

class _AdvancedLoginOptionsDialog extends ConsumerStatefulWidget {
  final String? initialSeerrUrl;

  const _AdvancedLoginOptionsDialog({this.initialSeerrUrl});

  @override
  ConsumerState<_AdvancedLoginOptionsDialog> createState() =>
      _AdvancedLoginOptionsDialogState();
}

class _AdvancedLoginOptionsDialogState
    extends ConsumerState<_AdvancedLoginOptionsDialog> {
  late final TextEditingController seerrUrlController =
      TextEditingController(text: widget.initialSeerrUrl ?? '');
  bool _probing = false;
  String? _warning;

  @override
  void dispose() {
    seerrUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpad = AdaptiveLayout.inputDeviceOf(context) == InputDevice.dPad;
    return GlassAlertDialog(
      title: Row(
        children: [
          const Icon(IconsaxPlusLinear.setting_3),
          const SizedBox(width: AppSpacing.sm),
          Text(context.localized.advanced),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLoginLayout.dialogWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.md,
          children: [
            if (_warning != null)
              SettingsMessageBox(_warning!, messageType: MessageType.warning),
            OutlinedTextField(
              controller: seerrUrlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autoFillHints: const [AutofillHints.url],
              autocorrect: false,
              label: context.localized.seerrServer,
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        LoginFocusAction(
          autofocus: dpad,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.localized.cancel),
          ),
        ),
        LoginFocusAction(
          child: FilledButton(
            onPressed: _probing ? null : _save,
            child: _probing
                ? const SizedBox.square(
                    dimension: AppLoginLayout.spinner,
                    child: CircularProgressIndicator(
                      strokeWidth: AppLoginLayout.progressStroke,
                      strokeCap: StrokeCap.round,
                    ),
                  )
                : Text(context.localized.save),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final url = seerrUrlController.text.trim();
    if (url.isEmpty) {
      Navigator.of(context).pop(url);
      return;
    }
    setState(() {
      _probing = true;
      _warning = null;
    });
    try {
      final result = await probeAndNormalizeUrl(url, probeSeerrUrl);
      if (!mounted) return;
      if (result.probed) {
        Navigator.of(context).pop(result.url);
      } else {
        seerrUrlController.text = result.url;
        _warning = context.localized.seerrUrlSchemeWarning;
      }
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }
}
