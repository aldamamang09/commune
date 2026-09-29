import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/inventory_item.dart';
import '../models/void_request.dart';
import '../models/restock_record.dart';
import '../models/staff_user.dart';
import '../models/login_activity.dart';

class SupabaseService {
  String? _activeAdminApiUrl;

  bool get isInitialized => true;
  String? get activeAdminApiUrl => _activeAdminApiUrl;

  Map<String, String> get _restHeaders => const {
        'apikey': SupabaseConfig.serviceRoleKey,
        'Authorization': 'Bearer ${SupabaseConfig.serviceRoleKey}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<bool> initialize({
    String? url,
    String? anonKey,
    String? adminApiUrl,
  }) async {
    return true;
  }

  Future<List<Map<String, dynamic>>> _restSelect(String queryPath) async {
    final uri = Uri.parse('${SupabaseConfig.restBaseUrl}/$queryPath');
    final response = await http
        .get(uri, headers: _restHeaders)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    throw Exception('Supabase SELECT failed (${response.statusCode}): ${response.body}');
  }

  Future<dynamic> _restRpc(String fnName, Map<String, dynamic> params) async {
    final uri = Uri.parse('${SupabaseConfig.restBaseUrl}/rpc/$fnName');
    final response = await http
        .post(
          uri,
          headers: _restHeaders,
          body: jsonEncode(params),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return null;
      return jsonDecode(response.body);
    }
    throw Exception('Supabase RPC $fnName failed (${response.statusCode}): ${response.body}');
  }

  Future<void> _restUpsert(String table, Object payload) async {
    final uri = Uri.parse('${SupabaseConfig.restBaseUrl}/$table');
    final response = await http
        .post(
          uri,
          headers: {
            ..._restHeaders,
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Supabase UPSERT $table failed (${response.statusCode}): ${response.body}');
    }
  }

  Future<void> _restDelete(String table, String id) async {
    final uri = Uri.parse(
      '${SupabaseConfig.restBaseUrl}/$table?id=eq.${Uri.encodeQueryComponent(id)}',
    );
    final response = await http
        .delete(uri, headers: _restHeaders)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Supabase DELETE $table failed (${response.statusCode}): ${response.body}');
    }
  }

  String _compactKey(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Authenticates a staff member (Cashier, Barista, Manager, Admin) directly against Supabase `staff_users`
  Future<Map<String, dynamic>> authenticateStaff(String username, String password) async {
    final cleanUsername = username.trim().toLowerCase();
    final compactUsername = _compactKey(username);
    final cleanPassword = password;

    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      return {'ok': false, 'error': 'Please enter username and password'};
    }

    try {
      final rows = await _restSelect('${SupabaseConfig.tableStaffUsers}?select=*&order=created_at.asc');
      final staffList = rows.map((e) => StaffUser.fromJson(e)).toList();

      final matched = staffList.where((u) {
        final uUser = u.username.trim().toLowerCase();
        final uName = u.name.trim().toLowerCase();
        return uUser == cleanUsername ||
            uName == cleanUsername ||
            (compactUsername.isNotEmpty &&
                (_compactKey(u.username) == compactUsername ||
                    _compactKey(u.name) == compactUsername));
      }).firstOrNull;

      if (matched != null) {
        if (matched.password == cleanPassword ||
            matched.password.trim() == cleanPassword.trim()) {
          return {'ok': true, 'user': matched, 'allStaff': staffList};
        }
        return {'ok': false, 'error': 'Invalid username or password'};
      } else {
        return {'ok': false, 'error': 'Staff account not found'};
      }
    } catch (e) {
      debugPrint('Direct Supabase auth error: $e');
      return {'ok': false, 'error': 'Unable to verify credentials'};
    }
  }

  /// Fetches the entire centralized StoreData directly from Supabase PostgREST
  Future<Map<String, dynamic>?> fetchFullStore() async {
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        _restSelect('${SupabaseConfig.tablePosState}?select=*&id=eq.${SupabaseConfig.posStateId}'),
        _restSelect('${SupabaseConfig.tableStaffUsers}?select=*&order=created_at.asc'),
        _restSelect('${SupabaseConfig.tableMenuCategories}?select=*&order=name.asc'),
        _restSelect('${SupabaseConfig.tableMenuItems}?select=*&order=created_at.asc'),
        _restSelect('${SupabaseConfig.tableInventoryItems}?select=*&order=created_at.asc'),
        _restSelect('${SupabaseConfig.tableOrders}?select=*&order=created_at.desc&limit=200'),
        _restSelect('${SupabaseConfig.tableOrderItems}?select=*&order=created_at.asc'),
        _restSelect('${SupabaseConfig.tableUsageLogs}?select=*&order=created_at.asc'),
        _restSelect('${SupabaseConfig.tableRestocks}?select=*&order=created_at.desc'),
        _restSelect('${SupabaseConfig.tableCostings}?select=*&order=created_at.asc'),
        _restSelect('${SupabaseConfig.tableCostingIngredients}?select=*&order=created_at.asc'),
        _restSelect('${SupabaseConfig.tableRecipes}?select=*&order=created_at.asc'),
        _restSelect('${SupabaseConfig.tableRecipeCostings}?select=*&order=created_at.asc'),
        _restSelect('${SupabaseConfig.tableRecipeCostingMenuItems}?select=*&order=created_at.asc'),
        _restSelect('${SupabaseConfig.tableRecipeCostingIngredients}?select=*&order=created_at.asc'),
        _restSelect('${SupabaseConfig.tableLoginActivity}?select=*&order=at.desc&limit=200'),
        _restSelect('${SupabaseConfig.tableVoidRequests}?select=*&order=requested_at.desc&limit=100'),
      ]);

      final posRows = results[0];
      final posRow = posRows.isNotEmpty ? posRows.first : null;
      final staffRows = results[1];
      final catRows = results[2];
      final menuRows = results[3];
      final invRows = results[4];
      final orderRows = results[5];
      final orderItemRows = results[6];
      final usageLogRows = results[7];
      final restockRows = results[8];
      final costingRows = results[9];
      final costingIngRows = results[10];
      final recipeRows = results[11];
      final rcRows = results[12];
      final rcMenuRows = results[13];
      final rcIngRows = results[14];
      final loginRows = results[15];
      final voidRows = results[16];

      final catById = <String, String>{};
      final categories = <String>[];
      for (final row in catRows) {
        final id = row['id']?.toString() ?? '';
        final name = row['name']?.toString() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          catById[id] = name;
          if (!categories.any((c) => c.toLowerCase() == name.toLowerCase())) {
            categories.add(name);
          }
        }
      }

      final mappedMenu = menuRows.map((row) {
        final catId = row['category_id']?.toString() ?? '';
        final category = catById[catId] ?? row['category']?.toString() ?? 'Other';
        if (category.isNotEmpty && !categories.any((c) => c.toLowerCase() == category.toLowerCase())) {
          categories.add(category);
        }
        return {
          ...row,
          'category': category,
        };
      }).toList();

      final itemsByOrder = <String, List<Map<String, dynamic>>>{};
      for (final item in orderItemRows) {
        final orderId = item['order_id']?.toString() ?? '';
        itemsByOrder.putIfAbsent(orderId, () => []).add(item);
      }

      final mappedOrders = orderRows.map((row) {
        final id = row['id']?.toString() ?? '';
        return {
          ...row,
          'items': itemsByOrder[id] ?? [],
          'isSynced': true,
        };
      }).toList();

      final recipesMap = <String, List<Map<String, dynamic>>>{};
      for (final r in recipeRows) {
        final menuId = r['menu_item_id']?.toString() ?? '';
        if (menuId.isEmpty) continue;
        recipesMap.putIfAbsent(menuId, () => []).add({
          'inventoryItemId': r['inventory_item_id']?.toString() ?? '',
          'name': '',
          'amount': (r['amount'] as num?)?.toDouble() ?? 0.0,
          'unit': r['unit']?.toString() ?? 'pcs',
        });
      }

      final mappedRecipeCostings = rcRows.map((row) {
        final rcId = row['id']?.toString() ?? '';
        return {
          'id': rcId,
          'name': row['name']?.toString() ?? '',
          'menuItems': rcMenuRows
              .where((m) => m['recipe_costing_id']?.toString() == rcId)
              .map((m) => m['menu_item_name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(),
          'ingredients': rcIngRows
              .where((i) => i['recipe_costing_id']?.toString() == rcId)
              .map((i) => {
                    'inventoryItemId': i['inventory_item_id']?.toString() ?? '',
                    'name': i['name']?.toString() ?? '',
                    'amount': (i['amount'] as num?)?.toDouble() ?? 0.0,
                    'unit': i['unit']?.toString() ?? 'pcs',
                  })
              .toList(),
          'hotCupInventoryItemId': row['hot_cup_inventory_item_id'],
          'icedCupInventoryItemId': row['iced_cup_inventory_item_id'],
          'otherCupInventoryItemId': row['other_cup_inventory_item_id'],
        };
      }).toList();

      final mappedCostings = costingRows.map((row) {
        final cId = row['id']?.toString() ?? '';
        return {
          'id': cId,
          'productName': row['product_name']?.toString() ?? '',
          'ingredients': costingIngRows
              .where((i) => i['costing_id']?.toString() == cId)
              .map((i) => {
                    'name': i['name']?.toString() ?? '',
                    'amount': (i['amount'] as num?)?.toDouble() ?? 0.0,
                    'unit': i['unit']?.toString() ?? 'pcs',
                    'outputCups': (i['output_cups'] as num?)?.toDouble(),
                  })
              .toList(),
        };
      }).toList();

      final mappedUsageLogs = usageLogRows
          .map((row) => {
                'id': row['id']?.toString() ?? '',
                'orderId': row['order_id']?.toString() ?? '',
                'orderItemId': row['order_item_id']?.toString() ?? '',
                'inventoryItemId': row['inventory_item_id']?.toString(),
                'date': row['created_at']?.toString() ?? '',
                'itemName': row['item_name_snapshot']?.toString() ?? '',
                'usedAmount': (row['used_amount'] as num?)?.toDouble() ?? 0.0,
                'unit': row['unit']?.toString() ?? 'pcs',
              })
          .toList();

      return {
        'ok': true,
        'pos': posRow != null
            ? {
                'isOpen': posRow['is_open'] == true,
                'openedAt': posRow['opened_at'],
                'openedBy': posRow['opened_by_name'] ?? posRow['opened_by'],
              }
            : {'isOpen': false, 'openedAt': null, 'openedBy': null},
        'users': staffRows,
        'categories': categories,
        'menu': mappedMenu,
        'inventory': invRows,
        'orders': mappedOrders,
        'restocks': restockRows,
        'voidRequests': voidRows,
        'loginActivity': loginRows,
        'recipes': recipesMap,
        'recipeCostings': mappedRecipeCostings,
        'costings': mappedCostings,
        'usageLogs': mappedUsageLogs,
      };
    } catch (e) {
      debugPrint('Direct Supabase fetchFullStore error: $e');
      return null;
    }
  }

  // --- Direct Table Queries ---

  Future<List<MenuItem>?> fetchMenu() async {
    try {
      final catRes = await _restSelect('${SupabaseConfig.tableMenuCategories}?select=id,name');
      final catMap = <String, String>{};
      for (final row in catRes) {
        catMap[row['id'].toString()] = row['name'].toString();
      }

      final res = await _restSelect('${SupabaseConfig.tableMenuItems}?select=*&order=created_at.asc');
      return res.map((map) {
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
    try {
      final res = await _restSelect('${SupabaseConfig.tableMenuCategories}?select=name&order=name.asc');
      final list = res.map((e) => e['name'].toString()).toList();
      return ['All', ...list.where((c) => c.toLowerCase() != 'all')];
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return null;
    }
  }

  Future<List<InventoryItem>?> fetchInventory() async {
    try {
      final res = await _restSelect('${SupabaseConfig.tableInventoryItems}?select=*&order=created_at.asc');
      return res.map((e) => InventoryItem.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching inventory: $e');
      return null;
    }
  }

  Future<List<RestockRecord>?> fetchRestocks() async {
    try {
      final res = await _restSelect('${SupabaseConfig.tableRestocks}?select=*&order=created_at.desc&limit=200');
      return res.map((map) {
        map['isSynced'] = true;
        return RestockRecord.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching restocks: $e');
      return null;
    }
  }

  Future<List<StaffUser>?> fetchStaff() async {
    try {
      final res = await _restSelect('${SupabaseConfig.tableStaffUsers}?select=*&order=created_at.asc');
      return res.map((e) => StaffUser.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      return null;
    }
  }

  Future<List<Order>?> fetchRecentOrders() async {
    try {
      final ordersRes = await _restSelect('${SupabaseConfig.tableOrders}?select=*&order=created_at.desc&limit=100');
      final itemsRes = await _restSelect('${SupabaseConfig.tableOrderItems}?select=*');

      final itemsByOrder = <String, List<Map<String, dynamic>>>{};
      for (final item in itemsRes) {
        final orderId = item['order_id']?.toString() ?? '';
        itemsByOrder.putIfAbsent(orderId, () => []).add(item);
      }

      final orders = <Order>[];
      for (final orderMap in ordersRes) {
        orderMap['items'] = itemsByOrder[orderMap['id']] ?? [];
        orderMap['isSynced'] = true;
        orders.add(Order.fromJson(orderMap));
      }
      return orders;
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      return null;
    }
  }

  // --- Transactions & Atomic RPC Operations (Direct Supabase PostgREST) ---

  Future<Map<String, dynamic>> pushOrderAtomic(
      Order order, List<Map<String, dynamic>> deductions) async {
    try {
      final itemsPayload = order.items
          .map((i) => {
                'productId': i.productId,
                'name': i.name,
                'qty': i.qty,
                'price': i.price.round(),
                if (i.style != null) 'style': i.style,
                'addons': i.addons.map((a) => a.toJson()).toList(),
              })
          .toList();

      final res = await _restRpc(SupabaseConfig.rpcCreateOrderAtomic, {
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

      if (res is Map && res['ticketNo'] != null) {
        return {'ok': true, 'ticketNo': res['ticketNo'].toString()};
      }
      return {'ok': true, 'ticketNo': order.ticketNo};
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('duplicate key') || msg.contains('already exists')) {
        return {'ok': true, 'ticketNo': order.ticketNo};
      }
      return {'ok': false, 'error': msg};
    }
  }

  Future<Map<String, dynamic>> voidOrderAtomic(
    String orderId,
    String reason,
    String? voidedBy, {
    String? managerUsername,
    String? managerPassword,
  }) async {
    try {
      if (managerUsername != null &&
          managerUsername.isNotEmpty &&
          managerPassword != null) {
        final auth = await authenticateStaff(managerUsername, managerPassword);
        if (auth['ok'] != true) {
          return {'ok': false, 'error': 'Invalid manager credentials.'};
        }
        final staff = auth['user'] as StaffUser;
        if (!staff.isManager) {
          return {
            'ok': false,
            'error': 'Manager or Admin credentials required to void an order.'
          };
        }
        voidedBy = staff.id;
      }

      final res = await _restRpc(SupabaseConfig.rpcVoidOrderAtomic, {
        'p_order_id': orderId,
        'p_reason': reason,
        'p_voided_by': voidedBy,
      });
      return {'ok': res is Map && res['ok'] == true};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<bool> pushRestockAtomic(RestockRecord record) async {
    try {
      await _restRpc(SupabaseConfig.rpcCreateRestockAtomic, {
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
      if (e.toString().contains('duplicate key')) return true;
      debugPrint('Restock RPC error: $e');
      return false;
    }
  }

  Future<bool> deleteRestockAtomic(String id) async {
    try {
      await _restRpc(SupabaseConfig.rpcDeleteRestockAtomic, {
        'p_id': id,
        'p_inventory_item_id': null,
        'p_quantity_added': null,
      });
      return true;
    } catch (e) {
      debugPrint('Delete restock RPC error: $e');
      return false;
    }
  }

  Future<bool> upsertInventoryItem(InventoryItem item) async {
    try {
      await _restUpsert(SupabaseConfig.tableInventoryItems, {
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
    } catch (e) {
      debugPrint('Upsert inventory error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> deleteInventoryItem(String id) async {
    try {
      await _restDelete(SupabaseConfig.tableInventoryItems, id);
      return {'ok': true};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<bool> pushVoidRequest(VoidRequest request) async {
    try {
      await _restUpsert(SupabaseConfig.tableVoidRequests, {
        'id': request.id,
        'requested_at': request.requestedAt,
        'requested_by_id': request.requestedById,
        'requested_by_name': request.requestedByName,
        'reason': request.reason,
        'status': request.status,
        'order_id': request.orderId,
        'items': request.items.map((i) => i.toJson()).toList(),
        'subtotal': request.subtotal.round(),
        'discount': request.discount.round(),
        'promo_label': request.promoLabel,
        'total': request.total.round(),
        'payment_method': request.paymentMethod,
      });
      return true;
    } catch (e) {
      debugPrint('Push void request error: $e');
      return false;
    }
  }

  Future<bool> pushLoginActivity(LoginActivity activity) async {
    try {
      await _restUpsert(SupabaseConfig.tableLoginActivity, {
        'id': activity.id,
        'user_id': activity.userId,
        'username': activity.username,
        'name': activity.name,
        'role': activity.role,
        'type': activity.type,
        'at': activity.at,
      });
      if (activity.type == 'login') {
        await _restUpsert(SupabaseConfig.tablePosState, {
          'id': SupabaseConfig.posStateId,
          'is_open': true,
          'opened_by_name': activity.name,
          'opened_at': activity.at,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('Push login activity error: $e');
      return false;
    }
  }
}
