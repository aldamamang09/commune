import 'package:flutter/material.dart';
import '../../models/staff_user.dart';

class BaristaShiftDialog extends StatefulWidget {
  final List<StaffUser> staffUsers;
  final List<StaffUser> onShiftBaristas;
  final Function(StaffUser staff, String type) onPunch;

  const BaristaShiftDialog({
    super.key,
    required this.staffUsers,
    required this.onShiftBaristas,
    required this.onPunch,
  });

  @override
  State<BaristaShiftDialog> createState() => _BaristaShiftDialogState();
}

class _BaristaShiftDialogState extends State<BaristaShiftDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  StaffUser? _clockOutTarget;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  StaffUser? _authenticatedBarista() {
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text;
    return widget.staffUsers
        .where((staff) =>
            staff.username.trim().toLowerCase() == username &&
            staff.canAccessBaristaShift &&
            staff.password.isNotEmpty &&
            staff.password == password)
        .firstOrNull;
  }

  void _handleClockIn() {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter both username and password');
      return;
    }

    final staff = _authenticatedBarista();
    if (staff == null) {
      setState(() => _error = 'Use valid credentials for a Barista account.');
      return;
    }

    widget.onPunch(staff, 'login');
    Navigator.pop(context);
  }

  void _selectClockOutTarget(StaffUser barista) {
    setState(() {
      _clockOutTarget = barista;
      _usernameController.text = barista.username;
      _passwordController.clear();
      _error = null;
    });
  }

  void _handleClockOut() {
    final onShift = _clockOutTarget;
    if (onShift == null) return;
    final staff = _authenticatedBarista();
    if (staff == null || staff.id != onShift.id) {
      setState(() => _error =
          'Only the Barista on shift can clock out with their credentials.');
      return;
    }

    widget.onPunch(staff, 'logout');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 440,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Baristas',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827)),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        size: 20, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.onShiftBaristas.isNotEmpty)
                ...widget.onShiftBaristas.map((barista) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.circle,
                              size: 8, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text('${barista.name} is on shift',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600))),
                          TextButton(
                            onPressed: () => _selectClockOutTarget(barista),
                            child: Text(_clockOutTarget?.id == barista.id
                                ? 'Selected'
                                : 'Clock out'),
                          ),
                        ],
                      ),
                    ))
              else ...[
                const Text('No barista is on shift yet.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(height: 24),
              ],
              Text(
                _clockOutTarget == null ? 'CLOCK IN' : 'CLOCK OUT',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 12),
              const Text('Username',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Password',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (_) => _clockOutTarget == null
                    ? _handleClockIn()
                    : _handleClockOut(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: Color(0xFFDC2626), fontSize: 12)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => _clockOutTarget == null
                      ? _handleClockIn()
                      : _handleClockOut(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                  ),
                  child:
                      Text(_clockOutTarget == null ? 'Clock in' : 'Clock out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
