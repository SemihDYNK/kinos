import 'package:flutter/material.dart';

import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/screens/login/widgets/login_focus_action.dart';
import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/deep_link_helper.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

Future<void> showConnectLinkDialog(
  BuildContext context,
  Function(AuthLinkData link) initLink,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ConnectLinkDialog(initLink: initLink),
  );
}

class _ConnectLinkDialog extends StatefulWidget {
  const _ConnectLinkDialog({required this.initLink});

  final Function(AuthLinkData link) initLink;

  @override
  State<_ConnectLinkDialog> createState() => _ConnectLinkDialogState();
}

class _ConnectLinkDialogState extends State<_ConnectLinkDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final data = AuthLinkData.parse(_controller.text.trim());
    if (data == null) {
      setState(() => _error = context.localized.invalidAuthLink);
      return;
    }
    widget.initLink(data);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppLoginLayout.dialogWidth),
      child: GlassAlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(context.localized.connectWithAuthLink)),
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
            OutlinedTextField(
              controller: _controller,
              autoFocus: true,
              textInputAction: TextInputAction.go,
              placeHolder: context.localized.pasteKinosAuthLink,
              errorText: _error,
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.localized.authLinkDesc,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
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
