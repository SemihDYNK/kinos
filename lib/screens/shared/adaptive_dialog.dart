import 'package:flutter/material.dart';

import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';

/// [backgroundColor]/[shape] : repli inchangé (thème par défaut de
/// [Dialog]) si omis — n'affecte donc aucun des appelants existants.
/// Un appelant qui veut les jetons du projet (`AppColors.surfaceHigh`,
/// `AppRadii.sheet`) les passe explicitement plutôt que de les coder en
/// dur dans son propre contenu, ce qui doublerait le fond/le rayon avec
/// ceux, par défaut, du `Dialog` englobant.
Future<void> showDialogAdaptive({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  if (AdaptiveLayout.viewSizeOf(context) >= ViewSize.tablet) {
    return showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => Padding(
        padding: MediaQuery.paddingOf(context),
        child: Dialog(
          backgroundColor: backgroundColor,
          shape: shape,
          child: builder(context),
        ),
      ),
    );
  } else {
    return showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: backgroundColor,
        child: Padding(
          padding: MediaQuery.paddingOf(context),
          child: builder(context),
        ),
      ),
    );
  }
}
