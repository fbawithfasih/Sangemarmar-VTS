import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/sale.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/uppercase_formatter.dart';
import '../../core/widgets/app_bar.dart';

class SaleEditScreen extends StatefulWidget {
  final String saleId;
  const SaleEditScreen({super.key, required this.saleId});

  @override
  State<SaleEditScreen> createState() => _SaleEditScreenState();
}

class _SaleEditScreenState extends State<SaleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  Sale? _sale;
  final _grossCtrl = TextEditingController();
  final _netCtrl = TextEditingController();
  final _salespersonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _orderType = 'ORDER';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _grossCtrl.dispose();
    _netCtrl.dispose();
    _salespersonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('${ApiConstants.sales}/${widget.saleId}');
      final sale = Sale.fromJson(res.data as Map<String, dynamic>);
      setState(() {
        _sale = sale;
        _grossCtrl.text = sale.grossSale.toStringAsFixed(2);
        _netCtrl.text = sale.netSale.toStringAsFixed(2);
        _salespersonCtrl.text = sale.salesperson;
        _notesCtrl.text = sale.notes ?? '';
        _orderType = sale.orderType;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    try {
      await _api.patch('${ApiConstants.sales}/${widget.saleId}', data: {
        'grossSale': double.parse(_grossCtrl.text),
        'netSale': double.parse(_netCtrl.text),
        'salesperson': _salespersonCtrl.text.trim(),
        'orderType': _orderType,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale updated'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (_) {
      setState(() { _error = 'Failed to update sale.'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(title: const Text('Edit Sale')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_sale?.vehicleEntry != null)
                      Card(
                        color: Colors.grey.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Vehicle: ${_sale!.vehicleEntry!.vehicleNumber}  '
                            '· ${_sale!.vehicleEntry!.driverName}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _grossCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Gross Sale',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || double.tryParse(v) == null ? 'Enter valid amount' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _netCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Net Sale',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || double.tryParse(v) == null ? 'Enter valid amount' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _salespersonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Salesperson',
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _orderType,
                      decoration: const InputDecoration(
                        labelText: 'Order Type',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ORDER', child: Text('Order')),
                        DropdownMenuItem(value: 'HAND_DELIVERY', child: Text('Hand Delivery')),
                      ],
                      onChanged: (v) => setState(() => _orderType = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
