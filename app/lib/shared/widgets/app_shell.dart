import 'package:flutter/material.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/profiles/profiles_page.dart';
import '../../features/routing/routing_page.dart';
import '../../features/settings/settings_page.dart';
import '../../gen_l10n/app_localizations.dart';

/// App 导航骨架 - 手机底部导航 / 桌面侧边导航
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final _pages = const [
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
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    if (isWide) return _buildWideLayout();
    return _buildNarrowLayout();
  }

  Widget _buildNarrowLayout() {
    final labels = _labels(context);
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
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

  Widget _buildWideLayout() {
    final labels = _labels(context);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
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
          Expanded(child: IndexedStack(index: _currentIndex, children: _pages)),
        ],
      ),
    );
  }
}
