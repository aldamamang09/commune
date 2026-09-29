import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  String? _activeAdminApiUrl;
  bool _supabaseSdkInitialized = false;

  bool get isInitialized => _activeAdminApiUrl != null || _client != null;
  String? get activeAdminApiUrl => _activeAdminApiUrl;

  List<String> _candidateApiUrls(String? customAdminUrl) {
    final urls = <String>[];
    void addCandidate(String? raw) {
      if (raw == null) return;
      var trimmed = raw.trim();
      if (trimmed.isEmpty) return;
      if (trimmed.endsWith('/')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      if (trimmed.endsWith('/api/sync')) {
        trimmed = trimmed.substring(0, trimmed.length - '/api/sync'.length);
      }
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        if (!urls.contains(trimmed)) urls.add(trimmed);
      }
    }

    addCandidate(customAdminUrl);
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.startsWith('http')) {
        addCandidate(origin);
      }
    }
    addCandidate(SupabaseConfig.adminApiBaseUrl);
    for (final fallback in SupabaseConfig.fallbackApiBaseUrls) {
      addCandidate(fallback);
    }
    return urls;
  }

  Future<bool> initialize({
    String? url,
    String? anonKey,
    String? adminApiUrl,
  }) async {
    // 1. Try initializing direct Supabase client if valid URL & Anon Key are provided
    final effectiveUrl = (url ?? SupabaseConfig.supabaseUrl).trim();
    final effectiveKey = (anonKey ?? SupabaseConfig.supabaseAnonKey).trim();

    if (effectiveUrl.isNotEmpty &&
        effectiveKey.isNotEmpty &&
        !effectiveUrl.contains('placeholder') &&
        effectiveUrl.contains('.supabase.co')) {
      try {
        if (!_supabaseSdkInitialized) {
          await Supabase.initialize(
            url: effectiveUrl,
            anonKey: effectiveKey,
          );
          _supabaseSdkInitialized = true;
        }
        _client = Supabase.instance.client;
      } catch (e) {
        debugPrint('Supabase SDK init warning: $e');
      }
    }

    // 2. Discover & verify centralized Admin API (/api/sync) so POS and Admin share the exact same database
    final candidates = _candidateApiUrls(adminApiUrl);
    for (final base in candidates) {
      try {
        final uri = Uri.parse('$base/api/sync');
        final res = await http.get(uri).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body is Map && body['ok'] == true) {
            _activeAdminApiUrl = base;
            return true;
          }
        }
      } catch (_) {
        // Try next candidate
      }
    }

    // Even if initial probe timed out, set default Admin API URL so subsequent syncs can connect automatically
    if (_activeAdminApiUrl == null && candidates.isNotEmpty) {
      _activeAdminApiUrl = candidates.first;
    }

    return isInitialized;
  }

  /// Fetches the entire centralized StoreData from the Admin backend `/api/sync`
  Future<Map<String, dynamic>?> fetchFullStore() async {
    final candidates = _candidateApiUrls(_activeAdminApiUrl);
    for (final base in candidates) {
      try {
        final uri = Uri.parse('$base/api/sync');
        final response = await http.get(
          uri,
          headers: {'Accept': 'application/json', 'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['ok'] == true) {
            _activeAdminApiUrl = base;
            return decoded;
          }
        }
      } catch (_) {
        // Try next candidate
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _postSyncAction(Map<String, dynamic> payload) async {
    final candidates = _candidateApiUrls(_activeAdminApiUrl);
    for (final base in candidates) {
      try {
        final uri = Uri.parse('$base/api/sync');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));

        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          _activeAdminApiUrl = base;
          return decoded;
        }
      } catch (_) {
        // Try next candidate
      }
    }
    return null;
  }

  /// Authenticates a staff member (Cashier, Barista, Manager, Admin) against the centralized Admin database
  Future<Map<String, dynamic>> authenticateStaff(String username, String password) async {
    final apiRes = await _postSyncAction({
      'action': 'auth',
      'username': username,
      'password': password,
    });
    if (apiRes != null) {
      if (apiRes['ok'] == true && apiRes['user'] is Map) {
        final userMap = Map<String, dynamic>.from(apiRes['user'] as Map);
        userMap['password'] = password;
        return {
          'ok': true,
          'user': StaffUser.fromJson(userMap),
        };
      }
      return {
        'ok': false,
        'error': apiRes['error']?.toString() ?? 'Invalid staff credentials',
      };
    }

    // Fallback to direct Supabase staff query if Admin API is unreachable
    if (_client != null) {
      final staffList = await fetchStaff();
      if (staffList != null) {
        final matched = staffList.where((u) => u.username.toLowerCase() == username.toLowerCase()).firstOrNull;
        if (matched != null && matched.password == password) {
          return {'ok': true, 'user': matched};
        }
      }
    }

    return {'ok': false, 'error': 'Unable to verify credentials'};
  }

  // --- Direct Supabase Table Fallbacks (only used when _client != null and Admin API is unavailable) ---

  Future<List<MenuItem>?> fetchMenu() async {
    final store = await fetchFullStore();
    if (store != null && store['menu'] is List) {
      return (store['menu'] as List)
          .whereType<Map>()
          .map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (_client == null) return null;
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
      debugPrint('Error fetching menu: $e');
      return null;
    }
  }

  Future<List<String>?> fetchCategories() async {
    final store = await fetchFullStore();
    if (store != null && store['categories'] is List) {
      final list = (store['categories'] as List).map((e) => e.toString()).toList();
      return ['All', ...list.where((c) => c.toLowerCase() != 'all')];
    }
    if (_client == null) return null;
    try {
      final res = await _client!
          .from(SupabaseConfig.tableMenuCategories)
          .select('name')
          .order('name');
      final list = (res as List).map((e) => e['name'].toString()).toList();
      return ['All', ...list.where((c) => c.toLowerCase() != 'all')];
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return null;
    }
  }

  Future<List<InventoryItem>?> fetchInventory() async {
    final store = await fetchFullStore();
    if (store != null && store['inventory'] is List) {
      return (store['inventory'] as List)
          .whereType<Map>()
          .map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (_client == null) return null;
    try {
      final res = await _client!
          .from(SupabaseConfig.tableInventoryItems)
          .select('*')
          .order('created_at');
      return (res as List).map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      debugPrint('Error fetching inventory: $e');
      return null;
    }
  }

  Future<List<RestockRecord>?> fetchRestocks() async {
    final store = await fetchFullStore();
    if (store != null && store['restocks'] is List) {
      return (store['restocks'] as List).whereType<Map>().map((e) {
        final map = Map<String, dynamic>.from(e);
        map['isSynced'] = true;
        return RestockRecord.fromJson(map);
      }).toList();
    }
    if (_client == null) return null;
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
      debugPrint('Error fetching restocks: $e');
      return null;
    }
  }

  Future<List<StaffUser>?> fetchStaff() async {
    final store = await fetchFullStore();
    if (store != null && store['users'] is List) {
      return (store['users'] as List)
          .whereType<Map>()
          .map((e) => StaffUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (_client == null) return null;
    try {
      final res = await _client!
          .from(SupabaseConfig.tableStaffUsers)
          .select('*')
          .order('id');
      return (res as List).map((e) => StaffUser.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      return null;
    }
  }

  Future<List<Order>?> fetchRecentOrders() async {
    final store = await fetchFullStore();
    if (store != null && store['orders'] is List) {
      return (store['orders'] as List).whereType<Map>().map((e) {
        final map = Map<String, dynamic>.from(e);
        map['isSynced'] = true;
        return Order.fromJson(map);
      }).toList();
    }
    if (_client == null) return null;
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
        itemsByOrder.putIfAbsent(orderId, () => []).add(Map<String, dynamic>.from(item as Map));
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
      debugPrint('Error fetching orders: $e');
      return null;
    }
  }

  // --- Transactions & Atomic RPC Operations ---

  Future<Map<String, dynamic>> pushOrderAtomic(Order order, List<Map<String, dynamic>> deductions) async {
    final apiRes = await _postSyncAction({
      'action': 'create_order',
      'order': order.toJson(),
      'deductions': deductions,
    });
    if (apiRes != null && apiRes['ok'] == true) {
      return {
        'ok': true,
        'ticketNo': apiRes['ticketNo']?.toString() ?? order.ticketNo,
      };
    }

    if (_client == null) {
      return {
        'ok': false,
        'error': apiRes?['error']?.toString() ?? 'Database not connected',
      };
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
        'p_ticket_no': null,
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
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> voidOrderAtomic(
    String orderId,
    String reason,
    String? voidedBy, {
    String? managerUsername,
    String? managerPassword,
  }) async {
    final apiRes = await _postSyncAction({
      'action': 'void_order',
      'orderId': orderId,
      'reason': reason,
      'voidedBy': voidedBy,
      if (managerUsername != null) 'managerUsername': managerUsername,
      if (managerPassword != null) 'managerPassword': managerPassword,
    });
    if (apiRes != null) {
      return {
        'ok': apiRes['ok'] == true,
        if (apiRes['error'] != null) 'error': apiRes['error'].toString(),
      };
    }

    if (_client == null) return {'ok': false, 'error': 'Database not connected'};
    try {
      final res = await _client!.rpc(SupabaseConfig.rpcVoidOrderAtomic, params: {
        'p_order_id': orderId,
        'p_reason': reason,
        'p_voided_by': voidedBy,
      });
      return {'ok': res != null && res['ok'] == true};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<bool> pushRestockAtomic(RestockRecord record) async {
    final apiRes = await _postSyncAction({
      'action': 'create_restock',
      'restock': record.toJson(),
    });
    if (apiRes != null && apiRes['ok'] == true) {
      return true;
    }

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
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteRestockAtomic(String id) async {
    final apiRes = await _postSyncAction({
      'action': 'delete_restock',
      'id': id,
    });
    if (apiRes != null && apiRes['ok'] == true) {
      return true;
    }
    if (_client == null) return false;
    try {
      await _client!.rpc(SupabaseConfig.rpcDeleteRestockAtomic, params: {
        'p_id': id,
        'p_inventory_item_id': null,
        'p_quantity_added': null,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> upsertInventoryItem(InventoryItem item) async {
    final apiRes = await _postSyncAction({
      'action': 'upsert_inventory_item',
      'item': item.toJson(),
    });
    if (apiRes != null && apiRes['ok'] == true) {
      return true;
    }
    if (_client == null) return false;
    try {
      await _client!.from(SupabaseConfig.tableInventoryItems).upsert({
        'id': item.id,
        'name': item.name,
        'unit': item.unit,
        'cost': item.cost,
        'stock': item.stock,
        'max_stock': item.maxStock,
        'opening_stock': item.openingStock,
        'purchase_unit_size': item.purchaseUnitSize,
        'cup_usage_amount': item.cupUsageAmount,
        'cups_make': item.cupsMake,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> deleteInventoryItem(String id) async {
    final apiRes = await _postSyncAction({
      'action': 'delete_inventory_item',
      'id': id,
    });
    if (apiRes != null) {
      return {
        'ok': apiRes['ok'] == true,
        if (apiRes['error'] != null) 'error': apiRes['error'].toString(),
      };
    }
    if (_client == null) return {'ok': false, 'error': 'Database not connected'};
    try {
      await _client!.from(SupabaseConfig.tableInventoryItems).delete().eq('id', id);
      return {'ok': true};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<bool> pushVoidRequest(VoidRequest request) async {
    final apiRes = await _postSyncAction({
      'action': 'create_void_request',
      'request': request.toJson(),
    });
    if (apiRes != null && apiRes['ok'] == true) {
      return true;
    }
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
    } catch (_) {
      return false;
    }
  }

  Future<bool> pushLoginActivity(LoginActivity activity) async {
    final apiRes = await _postSyncAction({
      'action': 'login_activity',
      'activity': activity.toJson(),
    });
    if (apiRes != null && apiRes['ok'] == true) {
      return true;
    }
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
    } catch (_) {
      return false;
    }
  }
}
