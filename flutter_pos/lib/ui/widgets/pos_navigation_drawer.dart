import 'package:flutter/material.dart';

enum PosSection { terminal, stock, restock }

typedef PosDrawerBuilder = Widget Function(PosSection section);

class PosNavigationDrawer extends StatelessWidget {
  final PosSection selectedSection;
  final String cashierName;
  final String labelsConnection;
  final String receiptConnection;
  final String syncStatus;
  final bool canLogout;
  final String logoutDisabledMessage;
  final VoidCallback onOpenTerminal;
  final VoidCallback onOpenStock;
  final VoidCallback onOpenRestock;
  final VoidCallback onOpenBaristas;
  final VoidCallback onConnectLabels;
  final VoidCallback onConnectReceipt;
  final VoidCallback onSync;
  final VoidCallback onLogout;

  const PosNavigationDrawer({
    super.key,
    required this.selectedSection,
    required this.cashierName,
    required this.labelsConnection,
    required this.receiptConnection,
    required this.syncStatus,
    required this.canLogout,
    required this.logoutDisabledMessage,
    required this.onOpenTerminal,
    required this.onOpenStock,
    required this.onOpenRestock,
    required this.onOpenBaristas,
    required this.onConnectLabels,
    required this.onConnectReceipt,
    required this.onSync,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
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
                    ),
                  ),
                  Text(
                    'Cashier: $cashierName',
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _destination(
                    context,
                    section: PosSection.terminal,
                    icon: Icons.point_of_sale_outlined,
                    label: 'POS Terminal',
                    onTap: onOpenTerminal,
                  ),
                  _destination(
                    context,
                    section: PosSection.stock,
                    icon: Icons.inventory_2_outlined,
                    label: 'Stock inventory',
                    onTap: onOpenStock,
                  ),
                  _destination(
                    context,
                    section: PosSection.restock,
                    icon: Icons.add_shopping_cart_outlined,
                    label: 'Restock',
                    onTap: onOpenRestock,
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.badge_outlined, color: Colors.black87),
                    title: const Text('Baristas on shift'),
                    onTap: () => _closeThen(context, onOpenBaristas),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                      'PRINTERS',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
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
                    subtitle: Text(labelsConnection),
                    onTap: () => _closeThen(context, onConnectLabels),
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined,
                        color: Colors.black87),
                    title: const Text('Connect receipt'),
                    subtitle: Text(receiptConnection),
                    onTap: () => _closeThen(context, onConnectReceipt),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync, color: Colors.black87),
                    title: const Text('Sync with Admin Database'),
                    subtitle: Text(syncStatus),
                    onTap: () => _closeThen(context, onSync),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              enabled: canLogout,
              leading: Icon(
                Icons.logout,
                color: canLogout
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF9CA3AF),
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                    color: canLogout
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF9CA3AF)),
              ),
              subtitle: canLogout ? null : Text(logoutDisabledMessage),
              onTap: canLogout ? () => _closeThen(context, onLogout) : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _destination(
    BuildContext context, {
    required PosSection section,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isSelected = section == selectedSection;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? Colors.black : const Color(0xFF4B5563)),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      selected: isSelected,
      selectedTileColor: const Color(0xFFF3F4F6),
      onTap: () {
        if (isSelected) {
          Navigator.pop(context);
        } else {
          _closeThen(context, onTap);
        }
      },
    );
  }

  void _closeThen(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }
}
