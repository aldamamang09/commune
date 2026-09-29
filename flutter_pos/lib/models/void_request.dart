import 'order_item.dart';

class VoidRequest {
  final String id;
  final String requestedAt;
  final String requestedById;
  final String requestedByName;
  final String reason;
  String status; // 'pending', 'approved', 'denied'
  final String? orderId;
  final List<OrderItem> items;
  final double subtotal;
  final double discount;
  final String? promoLabel;
  final double total;
  final String paymentMethod;
  String? approvedAt;
  String? approvedByName;
  String? processedOrderId;
  bool isSynced;

  VoidRequest({
    required this.id,
    required this.requestedAt,
    required this.requestedById,
    required this.requestedByName,
    required this.reason,
    this.status = 'pending',
    this.orderId,
    this.items = const [],
    required this.subtotal,
    this.discount = 0.0,
    this.promoLabel,
    required this.total,
    this.paymentMethod = 'cash',
    this.approvedAt,
    this.approvedByName,
    this.processedOrderId,
    this.isSynced = false,
  });

  factory VoidRequest.fromJson(Map<String, dynamic> json) {
    List<OrderItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => OrderItem.fromJson(e))
          .toList();
    }

    return VoidRequest(
      id: json['id'] as String? ?? '',
      requestedAt: json['requestedAt'] as String? ?? json['requested_at'] as String? ?? '',
      requestedById: json['requestedById'] as String? ?? json['requested_by_id'] as String? ?? '',
      requestedByName: json['requestedByName'] as String? ?? json['requested_by_name'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      orderId: json['orderId'] as String? ?? json['order_id'] as String?,
      items: parsedItems,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      promoLabel: json['promoLabel'] as String? ?? json['promo_label'] as String?,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String? ?? json['payment_method'] as String? ?? 'cash',
      approvedAt: json['approvedAt'] as String? ?? json['approved_at'] as String?,
      approvedByName: json['approvedByName'] as String? ?? json['approved_by_name'] as String?,
      processedOrderId: json['processedOrderId'] as String? ?? json['processed_order_id'] as String?,
      isSynced: json['isSynced'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'requestedAt': requestedAt,
    'requestedById': requestedById,
    'requestedByName': requestedByName,
    'reason': reason,
    'status': status,
    if (orderId != null) 'orderId': orderId,
    'items': items.map((i) => i.toJson()).toList(),
    'subtotal': subtotal,
    'discount': discount,
    if (promoLabel != null) 'promoLabel': promoLabel,
    'total': total,
    'paymentMethod': paymentMethod,
    if (approvedAt != null) 'approvedAt': approvedAt,
    if (approvedByName != null) 'approvedByName': approvedByName,
    if (processedOrderId != null) 'processedOrderId': processedOrderId,
    'isSynced': isSynced,
  };
}
