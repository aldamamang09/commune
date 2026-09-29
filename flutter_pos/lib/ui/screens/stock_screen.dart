import 'package:flutter/material.dart';
import '../../state/pos_controller.dart';
import '../theme.dart';

class StockScreen extends StatelessWidget {
  final PosController controller;

  const StockScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final inventory = controller.inventory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync inventory with Supabase',
            onPressed: () {
              controller.syncService.syncAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing inventory with Supabase...')),
              );
            },
          ),
        ],
      ),
      body: inventory.isEmpty
          ? const Center(child: Text('No inventory records found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: inventory.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = inventory[index];
                final percentage = item.maxStock > 0 ? (item.stock / item.maxStock).clamp(0.0, 1.0) : 0.5;

                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: CommuneTheme.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: item.isLowStock ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.isLowStock ? 'LOW STOCK' : 'IN STOCK',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.isLowStock ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current Stock: ${item.stock.toStringAsFixed(1)} ${item.unit}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Max: ${item.maxStock.toStringAsFixed(0)} ${item.unit} • Cost: ₱${item.cost.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, color: CommuneTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              item.isLowStock ? CommuneTheme.voidRed : CommuneTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
