class HandDeliveryItem {
  final String id;
  final String particulars;
  final String? hsnCode;
  final String? size;
  final int quantity;
  final double priceInr;
  final double amountInr;
  final double gstRate;
  final double taxableValue;
  final double gstAmount;

  HandDeliveryItem({
    required this.id,
    required this.particulars,
    this.hsnCode,
    this.size,
    required this.quantity,
    required this.priceInr,
    required this.amountInr,
    required this.gstRate,
    required this.taxableValue,
    required this.gstAmount,
  });

  factory HandDeliveryItem.fromJson(Map<String, dynamic> j) {
    double parseNum(dynamic v) => v == null ? 0 : double.parse(v.toString());
    return HandDeliveryItem(
      id: j['id'] as String,
      particulars: j['particulars'] as String,
      hsnCode: j['hsnCode'] as String?,
      size: j['size'] as String?,
      quantity: (j['quantity'] as num).toInt(),
      priceInr: parseNum(j['priceInr']),
      amountInr: parseNum(j['amountInr']),
      gstRate: parseNum(j['gstRate']),
      taxableValue: parseNum(j['taxableValue']),
      gstAmount: parseNum(j['gstAmount']),
    );
  }
}

class HandDeliveryOrder {
  final String id;
  final String invoiceNumber;
  final DateTime orderDate;
  final String status;
  final String invoiceType; // 'INTER_STATE' or 'LOCAL'
  final String? gstin;
  final String? dobPassport;

  final String buyerName;
  final String? buyerState;
  final String? buyerCountry;
  final String? buyerEmail;
  final String? buyerCellAreaCode;
  final String? buyerCellNo;

  final List<HandDeliveryItem> items;
  final DateTime createdAt;

  HandDeliveryOrder({
    required this.id,
    required this.invoiceNumber,
    required this.orderDate,
    required this.status,
    required this.invoiceType,
    this.gstin,
    this.dobPassport,
    required this.buyerName,
    this.buyerState,
    this.buyerCountry,
    this.buyerEmail,
    this.buyerCellAreaCode,
    this.buyerCellNo,
    required this.items,
    required this.createdAt,
  });

  double get totalAmount => items.fold(0.0, (s, i) => s + i.amountInr);
  double get totalTaxable => items.fold(0.0, (s, i) => s + i.taxableValue);
  double get totalGst => items.fold(0.0, (s, i) => s + i.gstAmount);

  /// Convenience: kept for any legacy callers that expected `totalInr`.
  double get totalInr => totalAmount;

  factory HandDeliveryOrder.fromJson(Map<String, dynamic> j) => HandDeliveryOrder(
        id: j['id'] as String,
        invoiceNumber: j['invoiceNumber'] as String,
        orderDate: DateTime.parse(j['orderDate'] as String),
        status: j['status'] as String,
        invoiceType: (j['invoiceType'] as String?) ?? 'INTER_STATE',
        gstin: j['gstin'] as String?,
        dobPassport: j['dobPassport'] as String?,
        buyerName: j['buyerName'] as String,
        buyerState: j['buyerState'] as String?,
        buyerCountry: j['buyerCountry'] as String?,
        buyerEmail: j['buyerEmail'] as String?,
        buyerCellAreaCode: j['buyerCellAreaCode'] as String?,
        buyerCellNo: j['buyerCellNo'] as String?,
        items: (j['items'] as List? ?? [])
            .map((e) => HandDeliveryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class BillingProduct {
  final String id;
  final String description;
  final String? hsnCode;
  final double gstRate;
  final bool isActive;

  BillingProduct({
    required this.id,
    required this.description,
    this.hsnCode,
    required this.gstRate,
    required this.isActive,
  });

  factory BillingProduct.fromJson(Map<String, dynamic> j) => BillingProduct(
        id: j['id'] as String,
        description: j['description'] as String,
        hsnCode: j['hsnCode'] as String?,
        gstRate: double.parse((j['gstRate'] ?? 5).toString()),
        isActive: (j['isActive'] as bool?) ?? true,
      );
}
