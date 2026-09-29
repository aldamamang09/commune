import 'package:intl/intl.dart';
import '../models/order.dart';

class PrinterService {
  static const String cafeName = 'commune';
  static const String cafeStreet = 'Veterans Ave, Tetuan';
  static const String cafeCity = 'Zamboanga City';
  static const String cafeTagline = 'have a seat, take a sip';

  /// Generates a plain-text thermal receipt representation
  static String formatReceipt(Order order) {
    final buffer = StringBuffer();
    final width = 32;

    String center(String text) {
      if (text.length >= width) return text;
      final left = (width - text.length) ~/ 2;
      return ' ' * left + text;
    }

    String row(String left, String right) {
      final space = width - left.length - right.length;
      if (space <= 0) return '$left $right';
      return left + (' ' * space) + right;
    }

    final currency = NumberFormat('#,##0.00', 'en_PH');

    buffer.writeln(center('COMMUNE COFFEE'));
    buffer.writeln(center(cafeStreet));
    buffer.writeln(center(cafeCity));
    buffer.writeln(center(cafeTagline));
    buffer.writeln('-' * width);

    buffer.writeln(row('Ticket #:', order.ticketNo.isNotEmpty ? order.ticketNo : 'N/A'));
    buffer.writeln(row('Date:', DateFormat('MM/dd/yyyy hh:mm a').format(DateTime.tryParse(order.createdAt) ?? DateTime.now())));
    buffer.writeln(row('Barista:', order.baristaName));
    buffer.writeln(row('Payment:', order.paymentMethod.toUpperCase()));
    if (order.voided) {
      buffer.writeln(center('*** VOIDED ***'));
      if (order.voidReason != null) {
        buffer.writeln(center('Reason: ${order.voidReason}'));
      }
    }
    buffer.writeln('-' * width);

    for (final item in order.items) {
      final itemPrice = currency.format(item.lineTotal);
      final itemName = '${item.qty}x ${item.name}';
      buffer.writeln(row(itemName, 'P$itemPrice'));
      if (item.optionsSummary.isNotEmpty) {
        buffer.writeln('  [${item.optionsSummary}]');
      }
    }

    buffer.writeln('-' * width);
    buffer.writeln(row('Subtotal:', 'P${currency.format(order.subtotal)}'));
    if (order.discount > 0) {
      buffer.writeln(row('Discount (${order.promoLabel ?? "Promo"}):', '-P${currency.format(order.discount)}'));
    }
    buffer.writeln(row('TOTAL:', 'P${currency.format(order.total)}'));
    buffer.writeln(row('Tendered:', 'P${currency.format(order.paid)}'));
    buffer.writeln(row('Change:', 'P${currency.format(order.change)}'));
    buffer.writeln('=' * width);
    buffer.writeln(center('Thank you for visiting!'));
    buffer.writeln(center('See you again soon.'));

    return buffer.toString();
  }

  /// Formats drink cup label text
  static String formatCupLabel(Order order, int itemIndex) {
    if (itemIndex >= order.items.length) return '';
    final item = order.items[itemIndex];
    final buffer = StringBuffer();

    buffer.writeln('COMMUNE COFFEE');
    buffer.writeln('Ticket: ${order.ticketNo}  (#${itemIndex + 1}/${order.items.length})');
    buffer.writeln('Item: ${item.name}');
    if (item.style != null) {
      buffer.writeln('Type: ${item.style!.toUpperCase()}');
    }
    if (item.addons.isNotEmpty) {
      buffer.writeln('Add-ons: ${item.addons.map((a) => "${a.name} x${a.qty}").join(", ")}');
    }
    buffer.writeln('Barista: ${order.baristaName}');
    return buffer.toString();
  }
}
