import 'package:flutter/material.dart';

/// Settings - 分组设置列表
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'General'),
          _SettingTile(icon: Icons.language_rounded, title: 'Language', subtitle: 'System default'),
          _SettingTile(icon: Icons.dark_mode_rounded, title: 'Theme', subtitle: 'Dark'),
          _SettingTile(icon: Icons.notifications_rounded, title: 'Notifications', trailing: Switch(value: true, onChanged: (_) {})),
          const SizedBox(height: 16),
          _SectionHeader(title: 'DNS'),
          _SettingTile(icon: Icons.dns_rounded, title: 'Remote DNS', subtitle: '8.8.8.8'),
          _SettingTile(icon: Icons.home_rounded, title: 'Domestic DNS', subtitle: '223.5.5.5'),
          _SettingTile(icon: Icons.security_rounded, title: 'FakeDNS', trailing: Switch(value: false, onChanged: (_) {})),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Advanced'),
          _SettingTile(icon: Icons.speed_rounded, title: 'Speed Test URL', subtitle: 'https://www.gstatic.com/generate_204'),
          _SettingTile(icon: Icons.timer_rounded, title: 'Auto Update', subtitle: 'Every 24h'),
          const SizedBox(height: 16),
          _SectionHeader(title: 'About'),
          _SettingTile(icon: Icons.info_outline_rounded, title: 'Version', subtitle: 'FlowGate 0.0.1'),
          _SettingTile(icon: Icons.code_rounded, title: 'Source Code', subtitle: 'github.com/pittosporum-seu/flowgate'),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, size: 22),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: trailing == null ? () {} : null,
      ),
    );
  }
}
