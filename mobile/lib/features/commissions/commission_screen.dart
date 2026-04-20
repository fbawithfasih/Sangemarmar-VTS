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

  final Map<String, TextEditingController> _rateCtrl = {};
  final Map<String, bool> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _rateCtrl.values) {
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
        if (!_rateCtrl.containsKey(c.id)) {
          _rateCtrl[c.id] = TextEditingController(text: c.rate.toStringAsFixed(2));
        } else {
          _rateCtrl[c.id]!.text = c.rate.toStringAsFixed(2);
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

  double _calcAmount(String commissionId) {
    final netSale = _sale?.netSale ?? 0;
    final rate = double.tryParse(_rateCtrl[commissionId]?.text ?? '') ?? 0;
    return (netSale * rate) / 100;
  }

  Future<void> _save(Commission commission) async {
    final rate = double.tryParse(_rateCtrl[commission.id]?.text ?? '');
    if (rate == null || rate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid percentage')),
      );
      return;
    }

    final netSale = _sale?.netSale ?? 0;
    final finalAmount =
        double.parse(((netSale * rate) / 100).toStringAsFixed(2));

    setState(() => _saving[commission.id] = true);
    try {
      await _api.patch('${ApiConstants.commissions}/${commission.id}/override',
          data: {
            'rate': rate,
            'finalAmount': finalAmount,
            'overrideReason': 'Rate adjusted to $rate%',
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${commission.recipientLabel} commission updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to save';
        try {
          final response = (e as dynamic).response;
          final data = response?.data;
          if (data is Map) msg = data['message']?.toString() ?? msg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red, duration: const Duration(seconds: 6)),
        );
      }
    }
    if (mounted) setState(() => _saving[commission.id] = false);
  }

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
                        child: Text(
                          'Net Sale: ${_fmt.format(_sale!.netSale)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                            fontSize: 14,
                          ),
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
                            rateCtrl: _rateCtrl[c.id]!,
                            saving: _saving[c.id] ?? false,
                            canEdit: canEdit,
                            fmt: _fmt,
                            calcAmount: _calcAmount,
                            onSave: () => _save(c),
                            onRateChanged: () => setState(() {}),
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
  final TextEditingController rateCtrl;
  final bool saving;
  final bool canEdit;
  final NumberFormat fmt;
  final double Function(String) calcAmount;
  final VoidCallback onSave;
  final VoidCallback onRateChanged;

  const _CommissionCard({
    required this.commission,
    required this.rateCtrl,
    required this.saving,
    required this.canEdit,
    required this.fmt,
    required this.calcAmount,
    required this.onSave,
    required this.onRateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final liveAmount = calcAmount(commission.id);
    final currentRate = double.tryParse(rateCtrl.text) ?? commission.rate;
    final rateChanged = currentRate != commission.rate;

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
                    Text(commission.recipientName,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                if (commission.isOverridden)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      'ADJUSTED',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Commission %',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      canEdit
                          ? TextField(
                              controller: rateCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (_) => onRateChanged(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 20),
                              decoration: InputDecoration(
                                suffixText: '%',
                                suffixStyle: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 16),
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
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text('${commission.rate}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                            ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: rateChanged
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: rateChanged
                            ? Colors.orange.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rateChanged ? 'New Amount' : 'Commission Amount',
                          style: TextStyle(
                            fontSize: 11,
                            color: rateChanged
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmt.format(liveAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: rateChanged
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (commission.isOverridden && commission.overrideReason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Note: ${commission.overrideReason}',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
              ),
            ],

            if (canEdit && rateChanged) ...[
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
                  label: Text(saving ? 'Saving…' : 'Apply ${rateCtrl.text}%'),
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
