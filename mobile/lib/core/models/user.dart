class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
      );

  bool get isAdmin => role == 'ADMIN';
  bool get isManager => role == 'MANAGER' || isAdmin;
  bool get isGateOperator => role == 'GATE_OPERATOR';
  bool get isSalesStaff => role == 'SALES_STAFF';
  bool get isCashier => role == 'CASHIER';

  bool get canCreateSale => isSalesStaff || isManager;

  bool get canCreatePayment => isCashier || isManager;

  bool get canOverrideCommissions => isManager;

  bool get canViewReports => isManager || isSalesStaff;

  bool get canViewStatements => isManager;

  bool get canEditCommissionRates => isManager;
}
