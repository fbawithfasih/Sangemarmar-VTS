import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';

class VehicleEntryFormScreen extends StatefulWidget {
  final String? entryId;
  const VehicleEntryFormScreen({super.key, this.entryId});

  @override
  State<VehicleEntryFormScreen> createState() => _VehicleEntryFormScreenState();
}

class _VehicleEntryFormScreenState extends State<VehicleEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  final _vehicleNumberCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _guideNameCtrl = TextEditingController();
  final _localAgentCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _vehicleNumberCtrl.dispose();
    _driverNameCtrl.dispose();
    _guideNameCtrl.dispose();
    _localAgentCtrl.dispose();
    _companyNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });

    try {
      await _api.post(ApiConstants.vehicles, data: {
        'vehicleNumber': _vehicleNumberCtrl.text.trim(),
        'driverName': _driverNameCtrl.text.trim(),
        'guideName': _guideNameCtrl.text.trim(),
        'localAgent': _localAgentCtrl.text.trim(),
        'companyName': _companyNameCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle entry created'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      setState(() { _error = 'Failed to create entry. Please try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(title: const Text('New Vehicle Entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildField(_vehicleNumberCtrl, 'Vehicle Number', Icons.pin, required: true),
              const SizedBox(height: 16),
              _buildField(_driverNameCtrl, 'Driver Name', Icons.person, required: true),
              const SizedBox(height: 16),
              _buildField(_guideNameCtrl, 'Guide Name', Icons.person_outline, required: true),
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
                    : const Text('Create Entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: required ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null : null,
    );
  }
}
