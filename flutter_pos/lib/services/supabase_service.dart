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

  bool get isInitialized => _client != null || _activeAdminApiUrl != null;
  String? get activeAdminApiUrl => _activeAdminApiUrl;

  Future<bool> initialize({
    String? url,
    String? anonKey,
    String? adminApiUrl,
  }) async {
    final rawUrl = (url ?? '').trim();
    final rawKey = (anonKey ?? '').trim();

    final effectiveUrl = (rawUrl.isEmpty || rawUrl.contains('placeholder'))
        ? SupabaseConfig.supabaseUrl.trim()
        : rawUrl;
    final effectiveKey = (rawKey.isEmpty ||
            rawKey.contains('placeholder') ||
            rawKey.startsWith('sb_publishable_'))
        ? SupabaseConfig.supabaseAnonKey.trim()
        : rawKey;

    if (effectiveUrl.isNotEmpty &&
        effectiveKey.isNotEmpty &&
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
        debugPrint('Supabase SDK init note: $e');
        try {
          _client = SupabaseClient(effectiveUrl, effectiveKey);
        } catch (_) {}
      }
    }

    if (adminApiUrl != null && adminApiUrl.trim().isNotEmpty) {
      var trimmed = adminApiUrl.trim();
      if (trimmed.endsWith('/')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      if (trimmed.endsWith('/api/sync')) {
        trimmed = trimmed.substring(0, trimmed.length - '/api/sync'.length);
      }
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        _activeAdminApiUrl = trimmed;
      }
    }

    return isInitialized;
  }

  Future<Map<String, dynamic>?> _postSyncAction(Map<String, dynamic> payload) async {
    final base = _activeAdminApiUrl;
    if (base == null || base.isEmpty) return null;
    try {
      final uri = Uri.parse('$base/api/sync');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode >= 200 && response.statusCode < 500) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Authenticates a staff member (Cashier, Barista, Manager, Admin) directly against Supabase `staff_users`
  Future<Map<String, dynamic>> authenticateStaff(String username, String password) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPassword = password;

    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      return {'ok': false, 'error': 'Please enter username and password'};
    }

    // 1. Direct Supabase query against `staff_users` table (primary source of truth)
    if (_client != null) {
      try {
        final res = await _client!
            .from(SupabaseConfig.tableStaffUsers)
            .select('*')
            .order('created_at');
        final staffList = (res as List)
            .map((e) => StaffUser.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        final matched = staffList
            .where((u) =>
                u.username.trim().toLowerCase() == cleanUsername ||
                u.name.trim().toLowerCase() == cleanUsername)
            .firstOrNull;

        if (matched != null) {
          if (matched.password == cleanPassword ||
              matched.password.trim() == cleanPassword.trim()) {
            return {'ok': true, 'user': matched, 'allStaff': staffList};
          }
          // If password is a bcrypt hash ($2...), check via Admin API if configured
          if (matched.password.startsWith(r'$2') && _activeAdminApiUrl != null) {
            final apiRes = await _postSyncAction({
              'action': 'auth',
              'username': cleanUsername,
              'password': cleanPassword,
            });
            if (apiRes != null && apiRes['ok'] == true && apiRes['user'] is Map) {
              final userMap = Map<String, dynamic>.from(apiRes['user'] as Map);
              userMap['password'] = cleanPassword;
              return {
                'ok': true,
                'user': StaffUser.fromJson(userMap),
                'allStaff': staffList,
              };
            }
          }
          return {'ok': false, 'error': 'Invalid username or password'};
        } else {
          return {'ok': false, 'error': 'Staff account not found'};
        }
      } catch (e) {
        debugPrint('Direct Supabase auth error: $e');
      }
    }

    // 2. Fallback to Admin API (/api/sync) if configured
    final apiRes = await _postSyncAction({
      'action': 'auth',
      'username': cleanUsername,
      'password': cleanPassword,
    });
    if (apiRes != null) {
      if (apiRes['ok'] == true && apiRes['user'] is Map) {
        final userMap = Map<String, dynamic>.from(apiRes['user'] as Map);
        userMap['password'] = cleanPassword;
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

    return {'ok': false, 'error': 'Unable to verify credentials'};
  }

  /// Fetches the entire centralized StoreData directly from Supabase (or Admin API fallback)
  Future<Map<String, dynamic>?> fetchFullStore() async {
    if (_client != null) {
      try {
        final results = await Future.wait<dynamic>([
          _client!.from(SupabaseConfig.tablePosState).select('*').eq('id', SupabaseConfig.posStateId).maybeSingle(),
          _client!.from(SupabaseConfig.tableStaffUsers).select('*').order('created_at'),
          _client!.from(SupabaseConfig.tableMenuCategories).select('*').order('name'),
          _client!.from(SupabaseConfig.tableMenuItems).select('*').order('created_at'),
          _client!.from(SupabaseConfig.tableInventoryItems).select('*').order('created_at'),
          _client!.from(SupabaseConfig.tableOrders).select('*').order('created_at', ascending: false).limit(200),
          _client!.from(SupabaseConfig.tableOrderItems).select('*').order('created_at'),
          _client!.from(SupabaseConfig.tableUsageLogs).select('*').order('created_at'),
          _client!.from(SupabaseConfig.tableRestocks).select('*').order('created_at', ascending: false),
          _client!.from(SupabaseConfig.tableCostings).select('*').order('created_at'),
          _client!.from(SupabaseConfig.tableCostingIngredients).select('*').order('created_at'),
          _client!.from(SupabaseConfig.tableRecipes).select('*').order('created_at'),
          _client!.from(SupabaseConfig.tableRecipeCostings).select('*').order('created_at'),
          _client!.from(SupabaseConfig.tableRecipeCostingMenuItems).select('*').order('created_at'),
          _client!.from(SupabaseConfig.tableRecipeCostingIngredients).select('*').order('created_at'),
          _client!.from(SupabaseConfig.tableLoginActivity).select('*').order('at', ascending: false).limit(200),
          _client!.from(SupabaseConfig.tableVoidRequests).select('*').order('requested_at', ascending: false).limit(100),
        ]);

        final posRow = results[0] as Map<String, dynamic>?;
        final staffRows = (results[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final catRows = (results[2] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final menuRows = (results[3] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final invRows = (results[4] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final orderRows = (results[5] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final orderItemRows = (results[6] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final usageLogRows = (results[7] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final restockRows = (results[8] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final costingRows = (results[9] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final costingIngRows = (results[10] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final recipeRows = (results[11] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final rcRows = (results[12] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final rcMenuRows = (results[13] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final rcIngRows = (results[14] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final loginRows = (results[15] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final voidRows = (results[16] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

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

        final mappedUsageLogs = usageLogRows.map((row) => {
          'id': row['id']?.toString() ?? '',
          'orderId': row['order_id']?.toString() ?? '',
          'orderItemId': row['order_item_id']?.toString() ?? '',
          'inventoryItemId': row['inventory_item_id']?.toString(),
          'date': row['created_at']?.toString() ?? '',
          'itemName': row['item_name_snapshot']?.toString() ?? '',
          'usedAmount': (row['used_amount'] as num?)?.toDouble() ?? 0.0,
          'unit': row['unit']?.toString() ?? 'pcs',
        }).toList();

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
      }
    }

    // Fallback to Admin API if configured
    final base = _activeAdminApiUrl;
    if (base != null && base.isNotEmpty) {
      try {
        final uri = Uri.parse('$base/api/sync');
        final response = await http.get(
          uri,
          headers: {'Accept': 'application/json', 'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['ok'] == true) {
            return decoded;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  // --- Direct Table Queries ---

  Future<List<MenuItem>?> fetchMenu() async {
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
    if (_client == null) return null;
    try {
      final res = await _client!
          .from(SupabaseConfig.tableInventoryItems)
          .select('*')
          .order('created_at');
      return (res as List)
          .map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching inventory: $e');
      return null;
    }
  }

  Future<List<RestockRecord>?> fetchRestocks() async {
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
    if (_client == null) return null;
    try {
      final res = await _client!
          .from(SupabaseConfig.tableStaffUsers)
          .select('*')
          .order('created_at');
      return (res as List)
          .map((e) => StaffUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      return null;
    }
  }

  Future<List<Order>?> fetchRecentOrders() async {
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
        itemsByOrder
            .putIfAbsent(orderId, () => [])
            .add(Map<String, dynamic>.from(item as Map));
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

  // --- Transactions & Atomic RPC Operations (Direct Supabase Primary) ---

  Future<Map<String, dynamic>> pushOrderAtomic(
      Order order, List<Map<String, dynamic>> deductions) async {
    if (_client != null) {
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
        final msg = e.toString();
        if (msg.contains('duplicate key') || msg.contains('already exists')) {
          return {'ok': true, 'ticketNo': order.ticketNo};
        }
        return {'ok': false, 'error': msg};
      }
    }

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

    return {
      'ok': false,
      'error': apiRes?['error']?.toString() ?? 'Database not connected',
    };
  }

  Future<Map<String, dynamic>> voidOrderAtomic(
    String orderId,
    String reason,
    String? voidedBy, {
    String? managerUsername,
    String? managerPassword,
  }) async {
    if (_client != null) {
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

    return {'ok': false, 'error': 'Database not connected'};
  }

  Future<bool> pushRestockAtomic(RestockRecord record) async {
    if (_client != null) {
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
        if (e.toString().contains('duplicate key')) return true;
        debugPrint('Restock RPC error: $e');
      }
    }

    final apiRes = await _postSyncAction({
      'action': 'create_restock',
      'restock': record.toJson(),
    });
    return apiRes != null && apiRes['ok'] == true;
  }

  Future<bool> deleteRestockAtomic(String id) async {
    if (_client != null) {
      try {
        await _client!.rpc(SupabaseConfig.rpcDeleteRestockAtomic, params: {
          'p_id': id,
          'p_inventory_item_id': null,
          'p_quantity_added': null,
        });
        return true;
      } catch (e) {
        debugPrint('Delete restock RPC error: $e');
      }
    }

    final apiRes = await _postSyncAction({
      'action': 'delete_restock',
      'id': id,
    });
    return apiRes != null && apiRes['ok'] == true;
  }

  Future<bool> upsertInventoryItem(InventoryItem item) async {
    if (_client != null) {
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
      } catch (e) {
        debugPrint('Upsert inventory error: $e');
      }
    }

    final apiRes = await _postSyncAction({
      'action': 'upsert_inventory_item',
      'item': item.toJson(),
    });
    return apiRes != null && apiRes['ok'] == true;
  }

  Future<Map<String, dynamic>> deleteInventoryItem(String id) async {
    if (_client != null) {
      try {
        await _client!.from(SupabaseConfig.tableInventoryItems).delete().eq('id', id);
        return {'ok': true};
      } catch (e) {
        return {'ok': false, 'error': e.toString()};
      }
    }

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
    return {'ok': false, 'error': 'Database not connected'};
  }

  Future<bool> pushVoidRequest(VoidRequest request) async {
    if (_client != null) {
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
          'subtotal': request.subtotal.round(),
          'discount': request.discount.round(),
          'promo_label': request.promoLabel,
          'total': request.total.round(),
          'payment_method': request.paymentMethod,
        });
        return true;
      } catch (e) {
        debugPrint('Push void request error: $e');
      }
    }

    final apiRes = await _postSyncAction({
      'action': 'create_void_request',
      'request': request.toJson(),
    });
    return apiRes != null && apiRes['ok'] == true;
  }

  Future<bool> pushLoginActivity(LoginActivity activity) async {
    if (_client != null) {
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
        if (activity.type == 'login') {
          await _client!.from(SupabaseConfig.tablePosState).upsert({
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
      }
    }

    final apiRes = await _postSyncAction({
      'action': 'login_activity',
      'activity': activity.toJson(),
    });
    return apiRes != null && apiRes['ok'] == true;
  }
}
