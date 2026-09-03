import 'package:flutter/material.dart';

/// Wraps [child] with a subtle press-down scale for tappable elements
/// (chips, cards) that otherwise give no tactile feedback beyond an ink
/// ripple. Purely decorative: uses [Listener] (raw pointer events) rather
/// than a [GestureDetector], so it never competes with the child's own tap
/// handling (e.g. an ActionChip's internal InkWell) in the gesture arena --
/// the child keeps its own `onPressed`/`onTap`, this only watches press/
/// release to drive the scale animation.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child});

  final Widget child;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
