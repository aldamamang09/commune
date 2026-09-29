class OrderAddonSelection {
  final String name;
  final int qty;
  final double price;
  final String? inventoryItemId;

  const OrderAddonSelection({
    required this.name,
    this.qty = 1,
    required this.price,
    this.inventoryItemId,
  });

  factory OrderAddonSelection.fromJson(Map<String, dynamic> json) {
    return OrderAddonSelection(
      name: json['name'] as String? ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      inventoryItemId: json['inventoryItemId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    'price': price,
    if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
  };
}

class OrderItem {
  final String productId;
  final String name;
  int qty;
  final double price;
  final String? style; // 'hot' or 'iced'
  final List<OrderAddonSelection> addons;
  final String? category;

  OrderItem({
    required this.productId,
    required this.name,
    this.qty = 1,
    required this.price,
    this.style,
    this.addons = const [],
    this.category,
  });

  double get unitPrice {
    double addonsTotal = addons.fold(0.0, (sum, a) => sum + (a.price * a.qty));
    return price + addonsTotal;
  }

  double get lineTotal => unitPrice * qty;

  String get optionsSummary {
    final parts = <String>[];
    if (style != null && style!.isNotEmpty) {
      parts.add(style == 'hot' ? 'Hot' : 'Iced');
    }
    for (final addon in addons) {
      if (addon.qty > 1) {
        parts.add('${addon.name} x${addon.qty}');
      } else {
        parts.add(addon.name);
      }
    }
    return parts.join(', ');
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    List<OrderAddonSelection> parsedAddons = [];
    if (json['addons'] is List) {
      parsedAddons = (json['addons'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => OrderAddonSelection.fromJson(e))
          .toList();
    }

    return OrderItem(
      productId: json['productId'] as String? ?? json['product_id_snapshot'] as String? ?? '',
      name: json['name'] as String? ?? json['name_snapshot'] as String? ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? (json['price_snapshot'] as num?)?.toDouble() ?? 0.0,
      style: json['style'] as String?,
      addons: parsedAddons,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'price': price,
    if (style != null) 'style': style,
    'addons': addons.map((a) => a.toJson()).toList(),
    if (category != null) 'category': category,
  };
}
