import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/download_helper.dart';
import '../../core/widgets/app_bar.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  final _fmtInt = NumberFormat('#,##0');

  Map<String, dynamic>? _dashboard;
  bool _loading = false;

  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{};
      if (_dateFrom != null) params['dateFrom'] = DateFormat('yyyy-MM-dd').format(_dateFrom!);
      if (_dateTo != null) params['dateTo'] = DateFormat('yyyy-MM-dd').format(_dateTo!);

      final res = await _api.get('${ApiConstants.reports}/dashboard', queryParams: params.isEmpty ? null : params);
      setState(() { _dashboard = res.data as Map<String, dynamic>; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) _dateFrom = picked;
      else _dateTo = picked;
    });
    _loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Report',
            onPressed: () => _showExportSheet(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Filter'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildDashboard(),
          _buildFilterPanel(),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildExportParams() => {
        if (_dateFrom != null) 'dateFrom': DateFormat('yyyy-MM-dd').format(_dateFrom!),
        if (_dateTo != null) 'dateTo': DateFormat('yyyy-MM-dd').format(_dateTo!),
      };

  void _showExportSheet() {
    final reportTypes = [
      ('sales', 'Sales Report', Icons.receipt),
      ('payments', 'Payments Report', Icons.payment),
      ('vehicles', 'Vehicle Entries Report', Icons.directions_car),
      ('commissions', 'Commissions Report', Icons.percent),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Choose report type, then format', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            ...reportTypes.map(
              (t) => ListTile(
                leading: Icon(t.$3, color: const Color(0xFF1B5E20)),
                title: Text(t.$2),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _exportChip('XLSX', Colors.green, () {
                      Navigator.pop(context);
                      showDownloadSheet(
                        context: context,
                        path: ApiConstants.reportsExport,
                        queryParams: {..._buildExportParams(), 'type': t.$1},
                        baseFilename: '${t.$1}_report',
                      );
                    }),
                    const SizedBox(width: 6),
                    _exportChip('PDF', Colors.red, () {
                      Navigator.pop(context);
                      downloadFile(
                        context: context,
                        path: ApiConstants.reportsExport,
                        queryParams: {..._buildExportParams(), 'type': t.$1, 'format': 'pdf'},
                        filename: '${t.$1}_report.pdf',
                      );
                    }),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportChip(String label, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      );

  Widget _buildDashboard() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_dashboard == null) return const Center(child: Text('No data'));

    final vehicles = _dashboard!['vehicles'] as Map<String, dynamic>;
    final sales = _dashboard!['sales'] as Map<String, dynamic>;
    final payments = _dashboard!['payments'] as Map<String, dynamic>;
    final commissions = _dashboard!['commissions'] as Map<String, dynamic>;

    final byMode = payments['byMode'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _statCard('Vehicle Entries', _fmtInt.format(vehicles['count']), Icons.directions_car, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Total Sales', _fmtInt.format(sales['count']), Icons.receipt, Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('Net Sales', _fmt.format(sales['totalNet']), Icons.monetization_on, Colors.teal)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Payments', _fmt.format(payments['totalAmount']), Icons.payment, Colors.purple)),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payments by Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...byMode.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.teal.shade200),
                                ),
                                child: Text(e.key, style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
                              ),
                              Text(_fmt.format(e.value), style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Commissions', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _row('Total Commissions', _fmtInt.format(commissions['count'])),
                    _row('Total Amount', _fmt.format(commissions['totalFinal'])),
                    _row('Manual Overrides', _fmtInt.format(commissions['overrides'])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Filter by Date Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: Colors.grey.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            leading: const Icon(Icons.calendar_today),
            title: const Text('From Date'),
            subtitle: Text(_dateFrom != null ? DateFormat('dd MMM yyyy').format(_dateFrom!) : 'Not set'),
            onTap: () => _pickDate(true),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.grey.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            leading: const Icon(Icons.calendar_today),
            title: const Text('To Date'),
            subtitle: Text(_dateTo != null ? DateFormat('dd MMM yyyy').format(_dateTo!) : 'Not set'),
            onTap: () => _pickDate(false),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Apply Filters'),
            onPressed: () {
              _loadDashboard();
              _tabs.animateTo(0);
            },
          ),
          if (_dateFrom != null || _dateTo != null)
            TextButton.icon(
              icon: const Icon(Icons.clear),
              label: const Text('Clear Filters'),
              onPressed: () {
                setState(() { _dateFrom = null; _dateTo = null; });
                _loadDashboard();
              },
            ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
