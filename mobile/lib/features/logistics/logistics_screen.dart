import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';

class LogisticsScreen extends StatefulWidget {
  final String vehicleEntryId;
  const LogisticsScreen({super.key, required this.vehicleEntryId});

  @override
  State<LogisticsScreen> createState() => _LogisticsScreenState();
}

class _LogisticsScreenState extends State<LogisticsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  final _dtFmt = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('${ApiConstants.logistics}/timeline/${widget.vehicleEntryId}');
      setState(() {
        _events = (res.data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    const colors = {
      'ENTERED': Colors.blue,
      'SALES_PENDING': Colors.orange,
      'SALES_COMPLETE': Colors.amber,
      'PAYMENT_PENDING': Colors.purple,
      'PAYMENT_COMPLETE': Colors.teal,
      'COMMISSION_PENDING': Colors.indigo,
      'COMMISSION_COMPLETE': Colors.cyan,
      'COMPLETED': Colors.green,
    };
    return colors[status] ?? Colors.grey;
  }

  String _statusLabel(String status) {
    const labels = {
      'ENTERED': 'Vehicle Entered',
      'SALES_PENDING': 'Sales Pending',
      'SALES_COMPLETE': 'Sales Recorded',
      'PAYMENT_PENDING': 'Payment Pending',
      'PAYMENT_COMPLETE': 'Payment Processed',
      'COMMISSION_PENDING': 'Commission Pending',
      'COMMISSION_COMPLETE': 'Commission Confirmed',
      'COMPLETED': 'Process Complete',
    };
    return labels[status] ?? status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(title: const Text('Logistics Timeline')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text('No events found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (_, i) {
                      final e = _events[i];
                      final status = e['status'] as String;
                      final color = _statusColor(status);
                      final isLast = i == _events.length - 1;
                      final createdAt = DateTime.parse(e['createdAt'] as String).toLocal();
                      final createdBy = e['createdBy'] as Map<String, dynamic>?;

                      return IntrinsicHeight(
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: color,
                                    child: const Icon(Icons.circle, size: 8, color: Colors.white),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(width: 2, color: Colors.grey.shade300),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _dtFmt.format(createdAt),
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                      if (createdBy != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'by ${createdBy['name']}',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                      if (e['notes'] != null) ...[
                                        const SizedBox(height: 6),
                                        Text(e['notes'] as String),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
