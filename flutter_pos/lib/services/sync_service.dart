import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';
import '../models/order.dart';

enum SyncStatus { idle, syncing, success, error, offline }

class SyncService extends ChangeNotifier {
  final LocalStorageService localStorage;
  final SupabaseService supabaseService;

  SyncStatus status = SyncStatus.idle;
  bool isOnline = true;
  String? lastError;
  DateTime? lastSyncTime;
  int pendingCount = 0;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicSyncTimer;

  SyncService({
    required this.localStorage,
    required this.supabaseService,
  });

  void start() {
    updatePendingCount();

    // Listen to network changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      isOnline = connected;
      if (connected) {
        syncAll();
      } else {
        status = SyncStatus.offline;
        notifyListeners();
      }
    });

    // Periodic sync attempt every 30 seconds when online
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isOnline && (getPendingCount() > 0 || status != SyncStatus.syncing)) {
        syncAll();
      }
    });

    // Initial sync
    syncAll();
  }

  void disposeService() {
    _connectivitySub?.cancel();
    _periodicSyncTimer?.cancel();
  }

  int getPendingCount() {
    pendingCount = localStorage.getPendingSyncCount();
    return pendingCount;
  }

  void updatePendingCount() {
    pendingCount = localStorage.getPendingSyncCount();
    notifyListeners();
  }

  /// Full bidirectional synchronization
  Future<void> syncAll() async {
    if (status == SyncStatus.syncing) return;

    if (!supabaseService.isInitialized) {
      status = SyncStatus.offline;
      updatePendingCount();
      return;
    }

    status = SyncStatus.syncing;
    lastError = null;
    notifyListeners();

    try {
      // 1. Pull latest master catalog from Supabase to refresh local cache
      final freshMenu = await supabaseService.fetchMenu();
      if (freshMenu.isNotEmpty) {
        await localStorage.saveMenu(freshMenu);
      }

      final freshCategories = await supabaseService.fetchCategories();
      if (freshCategories.isNotEmpty) {
        await localStorage.saveCategories(freshCategories);
      }

      final freshInventory = await supabaseService.fetchInventory();
      if (freshInventory.isNotEmpty) {
        await localStorage.saveInventory(freshInventory);
      }

      final freshStaff = await supabaseService.fetchStaff();
      if (freshStaff.isNotEmpty) {
        await localStorage.saveStaff(freshStaff);
      }

      final freshRestocks = await supabaseService.fetchRestocks();
      if (freshRestocks.isNotEmpty) {
        await localStorage.saveRestocks(freshRestocks);
      }

      final freshOrders = await supabaseService.fetchRecentOrders();
      if (freshOrders.isNotEmpty) {
        await localStorage.saveOrders(freshOrders);
      }

      // 2. Push offline shift punches
      final pendingPunches = localStorage.getPendingLoginActivity();
      for (final punch in pendingPunches) {
        try {
          final ok = await supabaseService.pushLoginActivity(punch);
          if (ok) {
            punch.isSynced = true;
            await localStorage.removePendingLoginActivity(punch.id);
          }
        } catch (e) {
          print('Error pushing punch: $e');
        }
      }

      // 3. Push offline orders
      final pendingOrders = localStorage.getPendingOrders();
      for (final order in pendingOrders) {
        try {
          // Calculate ingredient deductions for this order
          final deductions = _buildDeductionsForOrder(order);
          final result = await supabaseService.pushOrderAtomic(order, deductions);
          if (result['ok'] == true) {
            order.isSynced = true;
            if (result['ticketNo'] != null && result['ticketNo'].toString().isNotEmpty) {
              order.ticketNo = result['ticketNo'].toString();
            }
            await localStorage.addOrder(order);
            await localStorage.removePendingOrder(order.id);
          }
        } catch (e) {
          print('Error pushing order: $e');
        }
      }

      // 4. Push offline restocks
      final pendingRestocks = localStorage.getPendingRestocks();
      for (final restock in pendingRestocks) {
        try {
          final ok = await supabaseService.pushRestockAtomic(restock);
          if (ok) {
            restock.isSynced = true;
            await localStorage.removePendingRestock(restock.id);
          }
        } catch (e) {
          print('Error pushing restock: $e');
        }
      }

      // 5. Push offline void requests
      final pendingVoids = localStorage.getPendingVoidRequests();
      for (final voidReq in pendingVoids) {
        try {
          final ok = await supabaseService.pushVoidRequest(voidReq);
          if (ok) {
            voidReq.isSynced = true;
            await localStorage.removePendingVoidRequest(voidReq.id);
          }
        } catch (e) {
          print('Error pushing void request: $e');
        }
      }

      status = SyncStatus.success;
      lastSyncTime = DateTime.now();
    } catch (e) {
      print('Sync failed: $e');
      status = SyncStatus.error;
      lastError = e.toString();
    } finally {
      updatePendingCount();
    }
  }

  List<Map<String, dynamic>> _buildDeductionsForOrder(Order order) {
    final deductions = <Map<String, dynamic>>[];
    final inventory = localStorage.getInventory();

    // Automatic default standard deductions for coffee drinks
    for (final item in order.items) {
      final name = item.name.toLowerCase();
      if (name.contains('espresso') || name.contains('latte') || name.contains('cappuccino') || name.contains('americano')) {
        final beans = inventory.cast<dynamic>().firstWhere((i) => i.id == 'coffee-beans', orElse: () => null);
        if (beans != null) {
          deductions.add({
            'inventoryItemId': beans.id,
            'itemName': beans.name,
            'amount': 18.0 * item.qty,
            'unit': 'g',
            'orderItemId': item.productId,
          });
        }
      }

      if (name.contains('latte') || name.contains('cappuccino') || name.contains('flat white')) {
        final milk = inventory.cast<dynamic>().firstWhere((i) => i.id == 'milk', orElse: () => null);
        if (milk != null) {
          deductions.add({
            'inventoryItemId': milk.id,
            'itemName': milk.name,
            'amount': 180.0 * item.qty,
            'unit': 'ml',
            'orderItemId': item.productId,
          });
        }
      }

      if (name.contains('matcha')) {
        final matcha = inventory.cast<dynamic>().firstWhere((i) => i.id == 'matcha-powder', orElse: () => null);
        if (matcha != null) {
          deductions.add({
            'inventoryItemId': matcha.id,
            'itemName': matcha.name,
            'amount': 10.0 * item.qty,
            'unit': 'g',
            'orderItemId': item.productId,
          });
        }
      }

      // Cup deduction
      final cupId = item.style == 'hot' ? 'cups-hot' : 'cups-peta';
      final cup = inventory.cast<dynamic>().firstWhere((i) => i.id == cupId, orElse: () => null);
      if (cup != null) {
        deductions.add({
          'inventoryItemId': cup.id,
          'itemName': cup.name,
          'amount': 1.0 * item.qty,
          'unit': 'pcs',
          'orderItemId': item.productId,
        });
      }
    }
    return deductions;
  }
}
