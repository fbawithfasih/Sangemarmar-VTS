import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';
import 'models/shipment.dart';

class ShipmentListScreen extends StatefulWidget {
  const ShipmentListScreen({super.key});

  @override
  State<ShipmentListScreen> createState() => _ShipmentListScreenState();
}

class _ShipmentListScreenState extends State<ShipmentListScreen> {
  final _api = ApiService();
  List<Shipment> _shipments = [];
  bool _loading = true;
  String? _error;
  final _dtFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get(ApiConstants.shipping);
      setState(() {
        _shipments = (res.data as List)
            .map((e) => Shipment.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() { _error = 'Failed to load shipments'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(title: const Text('Shipments')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/shipping/new');
          _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _shipments.isEmpty
                  ? const Center(child: Text('No shipments yet', style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _shipments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ShipmentTile(
                          shipment: _shipments[i],
                          dtFmt: _dtFmt,
                          onTap: () async {
                            await context.push('/shipping/${_shipments[i].id}');
                            _load();
                          },
                        ),
                      ),
                    ),
    );
  }
}

class _ShipmentTile extends StatelessWidget {
  final Shipment shipment;
  final DateFormat dtFmt;
  final VoidCallback onTap;
  const _ShipmentTile({required this.shipment, required this.dtFmt, required this.onTap});

  Color get _statusColor {
    switch (shipment.status) {
      case 'DELIVERED': return Colors.green;
      case 'EXCEPTION': return Colors.red;
      case 'OUT_FOR_DELIVERY': return Colors.orange;
      case 'IN_TRANSIT': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Color get _carrierColor {
    switch (shipment.carrier) {
      case 'FEDEX': return const Color(0xFF4D148C);
      case 'DHL': return const Color(0xFFD40511);
      case 'UPS': return const Color(0xFF351C15);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _carrierColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  shipment.carrier,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shipment.recipientName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (shipment.trackingNumber != null)
                      Text(shipment.trackingNumber!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${shipment.serviceLabel}  •  ${dtFmt.format(shipment.shipDate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (shipment.billingOrderId != null)
                      Text(
                        'Invoice: ${shipment.invoiceNumber}',
                        style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      shipment.statusLabel,
                      style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (shipment.quotedCostUsd != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '\$ ${shipment.quotedCostUsd!.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
