import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/menu_item.dart';
import '../models/order_item.dart';
import '../models/order.dart';
import '../models/inventory_item.dart';
import '../models/void_request.dart';
import '../models/restock_record.dart';
import '../models/staff_user.dart';
import '../models/login_activity.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';

class PosController extends ChangeNotifier {
  final LocalStorageService localStorage;
  final SupabaseService supabaseService;
  final SyncService syncService;

  StaffUser? currentUser;
  String currentBaristaName = 'Barista';
  String? currentBaristaUserId;
  bool isPosOpen = false;

  List<MenuItem> menu = [];
  List<String> categories = ['All'];
  List<InventoryItem> inventory = [];
  List<Order> orders = [];
  List<VoidRequest> voidRequests = [];
  List<RestockRecord> restocks = [];
  List<StaffUser> staffUsers = [];
  List<LoginActivity> shiftLogs = [];

  // Filtering
  String selectedCategory = 'All';
  String searchQuery = '';

  // Cart
  List<OrderItem> cart = [];
  String paymentMethod = 'cash'; // 'cash', 'gcash', 'maya'
  double tenderedAmount = 0.0;
  String? promoId;
  String? promoLabel;
  double discountAmount = 0.0;

  Order? lastCompletedOrder;
  bool isProcessing = false;

  PosController({
    required this.localStorage,
    required this.supabaseService,
    required this.syncService,
  });

  Future<void> init() async {
    isPosOpen = localStorage.getPosIsOpen();
    final openedBy = localStorage.getPosOpenedBy();
    if (openedBy != null && openedBy.isNotEmpty) {
      currentBaristaName = openedBy;
    }

    // Load from local cache first (Instant boot!)
    menu = localStorage.getMenu();
    categories = localStorage.getCategories();
    inventory = localStorage.getInventory();
    orders = localStorage.getOrders();
    staffUsers = localStorage.getStaff();
    voidRequests = localStorage.getVoidRequests();
    restocks = localStorage.getRestocks();
    shiftLogs = localStorage.getLoginActivity();

    // If cache is empty, seed defaults
    if (menu.isEmpty) {
      _seedDefaultMenu();
    }
    if (inventory.isEmpty) {
      _seedDefaultInventory();
    }
    if (staffUsers.isEmpty) {
      _seedDefaultStaff();
    }

    notifyListeners();

    // Trigger sync with Supabase in background
    syncService.syncAll().then((_) {
      // Refresh local copy from cache after sync
      menu = localStorage.getMenu();
      categories = localStorage.getCategories();
      inventory = localStorage.getInventory();
      orders = localStorage.getOrders();
      staffUsers = localStorage.getStaff();
      voidRequests = localStorage.getVoidRequests();
      restocks = localStorage.getRestocks();
      shiftLogs = localStorage.getLoginActivity();
      notifyListeners();
    });
  }

  // --- Stock Ledger Calculation (Opening, Restock, Used, Remaining) ---
  Map<String, double> getStockLedger(InventoryItem item, {String range = 'Today', DateTime? selectedDate}) {
    final itemRestocks = restocks.where((r) =>
      (r.inventoryItemId != null && r.inventoryItemId == item.id) ||
      r.itemName.trim().toLowerCase() == item.name.trim().toLowerCase()
    );

    final targetDate = selectedDate ?? DateTime.now();
    final dateStr = "${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

    double totalRestocked = 0;
    for (final r in itemRestocks) {
      if (range == 'Today') {
        if (r.date.startsWith(dateStr)) {
          totalRestocked += r.quantityAdded;
        }
      } else {
        totalRestocked += r.quantityAdded;
      }
    }

    double totalUsed = 0;
    for (final order in orders) {
      if (order.voided) continue;
      final oDate = DateTime.tryParse(order.createdAt);
      if (range == 'Today') {
        if (oDate == null || oDate.year != targetDate.year || oDate.month != targetDate.month || oDate.day != targetDate.day) {
          continue;
        }
      }
      for (final line in order.items) {
        final name = line.name.toLowerCase();
        if (item.id == 'coffee-beans' && (name.contains('espresso') || name.contains('latte') || name.contains('cappuccino') || name.contains('americano'))) {
          totalUsed += 18.0 * line.qty;
        } else if (item.id == 'milk' && (name.contains('latte') || name.contains('cappuccino') || name.contains('flat white'))) {
          totalUsed += 180.0 * line.qty;
        } else if (item.id == 'matcha-powder' && name.contains('matcha')) {
          totalUsed += 10.0 * line.qty;
        } else if (item.id == 'cups-hot' && line.style == 'hot') {
          totalUsed += 1.0 * line.qty;
        } else if (item.id == 'cups-peta' && line.style != 'hot') {
          totalUsed += 1.0 * line.qty;
        } else if (item.cupUsageAmount != null && item.cupUsageAmount! > 0) {
          totalUsed += item.cupUsageAmount! * line.qty;
        }
      }
    }

    final double pieceSize = (item.purchaseUnitSize != null && item.purchaseUnitSize! > 0) ? item.purchaseUnitSize! : 1.0;
    final double remainingBase = item.stock;
    final double remainingPcs = remainingBase / pieceSize;
    final double restockedPcs = totalRestocked / pieceSize;
    final double usedPcs = totalUsed / pieceSize;
    final double openingBase = remainingBase - totalRestocked + totalUsed;
    final double openingPcs = openingBase / pieceSize;
    final double usedPerUnit = totalUsed;

    double? cupsLeft;
    if (item.cupUsageAmount != null && item.cupUsageAmount! > 0) {
      cupsLeft = remainingBase / item.cupUsageAmount!;
    } else if (item.cupsMake != null) {
      cupsLeft = item.cupsMake!;
    }

    return {
      'openingPcs': openingPcs < 0 ? 0.0 : openingPcs,
      'restockedPcs': restockedPcs,
      'usedPerUnit': usedPerUnit,
      'usedPcs': usedPcs,
      'remainingPcs': remainingPcs < 0 ? 0.0 : remainingPcs,
      'cupsLeft': cupsLeft ?? -1.0,
    };
  }

  // --- Filtered Menu ---
  List<MenuItem> get filteredMenu {
    return menu.where((item) {
      if (!item.available) return false;
      if (selectedCategory != 'All' && item.category.toLowerCase() != selectedCategory.toLowerCase()) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        return item.name.toLowerCase().contains(query) || item.category.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  void setCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  // --- Cart Management ---
  double get subtotal => cart.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get total => (subtotal - discountAmount) > 0 ? (subtotal - discountAmount) : 0.0;
  double get change => paymentMethod == 'cash' && tenderedAmount >= total ? (tenderedAmount - total) : 0.0;

  void addToCart(MenuItem product, {String? style, List<OrderAddonSelection> addons = const [], int qty = 1}) {
    // Check if duplicate item exists in cart
    final existingIndex = cart.indexWhere((line) {
      if (line.productId != product.id) return false;
      if (line.style != style) return false;
      if (line.addons.length != addons.length) return false;
      for (int i = 0; i < addons.length; i++) {
        if (line.addons[i].name != addons[i].name || line.addons[i].qty != addons[i].qty) {
          return false;
        }
      }
      return true;
    });

    if (existingIndex >= 0) {
      cart[existingIndex].qty += qty;
    } else {
      cart.add(OrderItem(
        productId: product.id,
        name: product.name,
        price: product.price,
        qty: qty,
        style: style,
        addons: addons,
        category: product.category,
      ));
    }
    notifyListeners();
  }

  void updateCartQty(int index, int newQty) {
    if (index >= 0 && index < cart.length) {
      if (newQty <= 0) {
        cart.removeAt(index);
      } else {
        cart[index].qty = newQty;
      }
      notifyListeners();
    }
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < cart.length) {
      cart.removeAt(index);
      notifyListeners();
    }
  }

  void clearCart() {
    cart.clear();
    tenderedAmount = 0.0;
    discountAmount = 0.0;
    promoId = null;
    promoLabel = null;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    paymentMethod = method;
    if (method != 'cash') {
      tenderedAmount = total;
    }
    notifyListeners();
  }

  void setTenderedAmount(double amount) {
    tenderedAmount = amount;
    notifyListeners();
  }

  // --- Order Checkout ---
  Future<Map<String, dynamic>> proceedOrder() async {
    if (cart.isEmpty) {
      return {'ok': false, 'error': 'Cart is empty'};
    }
    if (paymentMethod == 'cash' && tenderedAmount < total) {
      return {'ok': false, 'error': 'Cash tendered is insufficient'};
    }

    isProcessing = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final orderId = 'ord-${now.millisecondsSinceEpoch}';

      // Generate next ticket number (PH day format or sequence e.g. 001)
      final existingTodayCount = orders.where((o) {
        final d = DateTime.tryParse(o.createdAt);
        return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
      }).length;
      final localTicketNo = (existingTodayCount + 1).toString().padLeft(3, '0');

      final order = Order(
        id: orderId,
        createdAt: now.toIso8601String(),
        baristaName: currentBaristaName,
        baristaUserId: currentBaristaUserId,
        items: List.from(cart),
        subtotal: subtotal,
        discount: discountAmount,
        promoLabel: promoLabel,
        total: total,
        paymentMethod: paymentMethod,
        ticketNo: localTicketNo,
        paid: paymentMethod == 'cash' ? tenderedAmount : total,
        change: change,
        voided: false,
        isSynced: false,
      );

      // Save locally immediately (Local-First!)
      await localStorage.addOrder(order);
      orders.insert(0, order);
      lastCompletedOrder = order;

      // Deduct inventory locally
      _deductInventoryLocally(order);

      // Clear cart
      clearCart();

      // Trigger background sync
      syncService.syncAll();

      isProcessing = false;
      notifyListeners();
      return {'ok': true, 'order': order};
    } catch (e) {
      isProcessing = false;
      notifyListeners();
      return {'ok': false, 'error': e.toString()};
    }
  }

  void _deductInventoryLocally(Order order) {
    for (final line in order.items) {
      final name = line.name.toLowerCase();
      if (name.contains('espresso') || name.contains('latte') || name.contains('cappuccino') || name.contains('americano')) {
        final beans = inventory.where((i) => i.id == 'coffee-beans').firstOrNull;
        if (beans != null) beans.stock = (beans.stock - (18.0 * line.qty)).clamp(0.0, double.infinity);
      }
      if (name.contains('latte') || name.contains('cappuccino') || name.contains('flat white')) {
        final milk = inventory.where((i) => i.id == 'milk').firstOrNull;
        if (milk != null) milk.stock = (milk.stock - (180.0 * line.qty)).clamp(0.0, double.infinity);
      }
      if (name.contains('matcha')) {
        final matcha = inventory.where((i) => i.id == 'matcha-powder').firstOrNull;
        if (matcha != null) matcha.stock = (matcha.stock - (10.0 * line.qty)).clamp(0.0, double.infinity);
      }
      final cupId = line.style == 'hot' ? 'cups-hot' : 'cups-peta';
      final cup = inventory.where((i) => i.id == cupId).firstOrNull;
      if (cup != null) cup.stock = (cup.stock - (1.0 * line.qty)).clamp(0.0, double.infinity);
    }
    localStorage.saveInventory(inventory);
  }

  // --- Void Order Workflow ---
  Future<Map<String, dynamic>> voidOrder(String orderId, String reason, String managerUsername, String managerPassword) async {
    // 1. Verify manager credentials
    final manager = staffUsers.firstWhere(
      (u) => u.username.toLowerCase() == managerUsername.trim().toLowerCase() && u.isManager,
      orElse: () => const StaffUser(id: '', username: '', password: '', name: '', role: ''),
    );
    if (manager.id.isEmpty || manager.password != managerPassword) {
      return {'ok': false, 'error': 'Invalid manager credentials'};
    }

    final order = orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) {
      return {'ok': false, 'error': 'Order not found'};
    }
    if (order.voided) {
      return {'ok': false, 'error': 'Order is already voided'};
    }

    order.voided = true;
    order.voidReason = reason;
    order.voidedBy = manager.name;
    order.isSynced = false;

    // Save locally
    await localStorage.addOrder(order);

    // Restore inventory
    _restoreInventoryLocally(order);

    // Try Supabase atomic void
    if (syncService.isOnline && supabaseService.isInitialized) {
      supabaseService.voidOrderAtomic(orderId, reason, manager.name).then((ok) {
        if (ok) {
          order.isSynced = true;
          localStorage.addOrder(order);
        }
      });
    }

    notifyListeners();
    return {'ok': true};
  }

  void _restoreInventoryLocally(Order order) {
    for (final line in order.items) {
      final name = line.name.toLowerCase();
      if (name.contains('espresso') || name.contains('latte') || name.contains('cappuccino') || name.contains('americano')) {
        final beans = inventory.where((i) => i.id == 'coffee-beans').firstOrNull;
        if (beans != null) beans.stock += (18.0 * line.qty);
      }
      if (name.contains('latte') || name.contains('cappuccino') || name.contains('flat white')) {
        final milk = inventory.where((i) => i.id == 'milk').firstOrNull;
        if (milk != null) milk.stock += (180.0 * line.qty);
      }
      if (name.contains('matcha')) {
        final matcha = inventory.where((i) => i.id == 'matcha-powder').firstOrNull;
        if (matcha != null) matcha.stock += (10.0 * line.qty);
      }
      final cupId = line.style == 'hot' ? 'cups-hot' : 'cups-peta';
      final cup = inventory.where((i) => i.id == cupId).firstOrNull;
      if (cup != null) cup.stock += (1.0 * line.qty);
    }
    localStorage.saveInventory(inventory);
  }

  // --- Restock Operations ---
  Future<void> addRestockRecord({
    required String? inventoryItemId,
    required String itemName,
    required double quantityAdded,
    double? purchaseQty,
    String? purchaseUnit,
  }) async {
    final now = DateTime.now().toIso8601String();
    final record = RestockRecord(
      id: 'rst-${DateTime.now().millisecondsSinceEpoch}',
      inventoryItemId: inventoryItemId,
      itemName: itemName,
      quantityAdded: quantityAdded,
      purchaseQty: purchaseQty,
      purchaseUnit: purchaseUnit,
      date: now,
      isSynced: false,
    );

    await localStorage.addRestock(record);
    restocks.insert(0, record);

    if (inventoryItemId != null) {
      final item = inventory.where((i) => i.id == inventoryItemId).firstOrNull;
      if (item != null) {
        item.stock += quantityAdded;
        await localStorage.saveInventory(inventory);
      }
    }

    notifyListeners();
    syncService.syncAll();
  }

  Future<void> restockItem(String inventoryItemId, double qty, [String? notes]) async {
    final item = inventory.where((i) => i.id == inventoryItemId).firstOrNull;
    if (item == null) return;
    await addRestockRecord(
      inventoryItemId: inventoryItemId,
      itemName: item.name,
      quantityAdded: qty,
    );
  }

  // --- Shift Clock In / Out ---
  Future<void> punchShift(StaffUser staff, String type) async {
    final now = DateTime.now().toIso8601String();
    final log = LoginActivity(
      id: 'log-${DateTime.now().millisecondsSinceEpoch}',
      userId: staff.id,
      username: staff.username,
      name: staff.name,
      role: staff.role,
      type: type,
      at: now,
      isSynced: false,
    );

    await localStorage.addLoginActivity(log);
    shiftLogs.insert(0, log);

    if (type == 'login') {
      currentBaristaName = staff.name;
      currentBaristaUserId = staff.id;
      isPosOpen = true;
      await localStorage.setPosState(isOpen: true, openedBy: staff.name, openedAt: now);
    }

    notifyListeners();
    syncService.syncAll();
  }

  // --- Default Seeding ---
  void _seedDefaultMenu() {
    menu = [
      const MenuItem(id: 'spanish-latte', name: 'Spanish Latte', price: 130, category: 'Special', image: '/images/drinks.jpg', styles: ['iced', 'hot']),
      const MenuItem(id: 'matcha-espresso', name: 'Matcha Espresso', price: 140, category: 'Special', image: '/images/drinks.jpg', styles: ['iced']),
      const MenuItem(id: 'sea-salt-latte', name: 'Sea Salt Latte', price: 135, category: 'Special', image: '/images/drinks.jpg', styles: ['iced']),
      const MenuItem(id: 'americano', name: 'Americano', price: 100, category: 'Classic', image: '/images/drinks.jpg', styles: ['hot', 'iced']),
      const MenuItem(id: 'cappuccino', name: 'Cappuccino', price: 120, category: 'Classic', image: '/images/drinks.jpg', styles: ['hot', 'iced']),
      const MenuItem(id: 'latte', name: 'Café Latte', price: 120, category: 'Classic', image: '/images/drinks.jpg', styles: ['hot', 'iced']),
      const MenuItem(id: 'caramel-macchiato', name: 'Caramel Macchiato', price: 135, category: 'Classic', image: '/images/drinks.jpg', styles: ['hot', 'iced']),
      const MenuItem(id: 'pure-matcha', name: 'Pure Matcha Latte', price: 130, category: 'Matcha Drinks', image: '/images/matcha-umami.jpg', styles: ['hot', 'iced']),
      const MenuItem(id: 'strawberry-matcha', name: 'Strawberry Matcha', price: 145, category: 'Matcha Drinks', image: '/images/matcha-umami.jpg', styles: ['iced']),
      const MenuItem(id: 'chocolate', name: 'Artisan Chocolate', price: 120, category: 'Non-Coffee', image: '/images/drinks.jpg', styles: ['hot', 'iced']),
      const MenuItem(id: 'berry-hibiscus', name: 'Berry Hibiscus Refresher', price: 115, category: 'Fresh Drinks', image: '/images/drinks.jpg', styles: ['iced']),
      const MenuItem(id: 'grilled-cheese', name: 'Truffle Grilled Cheese', price: 160, category: 'Food', image: '/images/drinks.jpg', styles: []),
      const MenuItem(id: 'butter-croissant', name: 'Butter Croissant', price: 85, category: 'Pastries', image: '/images/drinks.jpg', styles: []),
    ];
    categories = ["All", "Special", "Classic", "Non-Coffee", "Fresh Drinks", "Matcha Drinks", "Food", "Pastries"];
    localStorage.saveMenu(menu);
    localStorage.saveCategories(categories);
  }

  void _seedDefaultInventory() {
    inventory = [
      InventoryItem(id: 'coffee-beans', name: 'Coffee Beans', unit: 'g', cost: 1.2, stock: 5000, maxStock: 10000, openingStock: 5000),
      InventoryItem(id: 'milk', name: 'Fresh Milk', unit: 'ml', cost: 0.1, stock: 10000, maxStock: 20000, openingStock: 10000),
      InventoryItem(id: 'sugar', name: 'Sugar Syrup', unit: 'ml', cost: 0.05, stock: 3000, maxStock: 5000, openingStock: 3000),
      InventoryItem(id: 'matcha-powder', name: 'Matcha Powder', unit: 'g', cost: 2.5, stock: 1000, maxStock: 2000, openingStock: 1000),
      InventoryItem(id: 'cups-hot', name: 'Hot Cups 8oz', unit: 'pcs', cost: 5.0, stock: 500, maxStock: 1000, openingStock: 500),
      InventoryItem(id: 'cups-peta', name: 'Iced Cups 16oz', unit: 'pcs', cost: 6.0, stock: 500, maxStock: 1000, openingStock: 500),
    ];
    localStorage.saveInventory(inventory);
  }

  void _seedDefaultStaff() {
    staffUsers = [
      const StaffUser(id: 'admin-1', username: 'admin', password: 'commune', name: 'Admin', role: 'admin', title: 'Owner'),
      const StaffUser(id: 'cashier-1', username: 'cashier', password: 'commune', name: 'Cashier On Duty', role: 'cashier', title: 'Cashier'),
      const StaffUser(id: 'manager-1', username: 'manager', password: 'commune', name: 'Manager', role: 'manager', title: 'Manager'),
      const StaffUser(id: 'barista-1', username: 'barista', password: 'commune', name: 'Barista', role: 'barista', title: 'Barista'),
    ];
    localStorage.saveStaff(staffUsers);
  }
}
