import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

import 'kinos_ratings.dart';

/// Le bouton « Votre note » d'une fiche, dans la rangée des actions : vide
/// tant qu'on n'a pas noté, puis la note en étoiles. Il ouvre la saisie.
class KinosRatingButton extends ConsumerWidget {
  const KinosRatingButton(
      {required this.identity, required this.title, super.key});
  final String identity;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(kinosRatingsProvider.select((r) => r[identity]));
    final text = Theme.of(context).textTheme;
    void open() => showDialog<void>(
        context: context,
        builder: (_) => KinosRatingDialog(identity: identity, title: title));
    return Tooltip(
      message: rating == null
          ? 'Noter'
          : 'Votre note : ${formatStars(rating.value)} · modifier',
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: open,
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: AppPlayerStyle.controlSurface,
              border: Border.all(color: AppColors.borderStrong),
              borderRadius: AppRadii.controlBorder),
          child: SizedBox(
            height: AppDetailLayout.ratingButtonHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (rating == null) ...[
                  const Icon(Icons.star_outline_rounded,
                      color: AppColors.textPrimary),
                  const SizedBox(width: AppSpacing.xxs),
                  Text('Noter',
                      style: text.labelLarge
                          ?.copyWith(color: AppColors.textPrimary)),
                ] else
                  StarRow(value: rating.value),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// « ★★★★½ ».
String formatStars(int value) =>
    '${'★' * (value ~/ 2)}${value.isOdd ? '½' : ''}';

/// Cinq étoiles, pleines, demies ou vides, de la même taille.
class StarRow extends StatelessWidget {
  const StarRow(
      {required this.value,
      this.size = AppDetailLayout.ratingStarSize,
      super.key});

  /// Sur 10 ; 0 pour aucune.
  final int value;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
                value >= i * 2
                    ? Icons.star_rounded
                    : value == i * 2 - 1
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded,
                size: size,
                color: value >= i * 2 - 1
                    ? AppColors.textPrimary
                    : AppColors.textSecondary),
        ],
      );
}

/// La saisie de la note : cinq étoiles par demi-étoile, à la souris (moitié
/// gauche ou droite d'une étoile) ou au clavier (← →, Entrée pour garder,
/// Retour arrière pour effacer, Échap pour annuler).
class KinosRatingDialog extends ConsumerStatefulWidget {
  const KinosRatingDialog(
      {required this.identity, required this.title, super.key});
  final String identity;
  final String title;

  @override
  ConsumerState<KinosRatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends ConsumerState<KinosRatingDialog> {
  late int _value = ref.read(kinosRatingsProvider)[widget.identity]?.value ?? 6;
  int? _hover;

  void _save([int? value]) {
    ref.read(kinosRatingsProvider.notifier).set(widget.identity, value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = _hover ?? _value;
    const star = AppDetailLayout.ratingDialogStarSize;
    final known = ref.watch(kinosRatingsProvider)[widget.identity];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            setState(() => _value = (_value - 1).clamp(1, 10)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            setState(() => _value = (_value + 1).clamp(1, 10)),
        const SingleActivator(LogicalKeyboardKey.enter): () => _save(_value),
        const SingleActivator(LogicalKeyboardKey.backspace): () => _save(),
        const SingleActivator(LogicalKeyboardKey.delete): () => _save(),
      },
      child: Focus(
        autofocus: true,
        child: GlassDialog(
          constraints:
              const BoxConstraints(maxWidth: AppDetailLayout.reviewTileWidth),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Votre note', style: text.headlineSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      text.bodySmall?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              MouseRegion(
                onExit: (_) => setState(() => _hover = null),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 1; i <= 5; i++)
                    SizedBox(
                      width: star,
                      height: star,
                      child: Stack(children: [
                        Positioned.fill(
                          child: Icon(
                              shown >= i * 2
                                  ? Icons.star_rounded
                                  : shown == i * 2 - 1
                                      ? Icons.star_half_rounded
                                      : Icons.star_outline_rounded,
                              size: star,
                              color: AppColors.textPrimary),
                        ),
                        // Moitié gauche : demi-étoile ; moitié droite :
                        // étoile pleine.
                        Row(children: [
                          for (final half in [i * 2 - 1, i * 2])
                            Expanded(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) => setState(() => _hover = half),
                                child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _save(half)),
                              ),
                            ),
                        ]),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('${shown ~/ 2}${shown.isOdd ? ',5' : ''} / 5',
                  style:
                      text.titleMedium?.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.lg),
              // Passe à la ligne plutôt que déborder (grandes polices).
              Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (known != null)
                      TextButton(
                          onPressed: () => _save(),
                          child: const Text('Effacer')),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler')),
                    FilledButton(
                        onPressed: () => _save(_value),
                        child: const Text('Enregistrer')),
                  ]),
            ]),
          ),
        ),
      ),
    );
  }
}
