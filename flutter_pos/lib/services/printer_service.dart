import 'package:intl/intl.dart';
import '../manila_time.dart';
import '../models/menu_item.dart';
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
    buffer.writeln(_center(DateFormat('MM/dd/yyyy hh:mm a').format(ManilaTime.parse(order.createdAt) ?? ManilaTime.now())));
    buffer.writeln(_center('Cashier: ${order.baristaName}'));
    buffer.writeln('-' * width);

    buffer.writeln(_row('Item', 'Amount', width: width, strong: true));
    for (final item in order.items) {
      final itemPrice = currency.format(item.lineTotal);
      buffer.writeln(_row('${item.qty}x ${item.name}', 'P$itemPrice', width: width));
      if (item.style != null && item.style!.isNotEmpty) {
        buffer.writeln('  ${item.style!.toUpperCase()}');
      }
      for (final addon in item.addons) {
        final addonTotal = addon.price * addon.qty * item.qty;
        buffer.writeln(
          _row(
            '  Add: ${addon.name} x${addon.qty}',
            'incl P${currency.format(addonTotal)}',
            width: width,
          ),
        );
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

  static bool isDrinkCategory(String? category) {
    if (category == null || category.trim().isEmpty) return false;
    return !RegExp(r'^\s*(food|pastr)', caseSensitive: false).hasMatch(category);
  }

  static List<int> cupLabelItemIndexes(Order order, List<MenuItem> menu) {
    final indexes = <int>[];
    for (var itemIndex = 0; itemIndex < order.items.length; itemIndex++) {
      final item = order.items[itemIndex];
      final category = item.category ??
          menu.where((menuItem) => menuItem.id == item.productId).firstOrNull?.category;
      if (!isDrinkCategory(category)) continue;
      for (var copy = 0; copy < item.qty; copy++) {
        indexes.add(itemIndex);
      }
    }
    return indexes;
  }

  /// Formats drink cup label text
  static String formatCupLabel(Order order, int itemIndex) {
    if (itemIndex >= order.items.length) return '';
    final item = order.items[itemIndex];
    final buffer = StringBuffer();

    buffer.writeln('MAKE THIS DRINKS');
    buffer.writeln('-' * 22);
    buffer.writeln('ORDER NO. ${order.ticketNo.isNotEmpty ? order.ticketNo : 'N/A'}');
    buffer.writeln('-' * 22);
    buffer.writeln('1X ${item.name.toUpperCase()}');
    final options = <String>[];
    if (item.style != null && item.style!.isNotEmpty) {
      options.add('(${item.style!.toUpperCase()})');
    }
    if (item.addons.isNotEmpty) {
      options.add(
        '*addson ${item.addons.map((addon) => '+${addon.qty} ${addon.name}').join(', ')}',
      );
    }
    if (options.isNotEmpty) buffer.writeln(options.join(' '));
    return buffer.toString();
  }
}
