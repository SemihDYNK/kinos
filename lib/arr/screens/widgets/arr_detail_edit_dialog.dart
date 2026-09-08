import 'package:flutter/material.dart';

import 'package:kinos/arr/models/arr_media_detail.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/labeled_selector.dart';

/// Résultat de [showArrDetailEditDialog] — `null` si annulé.
typedef ArrDetailEditResult = ({
  bool monitored,
  int qualityProfileId,
  String rootFolderPath,
});

/// Modifier profil de qualité / dossier racine / surveillance — les trois
/// champs cités par la fiche détail (cf. CLAUDE.md § Arr, cette fiche).
/// Sélecteurs en popover ([LabeledSelector], déjà éprouvé dans une modale
/// — cf. `anchored_popover_modal_test.dart`), pas des listes déroulantes
/// pleine largeur.
Future<ArrDetailEditResult?> showArrDetailEditDialog(
  BuildContext context, {
  required ArrDetailEntry entry,
  required List<ArrQualityProfile> qualityProfiles,
  required List<ArrRootFolder> rootFolders,
}) {
  return showDialog<ArrDetailEditResult>(
    context: context,
    builder: (context) => _ArrDetailEditDialog(
      entry: entry,
      qualityProfiles: qualityProfiles,
      rootFolders: rootFolders,
    ),
  );
}

class _ArrDetailEditDialog extends StatefulWidget {
  final ArrDetailEntry entry;
  final List<ArrQualityProfile> qualityProfiles;
  final List<ArrRootFolder> rootFolders;

  const _ArrDetailEditDialog({
    required this.entry,
    required this.qualityProfiles,
    required this.rootFolders,
  });

  @override
  State<_ArrDetailEditDialog> createState() => _ArrDetailEditDialogState();
}

class _ArrDetailEditDialogState extends State<_ArrDetailEditDialog> {
  late bool _monitored = widget.entry.monitored;
  late int _qualityProfileId = widget.entry.qualityProfileId;
  late String _rootFolderPath = widget.entry.rootFolderPath ?? '';

  String _profileLabel(int id) => widget.qualityProfiles
      .firstWhere((p) => p.id == id,
          orElse: () => const ArrQualityProfile(id: 0, name: 'Inconnu'))
      .name;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
      title: Text('Modifier "${widget.entry.title}"'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.qualityProfiles.isNotEmpty)
              LabeledSelector(
                label: 'Profil de qualité',
                value: _profileLabel(_qualityProfileId),
                options: widget.qualityProfiles
                    .map((profile) => (
                          label: profile.name,
                          selected: profile.id == _qualityProfileId,
                          subtitle: null,
                          onSelect: () =>
                              setState(() => _qualityProfileId = profile.id),
                        ))
                    .toList(),
              ),
            if (widget.rootFolders.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              LabeledSelector(
                label: 'Dossier racine',
                value: _rootFolderPath.isEmpty ? '—' : _rootFolderPath,
                options: widget.rootFolders
                    .map((folder) => (
                          label: folder.path,
                          selected: folder.path == _rootFolderPath,
                          subtitle: null,
                          onSelect: () =>
                              setState(() => _rootFolderPath = folder.path),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Checkbox(
                  value: _monitored,
                  onChanged: (value) =>
                      setState(() => _monitored = value ?? _monitored),
                ),
                const Text('Surveillé'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            monitored: _monitored,
            qualityProfileId: _qualityProfileId,
            rootFolderPath: _rootFolderPath,
          )),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
