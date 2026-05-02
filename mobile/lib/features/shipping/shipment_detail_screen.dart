import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/download_helper.dart';
import '../../core/widgets/app_bar.dart';
import 'models/shipment.dart';

class ShipmentDetailScreen extends StatefulWidget {
  final String shipmentId;
  const ShipmentDetailScreen({super.key, required this.shipmentId});

  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends State<ShipmentDetailScreen> {
  final _api = ApiService();
  Shipment? _shipment;
  bool _loading = true;
  String? _error;
  bool _tracking = false;
  Map<String, dynamic>? _trackResult;
  final _dtFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get('${ApiConstants.shipping}/${widget.shipmentId}');
      setState(() { _shipment = Shipment.fromJson(res.data as Map<String, dynamic>); _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed to load shipment'; _loading = false; });
    }
  }

  Future<void> _track() async {
    setState(() { _tracking = true; _trackResult = null; });
    try {
      final res = await _api.get('${ApiConstants.shipping}/${widget.shipmentId}/track');
      setState(() => _trackResult = res.data as Map<String, dynamic>);
      await _load();
    } catch (e) {
      String msg = 'Tracking failed';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data['message'] != null) {
          msg = data['message'] as String;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _tracking = false);
  }

  void _downloadLabel() {
    downloadFile(
      context: context,
      path: '${ApiConstants.shipping}/${widget.shipmentId}/label',
      queryParams: {},
      filename: 'label_${widget.shipmentId.substring(0, 8)}.pdf',
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DELIVERED': return Colors.green;
      case 'EXCEPTION': return Colors.red;
      case 'OUT_FOR_DELIVERY': return Colors.orange;
      case 'IN_TRANSIT': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(
        title: Text(_shipment?.trackingNumber ?? 'Shipment'),
        actions: _shipment == null ? [] : [
          IconButton(
            icon: _tracking
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            tooltip: 'Track',
            onPressed: _tracking ? null : _track,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download Label',
            onPressed: _downloadLabel,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: _buildContent(),
                  ),
                ),
    );
  }

  Widget _buildContent() {
    final s = _shipment!;
    final statusColor = _statusColor(s.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _carrierBadge(s.carrier),
                  const SizedBox(height: 6),
                  Text(s.serviceLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (s.trackingNumber != null)
                    Text(s.trackingNumber!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                s.statusLabel,
                style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Linked invoice
        if (s.billingOrderId != null)
          Card(
            color: const Color(0xFF6A1B9A).withValues(alpha: 0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: const Color(0xFF6A1B9A).withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: Color(0xFF6A1B9A)),
              title: Text('Invoice: ${s.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            ),
          ),
        const SizedBox(height: 12),

        // Key dates + cost
        _card(
          title: 'Shipment Info',
          icon: Icons.info_outline,
          color: const Color(0xFF1565C0),
          child: Column(children: [
            _row('Ship Date', _dtFmt.format(s.shipDate)),
            if (s.estimatedDelivery != null) _row('Est. Delivery', _dtFmt.format(s.estimatedDelivery!)),
            _row('Weight', '${s.weightKg} kg'),
            if (s.lengthCm != null) _row('Dimensions', '${s.lengthCm} × ${s.widthCm} × ${s.heightCm} cm'),
            _row('Declared Value', '\$ ${s.declaredValueUsd.toStringAsFixed(2)}'),
            _row('Contents', s.contentsDescription),
            if (s.quotedCostUsd != null) _row('Shipping Cost', '\$ ${s.quotedCostUsd!.toStringAsFixed(2)}'),
          ]),
        ),
        const SizedBox(height: 12),

        // Recipient
        _card(
          title: 'Recipient',
          icon: Icons.person_pin_circle,
          color: const Color(0xFF2E7D32),
          child: Column(children: [
            _row('Name', s.recipientName),
            _row('Address', s.recipientAddress),
            _row('City / State', '${s.recipientCity}, ${s.recipientState}'),
            _row('Zip / Country', '${s.recipientZip}, ${s.recipientCountry}'),
            _row('Phone', s.recipientPhone),
            _row('Email', s.recipientEmail),
          ]),
        ),
        const SizedBox(height: 12),

        // Tracking events
        if (_trackResult != null) ...[
          _card(
            title: 'Tracking Events',
            icon: Icons.timeline,
            color: const Color(0xFFBF360C),
            child: Column(
              children: [
                _row('Status', (_trackResult!['statusLabel'] as String?) ?? '—'),
                if (_trackResult!['estimatedDelivery'] != null)
                  _row('Est. Delivery', _trackResult!['estimatedDelivery'] as String),
                const Divider(height: 16),
                ...(_trackResult!['events'] as List? ?? []).take(8).map((e) {
                  final event = e as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event['description'] as String? ?? '', style: const TextStyle(fontSize: 13)),
                              Text(
                                '${event['location'] ?? ''}  •  ${event['timestamp'] ?? ''}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Action buttons
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: _tracking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.track_changes),
              label: Text(_tracking ? 'Tracking…' : 'Track Shipment'),
              onPressed: _tracking ? null : _track,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download Label'),
              onPressed: _downloadLabel,
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
            ),
          ),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _carrierBadge(String carrier) {
    final colors = {
      'FEDEX': const Color(0xFF4D148C),
      'DHL': const Color(0xFFD40511),
      'UPS': const Color(0xFF351C15),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors[carrier] ?? Colors.grey,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(carrier, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _card({required String title, required IconData icon, required Color color, required Widget child}) =>
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
              ]),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}
