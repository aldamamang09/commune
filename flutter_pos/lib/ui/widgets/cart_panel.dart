import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../state/pos_controller.dart';
import '../theme.dart';

class CartPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00', 'en_PH');

    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: CommuneTheme.border)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 20, color: CommuneTheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Current Order',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CommuneTheme.textMain),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAEAEA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${controller.cart.fold(0, (sum, i) => sum + i.qty)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (controller.cart.isNotEmpty)
                  TextButton(
                    onPressed: controller.clearCart,
                    style: TextButton.styleFrom(
                      foregroundColor: CommuneTheme.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Divider(),

          // Cart Items List
          Expanded(
            child: controller.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.coffee_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No items in cart', style: TextStyle(color: CommuneTheme.textMuted, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Select drinks or food from the menu', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: controller.cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final item = controller.cart[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: CommuneTheme.textMain),
                                ),
                                if (item.optionsSummary.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.optionsSummary,
                                    style: const TextStyle(fontSize: 11, color: CommuneTheme.textMuted),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  '₱${currency.format(item.unitPrice)} each',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => controller.updateCartQty(index, item.qty - 1),
                                icon: const Icon(Icons.remove, size: 14),
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F1F1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              IconButton(
                                onPressed: () => controller.updateCartQty(index, item.qty + 1),
                                icon: const Icon(Icons.add, size: 14),
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F1F1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '₱${currency.format(item.lineTotal)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const Divider(),

          // Calculation Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFFAFAFA),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 12, color: CommuneTheme.textMuted)),
                    Text('₱${currency.format(controller.subtotal)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (controller.discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Discount (${controller.promoLabel ?? "Promo"})', style: const TextStyle(fontSize: 12, color: Colors.green)),
                      Text('-₱${currency.format(controller.discountAmount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Due', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CommuneTheme.primary)),
                    Text('₱${currency.format(controller.total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CommuneTheme.primary)),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Payment Method Selector Buttons: Cash, GCash, Maya
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PAYMENT METHOD',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: CommuneTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Cash Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.setPaymentMethod('cash'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: controller.paymentMethod == 'cash' ? CommuneTheme.primary : Colors.white,
                          foregroundColor: controller.paymentMethod == 'cash' ? Colors.white : CommuneTheme.textMain,
                          side: BorderSide(color: controller.paymentMethod == 'cash' ? CommuneTheme.primary : CommuneTheme.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Cash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // GCash Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.setPaymentMethod('gcash'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: controller.paymentMethod == 'gcash' ? const Color(0xFF007DFE) : Colors.white,
                          foregroundColor: controller.paymentMethod == 'gcash' ? Colors.white : const Color(0xFF007DFE),
                          side: BorderSide(color: controller.paymentMethod == 'gcash' ? const Color(0xFF007DFE) : CommuneTheme.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('GCash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Maya Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.setPaymentMethod('maya'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: controller.paymentMethod == 'maya' ? const Color(0xFF00D166) : Colors.white,
                          foregroundColor: controller.paymentMethod == 'maya' ? Colors.white : const Color(0xFF00A34F),
                          side: BorderSide(color: controller.paymentMethod == 'maya' ? const Color(0xFF00D166) : CommuneTheme.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Maya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),

                // Cash presets (500, 1000, 2000) & Tendered amount
                if (controller.paymentMethod == 'cash') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [500, 1000, 2000].map((preset) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () => controller.setTenderedAmount(preset.toDouble()),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: controller.tenderedAmount == preset ? const Color(0xFFE5E7EB) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: controller.tenderedAmount == preset ? Colors.black : Colors.transparent),
                              ),
                              child: Center(
                                child: Text('₱$preset', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tendered:', style: TextStyle(fontSize: 12, color: CommuneTheme.textMuted)),
                      Text('₱${currency.format(controller.tenderedAmount)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Change Due:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CommuneTheme.primary)),
                      Text(
                        '₱${currency.format(controller.change)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: controller.tenderedAmount >= controller.total ? Colors.green.shade700 : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // Action Buttons Row: Void, Print, Proceed Order
                Row(
                  children: [
                    // Void button
                    IconButton(
                      onPressed: onVoid,
                      icon: const Icon(Icons.remove_circle_outline, color: CommuneTheme.voidRed),
                      tooltip: 'Void Order',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF1F2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Print button
                    IconButton(
                      onPressed: onPrint,
                      icon: const Icon(Icons.print_outlined, color: CommuneTheme.primary),
                      tooltip: 'Reprint / Preview Receipt',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F1F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Proceed Order button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: controller.cart.isEmpty || controller.isProcessing ? null : onProceedOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CommuneTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          disabledBackgroundColor: const Color(0xFFCCCCCC),
                        ),
                        child: controller.isProcessing
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Proceed Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward, size: 16),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
