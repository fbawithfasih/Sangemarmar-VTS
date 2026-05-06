class HandDeliveryItem {
  final String id;
  final String particulars;
  final String? hsnCode;
  final String? size;
  final int quantity;
  final double priceInr;
  final double amountInr;

  HandDeliveryItem({
    required this.id,
    required this.particulars,
    this.hsnCode,
    this.size,
    required this.quantity,
    required this.priceInr,
    required this.amountInr,
  });

  factory HandDeliveryItem.fromJson(Map<String, dynamic> j) => HandDeliveryItem(
        id: j['id'] as String,
        particulars: j['particulars'] as String,
        hsnCode: j['hsnCode'] as String?,
        size: j['size'] as String?,
        quantity: (j['quantity'] as num).toInt(),
        priceInr: double.parse(j['priceInr'].toString()),
        amountInr: double.parse(j['amountInr'].toString()),
      );
}

class HandDeliveryOrder {
  final String id;
  final String invoiceNumber;
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
  final String? buyerCellAreaCode;
  final String? buyerCellNo;
  final String buyerPassportNo;
  final DateTime? buyerDOB;
  final String buyerNationality;
  final String buyerSeaPort;
  final String? notes;
  final List<HandDeliveryItem> items;
  final DateTime createdAt;

  HandDeliveryOrder({
    required this.id,
    required this.invoiceNumber,
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
    this.buyerCellAreaCode,
    this.buyerCellNo,
    required this.buyerPassportNo,
    this.buyerDOB,
    required this.buyerNationality,
    required this.buyerSeaPort,
    this.notes,
    required this.items,
    required this.createdAt,
  });

  double get totalInr => items.fold(0.0, (s, i) => s + i.amountInr);

  factory HandDeliveryOrder.fromJson(Map<String, dynamic> j) => HandDeliveryOrder(
        id: j['id'] as String,
        invoiceNumber: j['invoiceNumber'] as String,
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
        buyerCellAreaCode: j['buyerCellAreaCode'] as String?,
        buyerCellNo: j['buyerCellNo'] as String?,
        buyerPassportNo: j['buyerPassportNo'] as String,
        buyerDOB: j['buyerDOB'] != null ? DateTime.parse(j['buyerDOB'] as String) : null,
        buyerNationality: j['buyerNationality'] as String,
        buyerSeaPort: (j['buyerSeaPort'] as String?) ?? '',
        notes: j['notes'] as String?,
        items: (j['items'] as List? ?? []).map((e) => HandDeliveryItem.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
