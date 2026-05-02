import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/vehicle_entry.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/uppercase_formatter.dart';
import '../../core/widgets/app_bar.dart';

class SalesFormScreen extends StatefulWidget {
  final String? vehicleEntryId;
  const SalesFormScreen({super.key, this.vehicleEntryId});

  @override
  State<SalesFormScreen> createState() => _SalesFormScreenState();
}

class _SalesFormScreenState extends State<SalesFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  VehicleEntry? _vehicleEntry;
  final _grossSaleCtrl = TextEditingController();
  final _netSaleCtrl = TextEditingController();
  final _salespersonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _orderType = 'ORDER';
  bool _loading = false;
  bool _loadingEntry = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.vehicleEntryId != null) _loadEntry();
  }

  Future<void> _loadEntry() async {
    setState(() => _loadingEntry = true);
    try {
      final res = await _api.get('${ApiConstants.vehicles}/${widget.vehicleEntryId}');
      setState(() {
        _vehicleEntry = VehicleEntry.fromJson(res.data as Map<String, dynamic>);
        _loadingEntry = false;
      });
    } catch (_) {
      setState(() => _loadingEntry = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final res = await _api.post(ApiConstants.sales, data: {
        'vehicleEntryId': widget.vehicleEntryId,
        'grossSale': double.parse(_grossSaleCtrl.text),
        'netSale': double.parse(_netSaleCtrl.text),
        'salesperson': _salespersonCtrl.text.trim(),
        'orderType': _orderType,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });

      final saleId = res.data['id'] as String;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale created successfully'), backgroundColor: Colors.green),
        );
        context.pushReplacement('/sales/$saleId/payments');
      }
    } catch (e) {
      setState(() { _error = 'Failed to create sale. Check all fields.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(title: const Text('New Sale')),
      body: _loadingEntry
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_vehicleEntry != null) ...[
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Vehicle Details', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                              const SizedBox(height: 8),
                              _infoRow('Vehicle', _vehicleEntry!.vehicleNumber),
                              _infoRow('Driver', _vehicleEntry!.driverName),
                              _infoRow('Guide', _vehicleEntry!.guideName),
                              _infoRow('Local Agent', _vehicleEntry!.localAgent),
                              _infoRow('Company', _vehicleEntry!.companyName),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _grossSaleCtrl,
                      decoration: const InputDecoration(labelText: 'Gross Sale', prefixIcon: Icon(Icons.currency_rupee)),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || double.tryParse(v) == null ? 'Enter valid amount' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _netSaleCtrl,
                      decoration: const InputDecoration(labelText: 'Net Sale', prefixIcon: Icon(Icons.currency_rupee)),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || double.tryParse(v) == null ? 'Enter valid amount' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _salespersonCtrl,
                      decoration: const InputDecoration(labelText: 'Salesperson', prefixIcon: Icon(Icons.person)),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _orderType,
                      decoration: const InputDecoration(labelText: 'Order Type', prefixIcon: Icon(Icons.category)),
                      items: const [
                        DropdownMenuItem(value: 'ORDER', child: Text('Order')),
                        DropdownMenuItem(value: 'HAND_DELIVERY', child: Text('Hand Delivery')),
                      ],
                      onChanged: (v) => setState(() => _orderType = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.notes)),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Sale & Proceed to Payment'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 12))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
      );
}
