import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engine/config_assembler.dart';
import '../../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'model/routing_models.dart';
import 'routing_provider.dart';

/// Routing - 模式选择 + 自适应探测 + 规则预览
class RoutingPage extends ConsumerWidget {
  const RoutingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routing = ref.watch(routingProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(
              l.routing,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: FlowGateTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            // 模式选择
            Text(l.mode,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FlowGateTheme.textSecondary)),
            const SizedBox(height: 12),
            ...RouteMode.values.map((mode) => _ModeCard(
                  mode: mode,
                  selected: routing.mode == mode,
                  onTap: () => ref.read(routingProvider.notifier).setMode(mode),
                )),
            const SizedBox(height: 28),
            // 自适应探测
            _buildAdaptiveSection(context, ref, routing),
            const SizedBox(height: 28),
            // 编译后的规则
            _buildRulesSection(context, routing),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptiveSection(BuildContext context, WidgetRef ref, RoutingState routing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Service Adaptive',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FlowGateTheme.textSecondary)),
            const Spacer(),
            SizedBox(
              height: 32,
              child: FilledButton.icon(
                onPressed: routing.isProbing
                    ? null
                    : () => ref.read(routingProvider.notifier).probeServices(),
                icon: routing.isProbing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.radar_rounded, size: 16),
                label: Text(routing.isProbing ? 'Probing' : 'Probe'),
                style: FilledButton.styleFrom(
                  backgroundColor: FlowGateTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (routing.decisions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FlowGateTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: FlowGateTheme.line, width: 0.5),
            ),
            child: const Column(
              children: [
                Icon(Icons.radar_rounded, size: 28, color: FlowGateTheme.textTertiary),
                SizedBox(height: 8),
                Text('Run a probe to detect\nservice availability',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary, height: 1.5)),
              ],
            ),
          )
        else
          ...routing.decisions.map((d) => _DecisionRow(decision: d)),
      ],
    );
  }

  Widget _buildRulesSection(BuildContext context, RoutingState routing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(AppLocalizations.of(context).compiledRules,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FlowGateTheme.textSecondary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: FlowGateTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${routing.compiledRules.length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: FlowGateTheme.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (routing.compiledRules.isEmpty)
          Text(AppLocalizations.of(context).rulesEmptyHint,
              style: const TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary))
        else
          Container(
            decoration: BoxDecoration(
              color: FlowGateTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: FlowGateTheme.line, width: 0.5),
            ),
            child: Column(
              children: routing.compiledRules
                  .map((r) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        child: Row(
                          children: [
                            _OutboundBadge(tag: r.outboundTag),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(r.remarks,
                                  style: const TextStyle(fontSize: 13, color: FlowGateTheme.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 12),
        if (routing.compiledRules.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showXrayJsonDialog(context, routing.compiledRules),
              icon: const Icon(Icons.data_object_rounded, size: 16),
              label: Text(AppLocalizations.of(context).viewXrayJson),
              style: OutlinedButton.styleFrom(
                foregroundColor: FlowGateTheme.primary,
                side: const BorderSide(color: FlowGateTheme.line),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
      ],
    );
  }

  void _showXrayJsonDialog(BuildContext context, List<RulesetItem> rules) {
    final json = ConfigAssembler.buildRoutingPreview(rules);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).xrayRouting),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).close)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final RouteMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({required this.mode, required this.selected, required this.onTap});

  IconData get _icon => switch (mode) {
        RouteMode.smart => Icons.auto_awesome_rounded,
        RouteMode.global => Icons.public_rounded,
        RouteMode.blockCn => Icons.block_rounded,
        RouteMode.custom => Icons.tune_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              child: Icon(_icon, size: 18, color: selected ? Colors.white : FlowGateTheme.textTertiary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? FlowGateTheme.primary : FlowGateTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(mode.description,
                      style: const TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: FlowGateTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  final ServiceRoutingDecision decision;
  const _DecisionRow({required this.decision});

  @override
  Widget build(BuildContext context) {
    final target = defaultServiceTargets.firstWhere(
      (t) => t.id == decision.serviceId,
      orElse: () => ServiceTarget(id: decision.serviceId, title: decision.serviceId),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FlowGateTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlowGateTheme.line, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(target.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FlowGateTheme.textPrimary)),
          ),
          _ActionBadge(action: decision.action),
        ],
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  final RouteAction action;
  const _ActionBadge({required this.action});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (action) {
      RouteAction.proxy => ('PROXY', FlowGateTheme.primary, FlowGateTheme.primarySoft),
      RouteAction.direct => ('DIRECT', FlowGateTheme.success, FlowGateTheme.successSoft),
      RouteAction.block => ('BLOCK', FlowGateTheme.danger, const Color(0xFFFFE6EA)),
      RouteAction.unavailable => ('N/A', FlowGateTheme.textTertiary, FlowGateTheme.surfaceAlt),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _OutboundBadge extends StatelessWidget {
  final OutboundTag tag;
  const _OutboundBadge({required this.tag});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (tag) {
      OutboundTag.proxy => ('PROXY', FlowGateTheme.primary, FlowGateTheme.primarySoft),
      OutboundTag.direct => ('DIRECT', FlowGateTheme.success, FlowGateTheme.successSoft),
      OutboundTag.block => ('BLOCK', FlowGateTheme.danger, const Color(0xFFFFE6EA)),
    };
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
