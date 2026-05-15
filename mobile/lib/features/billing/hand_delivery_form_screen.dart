import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/uppercase_formatter.dart';
import '../../core/widgets/app_bar.dart';
import 'models/hand_delivery.dart';

// GST is fixed at 5% for now (5% IGST for inter-state, 2.5% CGST + 2.5% SGST
// for local). Per-product rate from the catalog is stored but not used yet.
const double _kFixedGstRate = 5.0;

class _ItemRow {
  String? productId; // null when nothing picked yet
  final TextEditingController particulars = TextEditingController();
  final TextEditingController hsnCode = TextEditingController();
  final TextEditingController size = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController amount = TextEditingController();

  double get amountValue => double.tryParse(amount.text) ?? 0;

  /// Reverse-calc: taxable + GST == amountValue
  double get taxable => amountValue / (1 + _kFixedGstRate / 100);
  double get gstAmount => amountValue - taxable;

  void dispose() {
    particulars.dispose();
    hsnCode.dispose();
    size.dispose();
    quantity.dispose();
    amount.dispose();
  }

  Map<String, dynamic> toJson() => {
        'particulars': particulars.text.trim(),
        if (hsnCode.text.trim().isNotEmpty) 'hsnCode': hsnCode.text.trim(),
        if (size.text.trim().isNotEmpty) 'size': size.text.trim(),
        'quantity': int.parse(quantity.text),
        'amountInr': amountValue,
        'gstRate': _kFixedGstRate,
      };
}

class HandDeliveryFormScreen extends StatefulWidget {
  final String? orderId;
  const HandDeliveryFormScreen({super.key, this.orderId});

  @override
  State<HandDeliveryFormScreen> createState() => _HandDeliveryFormScreenState();
}

class _HandDeliveryFormScreenState extends State<HandDeliveryFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _initializing = false;

  DateTime _orderDate = DateTime.now();
  String _invoiceType = 'INTER_STATE'; // or 'LOCAL'
  final _dtFmt = DateFormat('dd MMM yyyy');

  // Buyer (slim set)
  final _nameCtrl = TextEditingController();
  final _dobPassportCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cellAreaCtrl = TextEditingController();
  final _cellNoCtrl = TextEditingController();

  final List<_ItemRow> _items = [_ItemRow()];

  List<BillingProduct> _products = [];
  bool _productsLoaded = false;

  bool get _isEdit => widget.orderId != null;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (_isEdit) _load();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await _api.get(ApiConstants.billingProducts);
      _products = (res.data as List)
          .map((e) => BillingProduct.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Non-fatal: dropdown just stays empty; user can still "Add a product".
    } finally {
      if (mounted) setState(() => _productsLoaded = true);
    }
  }

  Future<void> _load() async {
    setState(() => _initializing = true);
    try {
      final res = await _api.get('${ApiConstants.handDelivery}/${widget.orderId}');
      final o = res.data as Map<String, dynamic>;
      _orderDate = DateTime.parse(o['orderDate'] as String).toLocal();
      _invoiceType = (o['invoiceType'] as String?) ?? 'INTER_STATE';
      _nameCtrl.text = ((o['buyerName'] as String?) ?? '').toUpperCase();
      _dobPassportCtrl.text = ((o['dobPassport'] as String?) ?? '').toUpperCase();
      _stateCtrl.text = ((o['buyerState'] as String?) ?? '').toUpperCase();
      _countryCtrl.text = ((o['buyerCountry'] as String?) ?? '').toUpperCase();
      _gstinCtrl.text = ((o['gstin'] as String?) ?? '').toUpperCase();
      _emailCtrl.text = (o['buyerEmail'] as String?) ?? '';
      _cellAreaCtrl.text = (o['buyerCellAreaCode'] as String?) ?? '';
      _cellNoCtrl.text = (o['buyerCellNo'] as String?) ?? '';

      _items.clear();
      for (final item in (o['items'] as List)) {
        final row = _ItemRow();
        row.particulars.text = (item['particulars'] as String).toUpperCase();
        row.hsnCode.text = ((item['hsnCode'] as String?) ?? '').toUpperCase();
        row.size.text = ((item['size'] as String?) ?? '').toUpperCase();
        row.quantity.text = item['quantity'].toString();
        row.amount.text = double.parse(item['amountInr'].toString()).toStringAsFixed(2);
        _items.add(row);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobPassportCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    _gstinCtrl.dispose();
    _emailCtrl.dispose();
    _cellAreaCtrl.dispose();
    _cellNoCtrl.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _pickOrderDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _orderDate = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.any((i) =>
        i.particulars.text.trim().isEmpty || i.amount.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete description and amount for every item'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final body = <String, dynamic>{
        'orderDate': _orderDate.toIso8601String(),
        'invoiceType': _invoiceType,
        'buyerName': _nameCtrl.text.trim(),
        if (_dobPassportCtrl.text.trim().isNotEmpty) 'dobPassport': _dobPassportCtrl.text.trim(),
        if (_stateCtrl.text.trim().isNotEmpty) 'buyerState': _stateCtrl.text.trim(),
        if (_countryCtrl.text.trim().isNotEmpty) 'buyerCountry': _countryCtrl.text.trim(),
        if (_gstinCtrl.text.trim().isNotEmpty) 'gstin': _gstinCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty) 'buyerEmail': _emailCtrl.text.trim(),
        if (_cellAreaCtrl.text.trim().isNotEmpty) 'buyerCellAreaCode': _cellAreaCtrl.text.trim(),
        if (_cellNoCtrl.text.trim().isNotEmpty) 'buyerCellNo': _cellNoCtrl.text.trim(),
        'items': _items.map((i) => i.toJson()).toList(),
      };

      if (_isEdit) {
        await _api.patch('${ApiConstants.handDelivery}/${widget.orderId}', data: body);
        if (mounted) context.pop();
      } else {
        final res = await _api.post(ApiConstants.handDelivery, data: body);
        final id = (res.data as Map<String, dynamic>)['id'] as String;
        if (mounted) context.pushReplacement('/billing/hand-delivery/$id');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Totals ──────────────────────────────────────────────────────────────
  double get _totalAmount => _items.fold(0.0, (s, i) => s + i.amountValue);
  double get _totalTaxable => _items.fold(0.0, (s, i) => s + i.taxable);
  double get _totalGst => _items.fold(0.0, (s, i) => s + i.gstAmount);

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: SangemarmarAppBar(
        title: Text(_isEdit ? 'Edit Hand Delivery' : 'New Hand Delivery'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Invoice type toggle ─────────────────────────────────────
            _SectionHeader(
              title: 'Invoice Type',
              icon: Icons.receipt_long,
              color: const Color(0xFF1565C0),
            ),
            const SizedBox(height: 10),
            _invoiceTypeSelector(),
            const SizedBox(height: 24),

            ListTile(
              tileColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              leading: const Icon(Icons.calendar_today, color: Color(0xFF2E7D32)),
              title: const Text('Order Date'),
              subtitle: Text(_dtFmt.format(_orderDate)),
              onTap: _pickOrderDate,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            ),
            const SizedBox(height: 24),

            // ── Buyer's details (slim) ──────────────────────────────────
            _SectionHeader(
              title: "Buyer's Details",
              icon: Icons.person,
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 12),
            _field(_nameCtrl, 'Name', required: true),
            _field(_dobPassportCtrl, 'DOB / Passport No.', required: false),
            Row(children: [
              Expanded(child: _field(_stateCtrl, 'State', required: false)),
              const SizedBox(width: 10),
              Expanded(child: _field(_countryCtrl, 'Country', required: false)),
            ]),
            _field(_gstinCtrl, 'GSTIN', required: false),
            _field(_emailCtrl, 'E-mail', required: false, keyboardType: TextInputType.emailAddress),
            Row(children: [
              Expanded(flex: 2, child: _field(_cellAreaCtrl, 'Area Code', required: false, keyboardType: TextInputType.phone)),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: _field(_cellNoCtrl, 'Cell No.', required: false, keyboardType: TextInputType.phone)),
            ]),
            const SizedBox(height: 24),

            // ── Items ──────────────────────────────────────────────────
            _SectionHeader(title: 'Items', icon: Icons.inventory_2, color: const Color(0xFFBF360C)),
            const SizedBox(height: 12),
            ..._items.asMap().entries.map((e) => _ItemCard(
                  index: e.key,
                  row: e.value,
                  products: _products,
                  productsLoaded: _productsLoaded,
                  canDelete: _items.length > 1,
                  onDelete: () => setState(() => _items.removeAt(e.key)),
                  onChanged: () => setState(() {}),
                  onAddProduct: _addProductFlow,
                )),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              onPressed: () => setState(() => _items.add(_ItemRow())),
            ),
            const SizedBox(height: 16),

            _totalsCard(),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Save Changes' : 'Create Hand Delivery'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _invoiceTypeSelector() {
    Widget option(String value, String label, String sublabel, IconData icon) {
      final selected = _invoiceType == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _invoiceType = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF1565C0).withOpacity(0.08) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? const Color(0xFF1565C0) : Colors.grey.shade300,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: selected ? const Color(0xFF1565C0) : Colors.grey, size: 22),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: selected ? const Color(0xFF1565C0) : Colors.black87)),
                Text(sublabel, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option('INTER_STATE', 'Inter State Invoice', 'IGST 5%', Icons.public),
        const SizedBox(width: 10),
        option('LOCAL', 'Local Invoice', 'CGST 2.5% + SGST 2.5%', Icons.location_city),
      ],
    );
  }

  Widget _totalsCard() {
    final igst = _invoiceType == 'INTER_STATE';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _totalRow('Taxable Value', _totalTaxable),
          if (igst)
            _totalRow('IGST (5%)', _totalGst)
          else ...[
            _totalRow('CGST (2.5%)', _totalGst / 2),
            _totalRow('SGST (2.5%)', _totalGst / 2),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(
                '₹ ${_totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF2E7D32)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            Text('₹ ${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
          ],
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = true,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final isEmail = keyboardType == TextInputType.emailAddress;
    final isPhone = keyboardType == TextInputType.phone;
    final upper = !isEmail && !isPhone;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textCapitalization: upper ? TextCapitalization.characters : TextCapitalization.none,
        inputFormatters: upper ? [UpperCaseTextFormatter()] : null,
        decoration: InputDecoration(labelText: label),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      ),
    );
  }

  // ── Add Product dialog ─────────────────────────────────────────────────
  Future<BillingProduct?> _addProductFlow() async {
    final descCtrl = TextEditingController();
    final hsnCtrl = TextEditingController();
    final gstCtrl = TextEditingController(text: '5');

    final result = await showDialog<BillingProduct>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                ),
                TextField(
                  controller: hsnCtrl,
                  decoration: const InputDecoration(labelText: 'HSN Code'),
                ),
                TextField(
                  controller: gstCtrl,
                  decoration: const InputDecoration(labelText: 'GST Rate (%)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (descCtrl.text.trim().isEmpty) return;
                try {
                  final res = await _api.post(ApiConstants.billingProducts, data: {
                    'description': descCtrl.text.trim(),
                    if (hsnCtrl.text.trim().isNotEmpty) 'hsnCode': hsnCtrl.text.trim(),
                    'gstRate': double.tryParse(gstCtrl.text.trim()) ?? 5,
                  });
                  final p = BillingProduct.fromJson(res.data as Map<String, dynamic>);
                  if (ctx.mounted) Navigator.pop(ctx, p);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        // Insert in sorted-by-description order to match server-side ordering.
        _products.add(result);
        _products.sort((a, b) => a.description.compareTo(b.description));
      });
    }
    return result;
  }
}

class _ItemCard extends StatelessWidget {
  final int index;
  final _ItemRow row;
  final List<BillingProduct> products;
  final bool productsLoaded;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final Future<BillingProduct?> Function() onAddProduct;

  const _ItemCard({
    required this.index,
    required this.row,
    required this.products,
    required this.productsLoaded,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
    required this.onAddProduct,
  });

  void _applyProduct(BillingProduct p) {
    row.productId = p.id;
    row.particulars.text = p.description.toUpperCase();
    row.hsnCode.text = (p.hsnCode ?? '').toUpperCase();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
            ]),
            // ── Product picker (dropdown) ──────────────────────────────
            DropdownButtonFormField<String>(
              value: products.any((p) => p.id == row.productId) ? row.productId : null,
              decoration: const InputDecoration(labelText: 'Description / Particulars'),
              isExpanded: true,
              hint: Text(productsLoaded ? 'Pick a product…' : 'Loading…'),
              items: [
                ...products.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.description, overflow: TextOverflow.ellipsis),
                    )),
                const DropdownMenuItem<String>(
                  value: '__add__',
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: Color(0xFF1B5E20)),
                      SizedBox(width: 6),
                      Text('Add a product', style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              onChanged: (v) async {
                if (v == '__add__') {
                  final newProd = await onAddProduct();
                  if (newProd != null) _applyProduct(newProd);
                  return;
                }
                if (v == null) return;
                final p = products.firstWhere((p) => p.id == v);
                _applyProduct(p);
              },
            ),
            const SizedBox(height: 10),
            // Particulars: also editable for tweaks/overrides; pre-filled from product.
            TextFormField(
              controller: row.particulars,
              decoration: const InputDecoration(labelText: 'Particulars (editable)'),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              onChanged: (_) => onChanged(),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: row.hsnCode,
                  decoration: const InputDecoration(labelText: 'HSN Code'),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: row.size,
                  decoration: const InputDecoration(labelText: 'Size'),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  onChanged: (_) => onChanged(),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: row.quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  onChanged: (_) => onChanged(),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return (n == null || n < 1) ? 'Min 1' : null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: row.amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (incl. GST)', prefixText: '₹ '),
                  onChanged: (_) => onChanged(),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return (n == null || n <= 0) ? 'Required' : null;
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            // Reverse-calc breakdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _kv('Taxable', '₹ ${row.taxable.toStringAsFixed(2)}'),
                  ),
                  Expanded(
                    child: _kv('GST ($_kFixedGstRate%)', '₹ ${row.gstAmount.toStringAsFixed(2)}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      ],
    );
  }
}
