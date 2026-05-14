import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _api = ApiService();
  final _fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final _fmtInt = NumberFormat('#,##0');

  static const _presets = [
    'Daily',
    'Month to date',
    'Last 30 days',
    'Year till date',
    'Last 12 months',
  ];
  int _periodIndex = 1; // default: Month to date

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  ({DateTime from, DateTime to}) _rangeFor(int index) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (index) {
      case 0: // Daily
        return (from: today, to: today);
      case 1: // Month to date
        return (from: DateTime(now.year, now.month, 1), to: today);
      case 2: // Last 30 days
        return (from: today.subtract(const Duration(days: 29)), to: today);
      case 3: // Year till date
        return (from: DateTime(now.year, 1, 1), to: today);
      case 4: // Last 12 months
      default:
        return (from: DateTime(now.year - 1, now.month, now.day), to: today);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final range = _rangeFor(_periodIndex);
      final df = DateFormat('yyyy-MM-dd');
      final res = await _api.get(
        ApiConstants.adminDashboard,
        queryParams: {
          'dateFrom': df.format(range.from),
          'dateTo': df.format(range.to),
        },
      );
      if (!mounted) return;
      setState(() {
        _data = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load dashboard';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, dynamic>((p) => p.user);

    return Scaffold(
      appBar: SangemarmarAppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(user?.name ?? '', style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    context.read<AuthProvider>().logout();
                    context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: List.generate(_presets.length, (i) {
            final selected = i == _periodIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_presets[i]),
                selected: selected,
                onSelected: (_) {
                  if (selected) return;
                  setState(() => _periodIndex = i);
                  _load();
                },
                selectedColor: const Color(0xFF1B5E20),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final data = _data;
    if (data == null) return const Center(child: Text('No data'));
    final summary = data['summary'] as Map<String, dynamic>;
    final performance = data['performance'] as Map<String, dynamic>;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummary(summary),
          const SizedBox(height: 20),
          _PerfSection(
            title: 'Salesperson Performance',
            icon: Icons.person,
            color: const Color(0xFF2E7D32),
            rows: (performance['salespersons'] as List).cast<Map<String, dynamic>>(),
            expanded: _expanded.contains('salespersons'),
            onToggle: () => _toggle('salespersons'),
            metricsBuilder: (r) => [
              '${_fmtInt.format(r['salesCount'])} sales',
              'Net ${_fmt.format(r['netSale'])}',
            ],
          ),
          _PerfSection(
            title: 'Company Performance',
            icon: Icons.business,
            color: const Color(0xFF1565C0),
            rows: (performance['companies'] as List).cast<Map<String, dynamic>>(),
            expanded: _expanded.contains('companies'),
            onToggle: () => _toggle('companies'),
            metricsBuilder: (r) => [
              '${_fmtInt.format(r['entries'])} entries  ·  ${_fmtInt.format(r['salesCount'])} sales',
              'Net ${_fmt.format(r['netSale'])}  ·  Comm ${_fmt.format(r['commission'])}',
            ],
          ),
          _PerfSection(
            title: 'Local Agent Performance',
            icon: Icons.support_agent,
            color: const Color(0xFF00695C),
            rows: (performance['agents'] as List).cast<Map<String, dynamic>>(),
            expanded: _expanded.contains('agents'),
            onToggle: () => _toggle('agents'),
            metricsBuilder: (r) => [
              '${_fmtInt.format(r['entries'])} entries',
              'Comm ${_fmt.format(r['commission'])}',
            ],
          ),
          _PerfSection(
            title: 'Guide Performance',
            icon: Icons.tour,
            color: const Color(0xFF6A1B9A),
            rows: (performance['guides'] as List).cast<Map<String, dynamic>>(),
            expanded: _expanded.contains('guides'),
            onToggle: () => _toggle('guides'),
            metricsBuilder: (r) => [
              '${_fmtInt.format(r['entries'])} entries',
              'Comm ${_fmt.format(r['commission'])}',
            ],
          ),
          _PerfSection(
            title: 'Driver Performance',
            icon: Icons.directions_car,
            color: const Color(0xFFBF360C),
            rows: (performance['drivers'] as List).cast<Map<String, dynamic>>(),
            expanded: _expanded.contains('drivers'),
            onToggle: () => _toggle('drivers'),
            metricsBuilder: (r) => [
              '${_fmtInt.format(r['entries'])} entries',
              'Comm ${_fmt.format(r['commission'])}',
            ],
          ),
        ],
      ),
    );
  }

  void _toggle(String key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
  }

  Widget _buildSummary(Map<String, dynamic> s) {
    final cards = [
      _statCard('Vehicle Entries', _fmtInt.format(s['vehicleEntries']), Icons.directions_car, Colors.blue),
      _statCard('Total Sales', _fmtInt.format(s['salesCount']), Icons.receipt_long, Colors.indigo),
      _statCard('Gross Sales', _fmt.format(s['grossSales']), Icons.trending_up, Colors.teal),
      _statCard('Net Sales', _fmt.format(s['netSales']), Icons.monetization_on, Colors.green),
      _statCard('Commission Paid', _fmt.format(s['commissionPaid']), Icons.check_circle, const Color(0xFF1565C0)),
      _statCard('Commission Pending', _fmt.format(s['commissionPending']), Icons.hourglass_bottom, Colors.redAccent),
    ];
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: 12),
                Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
              ],
            ),
          ),
      ],
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
              Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _PerfSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> rows;
  final bool expanded;
  final VoidCallback onToggle;
  final List<String> Function(Map<String, dynamic>) metricsBuilder;

  const _PerfSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
    required this.expanded,
    required this.onToggle,
    required this.metricsBuilder,
  });

  @override
  Widget build(BuildContext context) {
    const limit = 10;
    final visible = expanded ? rows : rows.take(limit).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Text('${rows.length}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const Divider(height: 20),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No data for this period', style: TextStyle(color: Colors.grey)),
              )
            else
              ...List.generate(visible.length, (i) {
                final r = visible[i];
                final metrics = metricsBuilder(r);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (r['name'] as String?)?.isNotEmpty == true
                                  ? r['name'] as String
                                  : '(unnamed)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              metrics.join('   '),
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (rows.length > limit)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: onToggle,
                  child: Text(expanded ? 'Show less' : 'Show all (${rows.length})'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
