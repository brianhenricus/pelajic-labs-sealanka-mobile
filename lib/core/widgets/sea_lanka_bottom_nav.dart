import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/router/app_router.dart';

class SeaLankaBottomNav extends StatelessWidget {
  final Widget child;

  /// Tabs (0-4) that should show a notification badge dot.
  final Set<int> badgedTabs;

  const SeaLankaBottomNav({
    super.key,
    required this.child,
    this.badgedTabs = const {},
  });

  // Returns 0-4 for the 5 main tabs
  int _locationToIndex(String location) {
    if (location.startsWith(AppRoutes.pfz)) return 1;
    if (location.startsWith('/almanac')) return 2;
    if (location.startsWith(AppRoutes.marine)) return 3;
    if (location.startsWith(AppRoutes.logbook)) return 4;
    return 0; // home
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.pfz);
      case 2:
        context.go(AppRoutes.almanacWind);
      case 3:
        context.go(AppRoutes.marine);
      case 4:
        context.go(AppRoutes.logbook);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);
    final isAlmanac = currentIndex == 2;

    return Scaffold(
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Almanac sub-nav shelf — only visible when Almanac tab is active
          if (isAlmanac) _AlmanacSubNav(currentLocation: location),
          _BottomNavBar(
            currentIndex: currentIndex,
            onTap: (i) => _onTap(context, i),
            badgedTabs: badgedTabs,
          ),
        ],
      ),
    );
  }
}

class _AlmanacSubNav extends StatelessWidget {
  final String currentLocation;
  const _AlmanacSubNav({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.deepSeaBlue,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          _SubNavTab(
            label: AppLocalizations.of(context)!.navWindLabel,
            icon: Icons.air_rounded,
            route: AppRoutes.almanacWind,
            isActive: currentLocation.startsWith(AppRoutes.almanacWind),
          ),
          _SubNavTab(
            label: AppLocalizations.of(context)!.navCurrentsLabel,
            icon: Icons.waves_rounded,
            route: AppRoutes.almanacOcean,
            isActive: currentLocation.startsWith(AppRoutes.almanacOcean),
          ),
          _SubNavTab(
            label: AppLocalizations.of(context)!.navSolLunarLabel,
            icon: Icons.wb_sunny_rounded,
            route: AppRoutes.almanacSolunar,
            isActive: currentLocation.startsWith(AppRoutes.almanacSolunar),
          ),
        ],
      ),
    );
  }
}

class _SubNavTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final String route;
  final bool isActive;

  const _SubNavTab({
    required this.label,
    required this.icon,
    required this.route,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.go(route),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.skyBlue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? AppColors.skyBlue : Colors.white60,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.skyBlue : Colors.white60,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Set<int> badgedTabs;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    this.badgedTabs = const {},
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // DS bottom nav: active navy (marine on light) / inactive slate.
    final activeColor = isDark ? AppColors.skyBlue : AppColors.marineBlue;
    const inactiveColor = AppColors.fg3;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: AppLocalizations.of(context)!.navHomeLabel,
                isActive: currentIndex == 0,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.center_focus_strong_outlined,
                activeIcon: Icons.center_focus_strong,
                label: AppLocalizations.of(context)!.navPfzLabel,
                isActive: currentIndex == 1,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.wb_sunny_outlined,
                activeIcon: Icons.wb_sunny_rounded,
                label: AppLocalizations.of(context)!.navAlmanacLabel,
                isActive: currentIndex == 2,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.radar_outlined,
                activeIcon: Icons.radar,
                label: AppLocalizations.of(context)!.navMarineLabel,
                isActive: currentIndex == 3,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(3),
                hasBadge: badgedTabs.contains(3),
              ),
              _NavItem(
                icon: Icons.edit_note_outlined,
                activeIcon: Icons.edit_note_rounded,
                label: AppLocalizations.of(context)!.navLogbookLabel,
                isActive: currentIndex == 4,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final bool hasBadge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(isActive ? activeIcon : icon, color: color, size: 24),
                if (hasBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: color,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
