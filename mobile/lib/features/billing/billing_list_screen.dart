import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/download_helper.dart';
import '../../core/widgets/app_bar.dart';
import 'models/billing_order.dart';

class BillingListScreen extends StatefulWidget {
  const BillingListScreen({super.key});

  @override
  State<BillingListScreen> createState() => _BillingListScreenState();
}

class _BillingListScreenState extends State<BillingListScreen> {
  final _api = ApiService();
  List<BillingOrder> _orders = [];
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
      final res = await _api.get(ApiConstants.billing);
      final list = (res.data as List)
          .map((e) => BillingOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() { _orders = list; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed to load billing orders'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(
        title: const Text('Billing Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export list',
            onPressed: () => showDownloadSheet(
              context: context,
              path: ApiConstants.billingExport,
              queryParams: {},
              baseFilename: 'billing_orders',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/billing/new');
          _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _orders.isEmpty
                  ? const Center(child: Text('No billing orders yet', style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _OrderTile(
                          order: _orders[i],
                          dtFmt: _dtFmt,
                          onTap: () async {
                            await context.push('/billing/${_orders[i].id}');
                            _load();
                          },
                        ),
                      ),
                    ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final BillingOrder order;
  final DateFormat dtFmt;
  final VoidCallback onTap;
  const _OrderTile({required this.order, required this.dtFmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final vehicleNo = order.vehicleEntry?['vehicleNumber'] as String? ?? '—';
    final isConfirmed = order.status == 'CONFIRMED';

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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, color: Color(0xFF6A1B9A), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isConfirmed ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isConfirmed ? Colors.green.shade300 : Colors.orange.shade300,
                            ),
                          ),
                          child: Text(
                            order.status,
                            style: TextStyle(
                              fontSize: 10,
                              color: isConfirmed ? Colors.green.shade700 : Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order.buyerName}  •  ${order.buyerCountry}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Vehicle: $vehicleNo  •  ${dtFmt.format(order.orderDate.toLocal())}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$ ${order.totalUsd.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF6A1B9A)),
                  ),
                  Text(
                    '${order.items.length} item${order.items.length != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
