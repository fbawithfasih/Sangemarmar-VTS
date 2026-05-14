import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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

  String _compact(num v) {
    final n = v.abs();
    if (n >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (n >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
    return '₹${v.toStringAsFixed(0)}';
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
    final trend = (data['trend'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final bucketUnit = (data['bucketUnit'] as String?) ?? 'day';
    final companies = (performance['companies'] as List).cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummary(summary),
          const SizedBox(height: 8),
          _chartCard(
            'Sales Trend',
            Icons.show_chart,
            const Color(0xFF2E7D32),
            _buildTrendChart(trend, bucketUnit),
          ),
          _chartCard(
            'Commission: Paid vs Pending',
            Icons.pie_chart,
            const Color(0xFF1565C0),
            _buildCommissionDonut(summary),
          ),
          _chartCard(
            'Top Companies by Net Sales',
            Icons.bar_chart,
            const Color(0xFF6A1B9A),
            _buildTopCompaniesBar(companies),
          ),
          const SizedBox(height: 12),
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
            rows: companies,
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

  // ── Summary cards ───────────────────────────────────────────────────────
  Widget _buildSummary(Map<String, dynamic> s) {
    final cards = [
      _statCard('Vehicle Entries', _fmtInt.format(s['vehicleEntries']), Icons.directions_car, Colors.blue),
      _statCard('Total Sales', _fmtInt.format(s['salesCount']), Icons.receipt_long, Colors.indigo),
      _statCard('Gross Sales', _fmt.format(s['grossSales']), Icons.trending_up, Colors.teal),
      _statCard('Net Sales', _fmt.format(s['netSales']), Icons.monetization_on, Colors.green),
      _statCard('Payments', _fmt.format(s['totalPayments'] ?? 0), Icons.payments, const Color(0xFF00695C)),
      _statCard('Commission Total', _fmt.format(s['commissionTotal']), Icons.percent, const Color(0xFF6A1B9A)),
      _statCard('Commission Paid', _fmt.format(s['commissionPaid']), Icons.check_circle, const Color(0xFF1565C0)),
      _statCard('Commission Pending', _fmt.format(s['commissionPending']), Icons.hourglass_bottom, Colors.redAccent),
    ];
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            // IntrinsicHeight bounds the row height so CrossAxisAlignment.stretch
            // works — without it, a stretch Row in a ListView grows unbounded.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[i]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < cards.length ? cards[i + 1] : const SizedBox(),
                  ),
                ],
              ),
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
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: color),
              ),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );

  // ── Chart shell ─────────────────────────────────────────────────────────
  Widget _chartCard(String title, IconData icon, Color color, Widget chart) {
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: chart),
          ],
        ),
      ),
    );
  }

  // ── Sales trend line chart ──────────────────────────────────────────────
  Widget _buildTrendChart(List<Map<String, dynamic>> trend, String unit) {
    if (trend.isEmpty) {
      return const Center(child: Text('No sales in this period', style: TextStyle(color: Colors.grey)));
    }
    final gross = <FlSpot>[];
    final net = <FlSpot>[];
    for (var i = 0; i < trend.length; i++) {
      gross.add(FlSpot(i.toDouble(), (trend[i]['grossSales'] as num).toDouble()));
      net.add(FlSpot(i.toDouble(), (trend[i]['netSales'] as num).toDouble()));
    }
    final maxY = [
      ...gross.map((s) => s.y),
      ...net.map((s) => s.y),
    ].fold<double>(0, (m, v) => v > m ? v : m);
    final labelEvery = (trend.length / 5).ceil().clamp(1, trend.length);

    String bottomLabel(int i) {
      final d = DateTime.tryParse(trend[i]['label'] as String);
      if (d == null) return '';
      return unit == 'month'
          ? DateFormat('MMM').format(d)
          : DateFormat('d/M').format(d);
    }

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY == 0 ? 1 : maxY * 1.2,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(
                      _compact(v),
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (i < 0 || i >= trend.length || i % labelEvery != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          bottomLabel(i),
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: const LineTouchData(enabled: true),
              lineBarsData: [
                LineChartBarData(
                  spots: gross,
                  isCurved: true,
                  color: Colors.teal.shade300,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: net,
                  isCurved: true,
                  color: const Color(0xFF2E7D32),
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(Colors.teal.shade300, 'Gross'),
            const SizedBox(width: 16),
            _legendDot(const Color(0xFF2E7D32), 'Net'),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );

  // ── Commission donut ────────────────────────────────────────────────────
  Widget _buildCommissionDonut(Map<String, dynamic> s) {
    final paid = (s['commissionPaid'] as num).toDouble();
    final pending = (s['commissionPending'] as num).toDouble();
    final total = paid + pending;
    if (total <= 0) {
      return const Center(child: Text('No commissions in this period', style: TextStyle(color: Colors.grey)));
    }
    final paidPct = (paid / total * 100);
    final pendingPct = (pending / total * 100);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 36,
              sectionsSpace: 2,
              sections: [
                PieChartSectionData(
                  value: paid <= 0 ? 0.0001 : paid,
                  color: const Color(0xFF1565C0),
                  title: '${paidPct.toStringAsFixed(0)}%',
                  radius: 46,
                  titleStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                PieChartSectionData(
                  value: pending <= 0 ? 0.0001 : pending,
                  color: Colors.redAccent,
                  title: '${pendingPct.toStringAsFixed(0)}%',
                  radius: 46,
                  titleStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _donutLegend(const Color(0xFF1565C0), 'Paid', _fmt.format(paid)),
              const SizedBox(height: 12),
              _donutLegend(Colors.redAccent, 'Pending', _fmt.format(pending)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _donutLegend(Color color, String label, String value) => Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      );

  // ── Top companies bar chart ─────────────────────────────────────────────
  Widget _buildTopCompaniesBar(List<Map<String, dynamic>> companies) {
    final top = companies.take(5).toList();
    if (top.isEmpty) {
      return const Center(child: Text('No company data in this period', style: TextStyle(color: Colors.grey)));
    }
    final maxY = top
        .map((c) => (c['netSale'] as num).toDouble())
        .fold<double>(0, (m, v) => v > m ? v : m);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY == 0 ? 1 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${top[group.x]['name']}\n${_fmt.format(rod.toY)}',
              const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) =>
                  Text(_compact(v), style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= top.length) return const SizedBox.shrink();
                final name = (top[i]['name'] as String?) ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    name.length > 8 ? '${name.substring(0, 8)}…' : name,
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < top.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (top[i]['netSale'] as num).toDouble(),
                  color: const Color(0xFF6A1B9A),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
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
