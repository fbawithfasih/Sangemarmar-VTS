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

  final Map<String, bool> _saving = {};
  final Map<String, bool> _paying = {};

  @override
  void initState() {
    super.initState();
    _load();
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
        _saving[c.id] = false;
        _paying[c.id] = false;
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

  Future<void> _save(Commission commission, double amount) async {
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

  Future<void> _recordPayment(Commission commission, double paidAmount, DateTime paidAt) async {
    setState(() => _paying[commission.id] = true);
    try {
      await _api.patch(
        '${ApiConstants.commissions}/${commission.id}/pay',
        data: {
          'paidAmount': paidAmount,
          'paidAt': paidAt.toIso8601String().split('T').first,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment recorded for ${commission.recipientLabel}'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to record payment';
        try {
          final data = (e as dynamic).response?.data;
          if (data is Map) msg = data['message']?.toString() ?? msg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(msg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6)),
        );
      }
    }
    if (mounted) setState(() => _paying[commission.id] = false);
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
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.07),
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
                            key: ValueKey(c.id),
                            commission: c,
                            netSale: _sale?.netSale ?? 0,
                            saving: _saving[c.id] ?? false,
                            paying: _paying[c.id] ?? false,
                            canEdit: canEdit,
                            fmt: _fmt,
                            onSave: (amount) => _save(c, amount),
                            onPay: (amount, date) => _recordPayment(c, amount, date),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _CommissionCard extends StatefulWidget {
  final Commission commission;
  final double netSale;
  final bool saving;
  final bool paying;
  final bool canEdit;
  final NumberFormat fmt;
  final void Function(double amount) onSave;
  final void Function(double amount, DateTime date) onPay;

  const _CommissionCard({
    super.key,
    required this.commission,
    required this.netSale,
    required this.saving,
    required this.paying,
    required this.canEdit,
    required this.fmt,
    required this.onSave,
    required this.onPay,
  });

  @override
  State<_CommissionCard> createState() => _CommissionCardState();
}

class _CommissionCardState extends State<_CommissionCard> {
  late final TextEditingController _pctCtrl;
  late final TextEditingController _paidAmountCtrl;
  DateTime _paidAt = DateTime.now();
  final _dateFmt = DateFormat('dd MMM yyyy');

  double get _calculatedAmount {
    final pct = double.tryParse(_pctCtrl.text) ?? 0;
    return (pct / 100) * widget.netSale;
  }

  double get _paidAmountValue =>
      double.tryParse(_paidAmountCtrl.text) ?? 0;

  bool get _paidAmountExceedsCap =>
      _paidAmountValue > widget.commission.finalAmount;

  @override
  void initState() {
    super.initState();
    _pctCtrl = TextEditingController();
    _pctCtrl.addListener(() => setState(() {}));
    _paidAmountCtrl = TextEditingController();
    _paidAmountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pctCtrl.dispose();
    _paidAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _paidAt = picked);
  }

  void _submitPayment() {
    final amount = _paidAmountValue;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payment amount')),
      );
      return;
    }
    if (_paidAmountExceedsCap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount exceeds commission of ${widget.fmt.format(widget.commission.finalAmount)}',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    widget.onPay(amount, _paidAt);
  }

  @override
  Widget build(BuildContext context) {
    final amount = _calculatedAmount;
    final c = widget.commission;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.recipientLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(c.recipientName,
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    if (c.isPaid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Text(
                          'PAID',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (c.isPaid) const SizedBox(width: 6),
                    if (c.isOverridden)
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
              ],
            ),
            const SizedBox(height: 14),

            // ── Commission % input section ──────────────────────────
            if (widget.canEdit) ...[
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _pctCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20),
                      decoration: InputDecoration(
                        labelText: '% of Net Sale',
                        suffixText: '%',
                        suffixStyle: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF3D5216), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: amount > 0
                            ? const Color(0xFF1B5E20).withValues(alpha: 0.07)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: amount > 0
                              ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Commission Amount',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text(
                            amount > 0 ? widget.fmt.format(amount) : '₹ —',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: amount > 0
                                  ? const Color(0xFF1B5E20)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (widget.saving || amount <= 0)
                      ? null
                      : () => widget.onSave(amount),
                  icon: widget.saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(widget.saving ? 'Saving…' : 'Save Amount'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5216),
                    minimumSize: const Size(0, 42),
                  ),
                ),
              ),
            ] else
              Container(
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
                      widget.fmt.format(c.finalAmount),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green.shade800),
                    ),
                  ],
                ),
              ),

            // ── Payment section (only when finalAmount is set) ──────
            if (c.isOverridden && c.finalAmount > 0) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Existing payment info
              if (c.isPaid) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payments, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Paid: ${widget.fmt.format(c.paidAmount!)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                    fontSize: 14)),
                            Text('on ${_dateFmt.format(c.paidAt!)}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.blue.shade600)),
                          ],
                        ),
                      ),
                      Text(
                        c.paidAmount! < c.finalAmount
                            ? 'Partial'
                            : 'Full',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: c.paidAmount! < c.finalAmount
                                ? Colors.orange.shade700
                                : Colors.blue.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text('Update payment',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
              ] else ...[
                Text('Record Payment',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 8),
              ],

              // Amount + Date inputs
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _paidAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Amount Paid',
                        prefixText: '₹ ',
                        errorText: _paidAmountExceedsCap
                            ? 'Exceeds ₹${c.finalAmount.toStringAsFixed(2)}'
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _paidAmountExceedsCap
                                ? Colors.orange
                                : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _paidAmountExceedsCap
                                ? Colors.orange
                                : const Color(0xFF1565C0),
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _paidAmountExceedsCap
                                ? Colors.orange
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 11),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payment Date',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey.shade600)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 13, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  _dateFmt.format(_paidAt),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.paying ? null : _submitPayment,
                  icon: widget.paying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.payments, size: 18),
                  label: Text(widget.paying ? 'Saving…' : 'Record Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
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
