import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Routing - 模式选择 (现代简约)
class RoutingPage extends StatefulWidget {
  const RoutingPage({super.key});

  @override
  State<RoutingPage> createState() => _RoutingPageState();
}

class _RoutingPageState extends State<RoutingPage> {
  int _selectedMode = 0;

  final _modes = const [
    _ModeItem(Icons.auto_awesome_rounded, 'Smart', 'CN direct, overseas proxy'),
    _ModeItem(Icons.public_rounded, 'Global', 'All traffic via proxy'),
    _ModeItem(Icons.block_rounded, 'Block CN', 'Block CN, proxy others'),
    _ModeItem(Icons.tune_rounded, 'Custom', 'User-defined rules'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const Text(
              'Routing',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: FlowGateTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            // 模式选择
            const Text(
              'Mode',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FlowGateTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ...List.generate(_modes.length, (i) {
              final mode = _modes[i];
              final selected = i == _selectedMode;
              return GestureDetector(
                onTap: () => setState(() => _selectedMode = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? FlowGateTheme.primarySoft : FlowGateTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? FlowGateTheme.primary.withValues(alpha: 0.4) : FlowGateTheme.line,
                      width: selected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: selected ? FlowGateTheme.primary : FlowGateTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          mode.icon,
                          size: 18,
                          color: selected ? Colors.white : FlowGateTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: selected ? FlowGateTheme.primary : FlowGateTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mode.subtitle,
                              style: const TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle_rounded, color: FlowGateTheme.primary, size: 20),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 28),
            // 规则包
            const Text(
              'Rule Packs',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FlowGateTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ...[
              ('Smart CN', 'Geo-based routing', Icons.map_rounded),
              ('Service Adaptive', 'AI service detection', Icons.radar_rounded),
              ('AdBlock', 'Block advertisements', Icons.shield_rounded),
              ('Streaming', 'Media optimization', Icons.play_circle_outline_rounded),
            ].map((pack) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: FlowGateTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FlowGateTheme.line, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(pack.$3, size: 18, color: FlowGateTheme.textTertiary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pack.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FlowGateTheme.textPrimary)),
                            Text(pack.$2, style: const TextStyle(fontSize: 11, color: FlowGateTheme.textTertiary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: FlowGateTheme.textTertiary),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _ModeItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _ModeItem(this.icon, this.title, this.subtitle);
}
