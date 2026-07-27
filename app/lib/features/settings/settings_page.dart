import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/state/locale_provider.dart';
import '../../core/theme.dart';
import '../../gen_l10n/app_localizations.dart';
import '../log/log_page.dart';
import 'settings_provider.dart';

/// Settings - 现代简约设置页
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(
              l.settings,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: FlowGateTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            _section(l.general, [
              _navItem(context, Icons.language_rounded, l.language, _localeLabel(locale, l),
                  () => _showLanguageDialog(context, ref, l)),
              _item(Icons.dark_mode_rounded, l.theme, 'Light'),
              _toggle(Icons.notifications_rounded, l.notifications, settings.notifications,
                  (v) => ref.read(settingsProvider.notifier).setNotifications(v)),
            ]),
            _section(l.dns, [
              _item(Icons.dns_rounded, l.remoteDns, settings.remoteDns,
                  onTap: () => _editText(context, ref, l.remoteDns, settings.remoteDns,
                      (v) => ref.read(settingsProvider.notifier).setRemoteDns(v))),
              _item(Icons.home_rounded, l.domesticDns, settings.domesticDns,
                  onTap: () => _editText(context, ref, l.domesticDns, settings.domesticDns,
                      (v) => ref.read(settingsProvider.notifier).setDomesticDns(v))),
              _toggle(Icons.security_rounded, l.fakeDns, settings.fakeDns,
                  (v) => ref.read(settingsProvider.notifier).setFakeDns(v)),
            ]),
            _section(l.advanced, [
              _item(Icons.speed_rounded, l.speedTestUrl, settings.speedTestUrl,
                  onTap: () => _editText(context, ref, l.speedTestUrl, settings.speedTestUrl,
                      (v) => ref.read(settingsProvider.notifier).setSpeedTestUrl(v))),
              _item(Icons.timer_rounded, l.autoUpdate, 'Every 24h'),
            ]),
            _section(l.debug, [
              _navItem(context, Icons.bug_report_rounded, l.logs, l.logsSubtitle,
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogPage()))),
            ]),
            _section(l.about, [
              _item(Icons.info_outline_rounded, l.version, 'FlowGate 0.0.1'),
              _item(Icons.code_rounded, l.sourceCode, 'github.com/pittosporum-seu'),
            ]),
          ],
        ),
      ),
    );
  }

  String _localeLabel(dynamic locale, AppLocalizations l) {
    if (locale == null) return l.followSystem;
    return (locale.languageCode as String) == 'zh' ? l.chinese : l.english;
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, AppLocalizations l) {
    final current = ref.read(localeProvider);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.language),
        children: [
          _langOption(ctx, ref, l.followSystem, null, current == null),
          _langOption(ctx, ref, l.chinese, const Locale('zh'), current?.languageCode == 'zh'),
          _langOption(ctx, ref, l.english, const Locale('en'), current?.languageCode == 'en'),
        ],
      ),
    );
  }

  Widget _langOption(BuildContext ctx, WidgetRef ref, String label, dynamic value, bool selected) {
    return SimpleDialogOption(
      onPressed: () {
        ref.read(localeProvider.notifier).setLocale(value);
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20, color: selected ? FlowGateTheme.primary : FlowGateTheme.textTertiary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 15)),
        ],
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

  Widget _item(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
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
            const SizedBox(width: 8),
            Flexible(
              child: Text(subtitle,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: FlowGateTheme.textTertiary)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 16, color: FlowGateTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  /// 文本编辑对话框
  Future<void> _editText(BuildContext context, WidgetRef ref, String title,
      String current, ValueChanged<String> onSave) async {
    final controller = TextEditingController(text: current);
    final l = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(l.save)),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) onSave(result);
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
            Flexible(child: Text(subtitle, style: const TextStyle(fontSize: 13, color: FlowGateTheme.textTertiary))),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 16, color: FlowGateTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _toggle(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 19, color: FlowGateTheme.textTertiary),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: FlowGateTheme.textPrimary))),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
