class Commission {
  final String id;
  final String saleId;
  final String recipientType;
  final String recipientName;
  final double rate;
  final double calculatedAmount;
  final double finalAmount;
  final bool isOverridden;
  final String? overrideReason;
  final double? paidAmount;
  final DateTime? paidAt;
  final String? paidNote;
  final DateTime createdAt;

  const Commission({
    required this.id,
    required this.saleId,
    required this.recipientType,
    required this.recipientName,
    required this.rate,
    required this.calculatedAmount,
    required this.finalAmount,
    required this.isOverridden,
    this.overrideReason,
    this.paidAmount,
    this.paidAt,
    this.paidNote,
    required this.createdAt,
  });

  factory Commission.fromJson(Map<String, dynamic> json) => Commission(
        id: json['id'] as String,
        saleId: json['saleId'] as String,
        recipientType: json['recipientType'] as String,
        recipientName: json['recipientName'] as String,
        rate: double.parse(json['rate'].toString()),
        calculatedAmount: double.parse(json['calculatedAmount'].toString()),
        finalAmount: double.parse(json['finalAmount'].toString()),
        isOverridden: json['isOverridden'] as bool? ?? false,
        overrideReason: json['overrideReason'] as String?,
        paidAmount: json['paidAmount'] != null
            ? double.parse(json['paidAmount'].toString())
            : null,
        paidAt: json['paidAt'] != null
            ? DateTime.parse(json['paidAt'] as String).toLocal()
            : null,
        paidNote: json['paidNote'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );

  bool get isPaid => paidAmount != null && paidAmount! > 0;

  String get recipientLabel {
    const labels = {
      'DRIVER': 'Driver',
      'GUIDE': 'Guide',
      'LOCAL_AGENT': 'Local Agent',
      'COMPANY': 'Company',
    };
    return labels[recipientType] ?? recipientType;
  }
}
