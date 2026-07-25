import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/state/app_provider.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Dashboard - 连接控制 + 实时流量监控
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  static const _maxSamples = 30;
  final List<double> _upHistory = [];
  final List<double> _downHistory = [];
  int _lastUp = 0;
  int _lastDown = 0;

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);

    // 连接时采样流量速率用于曲线
    ref.listen<AppState>(appProvider, (prev, next) {
      if (next.isRunning) {
        final up = next.traffic.uplinkSpeed.toDouble();
        final down = next.traffic.downlinkSpeed.toDouble();
        if (up != _lastUp || down != _lastDown) {
          _lastUp = up.toInt();
          _lastDown = down.toInt();
          setState(() {
            _upHistory.add(up / 1024); // KB/s
            _downHistory.add(down / 1024);
            if (_upHistory.length > _maxSamples) _upHistory.removeAt(0);
            if (_downHistory.length > _maxSamples) _downHistory.removeAt(0);
          });
        }
      } else if (_upHistory.isNotEmpty) {
        setState(() {
          _upHistory.clear();
          _downHistory.clear();
        });
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _ConnectButton(state: app.connectionState),
              const SizedBox(height: 12),
              _buildDuration(app),
              if (app.errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildError(app.errorMessage!),
              ],
              const SizedBox(height: 28),
              _buildStatusCards(app),
              const SizedBox(height: 20),
              _buildTrafficChart(app),
              const SizedBox(height: 20),
              _buildNodeCard(app),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            child: Text('F',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1)),
          ),
        ),
        const SizedBox(width: 12),
        const Text('FlowGate',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: FlowGateTheme.textPrimary,
                letterSpacing: -0.5)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.smart_toy_rounded, color: FlowGateTheme.textTertiary),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildDuration(AppState app) {
    final l = AppLocalizations.of(context);
    final statusText = switch (app.connectionState) {
      VpnConnectionState.connected => l.connected,
      VpnConnectionState.connecting => l.connecting,
      VpnConnectionState.disconnecting => l.disconnecting,
      VpnConnectionState.error => l.error,
      VpnConnectionState.disconnected => l.disconnected,
    };
    final color = app.isRunning ? FlowGateTheme.success : FlowGateTheme.textSecondary;
    return Center(
      child: Text(
        app.isRunning ? '$statusText  ·  ${_formatDuration(app.durationSeconds)}' : statusText,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6EA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: FlowGateTheme.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 12, color: FlowGateTheme.danger)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCards(AppState app) {
    final l = AppLocalizations.of(context);
    final running = app.isRunning;
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.speed_rounded,
            iconColor: FlowGateTheme.primary,
            label: l.latency,
            value: running && app.latencyMs != null ? '${app.latencyMs}' : '--',
            unit: 'ms',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.arrow_downward_rounded,
            iconColor: FlowGateTheme.success,
            label: running ? formatSpeed(app.traffic.downlinkSpeed) : l.down,
            value: formatBytes(app.traffic.downlinkBytes),
            unit: '',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.arrow_upward_rounded,
            iconColor: FlowGateTheme.secondary,
            label: running ? formatSpeed(app.traffic.uplinkSpeed) : l.up,
            value: formatBytes(app.traffic.uplinkBytes),
            unit: '',
          ),
        ),
      ],
    );
  }

  Widget _buildTrafficChart(AppState app) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlowGateTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlowGateTheme.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l.traffic,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FlowGateTheme.textSecondary)),
              const Spacer(),
              _legendDot(FlowGateTheme.success, l.down),
              const SizedBox(width: 12),
              _legendDot(FlowGateTheme.secondary, l.up),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: _upHistory.length < 2
                ? Center(
                    child: Text(l.connectToSeeTraffic,
                        style: const TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary)))
                : LineChart(_chartData()),
          ),
        ],
      ),
    );
  }

  LineChartData _chartData() {
    final upSpots = <FlSpot>[
      for (var i = 0; i < _upHistory.length; i++) FlSpot(i.toDouble(), _upHistory[i]),
    ];
    final downSpots = <FlSpot>[
      for (var i = 0; i < _downHistory.length; i++) FlSpot(i.toDouble(), _downHistory[i]),
    ];
    return LineChartData(
      lineTouchData: const LineTouchData(enabled: false),
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: downSpots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: FlowGateTheme.success,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: FlowGateTheme.success.withValues(alpha: 0.12),
          ),
        ),
        LineChartBarData(
          spots: upSpots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: FlowGateTheme.secondary,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: FlowGateTheme.textTertiary)),
      ],
    );
  }

  Widget _buildNodeCard(AppState app) {
    final l = AppLocalizations.of(context);
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
                Text(l.currentNode,
                    style: const TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary)),
                const SizedBox(height: 3),
                Text(app.currentNodeName ?? l.tapToSelect,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: FlowGateTheme.textPrimary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: FlowGateTheme.textTertiary, size: 20),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

/// 连接按钮 - 状态驱动
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
            end: Alignment.bottomRight)
        : const LinearGradient(
            colors: [FlowGateTheme.primary, FlowGateTheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);

    return Center(
      child: GestureDetector(
        onTap: isTransitioning
            ? null
            : () => ref.read(appProvider.notifier).toggleConnection(),
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
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : Icon(
                  isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 56,
                  color: Colors.white,
                ),
        ),
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
          Text(unit.isEmpty ? value : '$value $unit',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: FlowGateTheme.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: FlowGateTheme.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
