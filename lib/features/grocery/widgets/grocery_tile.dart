import 'package:flutter/material.dart';

/// Bring!-style tile: big icon, name underneath, optional detail line.
/// Red when it's on the shopping list, teal when it's just on offer.
class GroceryTile extends StatefulWidget {
  const GroceryTile({
    super.key,
    required this.emoji,
    required this.name,
    this.spec = '',
    required this.onList,
    required this.onTap,
    this.onLongPress,
  });

  static const listColor = Color(0xFFE5625F);
  static const offerColor = Color(0xFF2F6E68);

  final String emoji;
  final String name;
  final String spec;
  final bool onList;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<GroceryTile> createState() => _GroceryTileState();
}

class _GroceryTileState extends State<GroceryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.onList
        ? GroceryTile.listColor
        : GroceryTile.offerColor;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: widget.onList
                ? [
                    BoxShadow(
                      color: GroceryTile.listColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          // Shrinks to fit rather than overflowing: long names ("Laundry
          // detergent") and larger iOS text sizes would otherwise spill out
          // of the tile.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 100,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.emoji, style: const TextStyle(fontSize: 38)),
                  const SizedBox(height: 6),
                  Text(
                    widget.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.15,
                    ),
                  ),
                  if (widget.spec.isNotEmpty)
                    Text(
                      widget.spec,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
