class Shipment {
  final String id;
  final String? billingOrderId;
  final Map<String, dynamic>? billingOrder;
  final String carrier;
  final String serviceCode;
  final String serviceLabel;
  final String? carrierShipmentId;
  final String? trackingNumber;
  final String status;
  final DateTime? estimatedDelivery;
  final String shipperName;
  final String recipientName;
  final String recipientAddress;
  final String recipientCity;
  final String recipientState;
  final String recipientZip;
  final String recipientCountry;
  final String recipientPhone;
  final String recipientEmail;
  final double weightKg;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final double declaredValueUsd;
  final String contentsDescription;
  final double? quotedCostUsd;
  final DateTime shipDate;
  final DateTime createdAt;

  Shipment({
    required this.id,
    this.billingOrderId,
    this.billingOrder,
    required this.carrier,
    required this.serviceCode,
    required this.serviceLabel,
    this.carrierShipmentId,
    this.trackingNumber,
    required this.status,
    this.estimatedDelivery,
    required this.shipperName,
    required this.recipientName,
    required this.recipientAddress,
    required this.recipientCity,
    required this.recipientState,
    required this.recipientZip,
    required this.recipientCountry,
    required this.recipientPhone,
    required this.recipientEmail,
    required this.weightKg,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    required this.declaredValueUsd,
    required this.contentsDescription,
    this.quotedCostUsd,
    required this.shipDate,
    required this.createdAt,
  });

  String get statusLabel {
    const labels = {
      'LABEL_CREATED': 'Label Created',
      'PICKED_UP': 'Picked Up',
      'IN_TRANSIT': 'In Transit',
      'OUT_FOR_DELIVERY': 'Out for Delivery',
      'DELIVERED': 'Delivered',
      'EXCEPTION': 'Exception',
      'CANCELLED': 'Cancelled',
    };
    return labels[status] ?? status;
  }

  String get invoiceNumber =>
      (billingOrder?['invoiceNumber'] as String?) ?? '—';

  factory Shipment.fromJson(Map<String, dynamic> j) => Shipment(
        id: j['id'] as String,
        billingOrderId: j['billingOrderId'] as String?,
        billingOrder: j['billingOrder'] as Map<String, dynamic>?,
        carrier: j['carrier'] as String,
        serviceCode: j['serviceCode'] as String,
        serviceLabel: j['serviceLabel'] as String,
        carrierShipmentId: j['carrierShipmentId'] as String?,
        trackingNumber: j['trackingNumber'] as String?,
        status: j['status'] as String,
        estimatedDelivery: j['estimatedDelivery'] != null
            ? DateTime.tryParse(j['estimatedDelivery'] as String)
            : null,
        shipperName: j['shipperName'] as String,
        recipientName: j['recipientName'] as String,
        recipientAddress: j['recipientAddress'] as String,
        recipientCity: j['recipientCity'] as String,
        recipientState: j['recipientState'] as String,
        recipientZip: j['recipientZip'] as String,
        recipientCountry: j['recipientCountry'] as String,
        recipientPhone: j['recipientPhone'] as String,
        recipientEmail: j['recipientEmail'] as String,
        weightKg: double.parse(j['weightKg'].toString()),
        lengthCm: j['lengthCm'] != null ? double.parse(j['lengthCm'].toString()) : null,
        widthCm: j['widthCm'] != null ? double.parse(j['widthCm'].toString()) : null,
        heightCm: j['heightCm'] != null ? double.parse(j['heightCm'].toString()) : null,
        declaredValueUsd: double.parse(j['declaredValueUsd'].toString()),
        contentsDescription: j['contentsDescription'] as String,
        quotedCostUsd: j['quotedCostUsd'] != null ? double.parse(j['quotedCostUsd'].toString()) : null,
        shipDate: DateTime.parse(j['shipDate'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class RateQuote {
  final String carrier;
  final String serviceCode;
  final String serviceLabel;
  final int? transitDays;
  final String? deliveryDate;
  final double costUsd;
  final String currency;

  RateQuote({
    required this.carrier,
    required this.serviceCode,
    required this.serviceLabel,
    this.transitDays,
    this.deliveryDate,
    required this.costUsd,
    required this.currency,
  });

  factory RateQuote.fromJson(Map<String, dynamic> j) => RateQuote(
        carrier: j['carrier'] as String,
        serviceCode: j['serviceCode'] as String,
        serviceLabel: j['serviceLabel'] as String,
        transitDays: j['transitDays'] as int?,
        deliveryDate: j['deliveryDate'] as String?,
        costUsd: double.parse(j['costUsd'].toString()),
        currency: j['currency'] as String? ?? 'USD',
      );
}
