import 'package:flutter/material.dart';
import '../../models/menu_item.dart';
import '../../models/order.dart';
import '../../services/sync_service.dart';
import '../../state/pos_controller.dart';
import '../theme.dart';
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
    if (item.isDrink) {
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
    final order = targetOrder ?? widget.controller.lastCompletedOrder ?? (widget.controller.orders.isNotEmpty ? widget.controller.orders.first : null);
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

  void _handleProceedOrder() async {
    final res = await widget.controller.proceedOrder();
    if (res['ok'] == true && mounted) {
      final order = res['order'] as Order;
      // Auto-popup receipt dialog for instant printing
      _openReceiptDialog(order);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: ${res['error']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final sync = controller.syncService;
    final filteredItems = controller.filteredMenu;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Sidebar Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CommuneTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('commune', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Text(
              'POS • ${controller.currentBaristaName}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          // Shift Punch Button
          TextButton.icon(
            onPressed: _openBaristaShiftDialog,
            icon: const Icon(Icons.badge_outlined, size: 16),
            label: const Text('Shift In/Out', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: CommuneTheme.textMain),
          ),
          const SizedBox(width: 8),

          // Sync Status Badge (Online / Offline / Syncing)
          InkWell(
            onTap: () => sync.syncAll(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: sync.status == SyncStatus.syncing
                    ? const Color(0xFFEFF6FF)
                    : (!sync.isOnline || sync.pendingCount > 0
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFDCFCE7)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sync.status == SyncStatus.syncing
                      ? const Color(0xFF93C5FD)
                      : (!sync.isOnline || sync.pendingCount > 0
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFF86EFAC)),
                ),
              ),
              child: Row(
                children: [
                  if (sync.status == SyncStatus.syncing)
                    const SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: CommuneTheme.statusSyncing))
                  else
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !sync.isOnline
                            ? CommuneTheme.statusOffline
                            : (sync.pendingCount > 0 ? CommuneTheme.statusOffline : CommuneTheme.statusOnline),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    sync.status == SyncStatus.syncing
                        ? 'Syncing...'
                        : (!sync.isOnline
                            ? 'Offline (${sync.pendingCount} queued)'
                            : (sync.pendingCount > 0 ? '${sync.pendingCount} to sync' : 'Online • Synced')),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sync.status == SyncStatus.syncing
                          ? CommuneTheme.statusSyncing
                          : (!sync.isOnline || sync.pendingCount > 0 ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),

      // Sidebar Drawer
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              color: CommuneTheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('commune', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text('Standalone POS Terminal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  Text('On Duty: ${controller.currentBaristaName}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale),
              title: const Text('POS Terminal', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Stock Inventory'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => StockScreen(controller: controller)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart_outlined),
              title: const Text('Restock Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => RestockScreen(controller: controller)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Reprint / Recent Tickets'),
              onTap: () {
                Navigator.pop(context);
                _openReceiptDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Force Cloud Sync Now'),
              subtitle: Text(sync.pendingCount > 0 ? '${sync.pendingCount} pending items' : 'Up to date with Supabase'),
              onTap: () {
                Navigator.pop(context);
                sync.syncAll();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Triggering full synchronization with Supabase...')),
                );
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: CommuneTheme.voidRed),
              title: const Text('Logout Cashier', style: TextStyle(color: CommuneTheme.voidRed)),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen(controller: controller)),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),

      body: Row(
        children: [
          // Center / Main Area (Menu Catalog & Search)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Search & Category Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Search input
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search drinks, food, coffee...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    controller.setSearchQuery('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF7F7F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onChanged: (val) => controller.setSearchQuery(val),
                      ),
                      const SizedBox(height: 10),

                      // Category Pills
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: controller.categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final cat = controller.categories[index];
                            final isSelected = controller.selectedCategory == cat;
                            return ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (_) => controller.setCategory(cat),
                              selectedColor: CommuneTheme.primary,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : CommuneTheme.textMain,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              side: BorderSide(color: isSelected ? CommuneTheme.primary : CommuneTheme.border),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Product Grid
                Expanded(
                  child: filteredItems.isEmpty
                      ? const Center(
                          child: Text('No menu items match your search.', style: TextStyle(color: CommuneTheme.textMuted)),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return ProductCard(
                              item: item,
                              onTap: () => _openDrinkOptions(item),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Right Cart & Checkout Panel
          CartPanel(
            controller: controller,
            onProceedOrder: _handleProceedOrder,
            onVoid: _openVoidDialog,
            onPrint: () => _openReceiptDialog(),
          ),
        ],
      ),
    );
  }
}
