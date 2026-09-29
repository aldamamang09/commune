import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/inventory_item.dart';
import '../../models/restock_record.dart';
import '../../state/pos_controller.dart';

class RestockScreen extends StatefulWidget {
  final PosController controller;

  const RestockScreen({super.key, required this.controller});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  String _range = 'Today';
  late final TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: DateFormat('MM/dd/yyyy').format(DateTime.now()),
    );
    widget.controller.addListener(_onControllerChange);
    widget.controller.syncService.addListener(_onControllerChange);
    widget.controller.syncService.syncAll();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    widget.controller.syncService.removeListener(_onControllerChange);
    _dateController.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  bool _matchesDateFilter(RestockRecord record) {
    final parsed = DateTime.tryParse(record.date);
    if (parsed == null) return true;
    final itemDay = DateTime(parsed.year, parsed.month, parsed.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_range) {
      case 'Today':
        return itemDay == today;
      case 'Yesterday':
        return itemDay == today.subtract(const Duration(days: 1));
      case 'This Week':
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return !itemDay.isBefore(startOfWeek) && !itemDay.isAfter(today);
      case 'Last Week':
        final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
        final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
        final endOfLastWeek = startOfThisWeek.subtract(const Duration(days: 1));
        return !itemDay.isBefore(startOfLastWeek) && !itemDay.isAfter(endOfLastWeek);
      case 'This Month':
        return itemDay.year == today.year && itemDay.month == today.month;
      case 'Last Month':
        final lastMonth = DateTime(today.year, today.month - 1, 1);
        return itemDay.year == lastMonth.year && itemDay.month == lastMonth.month;
      default:
        return true;
    }
  }

  String _formatDateTime(String iso) {
    final parsed = DateTime.tryParse(iso)?.toLocal();
    if (parsed == null) return iso;
    return DateFormat('MMM d, yyyy, h:mm a').format(parsed);
  }

  String _formatAddedQty(RestockRecord r) {
    if (r.purchaseQty != null && r.purchaseQty! > 0) {
      final q = r.purchaseQty!;
      return q % 1 == 0 ? '+${q.toInt()}' : '+${q.toStringAsFixed(2)}';
    }
    final stockItem = widget.controller.inventory.where((i) =>
        (r.inventoryItemId != null && i.id == r.inventoryItemId) ||
        i.name.trim().toLowerCase() == r.itemName.trim().toLowerCase()).firstOrNull;
    final unitSize = (stockItem?.purchaseUnitSize != null && stockItem!.purchaseUnitSize! > 0)
        ? stockItem.purchaseUnitSize!
        : 1.0;
    final pcs = r.quantityAdded / unitSize;
    return pcs % 1 == 0 ? '+${pcs.toInt()}' : '+${pcs.toStringAsFixed(2)}';
  }

  void _openAddRestockDialog() {
    if (widget.controller.inventory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a stock item in Stock Inventory first.')),
      );
      return;
    }
    InventoryItem? selectedItem = widget.controller.inventory.first;
    final qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Restock Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<InventoryItem>(
                  initialValue: selectedItem,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Select Item',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: widget.controller.inventory.map((i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${i.name} (${i.unit})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedItem = val),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity to Add (pcs)',
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
                final pieces = double.tryParse(qtyController.text.trim());
                if (selectedItem == null || pieces == null || pieces <= 0) return;

                await widget.controller.restockItem(selectedItem!.id, pieces);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
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
    final filteredRestocks = widget.controller.restocks.where(_matchesDateFilter).toList();

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
            Flexible(
              child: Text(
                'Restock',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF9CA3AF),
                ),
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
          IconButton(
            tooltip: 'Sync with Admin',
            icon: const Icon(Icons.sync, color: Colors.white, size: 18),
            onPressed: () => widget.controller.syncService.syncAll(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
              // Filters: Range & Date (responsive Wrap)
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                        items: ['Today', 'Yesterday', 'This Week', 'Last Week', 'This Month', 'Last Month'].map((r) {
                          return DropdownMenuItem(value: r, child: Text('Range:  $r'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _range = val);
                        },
                      ),
                    ),
                  ),
                  Container(
                    height: 38,
                    width: 190,
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

              // Table with solid black header row (matches Admin Restock table)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Date & Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 4, child: Text('Item Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Added Qty', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 16),
                          Expanded(flex: 2, child: Text('Unit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Actions', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                    ),
                    if (filteredRestocks.isEmpty)
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
                        itemCount: filteredRestocks.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final r = filteredRestocks[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    _formatDateTime(r.date),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    r.itemName,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatAddedQty(r),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    r.purchaseUnit ?? 'pcs',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                      onPressed: () => widget.controller.deleteRestock(r.id),
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      padding: EdgeInsets.zero,
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
