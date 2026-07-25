import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/state/app_provider.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';

/// Dashboard - 连接状态、流量监控、一键开关
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 40),
              _ConnectButton(state: app.connectionState),
              const SizedBox(height: 40),
              _buildStatusCards(app),
              const SizedBox(height: 20),
              _buildNodeCard(app),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [FlowGateTheme.primary, FlowGateTheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text(
              'F',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'FlowGate',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: FlowGateTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.smart_toy_rounded, color: FlowGateTheme.textTertiary),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildStatusCards(AppState app) {
    final running = app.isRunning;
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.speed_rounded,
            iconColor: FlowGateTheme.primary,
            label: 'Latency',
            value: running && app.latencyMs != null ? '${app.latencyMs}' : '--',
            unit: 'ms',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.arrow_downward_rounded,
            iconColor: FlowGateTheme.success,
            label: running ? formatSpeed(app.traffic.downlinkSpeed) : 'Down',
            value: formatBytes(app.traffic.downlinkBytes),
            unit: '',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.arrow_upward_rounded,
            iconColor: FlowGateTheme.secondary,
            label: running ? formatSpeed(app.traffic.uplinkSpeed) : 'Up',
            value: formatBytes(app.traffic.uplinkBytes),
            unit: '',
          ),
        ),
      ],
    );
  }

  Widget _buildNodeCard(AppState app) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FlowGateTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlowGateTheme.line, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: FlowGateTheme.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.dns_rounded, color: FlowGateTheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Node',
                  style: TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary),
                ),
                const SizedBox(height: 3),
                Text(
                  app.currentNodeName ?? 'Tap to select',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: FlowGateTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: FlowGateTheme.textTertiary, size: 20),
        ],
      ),
    );
  }
}

/// 大连接按钮 - 状态驱动
class _ConnectButton extends ConsumerWidget {
  final VpnConnectionState state;
  const _ConnectButton({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = state == VpnConnectionState.connected;
    final isTransitioning = state == VpnConnectionState.connecting ||
        state == VpnConnectionState.disconnecting;

    final gradient = isRunning
        ? const LinearGradient(
            colors: [FlowGateTheme.success, Color(0xFF2DD4A8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [FlowGateTheme.primary, FlowGateTheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final statusText = switch (state) {
      VpnConnectionState.connected => 'Connected',
      VpnConnectionState.connecting => 'Connecting...',
      VpnConnectionState.disconnecting => 'Disconnecting...',
      VpnConnectionState.error => 'Error',
      VpnConnectionState.disconnected => 'Tap to Connect',
    };

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: isTransitioning ? null : () => ref.read(appProvider.notifier).toggleConnection(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gradient,
                boxShadow: [
                  BoxShadow(
                    color: (isRunning ? FlowGateTheme.success : FlowGateTheme.primary)
                        .withValues(alpha: 0.3),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: isTransitioning
                  ? const Padding(
                      padding: EdgeInsets.all(50),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(
                      isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              statusText,
              key: ValueKey(statusText),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isRunning ? FlowGateTheme.success : FlowGateTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 指标卡片
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: FlowGateTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlowGateTheme.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 10),
          Text(
            unit.isEmpty ? value : '$value $unit',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: FlowGateTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: FlowGateTheme.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
