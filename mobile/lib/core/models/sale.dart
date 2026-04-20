import 'vehicle_entry.dart';

class Sale {
  final String id;
  final String vehicleEntryId;
  final VehicleEntry? vehicleEntry;
  final double grossSale;
  final double netSale;
  final String salesperson;
  final String orderType;
  final DateTime saleDate;
  final String? notes;
  final DateTime createdAt;

  const Sale({
    required this.id,
    required this.vehicleEntryId,
    this.vehicleEntry,
    required this.grossSale,
    required this.netSale,
    required this.salesperson,
    required this.orderType,
    required this.saleDate,
    this.notes,
    required this.createdAt,
  });

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as String,
        vehicleEntryId: json['vehicleEntryId'] as String,
        vehicleEntry: json['vehicleEntry'] != null
            ? VehicleEntry.fromJson(json['vehicleEntry'] as Map<String, dynamic>)
            : null,
        grossSale: double.parse(json['grossSale'].toString()),
        netSale: double.parse(json['netSale'].toString()),
        salesperson: json['salesperson'] as String,
        orderType: json['orderType'] as String,
        saleDate: DateTime.parse(json['saleDate'] as String).toLocal(),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}
