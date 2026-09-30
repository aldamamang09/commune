import 'package:flutter/material.dart';
import '../../models/staff_user.dart';

class BaristaShiftDialog extends StatefulWidget {
  final List<StaffUser> staffUsers;
  final String? currentBaristaUserId;
  final String currentBaristaName;
  final Function(StaffUser staff, String type) onPunch;

  const BaristaShiftDialog({
    super.key,
    required this.staffUsers,
    required this.currentBaristaUserId,
    required this.currentBaristaName,
    required this.onPunch,
  });

  @override
  State<BaristaShiftDialog> createState() => _BaristaShiftDialogState();
}

class _BaristaShiftDialogState extends State<BaristaShiftDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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

  void _handleClockOut(StaffUser onShift) {
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
    final onShift = widget.currentBaristaUserId == null
        ? null
        : widget.staffUsers
            .where((staff) =>
                staff.canAccessBaristaShift &&
                staff.id == widget.currentBaristaUserId)
            .firstOrNull;

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
              if (onShift != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFF16A34A), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text('${onShift.name} is on shift',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              else ...[
                const Text('No barista is on shift yet.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(height: 24),
              ],
              Text(
                onShift == null ? 'CLOCK IN' : 'BARISTA ACCESS',
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
                onSubmitted: (_) => onShift == null
                    ? _handleClockIn()
                    : _handleClockOut(onShift),
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
                  onPressed: () => onShift == null
                      ? _handleClockIn()
                      : _handleClockOut(onShift),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                  ),
                  child: Text(onShift == null ? 'Clock in' : 'Clock out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
