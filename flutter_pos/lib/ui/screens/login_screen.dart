import 'package:flutter/material.dart';
import '../../models/staff_user.dart';
import '../../state/pos_controller.dart';
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

    final cachedStaffProfile =
        widget.controller.localStorage.getActiveStaffProfile();
    final cachedPosApiToken = widget.controller.localStorage.getPosApiToken();
    widget.controller.supabaseService.setPosApiToken(null);

    StaffUser? authenticatedStaff;

    // 1. Authenticate through the POS API without persisting a token yet.
    final authRes = await widget.controller.supabaseService
        .authenticateStaff(username, password, persistSessionToken: false);
    if (authRes['ok'] == true && authRes['user'] is StaffUser) {
      authenticatedStaff = authRes['user'] as StaffUser;
    } else if (authRes['offline'] == true) {
      authenticatedStaff = await widget.controller
          .authenticateCachedStaffOffline(username, password);
    }

    if (authenticatedStaff == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = authRes['offline'] == true &&
                widget.controller.syncService.isOnline
            ? 'Unable to verify credentials. Please try again.'
            : authRes['error']?.toString() ?? 'Invalid Cashier credentials';
      });
      return;
    }

    if (!authenticatedStaff.canLoginToPos) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'This account cannot log in to the POS app.';
      });
      return;
    }

    if (authRes['ok'] == true) {
      await widget.controller.localStorage
          .saveOfflineStaffCredential(authenticatedStaff.id, password);
    }

    final authenticatedToken = authRes['token']?.toString();
    final canReuseCachedToken = cachedStaffProfile?.id == authenticatedStaff.id;
    final posApiToken =
        authenticatedToken != null && authenticatedToken.isNotEmpty
            ? authenticatedToken
            : canReuseCachedToken
                ? cachedPosApiToken
                : null;

    await widget.controller.localStorage.clearActiveStaffId();
    await widget.controller.localStorage.saveActiveStaffSession(
      authenticatedStaff,
      posApiToken: posApiToken,
    );
    widget.controller.supabaseService.setPosApiToken(posApiToken);
    if (authenticatedToken != null && authenticatedToken.isNotEmpty) {
      await widget.controller.syncService.syncAll();
      await widget.controller.init();
    }
    widget.controller.currentUser = authenticatedStaff;
    widget.controller.isPosOpen = true;
    await widget.controller
        .recordStaffSessionEvent(authenticatedStaff, 'login');

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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/src/images/hero_wide.jpg',
            fit: BoxFit.cover,
          ),
          const ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.68)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'lib/src/images/favicon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'WE COMMUNE, OVER COFFEE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'CASHIER LOGIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 42),
                      const Text(
                        'USERNAME',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: _inputDecoration(),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'PASSWORD',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: _inputDecoration(),
                        onSubmitted: (_) => _handleLogin(),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFAAA5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white70,
                            shape: const StadiumBorder(),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  'Enter commune',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return const InputDecoration(
      filled: true,
      fillColor: Color.fromRGBO(255, 255, 255, 0.04),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white54),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white54),
      ),
    );
  }
}
