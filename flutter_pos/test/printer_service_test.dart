import 'package:flutter_test/flutter_test.dart';
import 'package:commune_pos/models/order.dart';
import 'package:commune_pos/models/order_item.dart';
import 'package:commune_pos/services/printer_service.dart';

void main() {
  test('receipt format matches the compact customer receipt style', () {
    final order = Order(
      id: 'ord-1',
      createdAt: '2026-09-30T10:30:00Z',
      baristaName: 'Ari',
      items: [
        OrderItem(
          productId: 'latte',
          name: 'Vanilla Latte',
          qty: 2,
          price: 90,
          style: 'iced',
          addons: [
            OrderAddonSelection(name: 'Oat Milk', qty: 1, price: 15),
          ],
        ),
      ],
      subtotal: 180,
      discount: 0,
      total: 180,
      paymentMethod: 'cash',
      ticketNo: 'A-010',
      paid: 200,
      change: 20,
    );

    final receipt = PrinterService.formatReceipt(order);

    expect(receipt, contains('Order No. A-010'));
    expect(receipt, contains('Customer Copy'));
    expect(receipt, contains('have a seat, take a sip'));
    expect(receipt, contains('Vanilla Latte'));
    expect(receipt, contains('TOTAL'));
  });

  test('cup label format matches the drink label style', () {
    final order = Order(
      id: 'ord-2',
      createdAt: '2026-09-30T15:00:00Z',
      baristaName: 'Nina',
      items: [
        OrderItem(
          productId: 'mocha',
          name: 'Mocha',
          qty: 1,
          price: 110,
          style: 'hot',
        ),
      ],
      subtotal: 110,
      total: 110,
      paid: 110,
      ticketNo: 'A-011',
    );

    final label = PrinterService.formatCupLabel(order, 0);

    expect(label, contains('MAKE THESE DRINKS'));
    expect(label, contains('ORDER NO. A-011'));
    expect(label, contains('MOCHA'));
  });
}
