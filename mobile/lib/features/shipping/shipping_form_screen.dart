import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';
import 'models/shipment.dart';

class ShippingFormScreen extends StatefulWidget {
  final String? billingOrderId;
  final Map<String, dynamic>? prefillBuyer;

  const ShippingFormScreen({super.key, this.billingOrderId, this.prefillBuyer});

  @override
  State<ShippingFormScreen> createState() => _ShippingFormScreenState();
}

class _ShippingFormScreenState extends State<ShippingFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _dtFmt = DateFormat('dd MMM yyyy');

  // Package
  final _weightCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _contentsCtrl = TextEditingController(text: 'Marble Handicrafts');
  DateTime _shipDate = DateTime.now();

  // Recipient (pre-filled from billing order)
  final _recNameCtrl = TextEditingController();
  final _recAddressCtrl = TextEditingController();
  final _recCityCtrl = TextEditingController();
  final _recStateCtrl = TextEditingController();
  final _recZipCtrl = TextEditingController();
  final _recCountryCtrl = TextEditingController();
  final _recPhoneCtrl = TextEditingController();
  final _recEmailCtrl = TextEditingController();

  bool _fetchingRates = false;
  bool _booking = false;
  List<RateQuote> _quotes = [];
  RateQuote? _selectedQuote;
  String? _rateError;
  List<Map<String, String>> _carrierErrors = [];

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  void _prefill() {
    final b = widget.prefillBuyer;
    if (b == null) return;
    _recNameCtrl.text = (b['buyerName'] as String?) ?? '';
    _recAddressCtrl.text = (b['buyerAddress'] as String?) ?? '';
    _recCityCtrl.text = (b['buyerCity'] as String?) ?? '';
    _recStateCtrl.text = (b['buyerState'] as String?) ?? '';
    _recZipCtrl.text = (b['buyerZip'] as String?) ?? '';
    _recCountryCtrl.text = (b['buyerCountry'] as String?) ?? '';
    _recPhoneCtrl.text = (b['buyerWhatsApp'] as String?) ?? '';
    _recEmailCtrl.text = (b['buyerEmail'] as String?) ?? '';
    final totalUsd = b['totalUsd'] as double?;
    if (totalUsd != null) _valueCtrl.text = totalUsd.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _weightCtrl.dispose(); _lengthCtrl.dispose(); _widthCtrl.dispose();
    _heightCtrl.dispose(); _valueCtrl.dispose(); _contentsCtrl.dispose();
    _recNameCtrl.dispose(); _recAddressCtrl.dispose(); _recCityCtrl.dispose();
    _recStateCtrl.dispose(); _recZipCtrl.dispose(); _recCountryCtrl.dispose();
    _recPhoneCtrl.dispose(); _recEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickShipDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _shipDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) setState(() => _shipDate = d);
  }

  Future<void> _getRates() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _fetchingRates = true; _quotes = []; _selectedQuote = null; _rateError = null; _carrierErrors = []; });

    try {
      final body = {
        if (widget.billingOrderId != null) 'billingOrderId': widget.billingOrderId,
        'weightKg': double.parse(_weightCtrl.text),
        if (_lengthCtrl.text.isNotEmpty) 'lengthCm': double.parse(_lengthCtrl.text),
        if (_widthCtrl.text.isNotEmpty) 'widthCm': double.parse(_widthCtrl.text),
        if (_heightCtrl.text.isNotEmpty) 'heightCm': double.parse(_heightCtrl.text),
        'declaredValueUsd': double.parse(_valueCtrl.text),
        'contentsDescription': _contentsCtrl.text.trim(),
        'shipDate': _shipDate.toIso8601String().split('T').first,
      };

      final res = await _api.post(ApiConstants.shippingRates, data: body);
      final groups = res.data as List;
      final quotes = <RateQuote>[];
      final errors = <Map<String, String>>[];
      for (final group in groups) {
        final g = group as Map<String, dynamic>;
        final carrier = g['carrier'] as String;
        if (g['error'] != null) {
          errors.add({'carrier': carrier, 'message': g['error'] as String});
        }
        final groupQuotes = (g['quotes'] as List? ?? [])
            .map((q) => RateQuote.fromJson(q as Map<String, dynamic>))
            .toList();
        quotes.addAll(groupQuotes);
      }
      quotes.sort((a, b) => a.costUsd.compareTo(b.costUsd));
      setState(() { _quotes = quotes; _carrierErrors = errors; });
    } catch (e) {
      setState(() => _rateError = 'Request failed: $e');
    }
    setState(() => _fetchingRates = false);
  }

  Future<void> _book() async {
    if (_selectedQuote == null) return;
    setState(() => _booking = true);

    try {
      final body = {
        if (widget.billingOrderId != null) 'billingOrderId': widget.billingOrderId,
        'carrier': _selectedQuote!.carrier,
        'serviceCode': _selectedQuote!.serviceCode,
        'serviceLabel': _selectedQuote!.serviceLabel,
        'weightKg': double.parse(_weightCtrl.text),
        if (_lengthCtrl.text.isNotEmpty) 'lengthCm': double.parse(_lengthCtrl.text),
        if (_widthCtrl.text.isNotEmpty) 'widthCm': double.parse(_widthCtrl.text),
        if (_heightCtrl.text.isNotEmpty) 'heightCm': double.parse(_heightCtrl.text),
        'declaredValueUsd': double.parse(_valueCtrl.text),
        'contentsDescription': _contentsCtrl.text.trim(),
        'quotedCostUsd': _selectedQuote!.costUsd,
        'shipDate': _shipDate.toIso8601String().split('T').first,
        'recipientName': _recNameCtrl.text.trim(),
        'recipientAddress': _recAddressCtrl.text.trim(),
        'recipientCity': _recCityCtrl.text.trim(),
        'recipientState': _recStateCtrl.text.trim(),
        'recipientZip': _recZipCtrl.text.trim(),
        'recipientCountry': _recCountryCtrl.text.trim(),
        'recipientPhone': _recPhoneCtrl.text.trim(),
        'recipientEmail': _recEmailCtrl.text.trim(),
      };

      final res = await _api.post(ApiConstants.shipping, data: body);
      final id = (res.data as Map<String, dynamic>)['id'] as String;
      if (mounted) context.pushReplacement('/shipping/$id');
    } catch (e) {
      if (mounted) {
        String msg = 'Booking failed';
        try {
          final data = (e as dynamic).response?.data;
          if (data is Map) msg = data['message']?.toString() ?? msg;
          else if (data is String) msg = data;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
    if (mounted) setState(() => _booking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(title: const Text('Create Shipment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Recipient ──
            _sectionHeader('Recipient', Icons.person_pin_circle, const Color(0xFF1565C0)),
            const SizedBox(height: 10),
            if (widget.billingOrderId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Color(0xFF1565C0), size: 16),
                    SizedBox(width: 8),
                    Text('Pre-filled from billing order', style: TextStyle(fontSize: 12, color: Color(0xFF1565C0))),
                  ],
                ),
              ),
            _field(_recNameCtrl, 'Full Name'),
            _field(_recAddressCtrl, 'Address'),
            Row(children: [
              Expanded(child: _field(_recCityCtrl, 'City')),
              const SizedBox(width: 10),
              Expanded(child: _field(_recStateCtrl, 'State/Province')),
            ]),
            Row(children: [
              Expanded(child: _field(_recZipCtrl, 'Zip/Postal Code')),
              const SizedBox(width: 10),
              Expanded(child: _countryField()),
            ]),
            Row(children: [
              Expanded(child: _field(_recPhoneCtrl, 'Phone', keyboard: TextInputType.phone)),
              const SizedBox(width: 10),
              Expanded(child: _field(_recEmailCtrl, 'Email', keyboard: TextInputType.emailAddress)),
            ]),
            const SizedBox(height: 20),

            // ── Package ──
            _sectionHeader('Package Details', Icons.inventory_2, const Color(0xFFBF360C)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg) *', suffixText: 'kg'),
                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _valueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Declared Value *', prefixText: '\$ '),
                  validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Required' : null,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            const Text('Dimensions (optional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _optField(_lengthCtrl, 'L (cm)')),
              const SizedBox(width: 8),
              Expanded(child: _optField(_widthCtrl, 'W (cm)')),
              const SizedBox(width: 8),
              Expanded(child: _optField(_heightCtrl, 'H (cm)')),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contentsCtrl,
              decoration: const InputDecoration(labelText: 'Contents Description *'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              leading: const Icon(Icons.calendar_today, color: Color(0xFFBF360C)),
              title: const Text('Ship Date'),
              subtitle: Text(_dtFmt.format(_shipDate)),
              onTap: _pickShipDate,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            ),
            const SizedBox(height: 20),

            // ── Get Rates ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _fetchingRates ? null : _getRates,
                icon: _fetchingRates
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.compare_arrows),
                label: Text(_fetchingRates ? 'Fetching Rates…' : 'Get Rates from All Carriers'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D5216),
                  minimumSize: const Size(0, 46),
                ),
              ),
            ),

            if (_rateError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                child: Text(_rateError!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ),
            ],
            if (_carrierErrors.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._carrierErrors.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(4)),
                      child: Text(e['carrier']!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e['message']!, style: TextStyle(color: Colors.orange.shade800, fontSize: 12))),
                  ],
                ),
              )),
            ],

            if (_quotes.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionHeader('Available Rates', Icons.local_shipping, const Color(0xFF2E7D32)),
              const SizedBox(height: 10),
              ..._quotes.map((q) => _RateTile(
                    quote: q,
                    selected: _selectedQuote?.serviceCode == q.serviceCode && _selectedQuote?.carrier == q.carrier,
                    onTap: () => setState(() => _selectedQuote = q),
                  )),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedQuote == null || _booking) ? null : _book,
                  icon: _booking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle),
                  label: Text(_booking
                      ? 'Booking…'
                      : _selectedQuote != null
                          ? 'Book — ${_selectedQuote!.carrier} \$ ${_selectedQuote!.costUsd.toStringAsFixed(2)}'
                          : 'Select a rate to book'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) => Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        ],
      );

  Widget _countryField() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: _recCountryCtrl,
          maxLength: 2,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Country Code *',
            hintText: 'US / GB / AE',
            counterText: '',
            helperText: '2-letter ISO code',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (v.trim().length != 2) return 'Must be 2 letters (e.g. US)';
            return null;
          },
          onChanged: (v) {
            if (v.length == 2) {
              _recCountryCtrl.value = _recCountryCtrl.value.copyWith(
                text: v.toUpperCase(),
                selection: TextSelection.collapsed(offset: v.length),
              );
            }
          },
        ),
      );

  Widget _field(TextEditingController ctrl, String label, {TextInputType? keyboard, String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: '$label *', hintText: hint),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
      );

  Widget _optField(TextEditingController ctrl, String label) => TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: 'cm'),
      );
}

class _RateTile extends StatelessWidget {
  final RateQuote quote;
  final bool selected;
  final VoidCallback onTap;

  const _RateTile({required this.quote, required this.selected, required this.onTap});

  Color get _carrierColor {
    switch (quote.carrier) {
      case 'FEDEX': return const Color(0xFF4D148C);
      case 'DHL': return const Color(0xFFFFCC00);
      case 'UPS': return const Color(0xFF351C15);
      default: return Colors.grey;
    }
  }

  Color get _carrierTextColor => quote.carrier == 'DHL' ? Colors.black : Colors.white;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E7D32).withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _carrierColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                quote.carrier,
                style: TextStyle(color: _carrierTextColor, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quote.serviceLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (quote.transitDays != null)
                    Text('${quote.transitDays} business day${quote.transitDays != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$ ${quote.costUsd.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32)),
                ),
                Text(quote.currency, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFF2E7D32) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
