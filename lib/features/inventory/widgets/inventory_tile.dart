import 'package:flutter/material.dart';

import '../../grocery/models/catalog.dart';
import '../models/inventory_item.dart';

Color storageColor(StorageLocation s) => switch (s) {
  StorageLocation.fridge => const Color(0xFF2B5C86),
  StorageLocation.freezer => const Color(0xFF2F6F86),
  StorageLocation.pantry => const Color(0xFF7A5A2F),
  StorageLocation.household => const Color(0xFF4F5966),
};

/// Red when gone off or going today, orange within two days, green after.
Color expiryColor(int? daysLeft) {
  if (daysLeft == null) return const Color(0xFF8A939E);
  if (daysLeft <= 0) return const Color(0xFFFF453A);
  if (daysLeft <= 2) return const Color(0xFFFF9F0A);
  return const Color(0xFF30D158);
}

String expiryLabel(int? daysLeft) {
  if (daysLeft == null) return 'No date';
  if (daysLeft < 0) return '${-daysLeft}d over';
  if (daysLeft == 0) return 'Today';
  if (daysLeft == 1) return 'Tomorrow';
  if (daysLeft < 14) return '${daysLeft}d';
  if (daysLeft < 60) return '${(daysLeft / 7).round()}w';
  return '${(daysLeft / 30).round()}mo';
}

/// An inventory item as a tile: icon, name, and a days-left badge.
class InventoryTile extends StatelessWidget {
  const InventoryTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  final InventoryItem item;
  final VoidCallback onTap;

  /// Long-press: rename.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final supply = item.group == FoodGroup.household;
    final days = item.daysLeft();
    final badge = supply
        ? (item.low ? const Color(0xFFFFB74D) : Colors.white24)
        : expiryColor(days);
    return Material(
      color: storageColor(item.storage),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.emoji, style: const TextStyle(fontSize: 36)),
                        const SizedBox(height: 4),
                        Text(
                          item.name,
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
                        if (item.spec.isNotEmpty)
                          Text(
                            item.spec,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badge,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  supply ? (item.low ? 'Low' : 'Have') : expiryLabel(days),
                  style: TextStyle(
                    color: (supply ? !item.low : days == null)
                        ? Colors.white
                        : Colors.black,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
