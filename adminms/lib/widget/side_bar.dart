import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../component/colors.dart';

class SideBar extends StatefulWidget {
  final void Function(String)? onCategorySelect; // 🔹 Callback to InventoryPage
  final String currentPage; // Current page for highlighting

  const SideBar({super.key, this.onCategorySelect, this.currentPage = ''});

  @override
  State<SideBar> createState() => _SideBarState();
}

class _SideBarState extends State<SideBar> {
  String _currentTime = '';
  String _currentDate = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateDateTime(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateDateTime(DateTime.now());
    });
  }

  void _updateDateTime(DateTime now) {
    setState(() {
      _currentTime =
          "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}";
      _currentDate =
          "${_twoDigits(now.day)}/${_twoDigits(now.month)}/${now.year}";
    });
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 700;
    final bool isTablet = screenWidth < 1000 && screenWidth >= 700;
    final double sidebarWidth = isMobile ? 0 : (isTablet ? 180 : 220);

    if (isMobile) {
      return Drawer(
        backgroundColor: Colors.grey[300],
        child: _buildSidebarContent(context, isCollapsed: true),
      );
    }

    return Container(
      width: sidebarWidth,
      color: Colors.grey[300],
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _buildSidebarContent(context, isCollapsed: false),
        ),
      ),
    );
  }

  // ===== Sidebar Content =====
  Widget _buildSidebarContent(
    BuildContext context, {
    required bool isCollapsed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Time & Date
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _currentTime,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.pr,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _currentDate,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.pr,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),

        const Gap(10),

        // Logo Text
        RichText(
          text: const TextSpan(
            text: 'S',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xff6fad99),
              fontSize: 40,
              letterSpacing: 2.0,
            ),
            children: [
              TextSpan(
                text: 'PRS',
                style: TextStyle(
                  fontSize: 40,
                  letterSpacing: 1.0,
                  color: Color(0xff4a4a4a),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        RichText(
          text: const TextSpan(
            text: 'Where ',
            style: TextStyle(
              fontWeight: FontWeight.w200,
              color: Color(0xff4a4a4a),
              fontSize: 7,
              letterSpacing: 2.0,
            ),
            children: [
              TextSpan(
                text: 'Coffee ',
                style: TextStyle(
                  fontSize: 7,
                  letterSpacing: 2.0,
                  color: Color(0xff6fad99),
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: 'Meet Vibes',
                style: TextStyle(
                  fontWeight: FontWeight.w200,
                  color: Color(0xff4a4a4a),
                  fontSize: 7,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),

        const Gap(10),

        const Text("Hi,", style: TextStyle(fontSize: 14, color: Colors.black)),
        const Text(
          "Name",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),

        const Gap(12),

        // ===== Menu Buttons =====
        _buildMenuButton(Icons.dashboard, "Dashboard", routeName: '/dashboard'),
        _buildMenuButton(Icons.inventory, "Inventory", routeName: '/inventory',),
        _buildMenuButton(Icons.request_page,"Request", routeName: '/RequestItemPage',),
        _buildMenuButton(
          Icons.people,
          "Supplier",
          routeName: '/supplier',
          category: "Vegetables & Fruits",
        ),
        _buildMenuButton(Icons.person, "Employee", routeName: '/employee'),
        _buildMenuButton(Icons.receipt, "Orders", routeName: '/orders'),

        //const Gap(20),

        if (!isCollapsed)
          // Use errorBuilder to avoid crashing if the asset is missing or fails to load.
          Image.asset(
            'assets/logo/Image.png',
            width: 300,
            height: 300,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox(width: 140, height: 140),
          ),

        const Gap(10),

        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[400],
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text("Logout"),
          ),
        ),
      ],
    );
  }

  // ===== Menu Button =====
  Widget _buildMenuButton(
    IconData icon,
    String label, {
    String? routeName,
    String? category,
  }) {
    final bool isSelected = label == widget.currentPage;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isSelected ? Colors.grey[400] : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          // 🔹 If category callback exists, notify InventoryPage
          if (widget.onCategorySelect != null && category != null) {
            widget.onCategorySelect!(category);
          }

          // 🔹 Navigate between pages
          if (routeName != null) {
            Navigator.of(context).pushReplacementNamed(routeName);
          }

          // 🔹 Navigate between pages
          if (routeName != null) {
            Navigator.of(context).pushReplacementNamed(routeName);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xff4a4a4a), size: 28),
              const Gap(8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: const Color(0xff6fad99),
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(15),
            ],
          ),
        ),
      ),
    );
  }
}
