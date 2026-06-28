import 'package:flutter/material.dart';

class DashboardNavItem {
  const DashboardNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

const List<DashboardNavItem> dashboardNavItems = [
  DashboardNavItem(icon: Icons.directions_car_filled, label: 'Browse Cars'),
  DashboardNavItem(icon: Icons.event_available, label: 'Reservations'),
  DashboardNavItem(icon: Icons.chat_bubble_outline, label: 'Inquiries'),
  DashboardNavItem(icon: Icons.person_outline, label: 'Profile'),
];

/// The nav list itself — same widget renders inside the desktop sidebar
/// and inside the mobile Drawer, so the two surfaces never drift apart.
class DashboardNavList extends StatelessWidget {
  const DashboardNavList({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSignOut,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'MERIDIAN MOTORS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...dashboardNavItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final selected = index == selectedIndex;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Material(
              color: selected ? Colors.white.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(
                  item.icon,
                  color: selected ? Colors.white : const Color(0xFF9CA3AF),
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF9CA3AF),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                onTap: () => onSelect(index),
              ),
            ),
          );
        }),
        const Spacer(),
        const Divider(color: Colors.white12, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.logout, color: Color(0xFF9CA3AF)),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
            ),
            onTap: onSignOut,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}