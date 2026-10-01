import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/menu_item.dart';
import '../../models/order.dart';
import '../../models/staff_user.dart';
import '../../services/sync_service.dart';
import '../../state/pos_controller.dart';
import '../widgets/product_card.dart';
import '../widgets/cart_panel.dart';
import '../widgets/drink_options_dialog.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/void_dialog.dart';
import '../widgets/barista_shift_dialog.dart';
import '../widgets/bluetooth_printer_picker_dialog.dart';
import '../widgets/pos_navigation_drawer.dart';
import '../../services/bluetooth_printer_service.dart';
import '../theme.dart';
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
  final BluetoothPrinterService _printerService =
      BluetoothPrinterService.instance;
  String? _selectedItemId;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    widget.controller.syncService.addListener(_onControllerChange);
    _printerService.addListener(_onControllerChange);
    _printerService.initialize();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    widget.controller.syncService.removeListener(_onControllerChange);
    _printerService.removeListener(_onControllerChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  Future<void> _openPrinterPicker(PrinterRole role) async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => BluetoothPrinterPickerDialog(role: role),
    );
  }

  Future<void> _printOrder(Order order) async {
    final results = <String>[];
    try {
      await _printerService.printReceipt(order);
      results.add('Receipt sent');
    } catch (error) {
      results.add('Receipt: $error');
    }
    try {
      await _printerService.printLabels(
        order,
        menu: widget.controller.menu,
      );
      results.add('Labels sent');
    } catch (error) {
      results.add('Labels: $error');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(results.join(' | '))),
      );
    }
  }

  void _openDrinkOptions(MenuItem item) {
    setState(() => _selectedItemId = item.id);
    if (item.addons.isEmpty &&
        item.styles.length == 1 &&
        item.styles.single.toLowerCase() == 'iced') {
      widget.controller.addToCart(item, style: 'iced');
      return;
    }

    if (item.styles.isNotEmpty || item.addons.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => DrinkOptionsDialog(
          item: item,
          onConfirm: (style, addons, qty) {
            widget.controller
                .addToCart(item, style: style, addons: addons, qty: qty);
          },
        ),
      );
    } else {
      widget.controller.addToCart(item);
    }
  }

  void _openVoidDialog() {
    if (widget.controller.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items in checkout to void.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => VoidDialog(
        cart: widget.controller.cart,
        isManager: (widget.controller.currentUser?.isManager ?? false) &&
            (widget.controller.currentUser?.password.isNotEmpty ?? false),
        isRequestPending: widget.controller.isVoidRequestPending,
        isOnline: widget.controller.syncService.isOnline,
        onConfirmVoid: (reason, managerUser, managerPass) async {
          final username = managerUser.isNotEmpty
              ? managerUser
              : widget.controller.currentUser?.username ?? '';
          final password = managerPass.isNotEmpty
              ? managerPass
              : widget.controller.currentUser?.password ?? '';
          final res =
              await widget.controller.voidCheckout(reason, username, password);
          if (res['ok'] == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res['queued'] == true
                    ? 'Void saved offline and will sync when online.'
                    : 'Checkout voided.'),
              ),
            );
          }
          return res;
        },
        onRequestVoid: (reason) async {
          final result =
              await widget.controller.requestVoidApproval(null, reason);
          if (result['ok'] == true && mounted) {
            final synced = result['synced'] == true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(synced
                    ? 'Void request sent to Admin. Waiting for approval.'
                    : 'Void request saved and will sync when online.'),
              ),
            );
          }
          return result;
        },
      ),
    );
  }

  void _openReceiptDialog([Order? targetOrder]) {
    final order = targetOrder ??
        widget.controller.lastCompletedOrder ??
        (widget.controller.orders.isNotEmpty
            ? widget.controller.orders.first
            : null);
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
        orders: widget.controller.orders,
        menu: widget.controller.menu,
        onPrint: _printOrder,
      ),
    );
  }

  void _openBaristaShiftDialog() {
    showDialog(
      context: context,
      builder: (_) => BaristaShiftDialog(
        onShiftBaristas: widget.controller.onShiftBaristas,
        authenticateBarista: (username, password) async {
          return widget.controller.authenticateStaffForPurpose(
            username,
            password,
            accepts: (staff) => staff.canAccessBaristaShift,
          );
        },
        onPunch: (staff, type) async {
          await widget.controller.punchShift(staff, type);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${staff.name} clocked ${type == "login" ? "in" : "out"}')),
          );
        },
      ),
    );
  }

  Future<void> _handleProceedOrder() async {
    final controller = widget.controller;
    final stockShortfalls =
        controller.syncService.findStockShortfalls(controller.cart);
    if (stockShortfalls.isNotEmpty) {
      final number = NumberFormat('0.##');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Low stock warning'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text('The following items do not have enough stock:'),
                const SizedBox(height: 8),
                for (final item in stockShortfalls)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${item['itemName']}: ${number.format(item['required'])} '
                      '${item['unit']} required, '
                      '${number.format(item['available'])} available',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final wasOffline = !controller.syncService.isOnline;
    final res = await controller.proceedOrder();
    final offline = wasOffline ||
        !controller.syncService.isOnline ||
        res['networkFailure'] == true;
    if (res['ok'] == true && mounted) {
      final order = res['order'] as Order;
      if (res['synced'] != true && !offline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved on this device only. Server sync failed: ${res['syncError']}',
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
      _openReceiptDialog(order);
    } else if (mounted && !offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: ${res['error']}')),
      );
    }
  }

  void _openMobileCartSheet() {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
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
        builder: (context, scrollController) => Column(
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
                isKeyboardOpen: keyboardOpen,
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

  void _navigateToPos() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToStock() {
    _navigateToPos();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockScreen(
          controller: widget.controller,
          drawerBuilder: _buildPosDrawer,
        ),
      ),
    );
  }

  void _navigateToRestock() {
    _navigateToPos();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestockScreen(
          controller: widget.controller,
          drawerBuilder: _buildPosDrawer,
        ),
      ),
    );
  }

  Widget _buildPosDrawer(PosSection section) {
    final controller = widget.controller;
    final canLogout = controller.cart.isEmpty &&
        !controller.isVoidRequestPending &&
        !_isLoggingOut;

    return PosNavigationDrawer(
      selectedSection: section,
      cashierName: controller.currentUser?.name ?? 'Cashier',
      labelsConnection: _printerService.connectionSummary(PrinterRole.labels),
      receiptConnection: _printerService.connectionSummary(PrinterRole.receipt),
      syncStatus: controller.syncService.isOnline ? 'Online' : 'Offline',
      canLogout: canLogout,
      logoutDisabledMessage: controller.isVoidRequestPending
          ? 'Wait for void approval first'
          : 'Clear checkout first',
      onOpenTerminal: _navigateToPos,
      onOpenStock: _navigateToStock,
      onOpenRestock: _navigateToRestock,
      onOpenBaristas: _openBaristaShiftDialog,
      onConnectLabels: () => _openPrinterPicker(PrinterRole.labels),
      onConnectReceipt: () => _openPrinterPicker(PrinterRole.receipt),
      onSync: () => controller.syncService.syncAll(),
      onLogout: _handleLogout,
    );
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);
    final cashier = widget.controller.currentUser;
    try {
      if (cashier != null) {
        await widget.controller.recordStaffSessionEvent(cashier, 'logout');
      }
      await widget.controller.clearActiveSession();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(controller: widget.controller),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final sync = controller.syncService;
    final filteredItems = controller.filteredMenu;
    final currency = NumberFormat('#,##0', 'en_PH');
    final canLogout = controller.cart.isEmpty &&
        !controller.isVoidRequestPending &&
        !_isLoggingOut;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final syncStatusLabel = sync.isOnline ? 'Online' : 'Offline';
    final syncDotColor =
        sync.isOnline ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF);

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'lib/src/images/favicon.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text(
              'commune.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.6,
              ),
            ),
          ],
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
                child: Row(
                  children: [
                    Expanded(
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
                          Text(
                            'Cashier: ${controller.currentUser?.name ?? 'Cashier'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: canLogout ? () => _handleLogout() : null,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.point_of_sale, color: Colors.black),
                      title: const Text('POS Terminal',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      selected: true,
                      selectedTileColor: const Color(0xFFF3F4F6),
                      onTap: () => Navigator.pop(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined,
                          color: Colors.black87),
                      title: const Text('Stock inventory'),
                      onTap: _navigateToStock,
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_shopping_cart_outlined,
                          color: Colors.black87),
                      title: const Text('Restock'),
                      onTap: _navigateToRestock,
                    ),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined,
                          color: Colors.black87),
                      title: const Text('Baristas on shift'),
                      onTap: () {
                        Navigator.pop(context);
                        _openBaristaShiftDialog();
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text(
                        'PRINTERS',
                        style: TextStyle(
                          color: CommuneTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.local_cafe_outlined,
                          color: Colors.black87),
                      title: const Text('Connect labels'),
                      subtitle: Text(_printerService
                          .connectionSummary(PrinterRole.labels)),
                      onTap: () {
                        Navigator.pop(context);
                        _openPrinterPicker(PrinterRole.labels);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined,
                          color: Colors.black87),
                      title: const Text('Connect receipt'),
                      subtitle: Text(_printerService
                          .connectionSummary(PrinterRole.receipt)),
                      onTap: () {
                        Navigator.pop(context);
                        _openPrinterPicker(PrinterRole.receipt);
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Image.asset(
                      'lib/src/images/synorra.jpg',
                      width: 68,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => launchUrl(
                        Uri.parse('https://synnora.vercel.app/'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Contact Developer',
                          style: TextStyle(
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      body: LayoutBuilder(
        builder: (context, screenConstraints) {
          final checkoutPanelWidth =
              screenConstraints.maxWidth >= 1280 ? 400.0 : 370.0;
          final isWide = screenConstraints.maxWidth >= 960;
          final cartItemCount =
              controller.cart.fold<int>(0, (sum, i) => sum + i.qty);

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
                          hintStyle: const TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF)),
                          prefixIcon: const Icon(Icons.search,
                              size: 18, color: Color(0xFF9CA3AF)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      size: 14, color: Color(0xFF9CA3AF)),
                                  onPressed: () {
                                    _searchController.clear();
                                    controller.setSearchQuery('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                                color: Colors.black, width: 1.2),
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
                              style: const TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 14),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = 4;
                            if (constraints.maxWidth < 360) {
                              crossAxisCount = 1;
                            } else if (constraints.maxWidth < 520) {
                              crossAxisCount = 2;
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisExtent: 72,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return ProductCard(
                                  item: item,
                                  isSelected: _selectedItemId == item.id,
                                  isDisabled: controller.isVoidRequestPending,
                                  onTap: () => _openDrinkOptions(item),
                                );
                              },
                            );
                          },
                        ),
                ),

                // Bottom Category Bar (Strictly synced with Admin Categories)
                if (!keyboardOpen)
                  Container(
                    height: 54,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      border: Border(
                        top: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.categories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = controller.categories[index];
                        final isSelected = controller.selectedCategory == cat;
                        return InkWell(
                          onTap: () => controller.setCategory(cat),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black
                                    : const Color(0xFFD1D5DB),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF111827),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Mobile/Narrow Checkout Summary Bar
                if (!isWide && !keyboardOpen)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
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
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF6B7280)),
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
                            icon: const Icon(Icons.shopping_bag_outlined,
                                size: 18),
                            label: const Text('Checkout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: ClipRect(child: menuSection)),
              SizedBox(
                width: checkoutPanelWidth,
                child: CartPanel(
                  panelWidth: checkoutPanelWidth,
                  controller: controller,
                  isKeyboardOpen: keyboardOpen,
                  onProceedOrder: _handleProceedOrder,
                  onVoid: _openVoidDialog,
                  onPrint: () => _openReceiptDialog(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
