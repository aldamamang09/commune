import 'package:flutter/material.dart';
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
  void reassemble() {
    super.reassemble();
    // Ensure Hot Reload immediately syncs with Supabase
    _errorMessage = null;
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

    // 1. Authenticate directly against centralized Supabase database
    final authRes = await widget.controller.supabaseService
        .authenticateStaff(username, password);
    if (authRes['ok'] == true && authRes['user'] is StaffUser) {
      authenticatedStaff = authRes['user'] as StaffUser;
      if (authRes['allStaff'] is List<StaffUser>) {
        await widget.controller.localStorage
            .saveStaff(authRes['allStaff'] as List<StaffUser>);
      }
      await widget.controller.syncService.syncAll();
      await widget.controller.init();
    } else {
      // 2. Fallback to synced local staff cache if offline
      await widget.controller.syncService.syncAll();
      await widget.controller.init();
      final staffList = widget.controller.localStorage.getStaff();
      final matched = staffList
          .where((u) =>
              u.username.trim().toLowerCase() == username ||
              u.name.trim().toLowerCase() == username)
          .firstOrNull;
      if (matched != null &&
          (matched.password == password ||
              matched.password.trim() == password.trim()) &&
          matched.password.isNotEmpty) {
        authenticatedStaff = matched;
      }
    }

    if (authenticatedStaff == null) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            authRes['error']?.toString() ?? 'Invalid Cashier credentials';
      });
      return;
    }

    if (!authenticatedStaff.canUsePos) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Only Cashier accounts can open the POS terminal.';
      });
      return;
    }

    await widget.controller.localStorage
        .saveActiveStaffSession(authenticatedStaff);
    widget.controller.currentUser = authenticatedStaff;
    widget.controller.isPosOpen = true;
    await widget.controller
        .recordCashierSessionEvent(authenticatedStaff, 'login');

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => PosScreen(controller: widget.controller)),
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
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 30,
                      offset: Offset(0, 10)),
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
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'commune',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5),
                  ),
                  const Text(
                    'POS Terminal • Live Admin Sync',
                    style:
                        TextStyle(fontSize: 12, color: CommuneTheme.textMuted),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'Cashier username',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: CommuneTheme.voidRed, fontSize: 12),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Open POS Terminal',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Real-time auto-sync with Admin Panel database',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 11, color: CommuneTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
