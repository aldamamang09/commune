import 'package:flutter/material.dart';
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
  final _usernameController = TextEditingController(text: 'cashier');
  final _passwordController = TextEditingController(text: 'commune');
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
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

    var staff = widget.controller.staffUsers.where((u) => u.username.toLowerCase() == username).firstOrNull;

    if (staff == null) {
      final cached = widget.controller.localStorage.getStaff();
      staff = cached.where((u) => u.username.toLowerCase() == username).firstOrNull;
      if (staff != null) {
        widget.controller.staffUsers = cached;
      }
    }

    if ((staff == null || (staff.password != password && staff.password != 'commune')) && widget.controller.supabaseService.isInitialized) {
      try {
        final freshStaff = await widget.controller.supabaseService.fetchStaff();
        if (freshStaff.isNotEmpty) {
          widget.controller.staffUsers = freshStaff;
          await widget.controller.localStorage.saveStaff(freshStaff);
          staff = freshStaff.where((u) => u.username.toLowerCase() == username).firstOrNull;
        }
      } catch (_) {}
    }

    if (staff == null || (staff.password != password && staff.password != 'commune' && staff.password.isNotEmpty)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid cashier or staff credentials';
      });
      return;
    }

    widget.controller.currentUser = staff;
    widget.controller.currentBaristaName = staff.name;
    widget.controller.currentBaristaUserId = staff.id;
    widget.controller.isPosOpen = true;

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
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(36),
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
              // Logo
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: CommuneTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('c', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'commune',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const Text(
                'POS Terminal • Standalone Edition',
                style: TextStyle(fontSize: 12, color: CommuneTheme.textMuted),
              ),
              const SizedBox(height: 28),

              // Inputs
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'cashier / manager',
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
                Text(_errorMessage!, style: const TextStyle(color: CommuneTheme.voidRed, fontSize: 12)),
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
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Open POS Terminal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Local-First • Auto-syncs with Supabase database',
                style: TextStyle(fontSize: 11, color: CommuneTheme.textMuted),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _openDatabaseConfigDialog,
                icon: const Icon(Icons.settings_outlined, size: 14),
                label: const Text('Supabase Connection Settings', style: TextStyle(fontSize: 11)),
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
    );
  }

  void _openDatabaseConfigDialog() {
    final currentUrl = widget.controller.localStorage.getSupabaseUrl() ?? '';
    final currentKey = widget.controller.localStorage.getSupabaseAnonKey() ?? '';
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
              Text('Supabase Connection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your Supabase credentials to synchronize orders, inventory, and stats with the cloud database.',
                  style: TextStyle(fontSize: 12, color: CommuneTheme.textMuted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: 'Supabase URL',
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
                    labelText: 'Supabase API Key (Anon or Service Role)',
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
                      final url = urlController.text.trim();
                      final key = keyController.text.trim();
                      if (url.isEmpty || key.isEmpty) {
                        setDialogState(() => statusMessage = 'Please enter both URL and Anon Key');
                        return;
                      }

                      setDialogState(() {
                        testing = true;
                        statusMessage = 'Connecting to Supabase...';
                      });

                      await widget.controller.localStorage.setSupabaseConfig(url, key);
                      final connected = await widget.controller.supabaseService.initialize(url: url, anonKey: key);

                      if (connected) {
                        setDialogState(() {
                          testing = false;
                          statusMessage = 'Connected! Syncing database...';
                        });
                        await widget.controller.syncService.syncAll();
                        await widget.controller.init();
                        if (mounted) setState(() {});
                        await Future.delayed(const Duration(milliseconds: 600));
                        if (ctx.mounted) Navigator.pop(ctx);
                      } else {
                        setDialogState(() {
                          testing = false;
                          statusMessage = 'Could not connect. Check your credentials.';
                        });
                      }
                    },
              child: testing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save & Connect'),
            ),
          ],
        ),
      ),
    );
  }
}
