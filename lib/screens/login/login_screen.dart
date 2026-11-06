import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/login_screen_model.dart';
import 'package:kinos/providers/auth_provider.dart';
import 'package:kinos/screens/login/login_edit_user.dart';
import 'package:kinos/screens/login/login_screen_credentials.dart';
import 'package:kinos/screens/login/login_user_grid.dart';
import 'package:kinos/screens/login/widgets/login_focus_action.dart';
import 'package:kinos/screens/shared/animated_fade_size.dart';
import 'package:kinos/screens/shared/kinos_logo.dart';
import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/screens/shared/route_wrapper.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/deep_link_helper.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/keyboard/slide_in_keyboard.dart';
import 'package:kinos/widgets/navigation_scaffold/components/kinos_app_bar.dart';

@RoutePage()
class LoginScreen extends ConsumerStatefulWidget {
  final String? authLink;
  const LoginScreen({
    @QueryParam() this.authLink,
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginScreen> {
  bool editUsersMode = false;

  AuthLinkData? parsedAuthLink;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).initModel();
      if (widget.authLink != null) {
        final data = AuthLinkData.parse(widget.authLink!);
        if (data != null) {
          initLink(data);
        } else {
          KinosSnack.show(context.localized.invalidAuthLink);
        }
      }
    });
  }

  Future<void> initLink(AuthLinkData value) async {
    parsedAuthLink = value;
    ref.read(authProvider.notifier).addNewUser();
  }

  @override
  Widget build(BuildContext context) {
    final screen = ref.watch(authProvider.select((value) => value.screen));
    final accounts = ref.watch(authProvider.select((value) => value.accounts));
    return RouteWrapper(
      child: CustomKeyboardWrapper(
        child: Scaffold(
          appBar: KinosAppBar(
            isDesktop: AdaptiveLayout.of(context).isDesktop,
          ),
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLoginLayout.maxWidth,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: MediaQuery.paddingOf(context).add(
                  const EdgeInsets.all(AppSpacing.screenPadding),
                ),
                children: [
                  const KinosLogo(),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedFadeSize(
                    child: switch (screen) {
                      LoginScreenType.login ||
                      LoginScreenType.code =>
                        LoginScreenCredentials(
                          authLinkData: parsedAuthLink,
                        ),
                      _ => Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            LoginUserGrid(
                              users: accounts,
                              editMode: editUsersMode,
                              onPressed: (user) =>
                                  tapLoggedInAccount(context, user, ref),
                              onLongPress: (user) =>
                                  openUserEditDialogue(context, user),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _profileActions(context, accounts.length),
                          ],
                        ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileActions(BuildContext context, int accountCount) {
    final localized = context.localized;
    void onAdd() => ref.read(authProvider.notifier).addNewUser();
    void onToggleEdit() => setState(() => editUsersMode = !editUsersMode);
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        LoginFocusAction(
          onActivate: onAdd,
          child: OutlinedButton.icon(
            key: const Key('new_user_button'),
            onPressed: onAdd,
            icon: const Icon(IconsaxPlusLinear.add_square),
            label: Text(localized.addProfile),
          ),
        ),
        if (accountCount > 0)
          LoginFocusAction(
            onActivate: onToggleEdit,
            child: OutlinedButton.icon(
              key: const Key('edit_user_button'),
              onPressed: onToggleEdit,
              icon: Icon(
                editUsersMode
                    ? IconsaxPlusBold.tick_circle
                    : IconsaxPlusLinear.edit_2,
              ),
              label: Text(
                editUsersMode
                    ? localized.finishEditingProfiles
                    : localized.editProfiles,
              ),
            ),
          ),
      ],
    );
  }

  void openUserEditDialogue(BuildContext context, AccountModel user) {
    showDialog(
      context: context,
      builder: (context) => LoginEditUser(
        user: user,
        onTapServer: (value) {
          ref.read(authProvider.notifier).setServer(value);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
