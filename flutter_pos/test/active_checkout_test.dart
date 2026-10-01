import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:commune_pos/models/menu_item.dart';
import 'package:commune_pos/models/inventory_item.dart';
import 'package:commune_pos/models/order.dart';
import 'package:commune_pos/models/order_item.dart';
import 'package:commune_pos/services/local_storage_service.dart';
import 'package:commune_pos/services/supabase_service.dart';
import 'package:commune_pos/services/sync_service.dart';
import 'package:commune_pos/state/pos_controller.dart';
import 'package:commune_pos/ui/widgets/cart_panel.dart';

class _RetryableFailureSupabaseService extends SupabaseService {
  @override
  Future<Map<String, dynamic>> pushOrderAtomic(
    Order order,
    List<Map<String, dynamic>> deductions, {
    String? managerUsername,
    String? managerPassword,
  }) async {
    return {
      'ok': false,
      'error': 'Connection timed out',
      'retryable': true,
    };
  }
}

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

  test('cash tender follows add-on total without replacing custom tender',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    final api = SupabaseService();
    final sync = SyncService(localStorage: storage, supabaseService: api);
    final controller = PosController(
      localStorage: storage,
      supabaseService: api,
      syncService: sync,
    );
    const drink = MenuItem(
      id: 'americano',
      name: 'Americano',
      price: 120,
      category: 'Coffee',
      image: '',
    );
    const addon = OrderAddonSelection(id: 'oat', name: 'Oat', price: 40);

    controller.addToCart(drink, addons: const [addon]);
    expect(controller.total, 160);
    expect(controller.tenderedAmount, 160);

    controller.setTenderedAmount(500);
    controller.addToCart(drink, addons: const [addon]);
    expect(controller.total, 320);
    expect(controller.tenderedAmount, 500);

    controller.dispose();
    sync.dispose();
  });

  test('restores zero cash tender to the addon-inclusive checkout total',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    await storage.saveActiveCheckout(
      items: [
        OrderItem(
          productId: 'americano',
          name: 'Americano',
          price: 120,
          addons: [
            const OrderAddonSelection(id: 'oat', name: 'Oat', price: 40),
          ],
        ),
      ],
      paymentMethod: 'cash',
      tenderedAmount: 0,
      discountAmount: 0,
    );
    final api = SupabaseService();
    final sync = SyncService(localStorage: storage, supabaseService: api);
    final controller = PosController(
      localStorage: storage,
      supabaseService: api,
      syncService: sync,
    );

    await controller.init();

    expect(controller.total, 160);
    expect(controller.tenderedAmount, 160);
    controller.dispose();
    sync.dispose();
  });

  test('queues an order when network fails before connectivity updates',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    final api = _RetryableFailureSupabaseService()
      ..setPosApiToken('cached-pos-token');
    final sync = SyncService(localStorage: storage, supabaseService: api);
    final controller = PosController(
      localStorage: storage,
      supabaseService: api,
      syncService: sync,
    );

    controller.addToCart(const MenuItem(
      id: 'latte',
      name: 'Latte',
      price: 125,
      category: 'Coffee',
      image: '',
    ));
    final result = await controller.proceedOrder();

    expect(result['ok'], true);
    expect(result['synced'], false);
    expect(result['networkFailure'], true);
    expect(storage.getPendingOrders(), hasLength(1));
    expect(storage.getPendingOrders().single.items.single.name, 'Latte');

    controller.dispose();
    sync.dispose();
  });

  test('finds insufficient recipe and cup stock for the full cart', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    await storage.saveInventory([
      InventoryItem(id: 'milk', name: 'Milk', stock: 0.2, unit: 'L'),
      InventoryItem(id: 'hot-cup', name: 'Hot Cup', stock: 1, unit: 'pcs'),
    ]);
    await storage.saveRecipesData({
      'recipeCostings': [
        {
          'menuItems': ['Latte'],
          'ingredients': [
            {
              'inventoryItemId': 'milk',
              'name': 'Milk',
              'amount': 0.2,
              'unit': 'L'
            },
          ],
          'hotCupInventoryItemId': 'hot-cup',
        },
      ],
    });
    final api = SupabaseService();
    final sync = SyncService(localStorage: storage, supabaseService: api);

    final shortages = sync.findStockShortfalls([
      OrderItem(
        productId: 'latte',
        name: 'Latte',
        qty: 2,
        price: 120,
        style: 'hot',
      ),
    ]);

    expect(shortages.map((item) => item['itemName']),
        containsAll(['Milk', 'Hot Cup']));
    expect(
      shortages.firstWhere((item) => item['itemName'] == 'Milk')['required'],
      0.4,
    );
    expect(
      shortages.firstWhere((item) => item['itemName'] == 'Hot Cup')['required'],
      2,
    );

    sync.dispose();
  });

  testWidgets('checkout fits when the keyboard reduces panel height',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();
    final api = SupabaseService();
    final sync = SyncService(localStorage: storage, supabaseService: api);
    final controller = PosController(
      localStorage: storage,
      supabaseService: api,
      syncService: sync,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 250),
            viewInsets: EdgeInsets.only(bottom: 250),
          ),
          child: SizedBox(
            height: 250,
            child: Material(
              child: CartPanel(
                controller: controller,
                isFullWidth: true,
                isKeyboardOpen: true,
                onProceedOrder: () {},
                onVoid: () {},
                onPrint: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Proceed Order'), findsOneWidget);
    expect(find.text('Print'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    sync.dispose();
  });
}
