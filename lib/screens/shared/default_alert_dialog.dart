import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';

Future<void> showDefaultAlertDialog(
  BuildContext context,
  String title,
  String? content,
  FutureOr Function(BuildContext context)? accept,
  String? acceptTitle,
  FutureOr Function(BuildContext context)? decline,
  String declineTitle,
) {
  return showDialog(
    context: context,
    builder: (context) => GlassAlertDialog(
      title: Text(title),
      content: content != null ? Text(content) : null,
      actions: [
        if (decline != null)
          TextButton(
            autofocus: true,
            onPressed: () => decline.call(context),
            child: Text(declineTitle),
          ),
        if (accept != null)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
              iconColor: AppColors.textPrimary,
            ),
            onPressed: () => accept.call(context),
            child: Text(acceptTitle ?? context.localized.accept),
          ),
      ],
    ),
  );
}

Future<void> showDefaultActionDialog(
  BuildContext context,
  String title,
  String? content,
  FutureOr Function(BuildContext context)? accept,
  String? acceptTitle,
  FutureOr Function(BuildContext context)? decline,
  String declineTitle,
) {
  return showDialog(
    context: context,
    builder: (context) => GlassAlertDialog(
      title: Text(title),
      content: content != null ? Text(content) : null,
      actions: [
        if (decline != null)
          TextButton(
            autofocus: true,
            onPressed: () => decline.call(context),
            child: Text(declineTitle),
          ),
        if (accept != null)
          FilledButton(
            onPressed: () => accept.call(context),
            child: Text(acceptTitle ?? context.localized.accept),
          ),
      ],
    ),
  );
}
