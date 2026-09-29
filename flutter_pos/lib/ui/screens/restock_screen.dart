import 'package:flutter/material.dart';
import '../../models/inventory_item.dart';
import '../../state/pos_controller.dart';
import '../theme.dart';

class RestockScreen extends StatefulWidget {
  final PosController controller;

  const RestockScreen({super.key, required this.controller});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  InventoryItem? _selectedItem;
  final _qtyController = TextEditingController();
  final _purchaseQtyController = TextEditingController();
  final _purchaseUnitController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _purchaseQtyController.dispose();
    _purchaseUnitController.dispose();
    super.dispose();
  }

  void _submitRestock() async {
    final qty = double.tryParse(_qtyController.text);
    if (_selectedItem == null || qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select item and enter valid restock quantity')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await widget.controller.addRestockRecord(
      inventoryItemId: _selectedItem!.id,
      itemName: _selectedItem!.name,
      quantityAdded: qty,
      purchaseQty: double.tryParse(_purchaseQtyController.text),
      purchaseUnit: _purchaseUnitController.text.isNotEmpty ? _purchaseUnitController.text : null,
    );

    setState(() {
      _isSaving = false;
      _qtyController.clear();
      _purchaseQtyController.clear();
      _purchaseUnitController.clear();
      _selectedItem = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restock logged and inventory updated!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final restocks = widget.controller.restocks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restock Management'),
      ),
      body: Row(
        children: [
          // Left: Add Restock Form
          Container(
            width: 360,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: CommuneTheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New Restock Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Adds stock directly to inventory and logs transaction for admin reporting.', style: TextStyle(fontSize: 11, color: CommuneTheme.textMuted)),
                const SizedBox(height: 16),

                DropdownButtonFormField<InventoryItem>(
                  value: _selectedItem,
                  decoration: InputDecoration(
                    labelText: 'Inventory Item',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: widget.controller.inventory.map((i) {
                    return DropdownMenuItem(value: i, child: Text('${i.name} (${i.unit})'));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedItem = val),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity Added (${_selectedItem?.unit ?? "units"}) *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _purchaseQtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Purchase Qty (optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _purchaseUnitController,
                        decoration: InputDecoration(
                          labelText: 'Unit (e.g. bag, box)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submitRestock,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CommuneTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Add Restock', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // Right: Restock History List
          Expanded(
            child: restocks.isEmpty
                ? const Center(child: Text('No restock history available.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: restocks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = restocks[index];
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: CommuneTheme.border),
                        ),
                        child: ListTile(
                          title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('Added: +${item.quantityAdded.toStringAsFixed(1)} • ${item.date.split("T").first}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.isSynced ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.isSynced ? 'SYNCED' : 'LOCAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: item.isSynced ? const Color(0xFF15803D) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
