import 'package:flutter/material.dart';
import '../../models/order_item.dart';

class VoidDialog extends StatefulWidget {
  final List<OrderItem> cart;
  final bool isManager;
  final bool isRequestPending;
  final Future<Map<String, dynamic>> Function(
    String reason,
    String managerUsername,
    String managerPassword,
  ) onConfirmVoid;
  final Future<Map<String, dynamic>> Function(String reason) onRequestVoid;

  const VoidDialog({
    super.key,
    required this.cart,
    required this.isManager,
    required this.isRequestPending,
    required this.onConfirmVoid,
    required this.onRequestVoid,
  });

  @override
  State<VoidDialog> createState() => _VoidDialogState();
}

class _VoidDialogState extends State<VoidDialog> {
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  bool get _hasTarget => widget.cart.isNotEmpty;

  @override
  void dispose() {
    _reasonController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirmVoid() async {
    final reason = _reasonController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (!_hasTarget) {
      setState(() => _errorMessage = 'Select a ticket to void.');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'Enter a reason for voiding.');
      return;
    }
    if (!widget.isManager && (username.isEmpty || password.isEmpty)) {
      setState(() => _errorMessage = 'Manager credentials required to void.');
      return;
    }

    final navigator = Navigator.of(context);
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.onConfirmVoid(
        reason,
        username,
        password,
      );
      if (!mounted) return;
      if (result['ok'] == true) {
        navigator.pop();
      } else {
        setState(() {
          _errorMessage = result['error']?.toString() ?? 'Unable to void.';
          _isProcessing = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isProcessing = false;
      });
    }
  }

  Future<void> _requestVoid() async {
    final reason = _reasonController.text.trim();
    if (!_hasTarget) {
      setState(() => _errorMessage = 'Select a ticket to void.');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'Enter a reason for voiding.');
      return;
    }

    final navigator = Navigator.of(context);
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.onRequestVoid(reason);
      if (!mounted) return;
      if (result['ok'] == true) {
        navigator.pop();
      } else {
        setState(() {
          _errorMessage = result['error']?.toString() ?? 'Unable to send request.';
          _isProcessing = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.95,
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(30, 30, 30, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 2),
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        size: 27,
                        color: Color(0xFF292929),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Void checkout',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF171717),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.isManager
                        ? 'This action cannot be undone.'
                        : 'Manager approval required to void.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF737373)),
                  ),
                  const SizedBox(height: 30),
                  if (!widget.isManager) ...[
                    _fieldLabel('Manager username'),
                    TextField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(hint: 'Enter username'),
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Manager password'),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(hint: '••••••••'),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _fieldLabel('Reason for Voiding', required: true),
                  TextField(
                    controller: _reasonController,
                    minLines: 2,
                    maxLines: 2,
                    textInputAction: TextInputAction.newline,
                    decoration: _inputDecoration(
                      hint: 'e.g., Customer changed mind, wrong order input...',
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 38),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: _isProcessing ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF525252),
                            side: const BorderSide(color: Color(0xFFE5E5E5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isProcessing || widget.isRequestPending
                              ? null
                              : _confirmVoid,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF737373),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Confirm Void'),
                        ),
                      ),
                    ],
                  ),
                  if (!widget.isManager) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _isProcessing || widget.isRequestPending
                          ? null
                          : _requestVoid,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        widget.isRequestPending ? 'Waiting for admin approval' : 'Request to admin',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: _isProcessing ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Color(0xFF9A9A9A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Color(0xFF404040),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(text: label),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    Widget? prefix,
    String? label,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.black, width: 1.2),
      ),
    );
  }
}