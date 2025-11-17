import 'package:flutter/material.dart';
import 'package:adminms/component/colors.dart';

/// Reusable top bar used across dashboard, inventory, request and supplier pages.
/// Shows a left icon to toggle sidebar and a centered title. The parent page
/// should keep a local `isSidebarVisible` state and toggle it using the
/// provided callback.
class AppTopBar extends StatelessWidget {
  final bool isSidebarVisible;
  final VoidCallback onToggle;
  final String title;
  final Color? iconColor;

  const AppTopBar({
    Key? key,
    required this.isSidebarVisible,
    required this.onToggle,
    required this.title,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.black87;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(isSidebarVisible ? Icons.menu_open : Icons.menu, color: color),
          onPressed: onToggle,
        ),
        const Spacer(),
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900 , color : AppColors.se),
        ),
        const Spacer(),
      ],
    );
  }
}
