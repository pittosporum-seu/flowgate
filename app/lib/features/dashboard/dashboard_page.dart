import 'package:flutter/material.dart';

/// Dashboard - 连接状态、大按钮、信息卡片
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('FlowGate')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 状态文字
              Text(
                'Disconnected',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              // 大圆形连接按钮
              _ConnectButton(),
              const SizedBox(height: 48),
              // 信息卡片
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusCard(
                    icon: Icons.speed_rounded,
                    label: 'Latency',
                    value: '-- ms',
                  ),
                  const SizedBox(width: 12),
                  _StatusCard(
                    icon: Icons.swap_vert_rounded,
                    label: 'Traffic',
                    value: '0 B',
                  ),
                  const SizedBox(width: 12),
                  _StatusCard(
                    icon: Icons.route_rounded,
                    label: 'Mode',
                    value: 'Smart',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 当前节点
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.dns_rounded,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Node',
                                style: theme.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text('No node selected',
                                style: theme.textTheme.bodyLarge),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectButton extends StatefulWidget {
  @override
  State<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<_ConnectButton> {
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _connected ? Colors.green : theme.colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() => _connected = !_connected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.15),
          border: Border.all(color: color, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          _connected ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 64,
          color: color,
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(value,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}
