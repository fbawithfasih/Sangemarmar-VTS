import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/commission.dart';
import '../../core/models/sale.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';

class CommissionScreen extends StatefulWidget {
  final String saleId;
  const CommissionScreen({super.key, required this.saleId});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  final _api = ApiService();
  List<Commission> _commissions = [];
  Sale? _sale;
  bool _loading = true;
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  final Map<String, TextEditingController> _amountCtrl = {};
  final Map<String, bool> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _amountCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.get('${ApiConstants.sales}/${widget.saleId}'),
        _api.get('${ApiConstants.commissions}/sale/${widget.saleId}'),
      ]);

      final sale = Sale.fromJson(results[0].data as Map<String, dynamic>);
      final commissions = (results[1].data as List)
          .map((e) => Commission.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final c in commissions) {
        if (!_amountCtrl.containsKey(c.id)) {
          _amountCtrl[c.id] = TextEditingController(
            text: c.finalAmount > 0 ? c.finalAmount.toStringAsFixed(2) : '',
          );
        } else {
          _amountCtrl[c.id]!.text =
              c.finalAmount > 0 ? c.finalAmount.toStringAsFixed(2) : '';
        }
        _saving[c.id] = false;
      }

      setState(() {
        _sale = sale;
        _commissions = commissions;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save(Commission commission) async {
    final amount = double.tryParse(_amountCtrl[commission.id]?.text ?? '');
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    setState(() => _saving[commission.id] = true);
    try {
      await _api.patch(
        '${ApiConstants.commissions}/${commission.id}/override',
        data: {'finalAmount': amount},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${commission.recipientLabel} commission saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to save';
        try {
          final data = (e as dynamic).response?.data;
          if (data is Map) msg = data['message']?.toString() ?? msg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $msg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6)),
        );
      }
    }
    if (mounted) setState(() => _saving[commission.id] = false);
  }

  double get _totalCommission =>
      _commissions.fold(0, (sum, c) => sum + c.finalAmount);

  @override
  Widget build(BuildContext context) {
    final canEdit =
        context.watch<AuthProvider>().user?.canOverrideCommissions ?? false;

    return Scaffold(
      appBar: SangemarmarAppBar(title: const Text('Commissions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _commissions.isEmpty
              ? const Center(child: Text('No commissions found'))
              : Column(
                  children: [
                    if (_sale != null)
                      Container(
                        width: double.infinity,
                        color: const Color(0xFF1B5E20).withOpacity(0.07),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Net Sale: ${_fmt.format(_sale!.netSale)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Total Commission: ${_fmt.format(_totalCommission)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _commissions.length,
                        itemBuilder: (_, i) {
                          final c = _commissions[i];
                          return _CommissionCard(
                            commission: c,
                            amountCtrl: _amountCtrl[c.id]!,
                            saving: _saving[c.id] ?? false,
                            canEdit: canEdit,
                            fmt: _fmt,
                            onSave: () => _save(c),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  final Commission commission;
  final TextEditingController amountCtrl;
  final bool saving;
  final bool canEdit;
  final NumberFormat fmt;
  final VoidCallback onSave;

  const _CommissionCard({
    required this.commission,
    required this.amountCtrl,
    required this.saving,
    required this.canEdit,
    required this.fmt,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commission.recipientLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      commission.recipientName,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                if (commission.isOverridden)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      'SAVED',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            canEdit
                ? TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20),
                    decoration: InputDecoration(
                      labelText: 'Commission Amount',
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF3D5216), width: 2),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.currency_rupee,
                            size: 18, color: Colors.green.shade700),
                        Text(
                          fmt.format(commission.finalAmount),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  ),
            if (canEdit) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(saving ? 'Saving…' : 'Save Amount'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5216),
                    minimumSize: const Size(0, 42),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
