class LoginActivity {
  final String id;
  final String userId;
  final String username;
  final String name;
  final String role;
  final String type; // 'login' or 'logout'
  final String at;
  bool isSynced;

  LoginActivity({
    required this.id,
    required this.userId,
    required this.username,
    required this.name,
    required this.role,
    required this.type,
    required this.at,
    this.isSynced = false,
  });

  factory LoginActivity.fromJson(Map<String, dynamic> json) {
    return LoginActivity(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'barista',
      type: json['type'] as String? ?? 'login',
      at: json['at'] as String? ?? DateTime.now().toIso8601String(),
      isSynced: json['isSynced'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'username': username,
    'name': name,
    'role': role,
    'type': type,
    'at': at,
    'isSynced': isSynced,
  };
}
