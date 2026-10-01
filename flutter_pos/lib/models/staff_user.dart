class StaffUser {
  final String id;
  final String username;
  final String password;
  final String name;
  final String role; // 'admin', 'cashier', 'manager', 'barista'
  final String title;

  const StaffUser({
    required this.id,
    required this.username,
    required this.password,
    required this.name,
    required this.role,
    this.title = '',
  });

  bool get canUsePos => role == 'cashier';
  bool get canLoginToPos => canUsePos;
  bool get canAccessBaristaShift => role == 'barista';
  bool get isManager => role == 'manager' || role == 'admin';

  static String parseRole(String rawRole, String title, String username) {
    final combined =
        '${rawRole.toLowerCase()} ${title.toLowerCase()} ${username.toLowerCase()}';
    if (combined.contains('admin') || combined.contains('owner')) {
      return 'admin';
    }
    if (combined.contains('manager')) {
      return 'manager';
    }
    if (combined.contains('cashier') ||
        combined.contains('sale in charge') ||
        combined.contains('sale')) {
      return 'cashier';
    }
    return 'barista';
  }

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] as String? ?? 'barista').trim();
    final rawTitle = (json['title'] as String? ?? '').trim();
    final rawUsername = (json['username'] as String? ?? '').trim();
    final resolvedRole = parseRole(rawRole, rawTitle, rawUsername);

    return StaffUser(
      id: json['id'] as String? ?? '',
      username: rawUsername.toLowerCase(),
      password: json['password'] as String? ?? '',
      name: (json['name'] as String? ?? '').trim().isNotEmpty
          ? (json['name'] as String).trim()
          : rawUsername,
      role: resolvedRole,
      title: rawTitle.isNotEmpty
          ? rawTitle
          : (resolvedRole == 'admin'
              ? 'Owner'
              : resolvedRole == 'manager'
                  ? 'Manager'
                  : resolvedRole == 'cashier'
                      ? 'Cashier'
                      : 'Barista'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': name,
        'role': role,
        'title': title,
      };
}
