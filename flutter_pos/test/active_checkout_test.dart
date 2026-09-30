import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:commune_pos/models/order_item.dart';
import 'package:commune_pos/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores checkout draft and clears it only when requested', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();

    final item = OrderItem(
      productId: 'latte',
      name: 'Spanish Latte',
      qty: 2,
      price: 125,
      style: 'iced',
    );
    await storage.saveActiveCheckout(
      items: [item],
      paymentMethod: 'cash',
      tenderedAmount: 300,
      discountAmount: 0,
      pendingVoidRequestId: 'void-request-1',
    );

    final restored = storage.getActiveCheckout();
    expect(restored, isNotNull);
    expect(restored!['paymentMethod'], 'cash');
    expect(restored['tenderedAmount'], 300);
    expect(restored['pendingVoidRequestId'], 'void-request-1');
    final restoredItem = OrderItem.fromJson(
      Map<String, dynamic>.from((restored['items'] as List).first as Map),
    );
    expect(restoredItem.name, 'Spanish Latte');
    expect(restoredItem.qty, 2);
    expect(restoredItem.style, 'iced');

    await storage.clearActiveCheckout();
    expect(storage.getActiveCheckout(), isNull);
  });
}
