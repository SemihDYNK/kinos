import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/theme/app_theme.dart';

/// Champ numérique compact : la case ne contient que les chiffres, l'unité
/// est posée à côté. La valeur est enregistrée à la validation (Entrée) et
/// quand le champ perd le focus.
class IntInputField extends StatefulWidget {
  final int? value;
  final TextEditingController? controller;
  final String? placeHolder;
  final String? suffix;
  final Function(int? value)? onSubmitted;
  const IntInputField({
    this.value,
    this.controller,
    this.suffix,
    this.placeHolder,
    this.onSubmitted,
    super.key,
  });

  @override
  State<IntInputField> createState() => _IntInputFieldState();
}

class _IntInputFieldState extends State<IntInputField> {
  late final bool _ownsController = widget.controller == null;
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.value?.toString() ?? "");
  final FocusNode _focusNode = FocusNode();
  late String _lastCommitted;

  @override
  void initState() {
    super.initState();
    _lastCommitted = _controller.text;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit(_controller.text);
  }

  void _commit(String text) {
    if (text == _lastCommitted) return;
    _lastCommitted = text;
    widget.onSubmitted?.call(int.tryParse(text));
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: AppManagementLayout.numberFieldWidth,
          child: OutlinedTextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onSubmitted: _commit,
            textAlign: TextAlign.center,
            placeHolder: widget.placeHolder,
          ),
        ),
        if (widget.suffix != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(widget.suffix!, style: AppTypography.meta),
        ],
      ],
    );
  }
}

Future<void> openSimpleTextInput(
  BuildContext context,
  String? value,
  Function(String result) onChanged,
  String title,
  String description, {
  TextInputType keyboardType = TextInputType.url,
  String placeHolder = "http://192.168.1.1:8096, 192.168.1.1:8096",
}) {
  return showDialog(
    context: context,
    builder: (context) => _TextInputFieldDialog(
      value: value,
      title: title,
      description: description,
      onChanged: onChanged,
      keyboardType: keyboardType,
      placeHolder: placeHolder,
    ),
  );
}

class _TextInputFieldDialog extends ConsumerWidget {
  final String? value;
  final String title;
  final String description;
  final Function(String result) onChanged;
  final TextInputType keyboardType;
  final String placeHolder;
  const _TextInputFieldDialog({
    this.value,
    required this.title,
    required this.description,
    required this.onChanged,
    required this.keyboardType,
    required this.placeHolder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassDialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(),
            ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(6),
              children: [
                OutlinedTextField(
                  controller: TextEditingController(text: value),
                  keyboardType: keyboardType,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    onChanged.call(value);
                    context.pop();
                  },
                  textAlign: TextAlign.start,
                  placeHolder: placeHolder,
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
