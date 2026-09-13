import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/api_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore session from saved token before first frame renders,
  // so the router redirect fires with correct auth state.
  final auth = AuthProvider();
  await auth.tryAutoLogin();

  // Any later 401 means the token expired mid-session: sign out and return
  // to the login screen (the router doesn't redirect on auth changes itself).
  ApiService.onUnauthorized = () async {
    if (!auth.isAuthenticated) return;
    await auth.expireSession();
    appRouter.go('/login');
  };

  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: const SangemarmarApp(),
    ),
  );
}
