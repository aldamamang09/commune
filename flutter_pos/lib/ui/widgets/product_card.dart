import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_item.dart';
import '../theme.dart';

class ProductCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0', 'en_PH');

    return Card(
      elevation: 0,
      color: CommuneTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: CommuneTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / Product Header
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF1F1F1),
                child: Center(
                  child: item.isDrink
                      ? const Icon(Icons.local_cafe_outlined, size: 36, color: Color(0xFF888888))
                      : const Icon(Icons.bakery_dining_outlined, size: 36, color: Color(0xFF888888)),
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CommuneTheme.textMain,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.category,
                          style: const TextStyle(
                            fontSize: 10,
                            color: CommuneTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₱${currency.format(item.price)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: CommuneTheme.primary,
                          ),
                        ),
                        if (item.styles.isNotEmpty)
                          Row(
                            children: item.styles.map((style) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 3),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: style == 'iced' ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    style == 'iced' ? 'ICED' : 'HOT',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: style == 'iced' ? const Color(0xFF0369A1) : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
