import 'package:flutter/material.dart';
import '../../models/inventory_item.dart';
import '../../state/pos_controller.dart';

class RestockScreen extends StatefulWidget {
  final PosController controller;

  const RestockScreen({super.key, required this.controller});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  String _range = 'Today';
  final TextEditingController _dateController = TextEditingController(text: '09/29/2026');

  void _openAddRestockDialog() {
    InventoryItem? selectedItem = widget.controller.inventory.isNotEmpty ? widget.controller.inventory.first : null;
    final qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Restock Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<InventoryItem>(
                  initialValue: selectedItem,
                  decoration: InputDecoration(
                    labelText: 'Select Item',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: widget.controller.inventory.map((i) {
                    return DropdownMenuItem(value: i, child: Text('${i.name} (${i.unit})'));
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedItem = val),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity to Add',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final qty = double.tryParse(qtyController.text);
                if (selectedItem == null || qty == null || qty <= 0) return;

                await widget.controller.addRestockRecord(
                  inventoryItemId: selectedItem!.id,
                  itemName: selectedItem!.name,
                  quantityAdded: qty,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  setState(() {});
                }
              },
              child: const Text('Add Restock'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restocks = widget.controller.restocks;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Row(
          children: [
            Text(
              'commune.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Restock',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _openAddRestockDialog,
            icon: const Icon(Icons.add, color: Colors.white, size: 16),
            label: const Text('Add Restock', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filters: Range & Date (matches Screenshot 2)
              Row(
                children: [
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _range,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        style: const TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w500),
                        items: ['Today', 'Yesterday', 'This Week', 'This Month'].map((r) {
                          return DropdownMenuItem(value: r, child: Text('Range:  $r'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _range = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 38,
                    width: 180,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: Row(
                      children: [
                        const Text('Date: ', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                        Expanded(
                          child: TextField(
                            controller: _dateController,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF4B5563)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Table with solid black header row (matches Screenshot 2)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Black header bar
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Date & Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 4, child: Text('Item Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 2, child: Text('Added Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 2, child: Text('Unit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(flex: 2, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                        ],
                      ),
                    ),

                    // Content rows or empty state (matches Screenshot 2)
                    if (restocks.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: const Center(
                          child: Text(
                            'No restock data for this date range.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: restocks.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final r = restocks[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text(r.date.split('T').first, style: const TextStyle(fontSize: 13))),
                                Expanded(flex: 4, child: Text(r.itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                Expanded(flex: 2, child: Text('+${r.quantityAdded}', style: const TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text(r.purchaseUnit ?? 'pcs', style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                      onPressed: () {
                                        widget.controller.restocks.removeAt(index);
                                        widget.controller.localStorage.saveRestocks(widget.controller.restocks);
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
