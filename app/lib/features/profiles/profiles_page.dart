import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Profiles - 节点列表 (现代简约)
class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  const Text(
                    'Profiles',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: FlowGateTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: FlowGateTheme.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded, color: FlowGateTheme.primary, size: 20),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 节点列表
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final nodes = [
      ('HK-01 | Azure', 'VLESS', '42 ms', true),
      ('JP-02 | AWS', 'Trojan', '68 ms', false),
      ('US-03 | GCP', 'VMess', '120 ms', false),
      ('SG-04 | DO', 'Shadowsocks', '55 ms', false),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final (name, type, delay, active) = nodes[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: active ? FlowGateTheme.primarySoft : FlowGateTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? FlowGateTheme.primary.withValues(alpha: 0.3) : FlowGateTheme.line,
              width: active ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            children: [
              // 协议标签
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: active ? FlowGateTheme.primary : FlowGateTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    type[0],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : FlowGateTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FlowGateTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type,
                      style: const TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary),
                    ),
                  ],
                ),
              ),
              // 延迟
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FlowGateTheme.successSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  delay,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FlowGateTheme.success,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
