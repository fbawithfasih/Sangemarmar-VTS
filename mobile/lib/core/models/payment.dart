class Payment {
  final String id;
  final String saleId;
  final String mode;
  final double amount;
  final DateTime paymentDate;
  final String? notes;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.saleId,
    required this.mode,
    required this.amount,
    required this.paymentDate,
    this.notes,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String,
        saleId: json['saleId'] as String,
        mode: json['mode'] as String,
        amount: double.parse(json['amount'].toString()),
        paymentDate: DateTime.parse(json['paymentDate'] as String).toLocal(),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );

  String get modeLabel {
    const labels = {
      'CC': 'Credit Card (CC)',
      'IC': 'Indian Currency — ₹ (IC)',
      'FC': 'Foreign Currency — ₹ (FC)',
    };
    return labels[mode] ?? mode;
  }

  String get modeSymbol {
    const symbols = {'CC': '💳', 'IC': '₹', 'FC': '₹'};
    return symbols[mode] ?? mode;
  }
}
