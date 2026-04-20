import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';

class CommissionConfigScreen extends StatefulWidget {
  const CommissionConfigScreen({super.key});

  @override
  State<CommissionConfigScreen> createState() => _CommissionConfigScreenState();
}

class _CommissionConfigScreenState extends State<CommissionConfigScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers keyed by recipientType
  final Map<String, TextEditingController> _controllers = {
    'DRIVER': TextEditingController(),
    'GUIDE': TextEditingController(),
    'LOCAL_AGENT': TextEditingController(),
    'COMPANY': TextEditingController(),
  };

  final Map<String, String> _labels = {
    'DRIVER': 'Driver',
    'GUIDE': 'Guide',
    'LOCAL_AGENT': 'Local Agent',
    'COMPANY': 'Company',
  };

  final Map<String, IconData> _icons = {
    'DRIVER': Icons.drive_eta,
    'GUIDE': Icons.person_pin,
    'LOCAL_AGENT': Icons.support_agent,
    'COMPANY': Icons.business,
  };

  // Preview — net sale entered by user to see live amounts
  final _previewCtrl = TextEditingController(text: '10000');

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _load();
    _previewCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controllers.values.forEach((c) => c.dispose());
    _previewCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get(ApiConstants.commissionConfig);
      final list = res.data as List;
      for (final item in list) {
        final type = item['recipientType'] as String;
        final rate = item['rate'].toString();
        _controllers[type]?.text = rate;
        if (item['updatedAt'] != null) {
          _lastUpdated = DateFormat('dd MMM yyyy, HH:mm')
              .format(DateTime.parse(item['updatedAt'] as String).toLocal());
        }
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() { _error = 'Failed to load rates'; _loading = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final rates = _controllers.entries.map((e) => {
      'recipientType': e.key,
      'rate': double.parse(e.value.text),
    }).toList();

    try {
      await _api.put(ApiConstants.commissionConfig, data: {'rates': rates});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commission rates saved'),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      }
    } catch (_) {
      setState(() => _error = 'Failed to save rates. Check permissions.');
    }
    setState(() => _saving = false);
  }

  double get _previewNetSale => double.tryParse(_previewCtrl.text) ?? 0;

  double _previewAmount(String type) {
    final rate = double.tryParse(_controllers[type]?.text ?? '0') ?? 0;
    return (_previewNetSale * rate) / 100;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: SangemarmarAppBar(title: const Text('Commission Rate Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header info
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFF1B5E20), size: 18),
                                const SizedBox(width: 8),
                                const Text(
                                  'Commission rates are applied to Net Sale',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)),
                                ),
                              ],
                            ),
                            if (_lastUpdated != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Last updated: $_lastUpdated',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Rate fields
                    const Text(
                      'Set Rates (%)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ..._controllers.keys.map((type) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: _controllers[type],
                            decoration: InputDecoration(
                              labelText: '${_labels[type]} Commission Rate',
                              prefixIcon: Icon(_icons[type]),
                              suffixText: '%',
                              helperText: 'e.g. 2.5 means 2.5% of net sale',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final n = double.tryParse(v);
                              if (n == null) return 'Enter a valid number';
                              if (n < 0) return 'Cannot be negative';
                              if (n > 100) return 'Cannot exceed 100%';
                              return null;
                            },
                          ),
                        )),

                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Live preview section
                    const Text(
                      'Live Preview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter a net sale amount to preview calculated commissions:',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _previewCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Net Sale Amount',
                        prefixIcon: Icon(Icons.calculate),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: _controllers.keys.map((type) {
                            final amount = _previewAmount(type);
                            final rate = double.tryParse(_controllers[type]?.text ?? '0') ?? 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(_icons[type], size: 18, color: Colors.grey),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _labels[type]!,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          '$rate% of ${fmt.format(_previewNetSale)}',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    fmt.format(amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF1B5E20),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList()
                            ..add(
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Total Commissions',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text(
                                      fmt.format(_controllers.keys
                                          .map(_previewAmount)
                                          .fold(0.0, (a, b) => a + b)),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: Color(0xFF1B5E20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save Rates'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
