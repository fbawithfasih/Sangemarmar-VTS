import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/vehicle_entry.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/uppercase_formatter.dart';
import '../../core/widgets/app_bar.dart';

class VehicleEntryListScreen extends StatefulWidget {
  const VehicleEntryListScreen({super.key});

  @override
  State<VehicleEntryListScreen> createState() => _VehicleEntryListScreenState();
}

class _VehicleEntryListScreenState extends State<VehicleEntryListScreen> {
  final _api = ApiService();
  List<VehicleEntry> _entries = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _load(search: v);
    });
  }

  Future<void> _load({String? search}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get(
        ApiConstants.vehicles,
        queryParams: search != null && search.isNotEmpty
            ? {'vehicleNumber': search}
            : null,
      );
      final list = (res.data as List)
          .map((e) => VehicleEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() { _entries = list; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load entries'; _loading = false; });
    }
  }

  Color _statusColor(String status) {
    const colors = {
      'ENTERED': Colors.blue,
      'SALES_COMPLETE': Colors.orange,
      'PAYMENT_COMPLETE': Colors.teal,
      'COMPLETED': Colors.green,
      'NO_SALE': Colors.redAccent,
    };
    return colors[status] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(title: const Text('Vehicle Entries')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vehicles/new').then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('New Entry'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              decoration: InputDecoration(
                hintText: 'Search by vehicle number...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _entries.isEmpty
                        ? const Center(child: Text('No vehicle entries found'))
                        : RefreshIndicator(
                            onRefresh: () => _load(search: _searchCtrl.text),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _entries.length,
                              itemBuilder: (_, i) {
                                final e = _entries[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _statusColor(e.status).withOpacity(0.15),
                                      child: Icon(Icons.directions_car, color: _statusColor(e.status)),
                                    ),
                                    title: Text(
                                      e.vehicleNumber,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Driver: ${e.driverName}  •  Guide: ${e.guideName}'),
                                        Text(
                                          e.companyName,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          DateFormat('dd MMM yyyy, HH:mm').format(e.entryDate),
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(e.status).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            e.statusLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _statusColor(e.status),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _showEntryActions(context, e),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _editEntry(VehicleEntry entry) async {
    final updated = await context.push<bool>('/vehicles/${entry.id}');
    if (updated == true) _load(search: _searchCtrl.text);
  }

  Future<void> _deleteEntry(VehicleEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Vehicle Entry?'),
        content: Text(
          'This will permanently delete entry for ${entry.vehicleNumber}. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.delete('${ApiConstants.vehicles}/${entry.id}');
      _load(search: _searchCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle entry deleted'), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete entry'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markNoSale(VehicleEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as No Sale?'),
        content: Text('No sale was made for ${entry.vehicleNumber}. This will close the entry without a sale.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.patch('${ApiConstants.vehicles}/${entry.id}/status', data: {'status': 'NO_SALE'});
      _load(search: _searchCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as No Sale'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markCompleted(VehicleEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Completed?'),
        content: Text('This will set ${entry.vehicleNumber} status to COMPLETED.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.patch('${ApiConstants.vehicles}/${entry.id}/status', data: {'status': 'COMPLETED'});
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as Completed'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEntryActions(BuildContext context, VehicleEntry entry) {
    final user = context.read<AuthProvider>().user;
    final isAdmin = user?.isAdmin ?? false;
    final isGateOperator = user?.isGateOperator ?? false;
    final canComplete = (user?.isManager ?? false) && entry.status != 'COMPLETED';
    final canMarkNoSale = !isGateOperator &&
        entry.status != 'NO_SALE' &&
        entry.status != 'COMPLETED' &&
        entry.status != 'SALES_COMPLETE' &&
        entry.status != 'PAYMENT_COMPLETE' &&
        entry.status != 'COMMISSION_COMPLETE';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.vehicleNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(entry.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      entry.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(entry.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(Icons.calendar_today, 'Entry Date',
                        DateFormat('dd MMM yyyy, HH:mm').format(entry.entryDate)),
                    const SizedBox(height: 8),
                    _detailRow(Icons.person, 'Driver Name', entry.driverName),
                    const SizedBox(height: 8),
                    _detailRow(Icons.person_outline, 'Guide Name', entry.guideName),
                    const SizedBox(height: 8),
                    _detailRow(Icons.business, 'Company Name', entry.companyName),
                    if (entry.assignedSalesmanName != null) ...[
                      const SizedBox(height: 8),
                      _detailRow(Icons.badge, 'Salesman', entry.assignedSalesmanName!),
                    ],
                  ],
                ),
              ),
              const Divider(height: 24),
              if (!isGateOperator)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.point_of_sale, color: Color(0xFF2E7D32)),
                  title: const Text('Create Sale'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/sales/new?vehicleEntryId=${entry.id}').then((_) => _load());
                  },
                ),
              if (canMarkNoSale)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.do_not_disturb_on, color: Colors.redAccent),
                  title: const Text('Mark as No Sales'),
                  onTap: () {
                    Navigator.pop(context);
                    _markNoSale(entry);
                  },
                ),
              if (!isGateOperator)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timeline, color: Color(0xFF1565C0)),
                  title: const Text('View Logistics Timeline'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/logistics/${entry.id}');
                  },
                ),
              if (canComplete)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Mark as Completed'),
                  onTap: () {
                    Navigator.pop(context);
                    _markCompleted(entry);
                  },
                ),
              if (isAdmin) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit, color: Color(0xFF1565C0)),
                  title: const Text('Edit Entry'),
                  onTap: () {
                    Navigator.pop(context);
                    _editEntry(entry);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Entry', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteEntry(entry);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
