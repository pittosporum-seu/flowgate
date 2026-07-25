import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../log/log_page.dart';

/// Settings - 现代简约设置页
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: FlowGateTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            _section('General', [
              _item(Icons.language_rounded, 'Language', 'System default'),
              _item(Icons.dark_mode_rounded, 'Theme', 'Light'),
              _toggle(Icons.notifications_rounded, 'Notifications', true),
            ]),
            _section('DNS', [
              _item(Icons.dns_rounded, 'Remote DNS', '8.8.8.8'),
              _item(Icons.home_rounded, 'Domestic DNS', '223.5.5.5'),
              _toggle(Icons.security_rounded, 'FakeDNS', false),
            ]),
            _section('Advanced', [
              _item(Icons.speed_rounded, 'Speed Test URL', 'gstatic.com/generate_204'),
              _item(Icons.timer_rounded, 'Auto Update', 'Every 24h'),
            ]),
            _section('Debug', [
              _navItem(context, Icons.bug_report_rounded, 'Logs', 'View & share app logs',
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogPage()))),
            ]),
            _section('About', [
              _item(Icons.info_outline_rounded, 'Version', 'FlowGate 0.0.1'),
              _item(Icons.code_rounded, 'Source Code', 'github.com/pittosporum-seu'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FlowGateTheme.textSecondary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: FlowGateTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FlowGateTheme.line, width: 0.5),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _item(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 19, color: FlowGateTheme.textTertiary),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: FlowGateTheme.textPrimary))),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: FlowGateTheme.textTertiary)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, size: 16, color: FlowGateTheme.textTertiary),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 19, color: FlowGateTheme.textTertiary),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: FlowGateTheme.textPrimary))),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: FlowGateTheme.textTertiary)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 16, color: FlowGateTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _toggle(IconData icon, String title, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 19, color: FlowGateTheme.textTertiary),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: FlowGateTheme.textPrimary))),
          Switch(value: value, onChanged: (_) {}),
        ],
      ),
    );
  }
}
