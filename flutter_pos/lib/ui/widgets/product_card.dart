import 'package:flutter/material.dart';
import '../../models/menu_item.dart';

class ProductCard extends StatelessWidget {
  final MenuItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.item,
    this.isSelected = false,
    required this.onTap,
  });

  String _buildSubtitle() {
    if (!item.isDrink) {
      return '';
    }

    final hasIced = item.styles.contains('iced') || item.styles.isEmpty;
    final hasHot = item.styles.contains('hot');

    if (hasIced && hasHot) {
      return 'Iced / Hot · Add-ons';
    } else if (hasIced) {
      // Some drinks like Matcha Umami or Strawberry Whisper show 'Iced' or 'Iced · Add-ons'
      if (item.category.toLowerCase().contains('matcha') && !item.name.toLowerCase().contains('latte')) {
        return 'Iced';
      }
      if (item.name.toLowerCase().contains('whisper') || item.name.toLowerCase().contains('cloud')) {
        return 'Iced';
      }
      return 'Iced · Add-ons';
    } else if (hasHot) {
      return 'Hot · Add-ons';
    }
    return 'Add-ons';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildSubtitle();

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Colors.black : const Color(0xFFE5E7EB),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFFF3F4F6),
        highlightColor: const Color(0xFFE5E7EB),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '₱${item.price.toInt()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
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
