import 'package:flutter/material.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/profiles/profiles_page.dart';
import '../../features/routing/routing_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/ai_assistant/ai_assistant_page.dart';

/// App 导航骨架 - 响应式: 手机底部导航 / 桌面侧边导航
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

  final _navigationItems = const [
    NavigationItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    NavigationItem(icon: Icons.dns_rounded, label: 'Profiles'),
    NavigationItem(icon: Icons.route_rounded, label: 'Routing'),
    NavigationItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  void _openAiAssistant() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiAssistantPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      return _buildWideLayout();
    }
    return _buildNarrowLayout();
  }

  Widget _buildNarrowLayout() {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: _navigationItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.icon, fill: 1),
                  label: item.label,
                ))
            .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAiAssistant,
        tooltip: 'AI Assistant',
        child: const Icon(Icons.smart_toy_rounded),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: IconButton(
                icon: const Icon(Icons.smart_toy_rounded),
                tooltip: 'AI Assistant',
                onPressed: _openAiAssistant,
              ),
            ),
            destinations: _navigationItems
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.icon, fill: 1),
                      label: Text(item.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  const NavigationItem({required this.icon, required this.label});
}
