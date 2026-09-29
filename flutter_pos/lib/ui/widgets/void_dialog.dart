import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../theme.dart';

class VoidDialog extends StatefulWidget {
  final List<Order> orders;
  final Function(String orderId, String reason, String managerUsername, String managerPassword) onConfirmVoid;

  const VoidDialog({
    super.key,
    required this.orders,
    required this.onConfirmVoid,
  });

  @override
  State<VoidDialog> createState() => _VoidDialogState();
}

class _VoidDialogState extends State<VoidDialog> {
  String _searchQuery = '';
  Order? _selectedOrder;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(text: 'manager');
  final TextEditingController _passwordController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableOrders = widget.orders.where((o) => !o.voided).where((o) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return o.ticketNo.toLowerCase().contains(q) ||
          o.baristaName.toLowerCase().contains(q) ||
          o.items.any((i) => i.name.toLowerCase().contains(q));
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.remove_circle_outline, color: CommuneTheme.voidRed, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Void Order / Ticket',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CommuneTheme.textMain),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Select an existing order to void. Voiding restores inventory and requires manager credentials.',
              style: TextStyle(fontSize: 12, color: CommuneTheme.textMuted),
            ),
            const SizedBox(height: 16),

            if (_selectedOrder == null) ...[
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by Ticket #, Item, Barista...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CommuneTheme.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: availableOrders.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('No active orders found to void.', style: TextStyle(color: CommuneTheme.textMuted)),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: availableOrders.length,
                        separatorBuilder: (_, __) => const Divider(height: 8),
                        itemBuilder: (context, index) {
                          final order = availableOrders[index];
                          return ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            tileColor: const Color(0xFFFAFAFA),
                            title: Text('Ticket #${order.ticketNo.isNotEmpty ? order.ticketNo : order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('${order.items.length} items • ₱${order.total.toStringAsFixed(2)} • ${order.paymentMethod.toUpperCase()}'),
                            trailing: Text(order.baristaName, style: const TextStyle(fontSize: 11, color: CommuneTheme.textMuted)),
                            onTap: () => setState(() => _selectedOrder = order),
                          );
                        },
                      ),
              ),
            ] else ...[
              // Order selected: form for reason and manager auth
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selected Ticket #${_selectedOrder!.ticketNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${_selectedOrder!.items.map((i) => "${i.qty}x ${i.name}").join(", ")}', style: const TextStyle(fontSize: 11)),
                        Text('Total: ₱${_selectedOrder!.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selectedOrder = null),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for Void *',
                  hintText: 'e.g. Customer changed mind, wrong order, spillage',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Manager Username',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Manager Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(color: CommuneTheme.voidRed, fontSize: 12)),
              ],
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _selectedOrder = null),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              final reason = _reasonController.text.trim();
                              final u = _usernameController.text.trim();
                              final p = _passwordController.text;
                              if (reason.isEmpty) {
                                setState(() => _errorMessage = 'Please provide a reason');
                                return;
                              }
                              if (u.isEmpty || p.isEmpty) {
                                setState(() => _errorMessage = 'Manager login required');
                                return;
                              }

                              setState(() {
                                _isProcessing = true;
                                _errorMessage = null;
                              });

                              try {
                                await widget.onConfirmVoid(_selectedOrder!.id, reason, u, p);
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                setState(() {
                                  _errorMessage = e.toString();
                                  _isProcessing = false;
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CommuneTheme.voidRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isProcessing
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Confirm Void', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
