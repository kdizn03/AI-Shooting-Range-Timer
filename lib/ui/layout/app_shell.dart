import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_status_provider.dart';
import '../navigation.dart';
import '../screens/analytics_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/tokens.dart';
import '../widgets/readiness.dart';
import 'breakpoints.dart';

/// Destination metadata for primary navigation.
class _Destination {
  const _Destination(this.tab, this.label, this.icon, this.selectedIcon);
  final AppTab tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_Destination> _destinations = [
  _Destination(AppTab.home, 'Home', Icons.space_dashboard_outlined,
      Icons.space_dashboard),
  _Destination(AppTab.history, 'History', Icons.history, Icons.history),
  _Destination(AppTab.analytics, 'Analytics', Icons.insights_outlined,
      Icons.insights),
  _Destination(
      AppTab.settings, 'Settings', Icons.tune_outlined, Icons.tune),
];

/// Root layout with adaptive primary navigation:
/// bottom bar (< 768), navigation rail (768–1023), sidebar (≥ 1024).
///
/// Tab pages live in an [IndexedStack] so scroll position and filters are
/// preserved when switching sections.
class AppShell extends ConsumerWidget {
  /// Creates the [AppShell].
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTab tab = ref.watch(selectedTabProvider);
    final SizeClass sc = context.sizeClass;
    void select(int i) =>
        ref.read(selectedTabProvider.notifier).state = _destinations[i].tab;

    final Widget pages = IndexedStack(
      index: tab.index,
      children: const [
        HomeScreen(),
        HistoryScreen(),
        AnalyticsScreen(),
        SettingsScreen(),
      ],
    );

    if (sc.usesBottomNav) {
      return Scaffold(
        body: pages,
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: NavigationBar(
            selectedIndex: tab.index,
            onDestinationSelected: select,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        ),
      );
    }

    if (sc.usesRail) {
      return Scaffold(
        body: Row(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surfaceSunken,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                right: false,
                // Scrolls on short viewports (e.g. phones in landscape).
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: IntrinsicHeight(child: _rail(context, tab, select, c.maxHeight)),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: pages),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(selected: tab, onSelect: select),
          Expanded(child: pages),
        ],
      ),
    );
  }

  Widget _rail(BuildContext context, AppTab tab, ValueChanged<int> select,
      double height) {
    final bool short = height < 520;
    return NavigationRail(
      selectedIndex: tab.index,
      onDestinationSelected: select,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.8,
      leading: Padding(
        padding: EdgeInsets.only(
            top: AppSpace.md, bottom: short ? AppSpace.sm : AppSpace.xl),
        child: Column(
          children: [
            if (!short) ...[
              const BrandMark(size: 36),
              const SizedBox(height: AppSpace.xl),
            ],
            Tooltip(
              message: 'Start new session',
              child: FloatingActionButton(
                heroTag: 'rail-start',
                elevation: 0,
                mini: short,
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                onPressed: () => AppNav.startNewSession(context),
                child: const Icon(Icons.play_arrow),
              ),
            ),
          ],
        ),
      ),
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.selected, required this.onSelect});

  final AppTab selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: AppSizes.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSunken,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpace.xs, vertical: AppSpace.sm),
                child: BrandLockup(),
              ),
              const SizedBox(height: AppSpace.xl),
              FilledButton.icon(
                onPressed: () => AppNav.startNewSession(context),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('Start new session'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
              const SizedBox(height: AppSpace.xl),
              const Padding(
                padding: EdgeInsets.only(left: AppSpace.sm, bottom: AppSpace.sm),
                child: Text('NAVIGATION', style: AppType.overline),
              ),
              for (int i = 0; i < _destinations.length; i++)
                _SidebarItem(
                  destination: _destinations[i],
                  selected: _destinations[i].tab == selected,
                  onTap: () => onSelect(i),
                ),
              const Spacer(),
              const ReadinessPanel(compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? AppColors.accent : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected
              ? AppColors.tint(AppColors.accent, 0.10)
              : Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: AppSizes.minTouch,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: selected ? AppColors.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(selected ? destination.selectedIcon : destination.icon,
                      size: 20, color: fg),
                  const SizedBox(width: AppSpace.md),
                  Text(
                    destination.label,
                    style: AppType.body.copyWith(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
