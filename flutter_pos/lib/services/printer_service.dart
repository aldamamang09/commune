import 'package:intl/intl.dart';
import '../models/order.dart';

class PrinterService {
  static const String cafeName = 'commune';
  static const String cafeStreet = 'Veterans Ave, Tetuan';
  static const String cafeCity = 'Zamboanga City';
  static const String cafeTagline = 'have a seat, take a sip';

  static String _center(String text, {int width = 32}) {
    if (text.length >= width) return text;
    final left = (width - text.length) ~/ 2;
    return '${' ' * left}$text';
  }

  static String _row(String left, String right, {int width = 32, bool strong = false}) {
    final raw = '$left $right';
    if (raw.length >= width) {
      return '$left $right';
    }

    final padded = left.padRight(width - right.length);
    final output = strong ? '$padded$right' : '$padded$right';
    return output;
  }

  /// Generates a plain-text thermal receipt representation
  static String formatReceipt(Order order) {
    final buffer = StringBuffer();
    const width = 32;
    final currency = NumberFormat('#,##0.00', 'en_PH');

    buffer.writeln(_center('COMMUNE'));
    buffer.writeln(_center(cafeStreet));
    buffer.writeln(_center(cafeCity));
    buffer.writeln(_center(cafeTagline));
    buffer.writeln('-' * width);
    buffer.writeln(_center('Customer Copy'));
    buffer.writeln(_center('Order No. ${order.ticketNo.isNotEmpty ? order.ticketNo : 'N/A'}'));
    buffer.writeln(_center(DateFormat('MM/dd/yyyy hh:mm a').format(DateTime.tryParse(order.createdAt) ?? DateTime.now())));
    buffer.writeln(_center('Cashier: ${order.baristaName}'));
    buffer.writeln('-' * width);

    buffer.writeln(_row('Item', 'Amount', width: width, strong: true));
    for (final item in order.items) {
      final itemPrice = currency.format(item.lineTotal);
      buffer.writeln(_row('${item.qty}x ${item.name}', 'P$itemPrice', width: width));
      if (item.optionsSummary.isNotEmpty) {
        buffer.writeln('  ${item.optionsSummary}');
      }
    }

    buffer.writeln('-' * width);
    buffer.writeln(_row('Subtotal', 'P${currency.format(order.subtotal)}', width: width));
    if (order.discount > 0) {
      buffer.writeln(_row('Discount', '-P${currency.format(order.discount)}', width: width));
    }
    buffer.writeln(_row('TOTAL', 'P${currency.format(order.total)}', width: width));
    buffer.writeln('-' * width);
    buffer.writeln(_row('Payment', order.paymentMethod.toUpperCase(), width: width));
    buffer.writeln(_row(order.paymentMethod == 'cash' ? 'Cash / Tendered' : 'Paid', 'P${currency.format(order.paid)}', width: width));
    buffer.writeln(_row('Change', 'P${currency.format(order.change)}', width: width));
    buffer.writeln('-' * width);
    buffer.writeln(_center(cafeTagline));
    buffer.writeln(_center('Thank you. Please come again.'));

    return buffer.toString();
  }

  /// Formats drink cup label text
  static String formatCupLabel(Order order, int itemIndex) {
    if (itemIndex >= order.items.length) return '';
    final item = order.items[itemIndex];
    final buffer = StringBuffer();

    buffer.writeln('MAKE THESE DRINKS');
    buffer.writeln('-' * 20);
    buffer.writeln('ORDER NO. ${order.ticketNo.isNotEmpty ? order.ticketNo : 'N/A'}');
    buffer.writeln(DateFormat('MM/dd/yyyy hh:mm a').format(DateTime.tryParse(order.createdAt) ?? DateTime.now()));
    buffer.writeln('');
    buffer.writeln('Qty  Drink');
    buffer.writeln('${item.qty}x ${item.name.toUpperCase()}');
    if (item.style != null && item.style!.isNotEmpty) {
      buffer.writeln('Type: ${item.style!.toUpperCase()}');
    }
    if (item.optionsSummary.isNotEmpty) {
      buffer.writeln(item.optionsSummary.toUpperCase());
    }
    if (item.addons.isNotEmpty) {
      buffer.writeln('ADD-ONS: ${item.addons.map((a) => '${a.name} x${a.qty}').join(', ').toUpperCase()}');
    }
    buffer.writeln('BARISTA: ${order.baristaName.toUpperCase()}');
    buffer.writeln('');
    buffer.writeln('${itemIndex + 1}/${order.items.length}');
    return buffer.toString();
  }
}
