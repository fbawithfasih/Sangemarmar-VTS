class ApiConstants {
  static const String baseUrl = 'https://backend-production-63d2.up.railway.app/api/v1';

  // Auth
  static const String login = '/auth/login';
  static const String me = '/auth/me';

  // Vehicles
  static const String vehicles = '/vehicles';

  // Sales
  static const String sales = '/sales';

  // Payments
  static const String payments = '/payments';

  // Commissions
  static const String commissions = '/commissions';
  static const String commissionConfig = '/commissions/config';

  // Reports
  static const String reports = '/reports';
  static const String reportsExport = '/reports/export';

  // Users
  static const String users = '/users';

  // Logistics
  static const String logistics = '/logistics';

  // Statements
  static const String statements = '/statements';
  static const String statementNames = '/statements/names';
  static const String statementExport = '/statements/export';

  // Billing
  static const String billing = '/billing';
  static const String billingExport = '/billing/export';

  // Shipping
  static const String shipping = '/shipping';
  static const String shippingRates = '/shipping/rates';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';
}
