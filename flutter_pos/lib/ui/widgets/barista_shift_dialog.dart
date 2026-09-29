import 'package:flutter/material.dart';
import '../../models/staff_user.dart';
import '../theme.dart';

class BaristaShiftDialog extends StatefulWidget {
  final List<StaffUser> staffUsers;
  final String currentBaristaName;
  final Function(StaffUser staff, String type) onPunch;

  const BaristaShiftDialog({
    super.key,
    required this.staffUsers,
    required this.currentBaristaName,
    required this.onPunch,
  });

  @override
  State<BaristaShiftDialog> createState() => _BaristaShiftDialogState();
}

class _BaristaShiftDialogState extends State<BaristaShiftDialog> {
  StaffUser? _selectedStaff;
  String _type = 'login'; // 'login' or 'logout'

  @override
  void initState() {
    super.initState();
    if (widget.staffUsers.isNotEmpty) {
      _selectedStaff = widget.staffUsers.firstWhere(
        (u) => u.name == widget.currentBaristaName,
        orElse: () => widget.staffUsers.first,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 22, color: CommuneTheme.primary),
                    SizedBox(width: 8),
                    Text(
                      'Shift Clock In / Out',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Select staff member and record shift attendance. Synced with store attendance logs.',
              style: TextStyle(fontSize: 12, color: CommuneTheme.textMuted),
            ),
            const SizedBox(height: 16),

            // Staff Dropdown
            DropdownButtonFormField<StaffUser>(
              value: _selectedStaff,
              decoration: InputDecoration(
                labelText: 'Staff Member',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: widget.staffUsers.map((user) {
                return DropdownMenuItem(
                  value: user,
                  child: Text('${user.name} (${user.role.toUpperCase()})'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedStaff = val),
            ),
            const SizedBox(height: 16),

            // Type Toggle
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Clock In')),
                    selected: _type == 'login',
                    onSelected: (val) => setState(() => _type = 'login'),
                    selectedColor: const Color(0xFFDCFCE7),
                    labelStyle: TextStyle(
                      color: _type == 'login' ? const Color(0xFF15803D) : CommuneTheme.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Clock Out')),
                    selected: _type == 'logout',
                    onSelected: (val) => setState(() => _type = 'logout'),
                    selectedColor: const Color(0xFFFEE2E2),
                    labelStyle: TextStyle(
                      color: _type == 'logout' ? const Color(0xFFB91C1C) : CommuneTheme.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedStaff == null
                    ? null
                    : () {
                        widget.onPunch(_selectedStaff!, _type);
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommuneTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _type == 'login' ? 'Confirm Clock In' : 'Confirm Clock Out',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
