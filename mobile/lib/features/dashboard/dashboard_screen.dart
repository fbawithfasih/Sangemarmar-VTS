import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await _api.get(ApiConstants.notificationsUnreadCount);
      if (mounted) {
        setState(() => _unreadCount = (res.data['count'] as num).toInt());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    final items = [
      _DashItem(
        icon: Icons.directions_car,
        label: 'Vehicle Entry',
        subtitle: 'Gate entry & tracking',
        color: const Color(0xFF1565C0),
        route: '/vehicles',
      ),
      if (!(user?.isGateOperator ?? false))
        _DashItem(
          icon: Icons.point_of_sale,
          label: 'Sales',
          subtitle: 'Record & manage sales',
          color: const Color(0xFF2E7D32),
          route: '/sales',
        ),
      if (user?.isManager ?? false)
        _DashItem(
          icon: Icons.bar_chart,
          label: 'Reports',
          subtitle: 'Sales & financial reports',
          color: const Color(0xFF6A1B9A),
          route: '/reports',
        ),
      if (user?.isManager ?? false)
        _DashItem(
          icon: Icons.percent,
          label: 'Commission Rates',
          subtitle: 'Configure % rates per recipient',
          color: const Color(0xFFBF360C),
          route: '/commissions/config',
        ),
      if (user?.canViewStatements ?? false)
        _DashItem(
          icon: Icons.account_balance_wallet,
          label: 'Statements',
          subtitle: 'Driver, Guide, Agent, Company',
          color: const Color(0xFF00695C),
          route: '/statements',
        ),
      if (user?.isAdmin ?? false)
        _DashItem(
          icon: Icons.manage_accounts,
          label: 'Users',
          subtitle: 'Manage staff accounts',
          color: const Color(0xFF37474F),
          route: '/users',
        ),
    ];

    return Scaffold(
      appBar: SangemarmarAppBar(
        title: const Text('Dashboard'),
        actions: [
          // Notification bell — only for admin/manager
          if (user?.isManager ?? false)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () async {
                    await context.push('/notifications');
                    _fetchUnreadCount();
                  },
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE07B65),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user?.name ?? 'User'}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              user?.role.replaceAll('_', ' ') ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            if (!(user?.isGateOperator ?? false)) ...[
              const SizedBox(height: 12),
              const _ExchangeRateChip(),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _DashCard(item: items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExchangeRateChip extends StatefulWidget {
  const _ExchangeRateChip();

  @override
  State<_ExchangeRateChip> createState() => _ExchangeRateChipState();
}

class _ExchangeRateChipState extends State<_ExchangeRateChip> {
  final _dio = Dio();
  double? _rate;
  DateTime? _updatedAt;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('https://open.er-api.com/v6/latest/USD');
      final inr = (res.data['rates']['INR'] as num).toDouble();
      if (mounted) setState(() { _rate = inr; _updatedAt = DateTime.now(); });
    } catch (_) {
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final rateText = _rate != null
        ? '1 USD = ₹${_rate!.toStringAsFixed(2)}'
        : _loading ? 'Fetching rate…' : 'Rate unavailable';

    final timeText = _updatedAt != null
        ? 'Updated ${_updatedAt!.hour.toString().padLeft(2, '0')}:${_updatedAt!.minute.toString().padLeft(2, '0')}'
        : '';

    return GestureDetector(
      onTap: _loading ? null : _fetch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3D5216).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3D5216).withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.currency_exchange, size: 16, color: Color(0xFF3D5216)),
            const SizedBox(width: 8),
            Text(
              rateText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3D5216),
              ),
            ),
            if (timeText.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                timeText,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(width: 6),
            _loading
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                : Icon(Icons.refresh, size: 14, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}

class _DashItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;

  const _DashItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.route,
  });
}

class _DashCard extends StatelessWidget {
  final _DashItem item;
  const _DashCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push(item.route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
