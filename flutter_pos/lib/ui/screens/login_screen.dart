import 'package:flutter/material.dart';
import '../../config/supabase_config.dart';
import '../../models/staff_user.dart';
import '../../state/pos_controller.dart';
import '../theme.dart';
import 'pos_screen.dart';

class LoginScreen extends StatefulWidget {
  final PosController controller;

  const LoginScreen({super.key, required this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pull latest staff accounts, menu, and inventory from Admin on login screen load
    widget.controller.syncService.syncAll();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter username and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    StaffUser? authenticatedStaff;

    // 1. Authenticate against centralized Admin database (supports newly created Cashier/Barista accounts & bcrypt hashes)
    final authRes = await widget.controller.supabaseService.authenticateStaff(username, password);
    if (authRes['ok'] == true && authRes['user'] is StaffUser) {
      authenticatedStaff = authRes['user'] as StaffUser;
      // Ensure latest catalog, menu, inventory, and staff are synced before entering POS
      await widget.controller.syncService.syncAll();
    } else {
      // 2. Fallback to synced local staff cache if offline
      await widget.controller.syncService.syncAll();
      final staffList = widget.controller.localStorage.getStaff();
      final matched = staffList.where((u) => u.username.toLowerCase() == username).firstOrNull;
      if (matched != null && matched.password == password && matched.password.isNotEmpty) {
        authenticatedStaff = matched;
      }
    }

    if (authenticatedStaff == null || !authenticatedStaff.canUsePos) {
      setState(() {
        _isLoading = false;
        _errorMessage = authRes['error']?.toString() ?? 'Invalid cashier or staff credentials';
      });
      return;
    }

    widget.controller.currentUser = authenticatedStaff;
    widget.controller.currentBaristaName = authenticatedStaff.name;
    widget.controller.currentBaristaUserId = authenticatedStaff.id;
    widget.controller.isPosOpen = true;
    await widget.controller.punchShift(authenticatedStaff, 'login');

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PosScreen(controller: widget.controller)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: CommuneTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'c',
                        style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'commune',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  const Text(
                    'POS Terminal • Live Admin Sync',
                    style: TextStyle(fontSize: 12, color: CommuneTheme.textMuted),
                  ),
                  const SizedBox(height: 28),

                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'cashier / barista / manager',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _handleLogin(),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: CommuneTheme.voidRed, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CommuneTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Open POS Terminal',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Real-time auto-sync with Admin Panel database',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: CommuneTheme.textMuted),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _openDatabaseConfigDialog,
                    icon: const Icon(Icons.settings_outlined, size: 14),
                    label: const Text('Server & Database Settings', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: CommuneTheme.textMuted,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openDatabaseConfigDialog() {
    final currentAdminUrl = widget.controller.localStorage.getAdminApiUrl() ??
        widget.controller.supabaseService.activeAdminApiUrl ??
        SupabaseConfig.adminApiBaseUrl;
    final currentUrl = widget.controller.localStorage.getSupabaseUrl() ?? '';
    final currentKey = widget.controller.localStorage.getSupabaseAnonKey() ?? '';

    final adminUrlController = TextEditingController(text: currentAdminUrl);
    final urlController = TextEditingController(text: currentUrl);
    final keyController = TextEditingController(text: currentKey);
    bool testing = false;
    String? statusMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cloud_sync, color: CommuneTheme.primary),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Database Sync Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connect to the centralized Admin server or Supabase database so Menu, Stock Inventory, Restocks, and Staff accounts stay in sync.',
                    style: TextStyle(fontSize: 12, color: CommuneTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: adminUrlController,
                    decoration: InputDecoration(
                      labelText: 'Admin Panel Server URL',
                      hintText: 'https://...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: 'Supabase URL (Optional)',
                      hintText: 'https://xyzcompany.supabase.co',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Supabase Key (Optional)',
                      hintText: 'eyJhbGciOi...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  if (statusMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      statusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusMessage!.contains('Connected') ? Colors.green : CommuneTheme.voidRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CommuneTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: testing
                  ? null
                  : () async {
                      final adminUrl = adminUrlController.text.trim();
                      final url = urlController.text.trim();
                      final key = keyController.text.trim();

                      setDialogState(() {
                        testing = true;
                        statusMessage = 'Connecting & syncing...';
                      });

                      await widget.controller.localStorage.setSupabaseConfig(
                        url,
                        key,
                        adminApiUrl: adminUrl,
                      );
                      final connected = await widget.controller.supabaseService.initialize(
                        url: url,
                        anonKey: key,
                        adminApiUrl: adminUrl,
                      );

                      if (connected) {
                        await widget.controller.syncService.syncAll();
                        await widget.controller.init();
                        setDialogState(() {
                          testing = false;
                          statusMessage = 'Connected! All Admin data synced.';
                        });
                        if (mounted) setState(() {});
                        await Future.delayed(const Duration(milliseconds: 500));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } else {
                        setDialogState(() {
                          testing = false;
                          statusMessage = 'Could not connect. Check server URL.';
                        });
                      }
                    },
              child: testing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save & Sync'),
            ),
          ],
        ),
      ),
    );
  }
}
