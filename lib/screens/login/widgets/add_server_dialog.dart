import 'package:flutter/material.dart';

import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/screens/login/widgets/login_focus_action.dart';
import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

Future<String?> showAddServerDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _AddServerDialog(),
  );
}

class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog();

  @override
  State<_AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<_AddServerDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = context.localized.serverAddressRequired);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppLoginLayout.dialogWidth),
      child: GlassAlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(context.localized.addServerTitle)),
            LoginFocusAction(
              onActivate: () => Navigator.of(context).pop(),
              child: IconButton(
                tooltip: context.localized.close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(IconsaxPlusBold.close_square),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.localized.addServerDescription,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedTextField(
              controller: _controller,
              autoFocus: true,
              autoFillHints: const [AutofillHints.url],
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              label: context.localized.serverAddress,
              placeHolder: context.localized.serverAddressHint,
              errorText: _error,
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
        scrollable: true,
        actions: [
          LoginFocusAction(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.localized.cancel),
            ),
          ),
          LoginFocusAction(
            child: FilledButton(
              onPressed: _submit,
              child: Text(context.localized.connect),
            ),
          ),
        ],
      ),
    );
  }
}
