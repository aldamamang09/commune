import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/printer_service.dart';
import '../theme.dart';

class ReceiptDialog extends StatelessWidget {
  final Order order;
  final VoidCallback onPrint;

  const ReceiptDialog({
    super.key,
    required this.order,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final receiptText = PrinterService.formatReceipt(order);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TICKET #${order.ticketNo.isNotEmpty ? order.ticketNo : order.id.substring(order.id.length - 4)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: CommuneTheme.primary,
                      ),
                    ),
                    const Text('Receipt Preview', style: TextStyle(fontSize: 12, color: CommuneTheme.textMuted)),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 360,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CommuneTheme.border),
              ),
              child: SingleChildScrollView(
                child: Text(
                  receiptText,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onPrint();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Print job sent to thermal printer'), duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print Receipt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CommuneTheme.primary,
                      side: const BorderSide(color: CommuneTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CommuneTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
