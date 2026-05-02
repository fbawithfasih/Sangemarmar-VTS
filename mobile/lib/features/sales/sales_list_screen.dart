import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/sale.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  final _api = ApiService();
  List<Sale> _sales = [];
  bool _loading = true;
  String? _error;
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get(ApiConstants.sales);
      final list = (res.data as List).map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList();
      setState(() { _sales = list; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed to load sales'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(title: const Text('Sales')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _sales.isEmpty
                  ? const Center(child: Text('No sales found'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _sales.length,
                        itemBuilder: (_, i) {
                          final s = _sales[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE8F5E9),
                                child: Icon(Icons.receipt, color: Color(0xFF2E7D32)),
                              ),
                              title: Text(
                                s.vehicleEntry?.vehicleNumber ?? s.vehicleEntryId.substring(0, 8),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (s.vehicleEntry != null)
                                    Text(
                                      'Driver: ${s.vehicleEntry!.driverName}  •  Guide: ${s.vehicleEntry!.guideName}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  Text(
                                    '${s.salesperson} • ${DateFormat('dd MMM yyyy').format(s.saleDate)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                'Net: ${_fmt.format(s.netSale)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    children: [
                                      _row('Gross Sale', _fmt.format(s.grossSale)),
                                      _row('Net Sale', _fmt.format(s.netSale)),
                                      _row('Order Type', s.orderType.replaceAll('_', ' ')),
                                      if (s.notes != null) _row('Notes', s.notes!),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              icon: const Icon(Icons.payment, size: 16),
                                              label: const Text('Payments'),
                                              onPressed: () => context.push('/sales/${s.id}/payments'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              icon: const Icon(Icons.percent, size: 16),
                                              label: const Text('Commissions'),
                                              onPressed: () => context.push('/sales/${s.id}/commissions'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text('Edit Sale'),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size.fromHeight(36),
                                        ),
                                        onPressed: () =>
                                            context.push('/sales/${s.id}/edit').then((_) => _load()),
                                      ),
                                    ],
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

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
      );
}
