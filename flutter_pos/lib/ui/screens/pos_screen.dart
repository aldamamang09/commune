import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_item.dart';
import '../../models/order.dart';
import '../../services/sync_service.dart';
import '../../state/pos_controller.dart';
import '../widgets/product_card.dart';
import '../widgets/cart_panel.dart';
import '../widgets/drink_options_dialog.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/void_dialog.dart';
import '../widgets/barista_shift_dialog.dart';
import 'stock_screen.dart';
import 'restock_screen.dart';
import 'login_screen.dart';

class PosScreen extends StatefulWidget {
  final PosController controller;

  const PosScreen({super.key, required this.controller});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedItemId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    widget.controller.syncService.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    widget.controller.syncService.removeListener(_onControllerChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  void _openDrinkOptions(MenuItem item) {
    setState(() => _selectedItemId = item.id);
    if (item.styles.isNotEmpty || item.addons.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => DrinkOptionsDialog(
          item: item,
          onConfirm: (style, addons, qty) {
            widget.controller.addToCart(item, style: style, addons: addons, qty: qty);
          },
        ),
      );
    } else {
      widget.controller.addToCart(item);
    }
  }

  void _openVoidDialog() {
    showDialog(
      context: context,
      builder: (_) => VoidDialog(
        orders: widget.controller.orders,
        onConfirmVoid: (orderId, reason, managerUser, managerPass) async {
          final res = await widget.controller.voidOrder(orderId, reason, managerUser, managerPass);
          if (res['ok'] == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order successfully voided and inventory restored.')),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${res['error']}')),
            );
          }
        },
      ),
    );
  }

  void _openReceiptDialog([Order? targetOrder]) {
    final order = targetOrder ??
        widget.controller.lastCompletedOrder ??
        (widget.controller.orders.isNotEmpty ? widget.controller.orders.first : null);
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders found to print')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => ReceiptDialog(
        order: order,
        onPrint: () {},
      ),
    );
  }

  void _openBaristaShiftDialog() {
    showDialog(
      context: context,
      builder: (_) => BaristaShiftDialog(
        staffUsers: widget.controller.staffUsers,
        currentBaristaName: widget.controller.currentBaristaName,
        onPunch: (staff, type) {
          widget.controller.punchShift(staff, type);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${staff.name} clocked ${type == "login" ? "in" : "out"}')),
          );
        },
      ),
    );
  }

  Future<void> _handleProceedOrder() async {
    final res = await widget.controller.proceedOrder();
    if (res['ok'] == true && mounted) {
      final order = res['order'] as Order;
      _openReceiptDialog(order);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: ${res['error']}')),
      );
    }
  }

  void _openMobileCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, _) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: CartPanel(
                controller: widget.controller,
                isFullWidth: true,
                onProceedOrder: () async {
                  Navigator.pop(ctx);
                  await _handleProceedOrder();
                },
                onVoid: () {
                  Navigator.pop(ctx);
                  _openVoidDialog();
                },
                onPrint: () {
                  Navigator.pop(ctx);
                  _openReceiptDialog();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final sync = controller.syncService;
    final filteredItems = controller.filteredMenu;
    final currency = NumberFormat('#,##0', 'en_PH');

    String syncStatusLabel = 'Synced';
    Color syncDotColor = const Color(0xFF22C55E);
    if (sync.status == SyncStatus.syncing) {
      syncStatusLabel = 'Syncing...';
      syncDotColor = const Color(0xFF3B82F6);
    } else if (sync.pendingCount > 0) {
      syncStatusLabel = '${sync.pendingCount} pending';
      syncDotColor = const Color(0xFFF59E0B);
    } else if (!sync.isOnline) {
      syncStatusLabel = 'Offline';
      syncDotColor = const Color(0xFF9CA3AF);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 22),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: const Text(
          'commune.',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.6,
          ),
        ),
        actions: [
          InkWell(
            onTap: () => sync.syncAll(),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: syncDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    syncStatusLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),

      // Sidebar Drawer
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                color: Colors.black,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'commune.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('POS Terminal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 12),
                    Text(
                      'On Duty: ${controller.currentBaristaName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.point_of_sale, color: Colors.black),
                      title: const Text('POS Terminal', style: TextStyle(fontWeight: FontWeight.bold)),
                      selected: true,
                      selectedTileColor: const Color(0xFFF3F4F6),
                      onTap: () => Navigator.pop(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined, color: Colors.black87),
                      title: const Text('Stock inventory'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StockScreen(controller: controller)),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_shopping_cart_outlined, color: Colors.black87),
                      title: const Text('Restock'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RestockScreen(controller: controller)),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined, color: Colors.black87),
                      title: const Text('Baristas on shift'),
                      onTap: () {
                        Navigator.pop(context);
                        _openBaristaShiftDialog();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.sync, color: Colors.black87),
                      title: const Text('Sync with Admin Database'),
                      subtitle: Text(syncStatusLabel),
                      onTap: () {
                        Navigator.pop(context);
                        sync.syncAll();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                title: const Text('Logout', style: TextStyle(color: Color(0xFFDC2626))),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => LoginScreen(controller: controller)),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),

      body: LayoutBuilder(
        builder: (context, screenConstraints) {
          final isWide = screenConstraints.maxWidth >= 768;
          final cartItemCount = controller.cart.fold<int>(0, (sum, i) => sum + i.qty);

          final menuSection = Container(
            color: const Color(0xFFF9FAFB),
            child: Column(
              children: [
                // Top Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search item...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14, color: Color(0xFF9CA3AF)),
                                  onPressed: () {
                                    _searchController.clear();
                                    controller.setSearchQuery('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Colors.black, width: 1.2),
                          ),
                        ),
                        onChanged: (val) => controller.setSearchQuery(val),
                      ),
                    ),
                  ),
                ),

                // Responsive Product Grid
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              sync.status == SyncStatus.syncing
                                  ? 'Syncing menu from Admin...'
                                  : 'No menu items found in this category.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = 4;
                            double aspectRatio = 1.45;
                            if (constraints.maxWidth < 360) {
                              crossAxisCount = 1;
                              aspectRatio = 2.4;
                            } else if (constraints.maxWidth < 520) {
                              crossAxisCount = 2;
                              aspectRatio = 1.35;
                            } else if (constraints.maxWidth < 800) {
                              crossAxisCount = 3;
                              aspectRatio = 1.4;
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: aspectRatio,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return ProductCard(
                                  item: item,
                                  isSelected: _selectedItemId == item.id,
                                  onTap: () => _openDrinkOptions(item),
                                );
                              },
                            );
                          },
                        ),
                ),

                // Bottom Category Bar (Strictly synced with Admin Categories)
                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FAFB),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = controller.categories[index];
                      final isSelected = controller.selectedCategory == cat;
                      return InkWell(
                        onTap: () => controller.setCategory(cat),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.black : const Color(0xFFD1D5DB),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Mobile/Narrow Checkout Summary Bar
                if (!isWide)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$cartItemCount ${cartItemCount == 1 ? "item" : "items"} in cart',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                                Text(
                                  '₱${currency.format(controller.total)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _openMobileCartSheet,
                            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                            label: const Text('Checkout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );

          if (!isWide) {
            return menuSection;
          }

          return Row(
            children: [
              Expanded(child: menuSection),
              CartPanel(
                controller: controller,
                onProceedOrder: _handleProceedOrder,
                onVoid: _openVoidDialog,
                onPrint: () => _openReceiptDialog(),
              ),
            ],
          );
        },
      ),
    );
  }
}
