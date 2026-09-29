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

  bool get canUsePos => role == 'cashier' || role == 'manager' || role == 'admin' || role == 'barista';
  bool get isManager => role == 'manager' || role == 'admin';

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] as String? ?? 'barista').toLowerCase();
    final title = (json['title'] as String? ?? '').toLowerCase();
    final username = (json['username'] as String? ?? '').toLowerCase();

    var role = rawRole;
    if (role == 'barista' || role.isEmpty) {
      if (title.contains('admin') || title.contains('owner') || username == 'admin') {
        role = 'admin';
      } else if (title.contains('cashier') || title.contains('sale') || username == 'cashier') {
        role = 'cashier';
      } else if (title.contains('manager') || username == 'manager') {
        role = 'manager';
      }
    }

    return StaffUser(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      name: json['name'] as String? ?? json['username'] as String? ?? '',
      role: role,
      title: json['title'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'password': password,
    'name': name,
    'role': role,
    'title': title,
  };
}
