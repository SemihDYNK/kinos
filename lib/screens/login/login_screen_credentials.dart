import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/login_screen_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/auth_provider.dart';
import 'package:kinos/providers/discovery_provider.dart';
import 'package:kinos/providers/seerr_api_provider.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/login/lock_screen.dart';
import 'package:kinos/screens/login/login_code_dialog.dart';
import 'package:kinos/screens/login/login_user_grid.dart';
import 'package:kinos/screens/login/widgets/add_server_dialog.dart';
import 'package:kinos/screens/login/widgets/advanced_login_options_dialog.dart';
import 'package:kinos/screens/login/widgets/connect_link_dialog.dart';
import 'package:kinos/screens/login/widgets/login_account_actions.dart';
import 'package:kinos/screens/login/widgets/login_focus_action.dart';
import 'package:kinos/screens/login/widgets/login_server_step.dart';
import 'package:kinos/screens/login/widgets/login_step_parts.dart';
import 'package:kinos/screens/shared/animated_fade_size.dart';
import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/screens/shared/passcode_input.dart';
import 'package:kinos/services/local_network_permission.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/auth_service.dart';
import 'package:kinos/util/deep_link_helper.dart';
import 'package:kinos/util/kinos_config.dart';
import 'package:kinos/util/localization_helper.dart';

enum _LoginStep {
  server,
  account,
}

class LoginScreenCredentials extends ConsumerStatefulWidget {
  final AuthLinkData? authLinkData;
  const LoginScreenCredentials({
    this.authLinkData,
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _LoginScreenCredentialsState();
}

class _LoginScreenCredentialsState
    extends ConsumerState<LoginScreenCredentials> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  _LoginStep _step = _LoginStep.server;
  String? _selectedServerAddress;
  String? _connectingAddress;
  String? _serverError;
  String? _credentialsError;
  bool _loggingIn = false;

  @override
  void initState() {
    super.initState();
    _step = ref.read(authProvider).serverLoginModel == null
        ? _LoginStep.server
        : _LoginStep.account;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final link = widget.authLinkData;
      if (link != null) {
        _loginUsingAuthLink(link);
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(authProvider.select((value) => value.accounts));
    final serverCredentials =
        ref.watch(authProvider.select((value) => value.serverLoginModel));
    final loading = ref.watch(authProvider.select((value) => value.loading));
    final hasBaseUrl =
        ref.watch(authProvider.select((value) => value.hasBaseUrl));
    final authError =
        ref.watch(authProvider.select((value) => value.errorMessage));
    final hasQuickConnect = serverCredentials?.hasQuickConnect ?? false;

    final step = _step == _LoginStep.account && serverCredentials == null
        ? _LoginStep.server
        : _step;
    final allowDiscovery =
        !hasBaseUrl && KinosConfig.baseUrl?.isNotEmpty != true && !kIsWeb;
    final discoveredServers = allowDiscovery
        ? ref.watch(serverDiscoveryProvider)
        : const AsyncData<List<DiscoveryInfo>>(<DiscoveryInfo>[]);

    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: AppLoginLayout.contentWidth),
        child: AnimatedFadeSize(
          child: KeyedSubtree(
            key: ValueKey(step),
            child: switch (step) {
              _LoginStep.server => LoginServerStep(
                  savedServers: _savedServers(accounts),
                  discoveredServers: discoveredServers,
                  onServerSelected: _onServerSelected,
                  onAddServer: _openAddServer,
                  onRetryDiscovery: () =>
                      ref.invalidate(serverDiscoveryProvider),
                  onRequestPermission: _requestDiscoveryPermission,
                  onBackToProfiles: accounts.isNotEmpty && !hasBaseUrl
                      ? () => ref.read(authProvider.notifier).goUserSelect()
                      : null,
                  connectingAddress: _connectingAddress,
                  selectedAddress: _selectedServerAddress,
                  errorMessage: _connectingAddress == null
                      ? (_serverError ?? authError)
                      : _serverError,
                  allowDiscovery: allowDiscovery,
                ),
              _LoginStep.account => _buildAccountStep(
                  context,
                  serverCredentials: serverCredentials!,
                  loading: loading,
                  hasBaseUrl: hasBaseUrl,
                  hasQuickConnect: hasQuickConnect,
                ),
            },
          ),
        ),
      ),
    );
  }

  List<DiscoveryInfo> _savedServers(List<AccountModel> accounts) {
    return [
      for (final account in accounts)
        DiscoveryInfo(
          id: account.credentials.serverId,
          name: account.credentials.serverName,
          address: account.credentials.url,
          endPointAddress: null,
        ),
    ];
  }

  Widget _buildAccountStep(
    BuildContext context, {
    required ServerLoginModel serverCredentials,
    required bool loading,
    required bool hasBaseUrl,
    required bool hasQuickConnect,
  }) {
    final localized = context.localized;
    final tempCredentials = serverCredentials.tempCredentials;
    final serverName = tempCredentials.serverName.trim().isEmpty
        ? tempCredentials.url
        : tempCredentials.serverName.trim();
    final users = serverCredentials.accounts;
    final canGoBack = !hasBaseUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canGoBack)
          Align(
            alignment: Alignment.centerLeft,
            child: LoginFocusAction(
              onActivate: () => _goToServerStep(),
              child: TextButton.icon(
                key: const Key('login.backToServers'),
                onPressed: _goToServerStep,
                icon: const Icon(IconsaxPlusLinear.arrow_left_2),
                label: Text(localized.backToServers),
              ),
            ),
          ),
        LoginStepHeader(
          step: 2,
          total: 2,
          title: localized.loginAccountStepTitle,
          description: localized.loginAccountStepDescription(serverName),
        ),
        const SizedBox(height: AppSpacing.lg),
        LoginServerSummary(
          name: serverName,
          address: tempCredentials.url,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (loading || users.isNotEmpty) ...[
          LoginSectionLabel(localized.selectProfile),
          const SizedBox(height: AppSpacing.xs),
          AnimatedFadeSize(
            duration: AppDurations.selection,
            alignment: Alignment.centerLeft,
            child: loading
                ? LoginStatusBlock(
                    key: const Key('login.account.loading'),
                    showProgress: true,
                    title: localized.loading,
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: LoginUserGrid(
                      users: users,
                      onPressed: _selectUser,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        LoginSectionLabel(localized.loginCredentialsTitle),
        const SizedBox(height: AppSpacing.xs),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedTextField(
                controller: _usernameController,
                autoFocus: users.isEmpty,
                autoFillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                autocorrect: false,
                onChanged: (_) => setState(() => _credentialsError = null),
                label: localized.userName,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedTextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                autoFillHints: const [AutofillHints.password],
                keyboardType: TextInputType.visiblePassword,
                autocorrect: false,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (_canSubmit) _loginWithCredentials();
                },
                onChanged: (_) {
                  if (_credentialsError != null) {
                    setState(() => _credentialsError = null);
                  }
                },
                label: localized.password,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LoginFocusAction(
          onActivate: _canSubmit ? _loginWithCredentials : null,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('login.submit'),
              onPressed: _canSubmit ? _loginWithCredentials : null,
              child: _loggingIn
                  ? const SizedBox.square(
                      dimension: AppLoginLayout.spinner,
                      child: CircularProgressIndicator(
                        strokeWidth: AppLoginLayout.progressStroke,
                        strokeCap: StrokeCap.round,
                        color: AppColors.background,
                      ),
                    )
                  : Text(localized.login),
            ),
          ),
        ),
        if (_credentialsError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          LoginInlineError(_credentialsError!),
        ],
        const SizedBox(height: AppSpacing.xl),
        LoginAlternateMethods(
          onAuthLink: _openAuthLinkDialog,
          onQuickConnect: hasQuickConnect ? _openQuickConnect : null,
          onAdvanced: KinosConfig.seerrBaseUrl?.isNotEmpty == true
              ? null
              : _openAdvancedLoginOptions,
        ),
        if (serverCredentials.serverMessage?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            serverCredentials.serverMessage!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  bool get _canSubmit =>
      _usernameController.text.trim().isNotEmpty && !_loggingIn;

  void _goToServerStep() {
    if (!mounted) return;
    setState(() {
      _step = _LoginStep.server;
      _credentialsError = null;
    });
  }

  void _selectUser(AccountModel user) {
    _usernameController.text = user.name;
    _passwordController.text = '';
    setState(() => _credentialsError = null);
    _passwordFocus.requestFocus();
  }

  void _onServerSelected(DiscoveryInfo server) {
    _usernameController.clear();
    _passwordController.clear();
    _credentialsError = null;
    _selectServer(server);
  }

  Future<void> _selectServer(DiscoveryInfo server) async {
    if (_connectingAddress != null) return;
    setState(() {
      _connectingAddress = server.address;
      _selectedServerAddress = server.address;
      _serverError = null;
      _credentialsError = null;
    });

    final before = ref.read(authProvider).serverLoginModel;
    await ref.read(authProvider.notifier).setServer(server.address);
    if (!mounted) return;

    final state = ref.read(authProvider);
    final serverChanged = !identical(state.serverLoginModel, before);
    if (serverChanged &&
        state.serverLoginModel != null &&
        state.errorMessage == null) {
      setState(() {
        _connectingAddress = null;
        _step = _LoginStep.account;
      });
      return;
    }

    setState(() {
      _connectingAddress = null;
      _serverError =
          state.errorMessage ?? context.localized.serverConnectionFailed;
    });
  }

  Future<void> _openAddServer() async {
    final address = await showAddServerDialog(context);
    if (!mounted || address == null || address.trim().isEmpty) return;
    _usernameController.clear();
    _passwordController.clear();
    _credentialsError = null;
    await _selectServer(
      DiscoveryInfo(
        id: '',
        name: address,
        address: address,
        endPointAddress: null,
      ),
    );
  }

  Future<void> _requestDiscoveryPermission() async {
    var status = await requestLocalNetworkPermission();
    if (status == LocalNetworkPermissionStatus.denied) {
      await openLocalNetworkPermissionSettings();
    }
    if (mounted) {
      ref.invalidate(serverDiscoveryProvider);
    }
  }

  Future<void> _loginUsingAuthLink(AuthLinkData link) async {
    _usernameController.text = link.userName;
    _passwordController.text = link.password ?? '';
    setState(() => _serverError = null);

    await _selectServer(
      DiscoveryInfo(
        id: '',
        name: link.serverUrl,
        address: link.serverUrl,
        endPointAddress: null,
      ),
    );
    if (!mounted || ref.read(authProvider).serverLoginModel == null) return;

    if ((link.password ?? '').isNotEmpty) {
      await _loginWithCredentials();
    } else {
      _passwordFocus.requestFocus();
    }
  }

  void _openAuthLinkDialog() {
    showConnectLinkDialog(context, _loginUsingAuthLink);
  }

  Future<void> _openQuickConnect() async {
    final result = await ref.read(jellyApiProvider).quickConnectInitiate();
    if (!mounted) return;
    if (result.body == null) {
      KinosSnack.show(context.localized.quickConnectPostFailed,
          context: context);
      return;
    }
    await openLoginCodeDialog(
      context,
      quickConnectInfo: result.body!,
      onAuthenticated: (context, secret) async {
        context.pop();
        if (secret.isNotEmpty) {
          await _loginUsingSecret(secret);
        }
      },
    );
  }

  Future<void> _openAdvancedLoginOptions() async {
    final tempSeerrUrl =
        ref.read(authProvider.select((value) => value.tempSeerrUrl));
    final result = await showAdvancedLoginOptionsDialog(
      context,
      initialSeerrUrl: tempSeerrUrl,
    );
    if (result != null) {
      ref.read(authProvider.notifier).setTempSeerrUrl(result);
    }
  }

  Future<void> _loginWithCredentials() async {
    if (!_canSubmit) return;
    setState(() {
      _loggingIn = true;
      _credentialsError = null;
    });

    final response = await ref.read(authProvider.notifier).authenticateByName(
          _usernameController.text.trim(),
          _passwordController.text,
        );
    if (!mounted) return;

    if (response?.isSuccessful == false || response?.body == null) {
      setState(() {
        _loggingIn = false;
        _credentialsError = response?.isSuccessful == false
            ? '(${response?.base.statusCode}) ${response?.base.reasonPhrase ?? context.localized.loginFailed}'
            : context.localized.loginFailed;
      });
      return;
    }

    final tempSeerrUrl =
        ref.read(authProvider.select((value) => value.tempSeerrUrl));
    if (tempSeerrUrl != null && tempSeerrUrl.isNotEmpty) {
      await _tryAuthenticateSeerr(tempSeerrUrl);
    }

    if (context.mounted) {
      await loggedInGoToHome(context, ref);
    }
  }

  Future<void> _loginUsingSecret(String secret) async {
    setState(() {
      _loggingIn = true;
      _credentialsError = null;
    });
    final response = await KinosSnack.showResponse(
      ref.read(authProvider.notifier).authenticateUsingSecret(secret),
    );
    if (!mounted) return;
    if (response.isSuccess) {
      await loggedInGoToHome(context, ref);
      return;
    }
    setState(() {
      _loggingIn = false;
      _credentialsError = context.localized.loginFailed;
    });
  }

  Future<void> _tryAuthenticateSeerr(String seerrUrl) async {
    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      final effectiveSeerrUrl = KinosConfig.seerrBaseUrl ?? seerrUrl;
      ref.read(userProvider.notifier).setSeerrServerUrl(effectiveSeerrUrl);

      final tempCookie = ref
          .read(authProvider.select((value) => value.tempSeerrSessionCookie));
      final cookie = tempCookie ??
          await ref.read(seerrApiProvider).authenticateJellyfin(
                username: username,
                password: password,
              );

      ref.read(userProvider.notifier).setSeerrSessionCookie(cookie);
      ref.read(userProvider.notifier).setSeerrApiKey('');
      ref.read(authProvider.notifier).setTempSeerrSessionCookie(null);

      if (context.mounted) {
        KinosSnack.show(context.localized.seerrLoggedIn, context: context);
      }
    } catch (e, stackTrace) {
      log('Seerr authentication failed', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        KinosSnack.show(
          '${context.localized.seerrAuthenticateLocal}: $e',
          context: context,
        );
      }
    }
  }
}

Future<void> loggedInGoToHome(BuildContext context, WidgetRef ref) async {
  ref.read(lockScreenActiveProvider.notifier).update((state) => false);
  if (context.mounted) {
    await context.router.replaceAll([const DashboardRoute()]);
  }
}

Future<void> _handleLogin(
    BuildContext context, AccountModel user, WidgetRef ref) async {
  await ref.read(authProvider.notifier).switchUser();
  await ref.read(sharedUtilityProvider).updateAccountInfo(user.copyWith(
        lastUsed: DateTime.now(),
      ));
  ref
      .read(userProvider.notifier)
      .updateUser(user.copyWith(lastUsed: DateTime.now()));

  await ensureLocalNetworkPermissions(
    [user.credentials.url, user.credentials.localUrl],
    context,
  );

  loggedInGoToHome(context, ref);
}

void tapLoggedInAccount(
    BuildContext context, AccountModel user, WidgetRef ref) async {
  Future<void> loginFunction() => _handleLogin(context, user, ref);
  switch (user.authMethod) {
    case Authentication.autoLogin:
      loginFunction();
      break;
    case Authentication.biometrics:
      final authenticated = await AuthService.authenticateUser(context, user);
      if (authenticated) {
        loginFunction();
      }
      break;
    case Authentication.passcode:
      if (context.mounted) {
        showPassCodeDialog(context, (newPin) {
          if (newPin == user.localPin) {
            loginFunction();
          } else {
            KinosSnack.show(context.localized.incorrectPinTryAgain,
                context: context);
          }
        });
      }
      break;
    case Authentication.none:
      loginFunction();
      break;
  }
}
