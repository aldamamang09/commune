import 'package:flutter/material.dart';
import '../../models/menu_item.dart';
import '../../models/order.dart';
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
      ),

      // Sidebar Drawer
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              color: Colors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('commune.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text('POS Terminal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  Text('On Duty: ${controller.currentBaristaName}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
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
                Navigator.push(context, MaterialPageRoute(builder: (_) => StockScreen(controller: controller)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart_outlined, color: Colors.black87),
              title: const Text('Restock'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => RestockScreen(controller: controller)));
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
              title: const Text('Sync with Supabase'),
              subtitle: Text(sync.pendingCount > 0 ? '${sync.pendingCount} pending' : 'Synced'),
              onTap: () {
                Navigator.pop(context);
                sync.syncAll();
              },
            ),
            const Spacer(),
            const Divider(),
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
            const SizedBox(height: 12),
          ],
        ),
      ),

      body: Row(
        children: [
          // Center / Main Area (Search, 4-column Grid, Bottom Category Pills)
          Expanded(
            child: Container(
              color: const Color(0xFFF9FAFB),
              child: Column(
                children: [
                  // Top Search Bar (matches Screenshot 4)
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

                  // 4-Column Product Grid (matches Screenshot 4)
                  Expanded(
                    child: filteredItems.isEmpty
                        ? const Center(
                            child: Text(
                              'No menu items found.',
                              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 1.55,
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
                          ),
                  ),

                  // Bottom Category Bar (matches Screenshot 4: [All] [Classic] [Food] [Fresh Drinks] ...)
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
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                ],
              ),
            ),
          ),

          // Right Cart & Checkout Panel (matches Screenshot 4)
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
