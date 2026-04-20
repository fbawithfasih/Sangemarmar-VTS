import 'package:flutter/material.dart';

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
      actions: actions,
      bottom: bottom,
    );
  }
}
