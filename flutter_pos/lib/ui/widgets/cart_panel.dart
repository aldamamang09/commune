import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../state/pos_controller.dart';

class CartPanel extends StatefulWidget {
  final PosController controller;
  final VoidCallback onProceedOrder;
  final VoidCallback onVoid;
  final VoidCallback onPrint;
  final bool isFullWidth;
  final double panelWidth;

  const CartPanel({
    super.key,
    required this.controller,
    required this.onProceedOrder,
    required this.onVoid,
    required this.onPrint,
    this.isFullWidth = false,
    this.panelWidth = 350,
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
    } else if (widget.controller.cart.isEmpty && widget.controller.tenderedAmount == 0) {
      _amountController.text = '0';
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
      width: widget.isFullWidth ? double.infinity : widget.panelWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: widget.isFullWidth
            ? null
            : const Border(
                left: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'Checkout',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
                letterSpacing: -0.4,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'NAME',
                    style: TextStyle(
                      fontSize: 9,
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
                      fontSize: 9,
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
                      fontSize: 9,
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
          Expanded(
            child: controller.cart.isEmpty
                ? const Center(
                    child: Text(
                      'No items yet.',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      children: [
                        for (int index = 0; index < controller.cart.length; index++) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        controller.cart[index].name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      if (controller.cart[index].optionsSummary.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          controller.cart[index].optionsSummary,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      InkWell(
                                        onTap: () => controller.updateCartQty(index, controller.cart[index].qty - 1),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          width: 17,
                                          height: 17,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.remove, size: 11, color: Color(0xFF374151)),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 3),
                                        child: Text(
                                          '${controller.cart[index].qty}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => controller.updateCartQty(index, controller.cart[index].qty + 1),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          width: 17,
                                          height: 17,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.add, size: 11, color: Color(0xFF374151)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '₱${currency.format(controller.cart[index].lineTotal)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (index < controller.cart.length - 1) const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pay with',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 3),
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
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(fontSize: 12, color: Color(0xFF374151)),
                    ),
                    SizedBox(
                      width: 92,
                      height: 28,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
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
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                    Text('₱${currency.format(controller.subtotal)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    Text(
                      '₱${currency.format(controller.total)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Change', style: TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                    Text('₱${currency.format(controller.change)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onPrint,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        child: const Text('Print', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
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
                          padding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        child: const Text('Void', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: controller.cart.isEmpty || controller.isProcessing
                        ? null
                        : widget.onProceedOrder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                    ),
                    child: controller.isProcessing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text(
                            'Proceed Order',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
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
          padding: const EdgeInsets.symmetric(vertical: 5),
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
                fontSize: 11,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }
}
