import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../manila_time.dart';
import '../../models/restock_record.dart';
import '../../state/pos_controller.dart';
import '../widgets/pos_navigation_drawer.dart';

class RestockScreen extends StatefulWidget {
  final PosController controller;
  final PosDrawerBuilder drawerBuilder;

  const RestockScreen({
    super.key,
    required this.controller,
    required this.drawerBuilder,
  });

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  String _filterMode = 'range';
  String _range = 'Today';
  static const List<String> _rangeOptions = [
    'Today',
    'This Week',
    'Last Week',
    'This Month',
    'Last Month',
    'This Year',
    'Last Year',
  ];
  String get _activeRange => _rangeOptions.contains(_range) ? _range : 'Today';
  late final TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: DateFormat('MM/dd/yyyy').format(ManilaTime.now()),
    );
    widget.controller.addListener(_onControllerChange);
    widget.controller.syncService.addListener(_onControllerChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.syncService.syncAll();
    });
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

  DateTime? _parseSelectedDate() {
    try {
      return DateFormat('MM/dd/yyyy').parseStrict(_dateController.text.trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate() async {
    final now = ManilaTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _parseSelectedDate() ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _dateController.text = DateFormat('MM/dd/yyyy').format(selected);
    });
  }

  bool _matchesDateFilter(RestockRecord record) {
    if (_filterMode == 'date') {
      final selectedDate = _parseSelectedDate() ?? ManilaTime.today();
      return ManilaTime.matchesRange(record.date, 'Today', selectedDate);
    }
    return ManilaTime.matchesRange(
        record.date, _activeRange, ManilaTime.today());
  }

  String _formatDateTime(String iso) {
    final parsed = ManilaTime.parse(iso);
    if (parsed == null) return iso;
    return DateFormat('MMM d, yyyy, h:mm a').format(parsed);
  }

  String _formatAddedQty(RestockRecord r) {
    if (r.purchaseQty != null && r.purchaseQty! > 0) {
      final q = r.purchaseQty!;
      return q % 1 == 0 ? '+${q.toInt()}' : '+${q.toStringAsFixed(2)}';
    }
    final stockItem = widget.controller.inventory
        .where((i) =>
            (r.inventoryItemId != null && i.id == r.inventoryItemId) ||
            i.name.trim().toLowerCase() == r.itemName.trim().toLowerCase())
        .firstOrNull;
    final unitSize = (stockItem?.purchaseUnitSize != null &&
            stockItem!.purchaseUnitSize! > 0)
        ? stockItem.purchaseUnitSize!
        : 1.0;
    final pcs = r.quantityAdded / unitSize;
    return pcs % 1 == 0 ? '+${pcs.toInt()}' : '+${pcs.toStringAsFixed(2)}';
  }

  Future<void> _deleteRestock(RestockRecord record) async {
    final result = await widget.controller.deleteRestock(record.id);
    if (!mounted || result == RestockDeleteResult.deleted) return;
    final message = result == RestockDeleteResult.queued
        ? 'Restock deleted on this POS and queued to sync with Admin.'
        : 'Could not delete restock. Check the connection and try again.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildRestockCard(RestockRecord record) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatDateTime(record.date),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280))),
                    const SizedBox(height: 5),
                    Text(record.itemName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete restock',
                onPressed: () => _deleteRestock(record),
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Color(0xFFDC2626)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              const Text('Added',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const Spacer(),
              Text(
                '${_formatAddedQty(record)} ${record.purchaseUnit ?? 'pcs'}',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRestocks =
        widget.controller.restocks.where(_matchesDateFilter).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Open navigation menu',
            icon: const Icon(Icons.menu, color: Colors.white, size: 20),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset(
              'lib/src/images/favicon.png',
              width: 18,
              height: 18,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text(
              'commune.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
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
          IconButton(
            tooltip: 'Sync with Admin',
            icon: const Icon(Icons.sync, color: Colors.white, size: 18),
            onPressed: () => widget.controller.syncService.syncAll(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: widget.drawerBuilder(PosSection.restock),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 8 : 16,
          vertical: MediaQuery.sizeOf(context).width < 600 ? 12 : 20,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding:
              EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filters: Range & Date (responsive Wrap)
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'range', label: Text('Range')),
                      ButtonSegment(value: 'date', label: Text('Date')),
                    ],
                    selected: {_filterMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() => _filterMode = selection.first);
                    },
                  ),
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
                        value: _activeRange,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black,
                            fontWeight: FontWeight.w500),
                        items: _rangeOptions.map((r) {
                          return DropdownMenuItem(
                              value: r, child: Text('Range:  $r'));
                        }).toList(),
                        onChanged: _filterMode == 'range'
                            ? (val) {
                                if (val != null) setState(() => _range = val);
                              }
                            : null,
                      ),
                    ),
                  ),
                  Container(
                    height: 38,
                    width: 190,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _filterMode == 'date'
                          ? Colors.white
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: Row(
                      children: [
                        const Text('Date: ',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF6B7280))),
                        Expanded(
                          child: TextField(
                            controller: _dateController,
                            enabled: _filterMode == 'date',
                            readOnly: true,
                            onTap: _pickDate,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Choose date',
                          onPressed: _filterMode == 'date' ? _pickDate : null,
                          icon: const Icon(Icons.calendar_today_outlined,
                              size: 16, color: Color(0xFF4B5563)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 24, height: 30),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Table with solid black header row (matches Admin Restock table)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 620) {
                    if (filteredRestocks.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No restock data for this date range.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children:
                          filteredRestocks.map(_buildRestockCard).toList(),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Container(
                          color: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: const Row(
                            children: [
                              Expanded(
                                  flex: 3,
                                  child: Text('Date & Time',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                              Expanded(
                                  flex: 4,
                                  child: Text('Item Name',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                              Expanded(
                                  flex: 2,
                                  child: Text('Added Qty',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                              SizedBox(width: 16),
                              Expanded(
                                  flex: 2,
                                  child: Text('Unit',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                              Expanded(
                                  flex: 2,
                                  child: Text('Actions',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
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
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final r = filteredRestocks[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        _formatDateTime(r.date),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF4B5563)),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        r.itemName,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _formatAddedQty(r),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        r.purchaseUnit ?? 'pcs',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF4B5563)),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 16,
                                              color: Color(0xFFDC2626)),
                                          onPressed: () => _deleteRestock(r),
                                          constraints: const BoxConstraints(
                                              minWidth: 28, minHeight: 28),
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
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
