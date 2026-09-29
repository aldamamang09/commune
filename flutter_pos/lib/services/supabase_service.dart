import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/inventory_item.dart';
import '../models/void_request.dart';
import '../models/restock_record.dart';
import '../models/staff_user.dart';
import '../models/login_activity.dart';

class SupabaseService {
  SupabaseClient? _client;

  bool get isInitialized => _client != null;

  Future<bool> initialize({String? url, String? anonKey}) async {
    final effectiveUrl = url ?? SupabaseConfig.supabaseUrl;
    final effectiveKey = anonKey ?? SupabaseConfig.supabaseAnonKey;

    if (effectiveUrl.isEmpty || effectiveKey.isEmpty || effectiveUrl.contains('placeholder')) {
      return false;
    }

    try {
      await Supabase.initialize(
        url: effectiveUrl,
        anonKey: effectiveKey,
      );
      _client = Supabase.instance.client;
      return true;
    } catch (e) {
      print('Supabase init error: $e');
      return false;
    }
  }

  // --- Fetch Catalog & Initial Data ---

  Future<List<MenuItem>> fetchMenu() async {
    if (_client == null) return [];
    try {
      final catRes = await _client!
          .from(SupabaseConfig.tableMenuCategories)
          .select('id, name');
      final catMap = <String, String>{};
      for (final row in (catRes as List)) {
        catMap[row['id'].toString()] = row['name'].toString();
      }

      final res = await _client!
          .from(SupabaseConfig.tableMenuItems)
          .select('*')
          .eq('available', true)
          .order('created_at');
      return (res as List).map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        final catId = map['category_id']?.toString();
        if (catId != null && catMap.containsKey(catId)) {
          map['category'] = catMap[catId];
        }
        return MenuItem.fromJson(map);
      }).toList();
    } catch (e) {
      print('Error fetching menu from Supabase: $e');
      return [];
    }
  }

  Future<List<String>> fetchCategories() async {
    if (_client == null) return [];
    try {
      final res = await _client!
          .from(SupabaseConfig.tableMenuCategories)
          .select('name')
          .order('name');
      final list = (res as List).map((e) => e['name'].toString()).toList();
      return ["All", ...list];
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  Future<List<InventoryItem>> fetchInventory() async {
    if (_client == null) return [];
    try {
      final res = await _client!
          .from(SupabaseConfig.tableInventoryItems)
          .select('*')
          .order('created_at');
      return (res as List).map((e) => InventoryItem.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching inventory: $e');
      return [];
    }
  }

  Future<List<RestockRecord>> fetchRestocks() async {
    if (_client == null) return [];
    try {
      final res = await _client!
          .from(SupabaseConfig.tableRestocks)
          .select('*')
          .order('created_at', ascending: false)
          .limit(200);
      return (res as List).map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        map['isSynced'] = true;
        return RestockRecord.fromJson(map);
      }).toList();
    } catch (e) {
      print('Error fetching restocks from Supabase: $e');
      return [];
    }
  }

  Future<List<StaffUser>> fetchStaff() async {
    if (_client == null) return [];
    try {
      final res = await _client!
          .from(SupabaseConfig.tableStaffUsers)
          .select('*')
          .order('id');
      return (res as List).map((e) => StaffUser.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching staff: $e');
      return [];
    }
  }

  Future<List<Order>> fetchRecentOrders() async {
    if (_client == null) return [];
    try {
      final ordersRes = await _client!
          .from(SupabaseConfig.tableOrders)
          .select('*')
          .order('created_at', ascending: false)
          .limit(100);

      final itemsRes = await _client!
          .from(SupabaseConfig.tableOrderItems)
          .select('*');

      final itemsByOrder = <String, List<Map<String, dynamic>>>{};
      for (final item in (itemsRes as List)) {
        final orderId = item['order_id']?.toString() ?? '';
        itemsByOrder.putIfAbsent(orderId, () => []).add(item as Map<String, dynamic>);
      }

      final orders = <Order>[];
      for (final row in (ordersRes as List)) {
        final orderMap = Map<String, dynamic>.from(row as Map);
        orderMap['items'] = itemsByOrder[row['id']] ?? [];
        orderMap['isSynced'] = true;
        orders.add(Order.fromJson(orderMap));
      }
      return orders;
    } catch (e) {
      print('Error fetching orders: $e');
      return [];
    }
  }

  Future<List<VoidRequest>> fetchVoidRequests() async {
    if (_client == null) return [];
    try {
      final res = await _client!
          .from(SupabaseConfig.tableVoidRequests)
          .select('*')
          .order('requested_at', ascending: false)
          .limit(50);
      return (res as List).map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        map['isSynced'] = true;
        return VoidRequest.fromJson(map);
      }).toList();
    } catch (e) {
      print('Error fetching void requests: $e');
      return [];
    }
  }

  // --- Transactions & Atomic RPC Operations ---

  /// Syncs an order atomically to Supabase via `create_order_atomic` RPC
  Future<Map<String, dynamic>> pushOrderAtomic(Order order, List<Map<String, dynamic>> deductions) async {
    if (_client == null) {
      return {'ok': false, 'error': 'Database not connected'};
    }

    try {
      final itemsPayload = order.items.map((i) => {
        'productId': i.productId,
        'name': i.name,
        'qty': i.qty,
        'price': i.price.round(),
        if (i.style != null) 'style': i.style,
        'addons': i.addons.map((a) => a.toJson()).toList(),
      }).toList();

      final res = await _client!.rpc(SupabaseConfig.rpcCreateOrderAtomic, params: {
        'p_order_id': order.id,
        'p_created_at': order.createdAt,
        'p_barista_name': order.baristaName,
        'p_barista_user_id': order.baristaUserId,
        'p_items': itemsPayload,
        'p_subtotal': order.subtotal.round(),
        'p_discount': order.discount.round(),
        'p_promo_id': null,
        'p_promo_label': order.promoLabel,
        'p_total': order.total.round(),
        'p_payment_method': order.paymentMethod,
        'p_ticket_no': null, // Server allocates daily sequence
        'p_paid': order.paid.round(),
        'p_change': order.change.round(),
        'p_deductions': deductions,
        'p_voided': order.voided,
        'p_void_reason': order.voidReason,
        'p_voided_by': order.voidedBy,
      });

      if (res != null && res['ticketNo'] != null) {
        return {'ok': true, 'ticketNo': res['ticketNo'].toString()};
      }
      return {'ok': true, 'ticketNo': order.ticketNo};
    } catch (e) {
      print('Error in pushOrderAtomic: $e');
      // If RPC fails (e.g. function not deployed), fallback to direct table upsert
      try {
        await _client!.from(SupabaseConfig.tableOrders).upsert({
          'id': order.id,
          'created_at': order.createdAt,
          'barista_name': order.baristaName,
          'barista_user_id': order.baristaUserId,
          'subtotal': order.subtotal.round(),
          'discount': order.discount.round(),
          'promo_label': order.promoLabel,
          'total': order.total.round(),
          'payment_method': order.paymentMethod,
          'ticket_no': order.ticketNo,
          'paid': order.paid.round(),
          'change': order.change.round(),
          'voided': order.voided,
          'void_reason': order.voidReason,
        });

        final orderItemRows = order.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return {
            'id': '${order.id}-item-${idx + 1}',
            'order_id': order.id,
            'product_id_snapshot': item.productId,
            'name_snapshot': item.name,
            'qty': item.qty,
            'price_snapshot': item.price.round(),
            'style': item.style,
            'addons': item.addons.map((a) => a.toJson()).toList(),
          };
        }).toList();

        await _client!.from(SupabaseConfig.tableOrderItems).upsert(orderItemRows);
        return {'ok': true, 'ticketNo': order.ticketNo};
      } catch (errFallback) {
        return {'ok': false, 'error': errFallback.toString()};
      }
    }
  }

  /// Voids an order atomically via `void_order_atomic` RPC
  Future<bool> voidOrderAtomic(String orderId, String reason, String? voidedBy) async {
    if (_client == null) return false;
    try {
      final res = await _client!.rpc(SupabaseConfig.rpcVoidOrderAtomic, params: {
        'p_order_id': orderId,
        'p_reason': reason,
        'p_voided_by': voidedBy,
      });
      return res != null && res['ok'] == true;
    } catch (e) {
      print('Error in voidOrderAtomic: $e');
      try {
        await _client!.from(SupabaseConfig.tableOrders).update({
          'voided': true,
          'void_reason': reason,
          'voided_by': voidedBy,
        }).eq('id', orderId);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Pushes restock atomically via `create_restock_atomic` RPC
  Future<bool> pushRestockAtomic(RestockRecord record) async {
    if (_client == null) return false;
    try {
      await _client!.rpc(SupabaseConfig.rpcCreateRestockAtomic, params: {
        'p_id': record.id,
        'p_inventory_item_id': record.inventoryItemId,
        'p_item_name_snapshot': record.itemName,
        'p_quantity_added': record.quantityAdded,
        'p_created_at': record.date,
        'p_purchase_qty': record.purchaseQty,
        'p_purchase_unit': record.purchaseUnit,
      });
      return true;
    } catch (e) {
      print('Error in pushRestockAtomic: $e');
      try {
        await _client!.from(SupabaseConfig.tableRestocks).upsert({
          'id': record.id,
          'inventory_item_id': record.inventoryItemId,
          'item_name_snapshot': record.itemName,
          'quantity_added': record.quantityAdded,
          'purchase_qty': record.purchaseQty,
          'purchase_unit': record.purchaseUnit,
          'created_at': record.date,
        });
        if (record.inventoryItemId != null) {
          final cur = await _client!
              .from(SupabaseConfig.tableInventoryItems)
              .select('stock')
              .eq('id', record.inventoryItemId!)
              .maybeSingle();
          if (cur != null && cur['stock'] != null) {
            final curStock = (cur['stock'] as num).toDouble();
            await _client!
                .from(SupabaseConfig.tableInventoryItems)
                .update({'stock': curStock + record.quantityAdded})
                .eq('id', record.inventoryItemId!);
          }
        }
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Pushes void request to Supabase
  Future<bool> pushVoidRequest(VoidRequest request) async {
    if (_client == null) return false;
    try {
      await _client!.from(SupabaseConfig.tableVoidRequests).upsert({
        'id': request.id,
        'requested_at': request.requestedAt,
        'requested_by_id': request.requestedById,
        'requested_by_name': request.requestedByName,
        'reason': request.reason,
        'status': request.status,
        'order_id': request.orderId,
        'items': request.items.map((i) => i.toJson()).toList(),
        'subtotal': request.subtotal,
        'discount': request.discount,
        'promo_label': request.promoLabel,
        'total': request.total,
        'payment_method': request.paymentMethod,
      });
      return true;
    } catch (e) {
      print('Error in pushVoidRequest: $e');
      return false;
    }
  }

  /// Pushes shift punch / login activity to Supabase
  Future<bool> pushLoginActivity(LoginActivity activity) async {
    if (_client == null) return false;
    try {
      await _client!.from(SupabaseConfig.tableLoginActivity).upsert({
        'id': activity.id,
        'user_id': activity.userId,
        'username': activity.username,
        'name': activity.name,
        'role': activity.role,
        'type': activity.type,
        'at': activity.at,
      });
      return true;
    } catch (e) {
      print('Error in pushLoginActivity: $e');
      return false;
    }
  }
}
