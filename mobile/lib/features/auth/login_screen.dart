import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  late final List<_VehicleAnim> _vehicles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _vehicles = List.generate(6, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(seconds: 6 + rng.nextInt(5)),
      )..repeat(reverse: true);

      final floatAnim = Tween<double>(begin: -12, end: 12).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );

      final driftController = AnimationController(
        vsync: this,
        duration: Duration(seconds: 10 + rng.nextInt(8)),
      )..repeat(reverse: true);

      final driftAnim = Tween<double>(begin: -18, end: 18).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );

      return _VehicleAnim(
        icon: _vehicleIcons[i % _vehicleIcons.length],
        x: 0.05 + rng.nextDouble() * 0.9,
        y: 0.05 + rng.nextDouble() * 0.9,
        size: 52 + rng.nextDouble() * 28,
        opacity: 0.06 + rng.nextDouble() * 0.08,
        floatController: controller,
        driftController: driftController,
        floatAnim: floatAnim,
        driftAnim: driftAnim,
        rotated: rng.nextBool(),
      );
    });
  }

  static const _vehicleIcons = [
    Icons.directions_car,
    Icons.directions_car_filled,
    Icons.electric_car,
    Icons.car_rental,
    Icons.car_repair,
    Icons.local_taxi,
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    for (final v in _vehicles) {
      v.floatController.dispose();
      v.driftController.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) {
      final user = context.read<AuthProvider>().user;
      context.go((user?.isManager ?? false) ? '/module-select' : '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Floating vehicle icons in background
          ..._vehicles.map((v) => AnimatedBuilder(
                animation: Listenable.merge([v.floatController, v.driftController]),
                builder: (context, _) {
                  return Positioned(
                    left: v.x * size.width + v.driftAnim.value,
                    top: v.y * size.height + v.floatAnim.value,
                    child: Opacity(
                      opacity: auth.loading
                          ? (v.opacity * 3).clamp(0.0, 0.35)
                          : v.opacity,
                      child: Transform.rotate(
                        angle: v.rotated ? pi : 0,
                        child: Icon(
                          v.icon,
                          size: auth.loading ? v.size * 1.3 : v.size,
                          color: const Color(0xFF3D5216),
                        ),
                      ),
                    ),
                  );
                },
              )),

          // Login form
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset('assets/images/logo.png', height: 120),
                        const SizedBox(height: 8),
                        Text(
                          'Vehicle Tracking System',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 40),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              v == null || !v.contains('@') ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passCtrl,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          obscureText: _obscure,
                          validator: (v) =>
                              v == null || v.length < 6 ? 'Enter your password' : null,
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(auth.error!,
                                style: TextStyle(color: Colors.red.shade700)),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: auth.loading ? null : _submit,
                          child: auth.loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign In'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleAnim {
  final IconData icon;
  final double x, y, size, opacity;
  final AnimationController floatController;
  final AnimationController driftController;
  final Animation<double> floatAnim;
  final Animation<double> driftAnim;
  final bool rotated;

  const _VehicleAnim({
    required this.icon,
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.floatController,
    required this.driftController,
    required this.floatAnim,
    required this.driftAnim,
    required this.rotated,
  });
}
