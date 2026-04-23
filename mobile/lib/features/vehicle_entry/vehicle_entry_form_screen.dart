import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';

class VehicleEntryFormScreen extends StatefulWidget {
  final String? entryId;
  const VehicleEntryFormScreen({super.key, this.entryId});

  bool get isEditing => entryId != null;

  @override
  State<VehicleEntryFormScreen> createState() => _VehicleEntryFormScreenState();
}

class _VehicleEntryFormScreenState extends State<VehicleEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  final _vehicleNumberCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverMobileCtrl = TextEditingController();
  final _guideNameCtrl = TextEditingController();
  final _guideMobileCtrl = TextEditingController();
  final _localAgentCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _loading = false;
  bool _prefilling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _prefill();
  }

  Future<void> _prefill() async {
    setState(() => _prefilling = true);
    try {
      final res = await _api.get('${ApiConstants.vehicles}/${widget.entryId}');
      final data = res.data as Map<String, dynamic>;
      _vehicleNumberCtrl.text = data['vehicleNumber'] ?? '';
      _driverNameCtrl.text = data['driverName'] ?? '';
      _driverMobileCtrl.text = data['driverMobile'] ?? '';
      _guideNameCtrl.text = data['guideName'] ?? '';
      _guideMobileCtrl.text = data['guideMobile'] ?? '';
      _localAgentCtrl.text = data['localAgent'] ?? '';
      _companyNameCtrl.text = data['companyName'] ?? '';
      _notesCtrl.text = data['notes'] ?? '';
    } catch (_) {
      setState(() => _error = 'Failed to load entry data.');
    }
    setState(() => _prefilling = false);
  }

  @override
  void dispose() {
    _vehicleNumberCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverMobileCtrl.dispose();
    _guideNameCtrl.dispose();
    _guideMobileCtrl.dispose();
    _localAgentCtrl.dispose();
    _companyNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final payload = {
      'vehicleNumber': _vehicleNumberCtrl.text.trim(),
      'driverName': _driverNameCtrl.text.trim(),
      'driverMobile': _driverMobileCtrl.text.trim().isEmpty ? null : _driverMobileCtrl.text.trim(),
      'guideName': _guideNameCtrl.text.trim(),
      'guideMobile': _guideMobileCtrl.text.trim().isEmpty ? null : _guideMobileCtrl.text.trim(),
      'localAgent': _localAgentCtrl.text.trim(),
      'companyName': _companyNameCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };

    try {
      if (widget.isEditing) {
        await _api.put('${ApiConstants.vehicles}/${widget.entryId}', data: payload);
      } else {
        await _api.post(ApiConstants.vehicles, data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Vehicle entry updated' : 'Vehicle entry created'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      String msg = widget.isEditing ? 'Failed to update entry.' : 'Failed to create entry.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) msg = data['message']?.toString() ?? msg;
      } catch (_) {}
      setState(() { _error = msg; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(
        title: Text(widget.isEditing ? 'Edit Vehicle Entry' : 'New Vehicle Entry'),
      ),
      body: _prefilling
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildField(_vehicleNumberCtrl, 'Vehicle Number', Icons.pin, required: true),
                    const SizedBox(height: 16),
                    _buildField(_driverNameCtrl, 'Driver Name', Icons.person, required: true),
                    const SizedBox(height: 12),
                    _buildField(_driverMobileCtrl, 'Driver Mobile', Icons.phone, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildField(_guideNameCtrl, 'Guide Name', Icons.person_outline, required: true),
                    const SizedBox(height: 12),
                    _buildField(_guideMobileCtrl, 'Guide Mobile', Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildField(_localAgentCtrl, 'Local Agent', Icons.support_agent, required: true),
                    const SizedBox(height: 16),
                    _buildField(_companyNameCtrl, 'Company Name', Icons.business, required: true),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 3,
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
                          : Text(widget.isEditing ? 'Save Changes' : 'Create Entry'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: required ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null : null,
    );
  }
}
