import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/login/widgets/login_icon.dart';
import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/screens/settings/widgets/settings_message_box.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> openQuickConnectDialog(
  BuildContext context,
) async {
  return showDialog(
      context: context, builder: (context) => const QuickConnectDialog());
}

class QuickConnectDialog extends ConsumerStatefulWidget {
  const QuickConnectDialog({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _QuickConnectDialogState();
}

class _QuickConnectDialogState extends ConsumerState<QuickConnectDialog> {
  final controller = TextEditingController();
  bool loading = false;
  String? error;
  String? success;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    return GlassAlertDialog(
      title: Text(
        context.localized.quickConnectTitle,
        textAlign: TextAlign.center,
      ),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            context.localized.quickConnectAction,
            textAlign: TextAlign.center,
          ),
          if (user != null) SizedBox(child: LoginIcon(user: user)),
          Flexible(
            child: OutlinedTextField(
              label: context.localized.code,
              controller: controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.go,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    error = null;
                    success = null;
                  });
                }
              },
              onSubmitted: (value) => tryLogin(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          AnimatedContainer(
            duration: AppDurations.selection,
            child: error != null || success != null
                ? SettingsMessageBox(
                    success ?? error ?? "",
                    key: Key(context.localized.error),
                    messageType: success == null ? MessageType.error : MessageType.info,
                  )
                : null,
          ),
          FilledButton(
            onPressed: loading ? null : () => tryLogin(),
            child: loading
                ? const SizedBox.square(
                    child: CircularProgressIndicator(),
                    dimension: 16.0,
                  )
                : Text(context.localized.login),
          )
        ],
      ),
    );
  }

  Future<void> tryLogin() async {
    setState(() {
      error = null;
      loading = true;
    });
    final response =
        await ref.read(userProvider.notifier).quickConnect(controller.text);
    if (response.isSuccessful) {
      setState(
        () {
          error = null;
          success = context.localized.loggedIn;
        },
      );
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pop();
    } else {
      if (controller.text.isEmpty) {
        error = context.localized.quickConnectInputACode;
      } else {
        error = context.localized.quickConnectWrongCode;
      }
    }
    loading = false;
    setState(
      () {},
    );
    controller.text = "";
  }
}
