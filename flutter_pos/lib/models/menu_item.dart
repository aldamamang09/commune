class MenuAddon {
  final String id;
  final String name;
  final double price;
  final int maxQty;
  final String? inventoryItemId;

  const MenuAddon({
    required this.id,
    required this.name,
    required this.price,
    this.maxQty = 9,
    this.inventoryItemId,
  });

  factory MenuAddon.fromJson(Map<String, dynamic> json) {
    return MenuAddon(
      id: json['id'] as String? ?? json['name'] as String? ?? 'addon',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      maxQty: (json['maxQty'] as num?)?.toInt() ?? 9,
      inventoryItemId: json['inventoryItemId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'maxQty': maxQty,
    if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
  };
}

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final String image;
  final bool available;
  final List<String> styles; // e.g. ["hot", "iced"]
  final List<MenuAddon> addons;

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.image,
    this.available = true,
    this.styles = const ['hot', 'iced'],
    this.addons = const [],
  });

  bool get isDrink => !RegExp(r'food|pastr', caseSensitive: false).hasMatch(category);

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    List<String> parsedStyles = [];
    if (json['styles'] is List) {
      parsedStyles = (json['styles'] as List)
          .map((e) => e.toString().toLowerCase())
          .where((e) => e == 'hot' || e == 'iced')
          .toList();
    }
    if (parsedStyles.isEmpty && !RegExp(r'food|pastr', caseSensitive: false).hasMatch(json['category']?.toString() ?? '')) {
      parsedStyles = ['hot', 'iced'];
    }

    List<MenuAddon> parsedAddons = [];
    if (json['addons'] is List) {
      parsedAddons = (json['addons'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => MenuAddon.fromJson(e))
          .toList();
    }

    return MenuItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Item',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'Other',
      image: json['image'] as String? ?? '/images/drinks.jpg',
      available: json['available'] != false,
      styles: parsedStyles,
      addons: parsedAddons,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'category': category,
    'image': image,
    'available': available,
    'styles': styles,
    'addons': addons.map((a) => a.toJson()).toList(),
  };
}
