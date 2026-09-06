import 'package:flutter/material.dart';

import 'package:fladder/models/items/item_shared_models.dart';
import 'package:fladder/screens/details_screens/person_detail_screen.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/fladder_image.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/util/string_extensions.dart';
import 'package:fladder/widgets/shared/modal_bottom_sheet.dart';

/// Casting (grille compacte) et informations techniques, en deux colonnes —
/// 60/40, l'une sous l'autre en dessous de [_narrowBreakpoint].
class MediaInfoSection extends StatelessWidget {
  final List<Person> people;
  final List<({String label, String value})> info;
  final EdgeInsets contentPadding;

  const MediaInfoSection({
    required this.people,
    required this.info,
    required this.contentPadding,
    super.key,
  });

  static const _narrowBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty && info.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: contentPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < _narrowBreakpoint;
          final castWidth = narrow
              ? constraints.maxWidth
              : constraints.maxWidth * 0.6 - AppSpacing.lg;
          final infoWidth = narrow
              ? constraints.maxWidth
              : constraints.maxWidth * 0.4 - AppSpacing.lg;

          final cast = _CastGrid(people: people, width: castWidth);
          final panel = _InfoPanel(info: info);

          // Un seul groupe de traversal : l'ordre de lecture (grille de
          // casting puis panneau) reste cohérent que les colonnes soient
          // côte à côte ou empilées — le panneau n'a de toute façon aucun
          // élément interactif, seule la grille et son lien "tout voir" le
          // sont.
          return FocusTraversalGroup(
            child: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cast,
                      if (info.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        panel,
                      ],
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: castWidth, child: cast),
                      const SizedBox(width: AppSpacing.lg),
                      SizedBox(width: infoWidth, child: panel),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _CastGrid extends StatelessWidget {
  final List<Person> people;
  final double width;

  const _CastGrid({required this.people, required this.width});

  static const _tileWidth = 88.0;
  static const _maxRows = 1;
  static const _tileAspectRatio = 0.72;

  void _seeAll(BuildContext context) {
    showBottomSheetPill(
      context: context,
      content: (context, scrollController) => ListView.builder(
        controller: scrollController,
        shrinkWrap: true,
        itemCount: people.length,
        itemBuilder: (context, index) {
          final person = people[index];
          return FocusRing(
            onActivate: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (context) => PersonDetailScreen(person: person)),
            ),
            child: ExcludeFocus(
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => PersonDetailScreen(person: person)),
                ),
                leading: ClipRRect(
                  borderRadius: AppRadii.controlBorder,
                  child: SizedBox.square(
                    dimension: 40,
                    child: FladderImage(image: person.image, fit: BoxFit.cover),
                  ),
                ),
                title: Text(person.name,
                    style: Theme.of(context).textTheme.bodyMedium),
                subtitle: person.role.isNotEmpty ? Text(person.role) : null,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    final columns = (width / (_tileWidth + AppSpacing.sm)).floor().clamp(2, 6);
    final maxVisible = columns * _maxRows;
    final visible = people.take(maxVisible).toList();
    final truncated = people.length > maxVisible;
    // `visible` s'arrête déjà à une rangée (itemCount du GridView ne dépasse
    // jamais `columns`), mais rien n'empêchait un éventuel dépassement de
    // peindre au-delà — un fragment de vignette (visage tronqué) restait
    // visible sous la rangée. Hauteur du conteneur contrainte à exactement
    // une rangée (même calcul que `childAspectRatio` ci-dessous), et
    // ClipRect en dernier rempart : rien ne peut plus déborder.
    final cellWidth = (width - (columns - 1) * AppSpacing.sm) / columns;
    final rowHeight = cellWidth / _tileAspectRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          // Sans ceci, le lien "tout voir" (FocusRing : bordure + padding)
          // rend la ligne plus haute que le titre seul et centre celui-ci
          // dedans, le décalant vers le bas — désaligné avec le titre
          // "Informations" du panneau voisin, une simple Text sans Row.
          // .start ancre le titre en haut de la ligne dans les deux cas.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.localized.castAndCrew,
                style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            if (truncated)
              FocusRing(
                borderRadius: AppRadii.controlBorder,
                onActivate: () => _seeAll(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                  child: Text(
                    'tout voir',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRect(
          child: SizedBox(
            height: rowHeight,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: _tileAspectRatio,
              ),
              itemBuilder: (context, index) =>
                  _CastTile(person: visible[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CastTile extends StatelessWidget {
  final Person person;

  const _CastTile({required this.person});

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      borderRadius: AppRadii.controlBorder,
      onActivate: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (context) => PersonDetailScreen(person: person)),
      ),
      child: ExcludeFocus(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadii.controlBorder,
              child: AspectRatio(
                aspectRatio: 1,
                child: FladderImage(
                  image: person.image,
                  fit: BoxFit.cover,
                  placeHolder: ColoredBox(
                    color: AppColors.surfaceHigh,
                    child: Center(
                      child: Text(
                        person.name.getInitials(),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              person.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feuille clé/valeur autonome — même style que le panneau "Informations",
/// pour un sous-ensemble d'informations affiché ailleurs (ex. les infos
/// techniques du fichier, déplacées dans le menu "..." du bandeau).
void showMediaInfoSheet(
  BuildContext context,
  String title,
  List<({String label, String value})> info,
) {
  showBottomSheetPill(
    context: context,
    content: (context, scrollController) => ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final entry in info)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  entry.value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _InfoPanel extends StatelessWidget {
  final List<({String label, String value})> info;

  const _InfoPanel({required this.info});

  @override
  Widget build(BuildContext context) {
    if (info.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Informations', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final entry in info)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  entry.value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
