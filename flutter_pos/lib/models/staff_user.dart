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

  bool get canUsePos => role == 'cashier' || role == 'manager' || role == 'admin';
  bool get isManager => role == 'manager' || role == 'admin';

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      name: json['name'] as String? ?? json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'barista',
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
