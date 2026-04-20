class VehicleEntry {
  final String id;
  final String vehicleNumber;
  final String driverName;
  final String guideName;
  final String localAgent;
  final String companyName;
  final DateTime entryDate;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const VehicleEntry({
    required this.id,
    required this.vehicleNumber,
    required this.driverName,
    required this.guideName,
    required this.localAgent,
    required this.companyName,
    required this.entryDate,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory VehicleEntry.fromJson(Map<String, dynamic> json) => VehicleEntry(
        id: json['id'] as String,
        vehicleNumber: json['vehicleNumber'] as String,
        driverName: json['driverName'] as String,
        guideName: json['guideName'] as String,
        localAgent: json['localAgent'] as String,
        companyName: json['companyName'] as String,
        entryDate: DateTime.parse(json['entryDate'] as String).toLocal(),
        status: json['status'] as String,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );

  String get statusLabel {
    const labels = {
      'ENTERED': 'Entered',
      'SALES_PENDING': 'Sales Pending',
      'SALES_COMPLETE': 'Sales Complete',
      'PAYMENT_PENDING': 'Payment Pending',
      'PAYMENT_COMPLETE': 'Payment Complete',
      'COMMISSION_PENDING': 'Commission Pending',
      'COMMISSION_COMPLETE': 'Commission Complete',
      'COMPLETED': 'Completed',
    };
    return labels[status] ?? status;
  }
}
