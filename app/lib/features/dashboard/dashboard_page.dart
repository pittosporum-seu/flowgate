import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/state/app_provider.dart';
import '../../core/state/app_state.dart';
import '../../core/state/tab_provider.dart';
import '../../core/theme.dart';
import '../../gen_l10n/app_localizations.dart';
import '../ai_assistant/ai_assistant_page.dart';

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
              const SizedBox(height: 16),
              _buildLiveSpeed(app),
              const SizedBox(height: 8),
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
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AiAssistantPage()),
          ),
        ),
      ],
    );
  }

  /// 实时上下行速率（大字展示）
  Widget _buildLiveSpeed(AppState app) {
    final running = app.isRunning;
    final down = running ? formatSpeed(app.traffic.downlinkSpeed) : '--';
    final up = running ? formatSpeed(app.traffic.uplinkSpeed) : '--';
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_downward_rounded,
              size: 18,
              color: running ? FlowGateTheme.success : FlowGateTheme.textTertiary),
          const SizedBox(width: 4),
          Text(
            down,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: running ? FlowGateTheme.success : FlowGateTheme.textTertiary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 24),
          Icon(Icons.arrow_upward_rounded,
              size: 18,
              color: running ? FlowGateTheme.secondary : FlowGateTheme.textTertiary),
          const SizedBox(width: 4),
          Text(
            up,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: running ? FlowGateTheme.secondary : FlowGateTheme.textTertiary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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
    final l = AppLocalizations.of(context);
    // 将错误 key 解析为本地化字符串；非 key 则原样显示
    final displayText = switch (message) {
      'errNoNodeSelected' => l.errNoNodeSelected,
      'errNodeConfigMissing' => l.errNodeConfigMissing,
      'errConnectTimeout' => l.errConnectTimeout,
      _ => message,
    };
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
            child: Text(displayText,
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
            height: 160,
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
          curveSmoothness: 0.35,
          color: FlowGateTheme.success,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                FlowGateTheme.success.withValues(alpha: 0.28),
                FlowGateTheme.success.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        LineChartBarData(
          spots: upSpots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: FlowGateTheme.secondary,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                FlowGateTheme.secondary.withValues(alpha: 0.22),
                FlowGateTheme.secondary.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => ref.read(tabIndexProvider.notifier).state = 1,
      child: Container(
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

/// 连接按钮 - 状态驱动动效
class _ConnectButton extends ConsumerStatefulWidget {
  final VpnConnectionState state;
  const _ConnectButton({required this.state});

  @override
  ConsumerState<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends ConsumerState<_ConnectButton>
    with TickerProviderStateMixin {
  static const double _size = 180;
  late final AnimationController _breath; // 空闲呼吸
  late final AnimationController _pulse; // 连接声呐脉冲

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _ConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _syncControllers();
  }

  /// 根据连接状态启停动画控制器
  void _syncControllers() {
    final connected = widget.state == VpnConnectionState.connected;
    final transitioning = widget.state == VpnConnectionState.connecting ||
        widget.state == VpnConnectionState.disconnecting;
    if (connected) {
      _breath.stop();
      _breath.reset();
      _pulse.repeat();
    } else if (transitioning) {
      _breath.stop();
      _breath.reset();
      _pulse.stop();
      _pulse.reset();
    } else {
      // disconnected / error
      _pulse.stop();
      _pulse.reset();
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Color get _baseColor => switch (widget.state) {
        VpnConnectionState.connected => FlowGateTheme.success,
        VpnConnectionState.error => FlowGateTheme.danger,
        _ => FlowGateTheme.primary,
      };

  Gradient get _gradient => switch (widget.state) {
        VpnConnectionState.connected => const LinearGradient(
            colors: [FlowGateTheme.success, Color(0xFF2DD4A8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        VpnConnectionState.error => const LinearGradient(
            colors: [FlowGateTheme.danger, Color(0xFFFF8A95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        _ => const LinearGradient(
            colors: [FlowGateTheme.primary, FlowGateTheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final isRunning = widget.state == VpnConnectionState.connected;
    final isTransitioning = widget.state == VpnConnectionState.connecting ||
        widget.state == VpnConnectionState.disconnecting;

    return Center(
      child: SizedBox(
        width: _size + 56,
        height: _size + 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isRunning) _buildPulseRings(),
            if (isTransitioning) _buildSpinner(),
            _buildCore(isTransitioning),
          ],
        ),
      ),
    );
  }

  /// 连接时的声呐脉冲环（3 个同心环交错扩散）
  Widget _buildPulseRings() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(3, (i) {
            final phase = (_pulse.value + i / 3) % 1.0;
            final scale = 1.0 + phase * 0.5;
            final opacity = (1 - phase) * 0.45;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FlowGateTheme.success.withValues(alpha: opacity),
                    width: 2,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// 连接中的旋转流光环
  Widget _buildSpinner() {
    return SizedBox(
      width: _size + 24,
      height: _size + 24,
      child: const CircularProgressIndicator(
        color: FlowGateTheme.primary,
        strokeWidth: 3,
        strokeCap: StrokeCap.round,
      ),
    );
  }

  /// 核心按钮（空闲呼吸缩放）
  Widget _buildCore(bool isTransitioning) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final scale = 1.0 + _breath.value * 0.03;
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(appProvider.notifier).toggleConnection();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _gradient,
            boxShadow: [
              BoxShadow(
                color: _baseColor.withValues(alpha: 0.35),
                blurRadius: 36,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            isTransitioning
                ? Icons.hourglass_empty_rounded
                : Icons.power_settings_new_rounded,
            size: 60,
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(unit.isEmpty ? value : '$value $unit',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: FlowGateTheme.textPrimary),
                maxLines: 1),
          ),
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
