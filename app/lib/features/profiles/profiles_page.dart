import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/service/subscription_fetcher.dart';
import '../../core/state/app_provider.dart';
import '../../core/theme.dart';
import '../../gen_l10n/app_localizations.dart';
import 'model/profile_item.dart';
import 'profiles_provider.dart';
import 'server_edit_page.dart';
import 'subscriptions/subscriptions_provider.dart';

/// Profiles - 节点列表 (真实数据)
class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final selectedId = ref.watch(appProvider.select((s) => s.selectedProfileId));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context).profiles,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: FlowGateTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: FlowGateTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${profiles.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FlowGateTheme.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _HeaderButton(
                    icon: Icons.link_rounded,
                    tooltip: 'Import from link',
                    onPressed: () => _showImportDialog(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _HeaderButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Add node',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ServerEditPage()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: profiles.isEmpty
                  ? _buildEmpty(context)
                  : _buildList(context, ref, profiles, selectedId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns_outlined, size: 56, color: FlowGateTheme.textTertiary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noNodesYet,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: FlowGateTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Import from a subscription link\nor add a node manually',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: FlowGateTheme.textTertiary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<ProfileItem> profiles,
    String? selectedId,
  ) {
    final l = AppLocalizations.of(context);
    final subscriptions = ref.watch(subscriptionsProvider);

    // 按订阅分组
    final bySub = <String?, List<ProfileItem>>{};
    for (final p in profiles) {
      bySub.putIfAbsent(p.subscriptionId, () => []).add(p);
    }

    final widgets = <Widget>[];

    // 订阅分组（有订阅的节点）
    for (final sub in subscriptions) {
      final nodes = bySub[sub.id];
      if (nodes == null || nodes.isEmpty) continue;
      widgets.add(_SubscriptionHeader(sub: sub, count: nodes.length));
      for (final p in nodes) {
        widgets.add(_NodeRow(profile: p, active: p.id == selectedId));
      }
    }

    // 手动节点（无订阅）
    final manual = bySub[null];
    if (manual != null && manual.isNotEmpty) {
      widgets.add(_GroupHeader(title: l.manualNodes, count: manual.length));
      for (final p in manual) {
        widgets.add(_NodeRow(profile: p, active: p.id == selectedId));
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: widgets,
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    var loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.importNodes),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 5,
                  enabled: !loading,
                  decoration: InputDecoration(
                    hintText: l.importHint,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: Text(l.pasteFromClipboard),
                    onPressed: loading
                        ? null
                        : () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null) {
                              setDialogState(() => controller.text = data!.text!);
                            }
                          },
                  ),
                ),
                if (loading) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(l.fetchingSubscription,
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      setDialogState(() => loading = true);
                      try {
                        // URL → 保存为订阅并拉取节点；原始内容/链接 → 直接解析
                        final int count;
                        if (SubscriptionFetcher.isUrl(text)) {
                          count = await ref
                              .read(subscriptionsProvider.notifier)
                              .addSubscription(text);
                        } else {
                          count = await ref
                              .read(profilesProvider.notifier)
                              .importBatch(text);
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(count > 0
                                  ? l.importedCount(count)
                                  : l.noValidNodes),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.importFailed(e.toString()))),
                          );
                        }
                      }
                    },
              child: Text(l.import),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlowGateTheme.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(icon: Icon(icon, color: FlowGateTheme.primary, size: 20), tooltip: tooltip, onPressed: onPressed),
    );
  }
}

/// 订阅分组头：订阅名 + 节点数 + 刷新/删除
class _SubscriptionHeader extends ConsumerWidget {
  final dynamic sub;
  final int count;
  const _SubscriptionHeader({required this.sub, required this.count});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.subscriptions_outlined, size: 16, color: FlowGateTheme.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${sub.name}  ($count)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FlowGateTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final n = await ref.read(subscriptionsProvider.notifier).refreshSubscription(sub.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(n > 0 ? l.importedCount(n) : l.noValidNodes)),
                );
              }
            },
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: Text(l.refreshSubscription, style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: FlowGateTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 17, color: FlowGateTheme.danger),
            onPressed: () => ref.read(subscriptionsProvider.notifier).deleteSubscription(sub.id),
          ),
        ],
      ),
    );
  }
}

/// 普通分组头（手动节点）
class _GroupHeader extends StatelessWidget {
  final String title;
  final int count;
  const _GroupHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded, size: 16, color: FlowGateTheme.textTertiary),
          const SizedBox(width: 8),
          Text(
            '$title  ($count)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FlowGateTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 节点行：选择 + 测速 + 滑动删除
class _NodeRow extends ConsumerStatefulWidget {
  final ProfileItem profile;
  final bool active;
  const _NodeRow({required this.profile, required this.active});

  @override
  ConsumerState<_NodeRow> createState() => _NodeRowState();
}

class _NodeRowState extends ConsumerState<_NodeRow> {
  bool _testing = false;

  Future<void> _testSpeed() async {
    setState(() => _testing = true);
    await ref.read(appProvider.notifier).testDelay(widget.profile);
    if (mounted) setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final active = widget.active;
    return Dismissible(
      key: ValueKey(p.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: FlowGateTheme.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: FlowGateTheme.danger),
      ),
      onDismissed: (_) => ref.read(profilesProvider.notifier).remove(p.id),
      child: GestureDetector(
        onTap: () => ref.read(appProvider.notifier).selectProfile(p),
        child: Container(
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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: active ? FlowGateTheme.primary : FlowGateTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    p.type.label[0],
                    style: TextStyle(
                      fontSize: 13,
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
                      p.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: FlowGateTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.type.label}  ${p.server}:${p.port}',
                      style: const TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (p.latencyMs != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FlowGateTheme.successSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${p.latencyMs} ms',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: FlowGateTheme.success),
                  ),
                ),
              // 测速按钮
              _testing
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.speed_rounded, size: 19, color: FlowGateTheme.textTertiary),
                      tooltip: AppLocalizations.of(context).testSpeed,
                      onPressed: _testSpeed,
                    ),
              if (active)
                const Icon(Icons.check_circle_rounded, color: FlowGateTheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
