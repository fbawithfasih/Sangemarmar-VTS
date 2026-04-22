import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/vehicle_entry/vehicle_entry_list_screen.dart';
import '../../features/vehicle_entry/vehicle_entry_form_screen.dart';
import '../../features/sales/sales_form_screen.dart';
import '../../features/sales/sales_list_screen.dart';
import '../../features/sales/sale_edit_screen.dart';
import '../../features/payments/payment_form_screen.dart';
import '../../features/commissions/commission_screen.dart';
import '../../features/commissions/commission_config_screen.dart';
import '../../features/statements/statements_screen.dart';
import '../../features/statements/statement_detail_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/logistics/logistics_screen.dart';
import '../../features/users/users_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/module_select/module_select_screen.dart';
import '../../features/billing/billing_list_screen.dart';
import '../../features/billing/billing_form_screen.dart';
import '../../features/billing/billing_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final auth = context.read<AuthProvider>();
    final isLoggedIn = auth.isAuthenticated;
    final isLoginPage = state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoginPage) return '/login';
    if (isLoggedIn && isLoginPage) {
      return (auth.user?.isManager ?? false) ? '/module-select' : '/dashboard';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/module-select', builder: (_, __) => const ModuleSelectScreen()),
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/billing', builder: (_, __) => const BillingListScreen()),
    GoRoute(path: '/billing/new', builder: (_, __) => const BillingFormScreen()),
    GoRoute(
      path: '/billing/:id',
      builder: (_, state) => BillingDetailScreen(orderId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/billing/:id/edit',
      builder: (_, state) => BillingFormScreen(orderId: state.pathParameters['id']),
    ),
    GoRoute(path: '/vehicles', builder: (_, __) => const VehicleEntryListScreen()),
    GoRoute(path: '/vehicles/new', builder: (_, __) => const VehicleEntryFormScreen()),
    GoRoute(
      path: '/vehicles/:id',
      builder: (_, state) => VehicleEntryFormScreen(entryId: state.pathParameters['id']),
    ),
    GoRoute(path: '/sales', builder: (_, __) => const SalesListScreen()),
    GoRoute(
      path: '/sales/new',
      builder: (_, state) => SalesFormScreen(
        vehicleEntryId: state.uri.queryParameters['vehicleEntryId'],
      ),
    ),
    GoRoute(
      path: '/sales/:id/edit',
      builder: (_, state) => SaleEditScreen(saleId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/sales/:id/payments',
      builder: (_, state) => PaymentFormScreen(saleId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/sales/:id/commissions',
      builder: (_, state) => CommissionScreen(saleId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
    GoRoute(path: '/commissions/config', builder: (_, __) => const CommissionConfigScreen()),
    GoRoute(path: '/statements', builder: (_, __) => const StatementsScreen()),
    GoRoute(
      path: '/statements/detail',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return StatementDetailScreen(
          type: extra['type'] as String,
          name: extra['name'] as String,
        );
      },
    ),
    GoRoute(
      path: '/logistics/:vehicleEntryId',
      builder: (_, state) =>
          LogisticsScreen(vehicleEntryId: state.pathParameters['vehicleEntryId']!),
    ),
    GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
  ],
);
