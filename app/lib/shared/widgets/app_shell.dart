import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/state/tab_provider.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/profiles/profiles_page.dart';
import '../../features/routing/routing_page.dart';
import '../../features/settings/settings_page.dart';
import '../../gen_l10n/app_localizations.dart';

/// App 导航骨架 - 手机底部导航 / 桌面侧边导航
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _pages = [
    DashboardPage(),
    ProfilesPage(),
    RoutingPage(),
    SettingsPage(),
  ];

  static const _icons = [
    Icons.dashboard_rounded,
    Icons.dns_rounded,
    Icons.route_rounded,
    Icons.settings_rounded,
  ];

  List<String> _labels(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [l.tabHome, l.tabNodes, l.tabRouting, l.tabSettings];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(tabIndexProvider);
    final isWide = MediaQuery.of(context).size.width >= 600;
    if (isWide) return _buildWideLayout(context, ref, currentIndex);
    return _buildNarrowLayout(context, ref, currentIndex);
  }

  Widget _buildNarrowLayout(BuildContext context, WidgetRef ref, int currentIndex) {
    final labels = _labels(context);
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => ref.read(tabIndexProvider.notifier).state = i,
        destinations: List.generate(
          4,
          (i) => NavigationDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_icons[i], fill: 1),
            label: labels[i],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, WidgetRef ref, int currentIndex) {
    final labels = _labels(context);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (i) => ref.read(tabIndexProvider.notifier).state = i,
            labelType: NavigationRailLabelType.all,
            minWidth: 72,
            destinations: List.generate(
              4,
              (i) => NavigationRailDestination(
                icon: Icon(_icons[i]),
                selectedIcon: Icon(_icons[i], fill: 1),
                label: Text(labels[i]),
              ),
            ),
          ),
          const VerticalDivider(thickness: 0.5, width: 1),
          Expanded(child: IndexedStack(index: currentIndex, children: _pages)),
        ],
      ),
    );
  }
}
