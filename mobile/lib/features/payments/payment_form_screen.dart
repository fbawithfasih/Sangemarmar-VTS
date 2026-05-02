import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/payment.dart';
import '../../core/models/sale.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/uppercase_formatter.dart';
import '../../core/widgets/app_bar.dart';

class PaymentFormScreen extends StatefulWidget {
  final String saleId;
  const PaymentFormScreen({super.key, required this.saleId});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _api = ApiService();
  Sale? _sale;
  List<Payment> _payments = [];
  double _total = 0;
  bool _loading = true;
  bool _submitting = false;

  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _mode = 'CC';
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final saleRes = await _api.get('${ApiConstants.sales}/${widget.saleId}');
      _sale = Sale.fromJson(saleRes.data as Map<String, dynamic>);

      final payRes = await _api.get('${ApiConstants.payments}/sale/${widget.saleId}');
      final data = payRes.data as Map<String, dynamic>;
      _payments = (data['payments'] as List)
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList();
      _total = double.parse(data['total'].toString());
    } catch (_) {}
    setState(() => _loading = false);
  }

  double get _remaining => (_sale?.grossSale ?? 0) - _total;
  bool get _isFullyPaid => _remaining <= 0;

  Future<void> _addPayment() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    if (amount > _remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Amount exceeds remaining balance of ${_fmt.format(_remaining)}')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _api.post(ApiConstants.payments, data: {
        'saleId': widget.saleId,
        'mode': _mode,
        'amount': amount,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });

      _amountCtrl.clear();
      _notesCtrl.clear();
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to record payment'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(title: const Text('Payment Processing')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_sale != null)
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sale Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _row('Gross Sale', _fmt.format(_sale!.grossSale)),
                            _row('Net Sale', _fmt.format(_sale!.netSale)),
                            _row('Salesperson', _sale!.salesperson),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _isFullyPaid ? 'FULLY PAID' : 'Remaining',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isFullyPaid ? Colors.green.shade700 : Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  _isFullyPaid ? '✓ ₹0.00' : _fmt.format(_remaining),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isFullyPaid ? Colors.green.shade700 : Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Payments Received', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('Total: ${_fmt.format(_total)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                            ],
                          ),
                          const Divider(),
                          if (_payments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No payments yet', style: TextStyle(color: Colors.grey)),
                            )
                          else
                            ..._payments.map((p) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.teal.shade200),
                                        ),
                                        child: Text(p.mode,
                                            style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(_fmt.format(p.amount), style: const TextStyle(fontWeight: FontWeight.w500))),
                                      Text(
                                        '${p.paymentDate.day}/${p.paymentDate.month}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isFullyPaid)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Payment Complete — Gross Sale Fully Collected',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Add Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  'Remaining: ${_fmt.format(_remaining)}',
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _mode,
                              decoration: const InputDecoration(labelText: 'Payment Mode'),
                              items: const [
                                DropdownMenuItem(value: 'CC', child: Text('CC — Credit Card')),
                                DropdownMenuItem(value: 'IC', child: Text('IC — Indian Currency (₹)')),
                                DropdownMenuItem(value: 'FC', child: Text('FC — Foreign Currency (₹)')),
                              ],
                              onChanged: (v) => setState(() => _mode = v!),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _amountCtrl,
                              decoration: InputDecoration(
                                labelText: 'Amount (max ${_fmt.format(_remaining)})',
                                prefixIcon: const Icon(Icons.currency_rupee),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notesCtrl,
                              decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.notes)),
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [UpperCaseTextFormatter()],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _submitting ? null : _addPayment,
                              icon: const Icon(Icons.add),
                              label: _submitting
                                  ? const Text('Adding...')
                                  : const Text('+ Add Payment'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.percent),
                    label: const Text('View Commissions'),
                    onPressed: () => context.push('/sales/${widget.saleId}/commissions'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 12))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
