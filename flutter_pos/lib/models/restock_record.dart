class RestockRecord {
  final String id;
  final String? inventoryItemId;
  final String itemName;
  final double quantityAdded;
  final double? purchaseQty;
  final String? purchaseUnit;
  final String date;
  bool isSynced;

  RestockRecord({
    required this.id,
    this.inventoryItemId,
    required this.itemName,
    required this.quantityAdded,
    this.purchaseQty,
    this.purchaseUnit,
    required this.date,
    this.isSynced = false,
  });

  factory RestockRecord.fromJson(Map<String, dynamic> json) {
    return RestockRecord(
      id: json['id'] as String? ?? '',
      inventoryItemId: json['inventoryItemId'] as String? ?? json['inventory_item_id'] as String?,
      itemName: json['itemName'] as String? ?? json['item_name_snapshot'] as String? ?? '',
      quantityAdded: (json['quantityAdded'] as num?)?.toDouble() ?? (json['quantity_added'] as num?)?.toDouble() ?? 0.0,
      purchaseQty: (json['purchaseQty'] as num?)?.toDouble() ?? (json['purchase_qty'] as num?)?.toDouble(),
      purchaseUnit: json['purchaseUnit'] as String? ?? json['purchase_unit'] as String?,
      date: json['date'] as String? ?? json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      isSynced: json['isSynced'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
    'itemName': itemName,
    'quantityAdded': quantityAdded,
    if (purchaseQty != null) 'purchaseQty': purchaseQty,
    if (purchaseUnit != null) 'purchaseUnit': purchaseUnit,
    'date': date,
    'isSynced': isSynced,
  };
}
