import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/download_helper.dart';
import '../../core/widgets/app_bar.dart';

class StatementDetailScreen extends StatefulWidget {
  final String type;
  final String name;

  const StatementDetailScreen({
    super.key,
    required this.type,
    required this.name,
  });

  @override
  State<StatementDetailScreen> createState() => _StatementDetailScreenState();
}

class _StatementDetailScreenState extends State<StatementDetailScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  final _dtFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = <String, dynamic>{
        'type': widget.type,
        'name': widget.name,
      };
      if (_dateFrom != null) params['dateFrom'] = _dateFrom!.toIso8601String();
      if (_dateTo != null) params['dateTo'] = _dateTo!.toIso8601String();

      final res = await _api.get(ApiConstants.statements, queryParams: params);
      setState(() { _data = res.data as Map<String, dynamic>; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed to load statement'; _loading = false; });
    }
  }

  Map<String, dynamic> _exportParams() => {
        'type': widget.type,
        'name': widget.name,
        if (_dateFrom != null) 'dateFrom': _dateFrom!.toIso8601String(),
        if (_dateTo != null) 'dateTo': _dateTo!.toIso8601String(),
      };

  void _showDownloadOptions() {
    final safeName = widget.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    showDownloadSheet(
      context: context,
      path: ApiConstants.statementExport,
      queryParams: _exportParams(),
      baseFilename: '${widget.type}_${safeName}_statement',
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.type.replaceAll('_', ' ');

    return Scaffold(
      appBar: SangemarmarAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$typeLabel Statement', style: const TextStyle(fontSize: 16)),
            Text(widget.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download Statement',
            onPressed: _showDownloadOptions,
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Filter by date',
            onPressed: () => _showDateFilter(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildContent(),
    );
  }

  void _showDateFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Filter by Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                tileColor: Colors.grey.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                leading: const Icon(Icons.calendar_today),
                title: const Text('From'),
                subtitle: Text(_dateFrom != null ? _dtFmt.format(_dateFrom!) : 'Not set'),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) { setState(() => _dateFrom = d); setLocal(() {}); _load(); }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                tileColor: Colors.grey.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                leading: const Icon(Icons.calendar_today),
                title: const Text('To'),
                subtitle: Text(_dateTo != null ? _dtFmt.format(_dateTo!) : 'Not set'),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) { setState(() => _dateTo = d); setLocal(() {}); _load(); }
                },
              ),
              if (_dateFrom != null || _dateTo != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear filter'),
                  onPressed: () {
                    setState(() { _dateFrom = null; _dateTo = null; });
                    setLocal(() {});
                    _load();
                    Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final s = _data!['summary'] as Map<String, dynamic>;
    final entries = _data!['entries'] as List;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date filter indicator
            if (_dateFrom != null || _dateTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Filtered: ${_dateFrom != null ? _dtFmt.format(_dateFrom!) : '—'} → ${_dateTo != null ? _dtFmt.format(_dateTo!) : '—'}',
                      style: const TextStyle(color: Colors.blue, fontSize: 13),
                    ),
                  ],
                ),
              ),

            // Summary grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _summaryCard('Vehicle Entries', s['totalVehicleEntries'].toString(), Icons.directions_car, Colors.blue),
                _summaryCard('Total Sales', s['totalSales'].toString(), Icons.receipt, Colors.orange),
                _summaryCard('Net Sales', _fmt.format(s['totalNetSale']), Icons.monetization_on, Colors.teal),
                _summaryCard('Commission Earned', _fmt.format(s['totalCommission']), Icons.percent, const Color(0xFF1B5E20)),
              ],
            ),
            const SizedBox(height: 16),

            // Totals bar
            Card(
              color: const Color(0xFF1B5E20),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _darkStat('Gross Sales', _fmt.format(s['totalGrossSale'])),
                    _darkDivider(),
                    _darkStat('Net Sales', _fmt.format(s['totalNetSale'])),
                    _darkDivider(),
                    _darkStat('Payments', _fmt.format(s['totalPayments'])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Transaction list
            Text(
              'Transactions (${entries.length} entries)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),

            if (entries.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No transactions found', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...entries.map((entryData) => _buildEntryCard(entryData as Map<String, dynamic>)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entryData) {
    final entry = entryData['entry'] as Map<String, dynamic>;
    final sales = entryData['sales'] as List;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.directions_car, color: Color(0xFF1B5E20), size: 20),
        ),
        title: Text(
          entry['vehicleNumber'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_dtFmt.format(DateTime.parse(entry['entryDate'] as String).toLocal())),
        trailing: Text(
          '${sales.length} sale${sales.length != 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        children: sales.isEmpty
            ? [const ListTile(title: Text('No sales', style: TextStyle(color: Colors.grey)))]
            : sales.map((sd) => _buildSaleRow(sd as Map<String, dynamic>)).toList(),
      ),
    );
  }

  Widget _buildSaleRow(Map<String, dynamic> sd) {
    final sale = sd['sale'] as Map<String, dynamic>;
    final payments = sd['payments'] as List;
    final payTotal = sd['paymentTotal'];
    final commission = sd['commission'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dtFmt.format(DateTime.parse(sale['saleDate'] as String).toLocal()),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  sale['orderType'].toString().replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _miniStat('Gross', _fmt.format(double.parse(sale['grossSale'].toString()))),
                const SizedBox(width: 12),
                _miniStat('Net', _fmt.format(double.parse(sale['netSale'].toString()))),
                const SizedBox(width: 12),
                _miniStat('Paid', _fmt.format(double.parse(payTotal.toString()))),
              ],
            ),
            if (commission != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.percent, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Commission: ${_fmt.format(double.parse(commission['finalAmount'].toString()))}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (commission['isOverridden'] == true) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text('adj', style: TextStyle(fontSize: 10, color: Colors.orange.shade700)),
                    ),
                  ],
                ],
              ),
            ],
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: payments.map((p) {
                  final pm = p as Map<String, dynamic>;
                  return Chip(
                    label: Text(
                      '${pm['mode']}  ${_fmt.format(double.parse(pm['amount'].toString()))}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.teal.shade50,
                    side: BorderSide(color: Colors.teal.shade200),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _darkStat(String label, String value) => Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      );

  Widget _darkDivider() => Container(width: 1, height: 28, color: Colors.white24);

  Widget _miniStat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
}
