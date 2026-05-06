import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/uppercase_formatter.dart';
import '../../core/widgets/app_bar.dart';

class _ItemRow {
  final TextEditingController particulars = TextEditingController();
  final TextEditingController hsnCode = TextEditingController();
  final TextEditingController size = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController priceInr = TextEditingController();

  double get amount {
    final qty = int.tryParse(quantity.text) ?? 0;
    final price = double.tryParse(priceInr.text) ?? 0;
    return qty * price;
  }

  void dispose() {
    particulars.dispose();
    hsnCode.dispose();
    size.dispose();
    quantity.dispose();
    priceInr.dispose();
  }

  Map<String, dynamic> toJson() => {
        'particulars': particulars.text.trim(),
        if (hsnCode.text.trim().isNotEmpty) 'hsnCode': hsnCode.text.trim(),
        if (size.text.trim().isNotEmpty) 'size': size.text.trim(),
        'quantity': int.parse(quantity.text),
        'priceInr': double.parse(priceInr.text),
      };
}

class BillingFormScreen extends StatefulWidget {
  final String? orderId;
  const BillingFormScreen({super.key, this.orderId});

  @override
  State<BillingFormScreen> createState() => _BillingFormScreenState();
}

class _BillingFormScreenState extends State<BillingFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _initializing = true;

  DateTime _orderDate = DateTime.now();
  DateTime? _buyerDOB;
  final _dtFmt = DateFormat('dd MMM yyyy');

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _whatsAppCtrl = TextEditingController();
  final _cellAreaCtrl = TextEditingController();
  final _cellNoCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _seaPortCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final List<_ItemRow> _items = [_ItemRow()];

  bool get _isEdit => widget.orderId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (_isEdit) {
        final orderRes = await _api.get('${ApiConstants.billing}/${widget.orderId}');
        final o = orderRes.data as Map<String, dynamic>;
        _orderDate = DateTime.parse(o['orderDate'] as String).toLocal();
        _nameCtrl.text = (o['buyerName'] as String).toUpperCase();
        _addressCtrl.text = (o['buyerAddress'] as String).toUpperCase();
        _cityCtrl.text = (o['buyerCity'] as String).toUpperCase();
        _stateCtrl.text = (o['buyerState'] as String).toUpperCase();
        _zipCtrl.text = (o['buyerZip'] as String).toUpperCase();
        _countryCtrl.text = (o['buyerCountry'] as String).toUpperCase();
        _emailCtrl.text = o['buyerEmail'] as String;
        _whatsAppCtrl.text = o['buyerWhatsApp'] as String;
        _cellAreaCtrl.text = (o['buyerCellAreaCode'] as String?) ?? '';
        _cellNoCtrl.text = (o['buyerCellNo'] as String?) ?? '';
        _passportCtrl.text = (o['buyerPassportNo'] as String).toUpperCase();
        _nationalityCtrl.text = (o['buyerNationality'] as String).toUpperCase();
        _seaPortCtrl.text = ((o['buyerSeaPort'] as String?) ?? '').toUpperCase();
        _notesCtrl.text = ((o['notes'] as String?) ?? '').toUpperCase();
        if (o['buyerDOB'] != null) _buyerDOB = DateTime.parse(o['buyerDOB'] as String);

        _items.clear();
        for (final item in (o['items'] as List)) {
          final row = _ItemRow();
          row.particulars.text = (item['particulars'] as String).toUpperCase();
          row.hsnCode.text = ((item['hsnCode'] as String?) ?? '').toUpperCase();
          row.size.text = ((item['size'] as String?) ?? '').toUpperCase();
          row.quantity.text = item['quantity'].toString();
          row.priceInr.text = double.parse(item['priceInr'].toString()).toStringAsFixed(2);
          _items.add(row);
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _addressCtrl.dispose(); _cityCtrl.dispose();
    _stateCtrl.dispose(); _zipCtrl.dispose(); _countryCtrl.dispose();
    _emailCtrl.dispose(); _whatsAppCtrl.dispose();
    _cellAreaCtrl.dispose(); _cellNoCtrl.dispose();
    _passportCtrl.dispose(); _nationalityCtrl.dispose();
    _seaPortCtrl.dispose(); _notesCtrl.dispose();
    for (final i in _items) { i.dispose(); }
    super.dispose();
  }

  Future<void> _pickOrderDate() async {
    final d = await showDatePicker(
      context: context, initialDate: _orderDate,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _orderDate = d);
  }

  Future<void> _pickDOB() async {
    final d = await showDatePicker(
      context: context, initialDate: _buyerDOB ?? DateTime(1990),
      firstDate: DateTime(1920), lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _buyerDOB = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.any((i) => i.particulars.text.trim().isEmpty || i.priceInr.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all item fields'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final body = {
        'orderDate': _orderDate.toIso8601String(),
        'buyerName': _nameCtrl.text.trim(),
        'buyerAddress': _addressCtrl.text.trim(),
        'buyerCity': _cityCtrl.text.trim(),
        'buyerState': _stateCtrl.text.trim(),
        'buyerZip': _zipCtrl.text.trim(),
        'buyerCountry': _countryCtrl.text.trim(),
        'buyerEmail': _emailCtrl.text.trim(),
        'buyerWhatsApp': _whatsAppCtrl.text.trim(),
        if (_cellAreaCtrl.text.trim().isNotEmpty) 'buyerCellAreaCode': _cellAreaCtrl.text.trim(),
        if (_cellNoCtrl.text.trim().isNotEmpty) 'buyerCellNo': _cellNoCtrl.text.trim(),
        'buyerPassportNo': _passportCtrl.text.trim(),
        if (_buyerDOB != null) 'buyerDOB': _buyerDOB!.toIso8601String().split('T').first,
        'buyerNationality': _nationalityCtrl.text.trim(),
        'buyerSeaPort': _seaPortCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'items': _items.map((i) => i.toJson()).toList(),
      };

      if (_isEdit) {
        await _api.patch('${ApiConstants.billing}/${widget.orderId}', data: body);
        if (mounted) context.pop();
      } else {
        final res = await _api.post(ApiConstants.billing, data: body);
        final id = (res.data as Map<String, dynamic>)['id'] as String;
        if (mounted) context.pushReplacement('/billing/$id');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save order: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: SangemarmarAppBar(
        title: Text(_isEdit ? 'Edit Order' : 'New Billing Order'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              tileColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              leading: const Icon(Icons.calendar_today, color: Color(0xFF6A1B9A)),
              title: const Text('Order Date'),
              subtitle: Text(_dtFmt.format(_orderDate)),
              onTap: _pickOrderDate,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            ),
            const SizedBox(height: 24),

            _SectionHeader(title: "Buyer's Details", icon: Icons.person, color: const Color(0xFF2E7D32)),
            const SizedBox(height: 12),
            _field(_nameCtrl, 'Full Name (Mr/Mrs/Ms)', required: true),
            _field(_addressCtrl, 'Address', required: true),
            Row(children: [
              Expanded(child: _field(_cityCtrl, 'City', required: true)),
              const SizedBox(width: 10),
              Expanded(child: _field(_stateCtrl, 'State', required: true)),
            ]),
            Row(children: [
              Expanded(child: _field(_zipCtrl, 'Zip Code', required: true)),
              const SizedBox(width: 10),
              Expanded(child: _field(_countryCtrl, 'Country', required: true)),
            ]),
            Row(children: [
              Expanded(flex: 2, child: _field(_cellAreaCtrl, 'Area Code', required: false, keyboardType: TextInputType.phone)),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: _field(_cellNoCtrl, 'Cell No.', required: false, keyboardType: TextInputType.phone)),
            ]),
            Row(children: [
              Expanded(child: _field(_emailCtrl, 'E-mail', required: true, keyboardType: TextInputType.emailAddress)),
              const SizedBox(width: 10),
              Expanded(child: _field(_whatsAppCtrl, 'WhatsApp No.', required: true, keyboardType: TextInputType.phone)),
            ]),
            Row(children: [
              Expanded(child: _field(_passportCtrl, 'Passport No.', required: true)),
              const SizedBox(width: 10),
              Expanded(child: _field(_nationalityCtrl, 'Nationality', required: true)),
            ]),
            Row(children: [
              Expanded(
                child: ListTile(
                  tileColor: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: const Icon(Icons.cake, color: Colors.grey),
                  title: const Text('Date of Birth', style: TextStyle(fontSize: 13)),
                  subtitle: Text(_buyerDOB != null ? _dtFmt.format(_buyerDOB!) : 'Not set', style: const TextStyle(fontSize: 12)),
                  onTap: _pickDOB,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _field(_seaPortCtrl, 'Sea Port / City', required: true)),
            ]),
            _field(_notesCtrl, 'Notes (optional)', required: false, maxLines: 2),
            const SizedBox(height: 24),

            _SectionHeader(title: 'Items', icon: Icons.inventory_2, color: const Color(0xFFBF360C)),
            const SizedBox(height: 12),
            ..._items.asMap().entries.map((e) => _ItemCard(
              index: e.key, row: e.value,
              canDelete: _items.length > 1,
              onDelete: () => setState(() => _items.removeAt(e.key)),
              onChanged: () => setState(() {}),
            )),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              onPressed: () => setState(() => _items.add(_ItemRow())),
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    '₹ ${_items.fold(0.0, (s, i) => s + i.amount).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6A1B9A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Save Changes' : 'Create Order'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

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
}

class _ItemCard extends StatelessWidget {
  final int index;
  final _ItemRow row;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _ItemCard({
    required this.index,
    required this.row,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            TextFormField(
              controller: row.particulars,
              decoration: const InputDecoration(labelText: 'Description / Particulars'),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              onChanged: (_) => onChanged(),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
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
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
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
                    controller: row.priceInr,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price (INR)', prefixText: '₹ '),
                    onChanged: (_) => onChanged(),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return (n == null || n < 0) ? 'Invalid' : null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Amount (INR)'),
                    child: Text(
                      '₹ ${row.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
