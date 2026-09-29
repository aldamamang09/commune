import 'package:flutter/material.dart';
import '../../models/inventory_item.dart';
import '../../state/pos_controller.dart';

class StockScreen extends StatefulWidget {
  final PosController controller;

  const StockScreen({super.key, required this.controller});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _range = 'Today';
  final TextEditingController _dateController = TextEditingController(text: '09/29/2026');

  // Add stock item inputs
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _totalUnitController = TextEditingController();
  final TextEditingController _unitItemController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '0');
  final TextEditingController _unitController = TextEditingController();

  // Restock addition map
  final Map<String, TextEditingController> _restockControllers = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.controller.inventory) {
      _restockControllers[item.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _nameController.dispose();
    _totalUnitController.dispose();
    _unitItemController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    for (final c in _restockControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleAddStockItem() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final qty = double.tryParse(_qtyController.text) ?? 0;
    final unit = _unitController.text.trim().isEmpty ? 'pcs' : _unitController.text.trim();

    final newItem = InventoryItem(
      id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      stock: qty,
      openingStock: qty,
      unit: unit,
      cost: 0,
      maxStock: 100,
    );

    widget.controller.inventory.add(newItem);
    widget.controller.localStorage.saveInventory(widget.controller.inventory);
    _restockControllers[newItem.id] = TextEditingController();

    _handleClear();
    setState(() {});
  }

  void _handleClear() {
    _nameController.clear();
    _totalUnitController.clear();
    _unitItemController.clear();
    _qtyController.text = '0';
    _unitController.clear();
    setState(() {});
  }

  void _handleRestock(InventoryItem item) {
    final controller = _restockControllers[item.id];
    if (controller == null) return;
    final qty = double.tryParse(controller.text) ?? 0;
    if (qty <= 0) return;

    widget.controller.restockItem(item.id, qty, 'Stock Restock');
    controller.clear();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $qty ${item.unit} to ${item.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = widget.controller.inventory;

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
              'Stock inventory',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
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
              // Filters: Range & Date
              Row(
                children: [
                  // Range dropdown
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

                  // Date input
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
              const SizedBox(height: 24),

              // Metric: Total Cups Used
              const Text(
                'Total Cups Used',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 4),
              const Text(
                '0.00 cups',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 24),

              // ADD STOCK ITEM Section (matches Screenshot 1)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ADD STOCK ITEM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            _buildFormField(label: 'Item Name', hint: 'e.g. Coffee Beans', controller: _nameController, width: 170),
                            _buildFormField(label: 'Total Unit Item', hint: 'e.g. 1000', controller: _totalUnitController, width: 140),
                            _buildFormField(label: 'Unit Item', hint: 'e.g. 9', controller: _unitItemController, width: 130),
                            _buildFormField(label: 'Quantity', hint: '0', controller: _qtyController, width: 120),
                            _buildFormField(label: 'Unit', hint: 'grams, ml, pcs', controller: _unitController, width: 130),
                            _buildFormField(label: 'Cups make', hint: '—', controller: TextEditingController(text: '—'), width: 120, enabled: false),

                            // Add & Clear buttons
                            SizedBox(
                              height: 38,
                              child: ElevatedButton(
                                onPressed: _handleAddStockItem,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  elevation: 0,
                                ),
                                child: const Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            SizedBox(
                              height: 38,
                              child: OutlinedButton(
                                onPressed: _handleClear,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: const Text('Clear', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Data Table (matches Screenshot 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 44,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 52,
                  horizontalMargin: 12,
                  columnSpacing: 24,
                  headingTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                  columns: const [
                    DataColumn(label: Text('Item')),
                    DataColumn(label: Text('Opening')),
                    DataColumn(label: Text('Restock')),
                    DataColumn(label: Text('Used per Unit')),
                    DataColumn(label: Text('Unit')),
                    DataColumn(label: Text('Used per Pcs')),
                    DataColumn(label: Text('Remaining')),
                    DataColumn(label: Text('Cups Left')),
                    DataColumn(label: Text('Restock')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: inventory.map((item) {
                    final isCup = item.name.toLowerCase().contains('cup');
                    final cupsLeft = !isCup
                        ? (item.stock > 0 ? (item.stock * 111).toStringAsFixed(1) : '0.0')
                        : '—';

                    _restockControllers.putIfAbsent(item.id, () => TextEditingController());
                    final rCtrl = _restockControllers[item.id]!;

                    return DataRow(
                      cells: [
                        DataCell(Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        DataCell(Text('${item.openingStock.toStringAsFixed(2)} pcs', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)))),
                        DataCell(const Text('0.00 pcs', style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)))),
                        DataCell(
                          Container(
                            width: 60,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFD1D5DB)),
                            ),
                            child: const Center(
                              child: Text(
                                '0',
                                style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(item.unit, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)))),
                        DataCell(Text(isCup ? '—' : '0.00 pc', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 68,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFD1D5DB)),
                                ),
                                child: Center(
                                  child: Text(
                                    item.stock.toStringAsFixed(2),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('pcs', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                        DataCell(Text(cupsLeft == '—' ? '—' : '$cupsLeft cups', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 60,
                                height: 28,
                                child: TextField(
                                  controller: rCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 11),
                                  decoration: InputDecoration(
                                    hintText: '+Qty',
                                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 28,
                                child: ElevatedButton(
                                  onPressed: () => _handleRestock(item),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    elevation: 0,
                                  ),
                                  child: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6B7280)),
                                onPressed: () {},
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF6B7280)),
                                onPressed: () {
                                  widget.controller.inventory.removeWhere((i) => i.id == item.id);
                                  widget.controller.localStorage.saveInventory(widget.controller.inventory);
                                  setState(() {});
                                },
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required double width,
    bool enabled = true,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          SizedBox(
            height: 38,
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
