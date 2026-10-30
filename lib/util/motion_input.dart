import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Le focus visible sur desktop n'indique pas si l'action vient de la souris.
class MotionInputBoundary extends StatefulWidget {
  const MotionInputBoundary({required this.child, super.key});
  final Widget child;

  static bool keyboardOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_MotionInput>()
          ?.state
          ._keyboard ??
      false;

  @override
  State<MotionInputBoundary> createState() => _MotionInputBoundaryState();
}

class _MotionInputBoundaryState extends State<MotionInputBoundary> {
  bool _keyboard = false;

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent && !_keyboard) setState(() => _keyboard = true);
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _usePointer() {
    if (_keyboard) setState(() => _keyboard = false);
  }

  @override
  Widget build(BuildContext context) => Listener(
      onPointerDown: (_) => _usePointer(),
      onPointerHover: (_) => _usePointer(),
      child:
          _MotionInput(keyboard: _keyboard, state: this, child: widget.child));
}

class _MotionInput extends InheritedWidget {
  const _MotionInput(
      {required this.keyboard, required this.state, required super.child});
  final bool keyboard;
  final _MotionInputBoundaryState state;
  @override
  bool updateShouldNotify(_MotionInput oldWidget) =>
      oldWidget.keyboard != keyboard;
}
