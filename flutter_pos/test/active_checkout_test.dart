import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:commune_pos/models/menu_item.dart';
import 'package:commune_pos/models/order_item.dart';
import 'package:commune_pos/services/local_storage_service.dart';
import 'package:commune_pos/services/supabase_service.dart';
import 'package:commune_pos/services/sync_service.dart';
import 'package:commune_pos/state/pos_controller.dart';

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

  test('blocks adding menu items while a void request is pending', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    final api = SupabaseService();
    final sync = SyncService(localStorage: storage, supabaseService: api);
    final controller = PosController(
      localStorage: storage,
      supabaseService: api,
      syncService: sync,
    )..pendingCartVoidRequestId = 'void-request-1';

    controller.addToCart(const MenuItem(
      id: 'latte',
      name: 'Latte',
      price: 125,
      category: 'Coffee',
      image: '',
    ));

    expect(controller.cart, isEmpty);
    controller.dispose();
    sync.dispose();
  });
}
