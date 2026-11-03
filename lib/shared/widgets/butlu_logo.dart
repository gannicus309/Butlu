import 'package:flutter/material.dart';

/// Butlu's mark: a calendar glyph on a blue gradient tile. With [pulse] it
/// gently breathes, standing in for a spinner on loading screens.
class ButluLogo extends StatefulWidget {
  const ButluLogo({super.key, this.size = 88, this.pulse = false});

  final double size;
  final bool pulse;

  @override
  State<ButluLogo> createState() => _ButluLogoState();
}

class _ButluLogoState extends State<ButluLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5AC8FA), Color(0xFF0A84FF), Color(0xFF5E5CE6)],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.45),
            blurRadius: widget.size * 0.35,
            offset: Offset(0, widget.size * 0.08),
          ),
        ],
      ),
      child: Icon(
        Icons.calendar_month_rounded,
        size: widget.size * 0.52,
        color: Colors.white,
      ),
    );
    if (!widget.pulse) return tile;
    return ScaleTransition(
      scale: Tween(
        begin: 0.94,
        end: 1.04,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: tile,
    );
  }
}
