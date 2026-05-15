import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';
import 'models/hand_delivery.dart';

class HandDeliveryListScreen extends StatefulWidget {
  const HandDeliveryListScreen({super.key});

  @override
  State<HandDeliveryListScreen> createState() => _HandDeliveryListScreenState();
}

class _HandDeliveryListScreenState extends State<HandDeliveryListScreen> {
  final _api = ApiService();
  List<HandDeliveryOrder> _orders = [];
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
      final res = await _api.get(ApiConstants.handDelivery);
      final list = (res.data as List)
          .map((e) => HandDeliveryOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() { _orders = list; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed to load hand delivery orders'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SangemarmarAppBar(
        title: Text('Hand Delivery'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/billing/hand-delivery/new');
          _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _orders.isEmpty
                  ? const Center(child: Text('No hand delivery orders yet', style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _Tile(
                          order: _orders[i],
                          dtFmt: _dtFmt,
                          onTap: () async {
                            await context.push('/billing/hand-delivery/${_orders[i].id}');
                            _load();
                          },
                        ),
                      ),
                    ),
    );
  }
}

class _Tile extends StatelessWidget {
  final HandDeliveryOrder order;
  final DateFormat dtFmt;
  final VoidCallback onTap;
  const _Tile({required this.order, required this.dtFmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping, color: Color(0xFF2E7D32), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(order.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isConfirmed ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isConfirmed ? Colors.green.shade300 : Colors.orange.shade300),
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
                      [order.buyerName, order.buyerCountry ?? '']
                          .where((s) => s.isNotEmpty)
                          .join('  •  '),
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(dtFmt.format(order.orderDate.toLocal()), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹ ${order.totalInr.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2E7D32)),
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
