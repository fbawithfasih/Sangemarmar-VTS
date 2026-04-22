import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SangemarmarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;

  const SangemarmarAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isManager = user?.isManager ?? false;
    final onModuleSelect =
        GoRouterState.of(context).matchedLocation == '/module-select';

    final mainMenuBtn = (isManager && !onModuleSelect)
        ? TextButton.icon(
            onPressed: () => context.go('/module-select'),
            icon: const Icon(Icons.grid_view_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Main Menu',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          )
        : null;

    final mergedActions = [
      if (mainMenuBtn != null) mainMenuBtn,
      ...?actions,
    ];

    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 30,
            width: 30,
          ),
          const SizedBox(width: 10),
          Flexible(child: title),
        ],
      ),
      actions: mergedActions.isEmpty ? null : mergedActions,
      bottom: bottom,
    );
  }
}
