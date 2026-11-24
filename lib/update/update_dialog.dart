import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/widget/markdown.dart';

import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/update_provider.dart';
import 'package:kinos/screens/shared/media/external_urls.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/update_checker.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

import 'kinos_updater.dart';

/// La version que l'utilisateur a choisi d'ignorer.
const _skippedKey = 'kinosSkippedUpdate';

/// Propose une fois par lancement la dernière version, sauf si elle a été
/// ignorée. Appelé depuis l'accueil : jamais pendant une lecture. Seulement
/// là où des versions sont publiées (Windows, macOS).
void listenForUpdates(WidgetRef ref, BuildContext Function() context) {
  if (!kinosCanSelfUpdate) return;
  final release =
      ref.watch(updateProvider.select((value) => value.latestRelease));
  if (release == null || _offered) return;
  final skipped = ref.read(sharedPreferencesProvider).getString(_skippedKey);
  if (skipped == release.version) return;
  _offered = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final current = context();
    if (current.mounted) showUpdateDialog(current, release);
  });
}

bool _offered = false;

Future<void> showUpdateDialog(BuildContext context, ReleaseInfo release) =>
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(release: release));

/// « Kinos 0.17.1 est disponible » : les nouveautés, puis la mise à jour en
/// un clic (téléchargement, vérification, remplacement, redémarrage). Sans
/// mise à jour automatique sur ce système, un lien vers la page de la
/// version.
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({required this.release, super.key});
  final ReleaseInfo release;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  UpdateStage? _stage;
  double? _progress;
  String? _error;

  bool get _busy => _stage != null;

  Future<void> _install() async {
    setState(() {
      _stage = UpdateStage.downloading;
      _progress = 0;
      _error = null;
    });
    try {
      await KinosUpdater().install(widget.release,
          onProgress: (stage, progress) {
        if (mounted) {
          setState(() {
            _stage = stage;
            _progress = progress;
          });
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _stage = null;
          _error = error is UpdateFailure
              ? error.message
              : 'La mise à jour a échoué : $error';
        });
      }
    }
  }

  void _skip() {
    ref
        .read(sharedPreferencesProvider)
        .setString(_skippedKey, widget.release.version);
    Navigator.of(context).pop();
  }

  String get _stageLabel => switch (_stage) {
        UpdateStage.downloading => _progress == null
            ? 'Téléchargement…'
            : 'Téléchargement… ${(_progress! * 100).round()} %',
        UpdateStage.verifying => 'Vérification de l\'archive…',
        UpdateStage.extracting => 'Préparation…',
        UpdateStage.installing => 'Redémarrage…',
        null => '',
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final release = widget.release;
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
              Text('Kinos ${release.version} est disponible',
                  style: text.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                  kinosCanSelfUpdate
                      ? 'Kinos se met à jour et redémarre ; vos réglages, '
                          'comptes et téléchargements sont conservés.'
                      : 'Téléchargez la nouvelle version depuis sa page.',
                  style: text.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              if (release.changelog.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: MarkdownWidget(
                        data: release.changelog, shrinkWrap: true),
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(
                    value:
                        _stage == UpdateStage.downloading ? _progress : null),
                const SizedBox(height: AppSpacing.xs),
                Text(_stageLabel, style: text.bodyMedium),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(error,
                    style: text.bodyMedium?.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  TextButton(
                      onPressed: _busy ? null : _skip,
                      child: const Text('Ignorer cette version')),
                  TextButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Plus tard')),
                  if (kinosCanSelfUpdate)
                    FilledButton(
                        autofocus: true,
                        onPressed: _busy ? null : _install,
                        child: const Text('Mettre à jour et redémarrer'))
                  else
                    FilledButton(
                        autofocus: true,
                        onPressed: () => launchUrl(context, release.url),
                        child: const Text('Ouvrir la page de la version')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
