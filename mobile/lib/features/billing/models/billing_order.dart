class BillingItem {
  final String id;
  final String particulars;
  final int quantity;
  final double priceUsd;
  final double amountUsd;

  BillingItem({
    required this.id,
    required this.particulars,
    required this.quantity,
    required this.priceUsd,
    required this.amountUsd,
  });

  factory BillingItem.fromJson(Map<String, dynamic> j) => BillingItem(
        id: j['id'] as String,
        particulars: j['particulars'] as String,
        quantity: (j['quantity'] as num).toInt(),
        priceUsd: double.parse(j['priceUsd'].toString()),
        amountUsd: double.parse(j['amountUsd'].toString()),
      );
}

class BillingOrder {
  final String id;
  final String invoiceNumber;
  final String vehicleEntryId;
  final Map<String, dynamic>? vehicleEntry;
  final DateTime orderDate;
  final String status;
  final String buyerName;
  final String buyerAddress;
  final String buyerCity;
  final String buyerState;
  final String buyerZip;
  final String buyerCountry;
  final String buyerEmail;
  final String buyerWhatsApp;
  final String buyerPassportNo;
  final DateTime? buyerDOB;
  final String buyerNationality;
  final String buyerSeaPort;
  final String? notes;
  final List<BillingItem> items;
  final DateTime createdAt;

  BillingOrder({
    required this.id,
    required this.invoiceNumber,
    required this.vehicleEntryId,
    this.vehicleEntry,
    required this.orderDate,
    required this.status,
    required this.buyerName,
    required this.buyerAddress,
    required this.buyerCity,
    required this.buyerState,
    required this.buyerZip,
    required this.buyerCountry,
    required this.buyerEmail,
    required this.buyerWhatsApp,
    required this.buyerPassportNo,
    this.buyerDOB,
    required this.buyerNationality,
    required this.buyerSeaPort,
    this.notes,
    required this.items,
    required this.createdAt,
  });

  double get totalUsd => items.fold(0.0, (s, i) => s + i.amountUsd);

  factory BillingOrder.fromJson(Map<String, dynamic> j) => BillingOrder(
        id: j['id'] as String,
        invoiceNumber: j['invoiceNumber'] as String,
        vehicleEntryId: j['vehicleEntryId'] as String,
        vehicleEntry: j['vehicleEntry'] as Map<String, dynamic>?,
        orderDate: DateTime.parse(j['orderDate'] as String),
        status: j['status'] as String,
        buyerName: j['buyerName'] as String,
        buyerAddress: j['buyerAddress'] as String,
        buyerCity: j['buyerCity'] as String,
        buyerState: j['buyerState'] as String,
        buyerZip: j['buyerZip'] as String,
        buyerCountry: j['buyerCountry'] as String,
        buyerEmail: j['buyerEmail'] as String,
        buyerWhatsApp: j['buyerWhatsApp'] as String,
        buyerPassportNo: j['buyerPassportNo'] as String,
        buyerDOB: j['buyerDOB'] != null ? DateTime.parse(j['buyerDOB'] as String) : null,
        buyerNationality: j['buyerNationality'] as String,
        buyerSeaPort: j['buyerSeaPort'] as String,
        notes: j['notes'] as String?,
        items: (j['items'] as List? ?? []).map((e) => BillingItem.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
