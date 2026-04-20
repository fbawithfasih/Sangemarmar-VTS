import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/vehicle_entry.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
              onChanged: (v) => _load(search: v),
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
                                        Text('${e.driverName} • ${e.companyName}'),
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
    final canComplete = (user?.isManager ?? false) && entry.status != 'COMPLETED';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.vehicleNumber,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text('${entry.driverName} | ${entry.companyName}', style: const TextStyle(color: Colors.grey)),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.point_of_sale, color: Color(0xFF2E7D32)),
              title: const Text('Create Sale'),
              onTap: () {
                Navigator.pop(context);
                context.push('/sales/new?vehicleEntryId=${entry.id}').then((_) => _load());
              },
            ),
            ListTile(
              leading: const Icon(Icons.timeline, color: Color(0xFF1565C0)),
              title: const Text('View Logistics Timeline'),
              onTap: () {
                Navigator.pop(context);
                context.push('/logistics/${entry.id}');
              },
            ),
            if (canComplete)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Mark as Completed'),
                onTap: () {
                  Navigator.pop(context);
                  _markCompleted(entry);
                },
              ),
          ],
        ),
      ),
    );
  }
}
