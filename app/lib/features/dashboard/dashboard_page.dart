import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Dashboard - 现代简约风格
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context),
              const SizedBox(height: 40),
              // 连接按钮
              const _ConnectButton(),
              const SizedBox(height: 40),
              // 状态卡片
              _buildStatusCards(context),
              const SizedBox(height: 20),
              // 当前节点
              _buildNodeCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Logo mark
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

  Widget _buildStatusCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.speed_rounded,
            iconColor: FlowGateTheme.primary,
            label: 'Latency',
            value: '--',
            unit: 'ms',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.arrow_downward_rounded,
            iconColor: FlowGateTheme.success,
            label: 'Down',
            value: '0',
            unit: 'B',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.arrow_upward_rounded,
            iconColor: FlowGateTheme.secondary,
            label: 'Up',
            value: '0',
            unit: 'B',
          ),
        ),
      ],
    );
  }

  Widget _buildNodeCard(BuildContext context) {
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Node',
                  style: TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary),
                ),
                SizedBox(height: 3),
                Text(
                  'Tap to select',
                  style: TextStyle(
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

/// 大连接按钮 - 渐变圆环
class _ConnectButton extends StatefulWidget {
  const _ConnectButton();

  @override
  State<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<_ConnectButton> {
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _connected = !_connected),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _connected
                    ? const LinearGradient(
                        colors: [FlowGateTheme.success, Color(0xFF2DD4A8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [FlowGateTheme.primary, FlowGateTheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (_connected ? FlowGateTheme.success : FlowGateTheme.primary)
                        .withValues(alpha: 0.3),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                _connected ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _connected ? 'Connected' : 'Tap to Connect',
              key: ValueKey(_connected),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _connected ? FlowGateTheme.success : FlowGateTheme.textSecondary,
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
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: FlowGateTheme.textPrimary,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(fontSize: 11, color: FlowGateTheme.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: FlowGateTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}
