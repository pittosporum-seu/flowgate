import 'package:flutter/material.dart';

/// Routing - 模式选择 + 规则包
class RoutingPage extends StatefulWidget {
  const RoutingPage({super.key});

  @override
  State<RoutingPage> createState() => _RoutingPageState();
}

class _RoutingPageState extends State<RoutingPage> {
  int _selectedMode = 0;

  final _modes = const [
    _ModeItem(
      icon: Icons.auto_awesome_rounded,
      title: 'Smart',
      subtitle: 'CN direct, overseas proxy',
    ),
    _ModeItem(
      icon: Icons.public_rounded,
      title: 'Global',
      subtitle: 'All traffic via proxy',
    ),
    _ModeItem(
      icon: Icons.block_rounded,
      title: 'Block CN',
      subtitle: 'Block CN, proxy others',
    ),
    _ModeItem(
      icon: Icons.tune_rounded,
      title: 'Custom',
      subtitle: 'User-defined rules',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Routing')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Route Mode', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          ...List.generate(_modes.length, (i) {
            final mode = _modes[i];
            final selected = i == _selectedMode;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: selected
                  ? theme.colorScheme.primary.withOpacity(0.15)
                  : null,
              child: ListTile(
                leading: Icon(
                  mode.icon,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                title: Text(mode.title),
                subtitle: Text(mode.subtitle),
                trailing: selected
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : null,
                onTap: () => setState(() => _selectedMode = i),
              ),
            );
          }),
          const SizedBox(height: 24),
          Text('Rule Packs', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          ...['Smart CN', 'Service Adaptive', 'AdBlock', 'Streaming']
              .map((pack) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.extension_rounded),
                      title: Text(pack),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                  )),
        ],
      ),
    );
  }
}

class _ModeItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _ModeItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
