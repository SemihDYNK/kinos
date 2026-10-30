import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart' as m;
import 'package:kinos/theme/app_theme.dart';

/// One clipped backdrop per floating panel. Never blurs the whole screen.
class FrostedSurface extends m.StatelessWidget {
  const FrostedSurface(
      {required this.child,
      this.borderRadius = AppRadii.sheetBorder,
      this.color = AppGlass.surface,
      super.key});
  final m.Widget child;
  final m.Color color;
  final m.BorderRadius borderRadius;
  @override
  m.Widget build(m.BuildContext context) {
    final opaque = m.MediaQuery.highContrastOf(context);
    final surface = m.DecoratedBox(
      decoration: m.BoxDecoration(
        color: opaque ? AppColors.surfaceHigh : color,
        borderRadius: borderRadius,
        border: m.Border.all(color: AppGlass.border),
      ),
      child: child,
    );
    return m.ClipRRect(
        borderRadius: borderRadius,
        child: opaque
            ? surface
            : m.BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: AppGlass.blur, sigmaY: AppGlass.blur),
                child: surface));
  }
}

m.Widget _dialog(m.BuildContext context, m.Dialog dialog) {
  final panel = m.Dialog(
    insetPadding: dialog.insetPadding,
    insetAnimationDuration: dialog.insetAnimationDuration,
    insetAnimationCurve: dialog.insetAnimationCurve,
    alignment: dialog.alignment,
    constraints: dialog.constraints,
    semanticsRole: dialog.semanticsRole,
    backgroundColor: m.Colors.transparent,
    surfaceTintColor: m.Colors.transparent,
    elevation: 0,
    shape: const m.RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
    child: FrostedSurface(child: dialog.child ?? const m.SizedBox.shrink()),
  );
  final animation = m.ModalRoute.of(context)?.animation;
  if (animation == null || !AppMotion.enabled(context)) return panel;
  return m.AnimatedBuilder(
    animation: animation,
    child: panel,
    builder: (context, child) => m.Transform.translate(
      offset: m.Offset(0,
          AppSpacing.sm * (1 - AppMotion.easeOut.transform(animation.value))),
      child: child,
    ),
  );
}

class GlassDialog extends m.Dialog {
  const GlassDialog(
      {super.key,
      super.backgroundColor,
      super.elevation,
      super.shadowColor,
      super.surfaceTintColor,
      super.insetAnimationDuration,
      super.insetAnimationCurve,
      super.insetPadding,
      super.clipBehavior,
      super.shape,
      super.alignment,
      super.child,
      super.semanticsRole,
      super.constraints});
  const GlassDialog.fullscreen(
      {super.key,
      super.backgroundColor,
      super.insetAnimationDuration,
      super.insetAnimationCurve,
      super.child,
      super.semanticsRole})
      : super.fullscreen();
  @override
  m.Widget build(m.BuildContext context) => _dialog(context, this);
}

class GlassAlertDialog extends m.AlertDialog {
  const GlassAlertDialog(
      {super.key,
      super.icon,
      super.iconPadding,
      super.iconColor,
      super.title,
      super.titlePadding,
      super.titleTextStyle,
      super.content,
      super.contentPadding,
      super.contentTextStyle,
      super.actions,
      super.actionsPadding,
      super.actionsAlignment,
      super.actionsOverflowAlignment,
      super.actionsOverflowDirection,
      super.actionsOverflowButtonSpacing,
      super.buttonPadding,
      super.backgroundColor,
      super.elevation,
      super.shadowColor,
      super.surfaceTintColor,
      super.semanticLabel,
      super.insetPadding,
      super.clipBehavior,
      super.shape,
      super.alignment,
      super.constraints,
      super.scrollable});
  @override
  m.Widget build(m.BuildContext context) =>
      _dialog(context, super.build(context) as m.Dialog);
}

class GlassSimpleDialog extends m.SimpleDialog {
  const GlassSimpleDialog(
      {super.key,
      super.title,
      super.titlePadding,
      super.titleTextStyle,
      super.children,
      super.contentPadding,
      super.backgroundColor,
      super.elevation,
      super.shadowColor,
      super.surfaceTintColor,
      super.semanticLabel,
      super.insetPadding,
      super.clipBehavior,
      super.shape,
      super.alignment,
      super.constraints});
  @override
  m.Widget build(m.BuildContext context) =>
      _dialog(context, super.build(context) as m.Dialog);
}

List<m.PopupMenuEntry<T>> _entries<T>(List<m.PopupMenuEntry<T>> items) =>
    items.isEmpty ? items : [_GlassMenuEntry<T>(items)];

class _GlassMenuEntry<T> extends m.PopupMenuEntry<T> {
  const _GlassMenuEntry(this.items);
  final List<m.PopupMenuEntry<T>> items;
  @override
  double get height => items.fold(0, (total, item) => total + item.height);
  @override
  bool represents(T? value) => items.any((item) => item.represents(value));
  @override
  m.State<_GlassMenuEntry<T>> createState() => _GlassMenuEntryState<T>();
}

class _GlassMenuEntryState<T> extends m.State<_GlassMenuEntry<T>> {
  @override
  m.Widget build(m.BuildContext context) => FrostedSurface(
      child: m.Padding(
          padding: const m.EdgeInsets.all(AppSpacing.xs),
          child: m.Column(
              mainAxisSize: m.MainAxisSize.min,
              crossAxisAlignment: m.CrossAxisAlignment.stretch,
              children: widget.items
                  .map((item) => m.ClipRRect(
                      borderRadius: AppRadii.controlBorder, child: item))
                  .toList())));
}

Future<T?> showGlassMenu<T>({
  required m.BuildContext context,
  m.RelativeRect? position,
  m.PopupMenuPositionBuilder? positionBuilder,
  required List<m.PopupMenuEntry<T>> items,
  double? elevation,
  m.Color? shadowColor,
  m.Color? surfaceTintColor,
  String? semanticLabel,
  m.ShapeBorder? shape,
  m.EdgeInsetsGeometry? menuPadding,
  m.Color? color,
  bool useRootNavigator = false,
  m.BoxConstraints? constraints,
  m.Clip clipBehavior = m.Clip.none,
  m.RouteSettings? routeSettings,
  m.AnimationStyle? popUpAnimationStyle,
  bool? requestFocus,
}) =>
    m.showMenu<T>(
        context: context,
        position: position,
        positionBuilder: positionBuilder,
        items: _entries(items),
        elevation: 0,
        color: m.Colors.transparent,
        surfaceTintColor: m.Colors.transparent,
        shadowColor: shadowColor,
        semanticLabel: semanticLabel,
        shape:
            const m.RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
        menuPadding: m.EdgeInsets.zero,
        useRootNavigator: useRootNavigator,
        constraints: constraints,
        clipBehavior: clipBehavior,
        routeSettings: routeSettings,
        popUpAnimationStyle: AppMotion.enabled(context)
            ? popUpAnimationStyle ??
                const m.AnimationStyle(
                    duration: AppDurations.popover,
                    reverseDuration: AppDurations.hover,
                    curve: AppMotion.easeOut,
                    reverseCurve: AppMotion.easeOut)
            : m.AnimationStyle.noAnimation,
        requestFocus: requestFocus);

class GlassPopupMenuButton<T> extends m.PopupMenuButton<T> {
  GlassPopupMenuButton({
    super.key,
    super.onOpened,
    super.onSelected,
    super.onCanceled,
    super.tooltip,
    super.shadowColor,
    super.padding,
    super.child,
    super.borderRadius,
    super.splashRadius,
    super.icon,
    super.iconSize,
    super.offset,
    super.enabled,
    super.iconColor,
    super.enableFeedback,
    super.constraints,
    super.position,
    super.clipBehavior,
    super.useRootNavigator,
    m.AnimationStyle? popUpAnimationStyle,
    super.routeSettings,
    super.style,
    super.requestFocus,
    required m.PopupMenuItemBuilder<T> itemBuilder,
    m.Color? color,
    m.Color? surfaceTintColor,
    double? elevation,
    m.EdgeInsetsGeometry? menuPadding,
    m.ShapeBorder? shape,
  }) : super(
            popUpAnimationStyle: popUpAnimationStyle ??
                const m.AnimationStyle(
                    duration: AppDurations.popover,
                    reverseDuration: AppDurations.hover,
                    curve: AppMotion.easeOut,
                    reverseCurve: AppMotion.easeOut),
            itemBuilder: (context) => _entries(itemBuilder(context)),
            color: m.Colors.transparent,
            surfaceTintColor: m.Colors.transparent,
            elevation: 0,
            menuPadding: m.EdgeInsets.zero,
            shape: const m.RoundedRectangleBorder(
                borderRadius: AppRadii.sheetBorder));
}
