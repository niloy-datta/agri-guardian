import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'route_paths.dart';
import '../core/localization/app_localizations.dart';

/// Persistent bottom-nav shell wrapping the 4 tab branches (Home, My
/// Fields, Insights, Profile) via go_router's `StatefulShellRoute.
/// indexedStack` (see `router.dart`). Anything nested under a branch -
/// including a drill-down screen like the satellite/field-health view
/// reached from the Insights tab, or Weather/Market/AI Assistant reached
/// from Home's quick actions - stays inside this shell, so the bottom
/// nav bar remains visible there too (previously those screens were
/// separate top-level routes with no nav bar at all).
///
/// Scan, and the screens Scan itself leads to (diagnosis, treatment
/// plan), stay OUTSIDE this shell on purpose - a focused capture/result
/// flow with no bottom nav, the same pattern a camera flow usually uses.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  static const _bg = Color(0xFF050C09);
  static const _line = Color(0xFF132A20);
  static const _mint = Color(0xFF2CEAA3);

  @override
  Widget build(BuildContext context) {
    // Each branch's own screen (HomeDashboardScreen, MyFieldsScreen,
    // FieldInsightsScreen, ProfileScreen) already manages its own
    // Scaffold/SafeArea/max-width centering exactly as it did before this
    // shell existed - this outer Scaffold only adds the persistent bottom
    // nav bar around whichever branch is currently showing.
    return Scaffold(
      backgroundColor: _bg,
      body: navigationShell,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF050C09).withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: _line, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _BottomNavItem(
                    icon: Icons.home_rounded,
                    label: l10n.home,
                    isSelected: navigationShell.currentIndex == 0,
                    onTap: () => navigationShell.goBranch(0),
                  ),
                ),
                Expanded(
                  child: _BottomNavItem(
                    icon: Icons.eco_outlined,
                    label: l10n.myFields,
                    isSelected: navigationShell.currentIndex == 1,
                    onTap: () => navigationShell.goBranch(1),
                  ),
                ),

                // Center Elevated Glowing Scan Button - not a shell branch,
                // a focused capture flow pushed on top with no bottom nav.
                GestureDetector(
                  onTap: () => context.push(RoutePaths.scan),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF061811),
                          border: Border.all(color: _mint, width: 2.2),
                          boxShadow: [
                            BoxShadow(
                              color: _mint.withValues(alpha: 0.45),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.filter_center_focus_rounded,
                            color: _mint,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.scan,
                        style: TextStyle(
                          color: _mint,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _BottomNavItem(
                    icon: Icons.bar_chart_rounded,
                    label: l10n.insights,
                    isSelected: navigationShell.currentIndex == 2,
                    onTap: () => navigationShell.goBranch(2),
                  ),
                ),
                Expanded(
                  child: _BottomNavItem(
                    icon: Icons.person_outline_rounded,
                    label: l10n.profile,
                    isSelected: navigationShell.currentIndex == 3,
                    onTap: () => navigationShell.goBranch(3),
                  ),
                ),
              ],
            ),
          ),

          // iPhone bottom indicator bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              width: 125,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22E57F);
    const muted = Color(0xFF829B90);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? green : muted, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? green : muted,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}