import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/anchored_popover.dart';

import 'kinos_ratings.dart';

/// Le bouton « Votre note » d'une fiche, dans la rangée des actions : vide
/// tant qu'on n'a pas noté, puis la note en étoiles. Il ouvre la saisie.
class KinosRatingButton extends ConsumerStatefulWidget {
  const KinosRatingButton(
      {required this.identity, required this.title, super.key});
  final String identity;
  final String title;

  @override
  ConsumerState<KinosRatingButton> createState() => _RatingButtonState();
}

class _RatingButtonState extends ConsumerState<KinosRatingButton> {
  final _popover = AnchoredPopoverController();

  @override
  Widget build(BuildContext context) {
    final rating =
        ref.watch(kinosRatingsProvider.select((r) => r[widget.identity]));
    final text = Theme.of(context).textTheme;
    // Le même menu déroulant que les pistes et sous-titres de la fiche.
    return AnchoredPopover(
      controller: _popover,
      preferredDirection: AxisDirection.down,
      popoverBuilder: (context, close) => KinosRatingPicker(
          initial: rating?.value,
          onDone: (value, {clear = false}) {
            if (clear || value != null) {
              ref
                  .read(kinosRatingsProvider.notifier)
                  .set(widget.identity, clear ? null : value);
            }
            close();
          }),
      child: Tooltip(
        message: rating == null
            ? 'Noter ${widget.title}'
            : 'Votre note : ${formatStars(rating.value)} · modifier',
        child: FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: _popover.toggle,
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

/// La saisie de la note, dans le menu déroulant du bouton : cinq étoiles
/// par demi-étoile, à la souris (moitié gauche ou droite d'une étoile,
/// un clic enregistre) ou au clavier (← →, Entrée pour garder, Retour
/// arrière pour effacer, Échap pour fermer).
class KinosRatingPicker extends StatefulWidget {
  const KinosRatingPicker(
      {required this.initial, required this.onDone, super.key});

  /// La note actuelle (sur 10), null si aucune.
  final int? initial;
  final void Function(int? value, {bool clear}) onDone;

  @override
  State<KinosRatingPicker> createState() => _RatingPickerState();
}

class _RatingPickerState extends State<KinosRatingPicker> {
  late int _value = widget.initial ?? 6;
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = _hover ?? _value;
    const star = AppDetailLayout.ratingDialogStarSize;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            setState(() => _value = (_value - 1).clamp(1, 10)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            setState(() => _value = (_value + 1).clamp(1, 10)),
        const SingleActivator(LogicalKeyboardKey.enter): () =>
            widget.onDone(_value),
        const SingleActivator(LogicalKeyboardKey.backspace): () =>
            widget.onDone(null, clear: true),
        const SingleActivator(LogicalKeyboardKey.delete): () =>
            widget.onDone(null, clear: true),
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Votre note',
                    style: text.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
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
                                      onTap: () => widget.onDone(half)),
                                ),
                              ),
                          ]),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(children: [
                  Text('${shown ~/ 2}${shown.isOdd ? ',5' : ''} / 5',
                      style: text.titleMedium
                          ?.copyWith(color: AppColors.textPrimary)),
                  const Spacer(),
                  if (widget.initial != null)
                    FocusRing(
                      borderRadius: AppRadii.controlBorder,
                      onActivate: () => widget.onDone(null, clear: true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.xxs),
                        child: Text('Effacer',
                            style: text.labelMedium
                                ?.copyWith(color: AppColors.textSecondary)),
                      ),
                    ),
                ]),
              ]),
        ),
      ),
    );
  }
}
