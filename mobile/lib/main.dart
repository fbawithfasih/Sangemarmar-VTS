import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore session from saved token before first frame renders,
  // so the router redirect fires with correct auth state.
  final auth = AuthProvider();
  await auth.tryAutoLogin();

  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: const SangemarmarApp(),
    ),
  );
}
