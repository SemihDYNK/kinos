import 'package:kinos/providers/incognito_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/shared/media/external_urls.dart' as urls;
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'anilist_account.dart';
import 'anilist_client.dart';
import 'anilist_runtime.dart';
import 'anilist_ui_service.dart';

Future<void> showAnilistAccountDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _AccountDialog());

class _AccountDialog extends ConsumerStatefulWidget {
  const _AccountDialog();
  @override
  ConsumerState<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<_AccountDialog> {
  final token = TextEditingController();
  bool busy = false;
  String? error;
  int? httpStatus;
  @override
  void dispose() {
    token.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      httpStatus = null;
    });
    try {
      await task();
      if (mounted) token.clear();
    } on AnilistUnauthorized {
      if (mounted) error = 'auth';
    } on AnilistAccountSaveFailed {
      if (mounted) error = 'storage';
    } on AnilistUnavailable catch (failure) {
      if (mounted) {
        error = 'connection';
        httpStatus = failure.statusCode;
      }
    } on Exception {
      if (mounted) error = 'connection';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
        userProvider.select(
            (u) => (u?.id, u?.credentials.serverId, u?.credentials.url)),
        (a, b) {
      if (a != b && mounted) Navigator.of(context).pop();
    });
    final connection = ref.watch(anilistConnectionProvider);
    final status = ref.watch(anilistSyncStatusProvider);
    final actions = ref.watch(anilistUiServiceProvider);
    final l = context.localized;
    final incognito = ref.watch(incognitoProvider);
    String message(String? value) => switch (value) {
          'auth' => l.anilistAuthError,
          'mapping' => l.anilistMappingError,
          _ => l.anilistNetworkError
        };
    String connectionMessage() => switch (error) {
          'auth' => l.anilistTokenRejected,
          'storage' => l.anilistAccountSaveError,
          _ => l.anilistConnectFailed(
              httpStatus == null ? 'network' : 'HTTP $httpStatus')
        };
    return GlassDialog(
        constraints: BoxConstraints(
            maxWidth: AppPageLayout.compactWidth,
            maxHeight: MediaQuery.sizeOf(context).height - AppSpacing.xxl * 2),
        child: FocusTraversalGroup(
            child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.anilistAccount,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.md),
                      Flexible(
                          child: SingleChildScrollView(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                            connection.when(
                                loading: () => const LinearProgressIndicator(),
                                error: (_, __) => Column(children: [
                                      Text(l.anilistUnavailable),
                                      TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => ref.invalidate(
                                                  anilistConnectionProvider),
                                          child: Text(l.anilistRetry))
                                    ]),
                                data: (account) => Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                              account?.name ??
                                                  l.anilistDisconnected,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                          if (account != null) ...[
                                            SwitchListTile.adaptive(
                                                contentPadding: EdgeInsets.zero,
                                                title:
                                                    Text(l.anilistSyncEnabled),
                                                subtitle: Text(
                                                    l.anilistSyncExplanation),
                                                value: account.enabled,
                                                onChanged: busy
                                                    ? null
                                                    : (value) => run(() =>
                                                        actions.setEnabled(
                                                            value))),
                                            if (account.enabled)
                                              Text(incognito
                                                  ? l.anilistIncognitoPaused
                                                  : status == null
                                                      ? l.anilistSyncReady
                                                      : message(status)),
                                            Align(
                                                alignment: Alignment.centerLeft,
                                                child: TextButton(
                                                    onPressed: busy
                                                        ? null
                                                        : () => run(
                                                            actions.disconnect),
                                                    child: Text(
                                                        l.anilistDisconnect))),
                                          ],
                                          if (account == null ||
                                              status == 'auth') ...[
                                            const SizedBox(
                                                height: AppSpacing.md),
                                            Text(l.anilistAuthInstructions),
                                            Align(
                                                alignment: Alignment.centerLeft,
                                                child: OutlinedButton.icon(
                                                    onPressed: busy
                                                        ? null
                                                        : () => run(() =>
                                                            urls.launchUrl(
                                                                context,
                                                                anilistAuthorizationUri()
                                                                    .toString())),
                                                    icon: const Icon(
                                                        Icons.open_in_new),
                                                    label: Text(l
                                                        .anilistConnectBrowser))),
                                            const SizedBox(
                                                height: AppSpacing.sm),
                                            TextField(
                                                controller: token,
                                                obscureText: true,
                                                enableSuggestions: false,
                                                autocorrect: false,
                                                decoration: InputDecoration(
                                                    labelText:
                                                        l.anilistAccessToken),
                                                onSubmitted: busy
                                                    ? null
                                                    : (_) => run(() => actions
                                                        .connect(token.text))),
                                            Align(
                                                alignment: Alignment.centerLeft,
                                                child: FilledButton(
                                                    onPressed: busy
                                                        ? null
                                                        : () => run(() =>
                                                            actions.connect(
                                                                token.text)),
                                                    child: Text(
                                                        l.anilistConnect))),
                                          ],
                                        ])),
                            if (error != null)
                              Padding(
                                  padding:
                                      const EdgeInsets.only(top: AppSpacing.sm),
                                  child: Text(connectionMessage())),
                            if (busy) const LinearProgressIndicator(),
                          ]))),
                      const SizedBox(height: AppSpacing.md),
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(l.close))),
                    ]))));
  }
}
