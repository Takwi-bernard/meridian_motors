import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardNavItem {
  const DashboardNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const List<DashboardNavItem> dashboardNavItems = [
  DashboardNavItem(
    icon: Icons.directions_car_outlined,
    selectedIcon: Icons.directions_car_filled,
    label: 'Browse Cars',
  ),
  DashboardNavItem(
    icon: Icons.favorite_border,
    selectedIcon: Icons.favorite,
    label: 'Favorites',
  ),
  DashboardNavItem(
    icon: Icons.event_available_outlined,
    selectedIcon: Icons.event_available,
    label: 'Reservations',
  ),
  DashboardNavItem(
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    label: 'Inquiries',
  ),
  DashboardNavItem(
    icon: Icons.notifications_none_outlined,
    selectedIcon: Icons.notifications,
    label: 'Notifications',
  ),
  DashboardNavItem(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'Profile',
  ),
];

/// The nav list — identical widget renders in the desktop sidebar and
/// the mobile Drawer so the two surfaces never drift apart visually.
class DashboardNavList extends StatelessWidget {
  const DashboardNavList({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSignOut,
    this.badgeCounts = const {},
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  /// Maps a tab index to an unread-notification count shown as a red pill.
  final Map<int, int> badgeCounts;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sidebar / Drawer header ──────────────────────────────────────
        _buildHeader(email),
        const SizedBox(height: 8),
        Divider(color: Colors.white.withOpacity(0.07), height: 1),
        const SizedBox(height: 8),

        // ── Nav items ────────────────────────────────────────────────────
        ...dashboardNavItems.asMap().entries.map(
              (entry) => _NavItem(
                index: entry.key,
                item: entry.value,
                selected: entry.key == selectedIndex,
                badge: badgeCounts[entry.key] ?? 0,
                onTap: () => onSelect(entry.key),
              ),
            ),

        const Spacer(),

        // ── Sign Out ────────────────────────────────────────────────────
        Divider(color: Colors.white.withOpacity(0.07), height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onSignOut,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded,
                        size: 20, color: Color(0xFFDC2626)),
                    const SizedBox(width: 14),
                    const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String email) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          // Logo
          Image.asset(
            'assets/images/meridian_logo.png',
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
              'MM',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meridian Motors',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.item,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final int index;
  final DashboardNavItem item;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Stack(
        children: [
          // Selected left-bar accent
          if (selected)
            Positioned(
              left: 0,
              top: 8,
              bottom: 8,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Material(
            color: selected
                ? Colors.white.withOpacity(0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 20,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF9CA3AF),
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    if (badge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
