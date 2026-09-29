import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../state/pos_controller.dart';
import '../theme.dart';

class CartPanel extends StatefulWidget {
  final PosController controller;
  final VoidCallback onProceedOrder;
  final VoidCallback onVoid;
  final VoidCallback onPrint;

  const CartPanel({
    super.key,
    required this.controller,
    required this.onProceedOrder,
    required this.onVoid,
    required this.onPrint,
  });

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.controller.tenderedAmount > 0
        ? widget.controller.tenderedAmount.toInt().toString()
        : '0';
  }

  @override
  void didUpdateWidget(covariant CartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.paymentMethod != 'cash') {
      _amountController.text = widget.controller.total.toInt().toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final currency = NumberFormat('#,##0', 'en_PH');

    return Container(
      width: 360,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header: Checkout
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 16),
            child: Text(
              'Checkout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
                letterSpacing: -0.4,
              ),
            ),
          ),

          // Table Column Headers: NAME | QTY | PRICE
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'NAME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'QTY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'PRICE',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Cart Items List
          Expanded(
            child: controller.cart.isEmpty
                ? const Center(
                    child: Text(
                      'No items yet.',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: controller.cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final item = controller.cart[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Name & options
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                if (item.optionsSummary.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.optionsSummary,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Qty adjustment
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () => controller.updateCartQty(index, item.qty - 1),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.remove, size: 12, color: Color(0xFF374151)),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    '${item.qty}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => controller.updateCartQty(index, item.qty + 1),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.add, size: 12, color: Color(0xFF374151)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Price
                          Expanded(
                            flex: 3,
                            child: Text(
                              '₱${currency.format(item.lineTotal)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Bottom Controls & Checkout Form
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Pay with" label
                const Text(
                  'Pay with',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),

                // 3 Payment Buttons: Cash, GCash, Maya
                Row(
                  children: [
                    _buildPaymentButton(
                      label: 'Cash',
                      isSelected: controller.paymentMethod == 'cash',
                      onTap: () {
                        controller.setPaymentMethod('cash');
                        setState(() {
                          _amountController.text = controller.tenderedAmount > 0
                              ? controller.tenderedAmount.toInt().toString()
                              : '0';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildPaymentButton(
                      label: 'GCash',
                      isSelected: controller.paymentMethod == 'gcash',
                      onTap: () {
                        controller.setPaymentMethod('gcash');
                        setState(() {
                          _amountController.text = controller.total.toInt().toString();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildPaymentButton(
                      label: 'Maya',
                      isSelected: controller.paymentMethod == 'maya',
                      onTap: () {
                        controller.setPaymentMethod('maya');
                        setState(() {
                          _amountController.text = controller.total.toInt().toString();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Amount row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
                    ),
                    SizedBox(
                      width: 90,
                      height: 34,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.black, width: 1.5),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val) ?? 0;
                          controller.setTenderedAmount(parsed);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Preset Quick Buttons: Exact, ₱500, ₱1,000, ₱2,000
                Row(
                  children: [
                    _buildPresetPill(
                      label: 'Exact',
                      onTap: () {
                        controller.setTenderedAmount(controller.total);
                        setState(() {
                          _amountController.text = controller.total.toInt().toString();
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildPresetPill(
                      label: '₱500',
                      onTap: () {
                        controller.setTenderedAmount(500);
                        setState(() => _amountController.text = '500');
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildPresetPill(
                      label: '₱1,000',
                      onTap: () {
                        controller.setTenderedAmount(1000);
                        setState(() => _amountController.text = '1000');
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildPresetPill(
                      label: '₱2,000',
                      onTap: () {
                        controller.setTenderedAmount(2000);
                        setState(() => _amountController.text = '2000');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Financial Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                    Text('₱${currency.format(controller.subtotal)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    Text(
                      '₱${currency.format(controller.total)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Change', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                    Text('₱${currency.format(controller.change)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Buttons: Print | Void
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onPrint,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Print', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onVoid,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Void', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Proceed Order Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: controller.cart.isEmpty || controller.isProcessing
                        ? null
                        : widget.onProceedOrder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                    ),
                    child: controller.isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text(
                            'Proceed Order',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 8),

                // Serial port info/error notice (matches Screenshot 4)
                const Center(
                  child: Text(
                    "Failed to execute 'requestPort' on 'Serial': No port selected by the user.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.black : const Color(0xFFD1D5DB),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetPill({
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD1D5DB)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
