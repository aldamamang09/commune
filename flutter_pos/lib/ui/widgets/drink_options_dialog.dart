import 'package:flutter/material.dart';
import '../../models/menu_item.dart';
import '../../models/order_item.dart';
import '../theme.dart';

class DrinkOptionsDialog extends StatefulWidget {
  final MenuItem item;
  final Function(String? style, List<OrderAddonSelection> addons, int qty) onConfirm;

  const DrinkOptionsDialog({
    super.key,
    required this.item,
    required this.onConfirm,
  });

  @override
  State<DrinkOptionsDialog> createState() => _DrinkOptionsDialogState();
}

class _DrinkOptionsDialogState extends State<DrinkOptionsDialog> {
  String? _selectedStyle;
  final Map<String, int> _addonQuantities = {};
  int _qty = 1;

  final List<MenuAddon> _standardAddons = const [
    MenuAddon(id: 'extra-espresso', name: 'Extra Espresso Shot', price: 30),
    MenuAddon(id: 'oat-milk', name: 'Sub Oat Milk', price: 40),
    MenuAddon(id: 'caramel-drizzle', name: 'Caramel Drizzle', price: 20),
    MenuAddon(id: 'vanilla-syrup', name: 'Vanilla Syrup Pump', price: 20),
    MenuAddon(id: 'sweet-foam', name: 'Sea Salt Cold Foam', price: 35),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.item.styles.isNotEmpty) {
      _selectedStyle = widget.item.styles.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final addonsList = widget.item.addons.isNotEmpty ? widget.item.addons : _standardAddons;

    double extraTotal = 0;
    for (final addon in addonsList) {
      final q = _addonQuantities[addon.name] ?? 0;
      extraTotal += addon.price * q;
    }
    final unitPrice = widget.item.price + extraTotal;
    final totalPrice = unitPrice * _qty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CommuneTheme.textMain,
                        ),
                      ),
                      Text(
                        'Base: ₱${widget.item.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CommuneTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Style Selector (Hot / Iced)
            if (widget.item.styles.isNotEmpty) ...[
              const Text(
                'DRINK STYLE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: CommuneTheme.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                children: widget.item.styles.map((style) {
                  final isSelected = _selectedStyle == style;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () => setState(() => _selectedStyle = style),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected ? CommuneTheme.primary : Colors.transparent,
                          foregroundColor: isSelected ? Colors.white : CommuneTheme.textMain,
                          side: BorderSide(color: isSelected ? CommuneTheme.primary : CommuneTheme.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              style == 'hot' ? Icons.local_fire_department : Icons.ac_unit,
                              size: 16,
                              color: isSelected ? Colors.white : (style == 'hot' ? Colors.orange : Colors.blue),
                            ),
                            const SizedBox(width: 6),
                            Text(style.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Add-ons Section
            if (widget.item.isDrink) ...[
              const Text(
                'ADD-ONS & MODIFIERS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: CommuneTheme.textMuted),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: addonsList.length,
                  separatorBuilder: (_, __) => const Divider(height: 8),
                  itemBuilder: (context, index) {
                    final addon = addonsList[index];
                    final currentQty = _addonQuantities[addon.name] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(addon.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              Text('+₱${addon.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: CommuneTheme.textMuted)),
                            ],
                          ),
                          Row(
                            children: [
                              if (currentQty > 0) ...[
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      if (currentQty > 1) {
                                        _addonQuantities[addon.name] = currentQty - 1;
                                      } else {
                                        _addonQuantities.remove(addon.name);
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('$currentQty', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    if (currentQty < addon.maxQty) {
                                      _addonQuantities[addon.name] = currentQty + 1;
                                    }
                                  });
                                },
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Quantity & Confirmation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                      icon: const Icon(Icons.remove, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFEEEEEE),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('$_qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _qty++),
                      icon: const Icon(Icons.add, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFEEEEEE),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    final addons = <OrderAddonSelection>[];
                    _addonQuantities.forEach((name, qty) {
                      final addonDef = addonsList.firstWhere((a) => a.name == name);
                      addons.add(OrderAddonSelection(
                        name: name,
                        qty: qty,
                        price: addonDef.price,
                        inventoryItemId: addonDef.inventoryItemId,
                      ));
                    });
                    widget.onConfirm(_selectedStyle, addons, _qty);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CommuneTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  child: Text(
                    'Add • ₱${totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}
