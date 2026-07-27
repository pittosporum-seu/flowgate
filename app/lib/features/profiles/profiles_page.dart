import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/state/app_provider.dart';
import '../../core/theme.dart';
import '../../gen_l10n/app_localizations.dart';
import '../qr_scan/qr_scan_page.dart';
import 'model/profile_item.dart';
import 'model/subscription_item.dart';
import 'profiles_provider.dart';
import 'subscriptions/subscriptions_provider.dart';

/// M3 节点管理页：搜索 + 分组（可折叠/改名）+ 节点（测速）
class ProfilesPage extends ConsumerStatefulWidget {
  const ProfilesPage({super.key});

  @override
  ConsumerState<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends ConsumerState<ProfilesPage> {
  final _urlController = TextEditingController();
  final _rawController = TextEditingController();
  final _searchController = TextEditingController();
  final _renameController = TextEditingController();
  bool _importing = false;
  final Set<String> _collapsed = {}; // 折叠的分组 id
  String _query = '';

  static const _manualGroupId = '__manual__';

  @override
  void dispose() {
    _urlController.dispose();
    _rawController.dispose();
    _searchController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profiles = ref.watch(profilesProvider);
    final app = ref.watch(appProvider);
    final subs = ref.watch(subscriptionsProvider);

    // 搜索过滤
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? profiles
        : profiles
            .where((p) =>
                p.name.toLowerCase().contains(query) ||
                p.server.toLowerCase().contains(query))
            .toList();

    // 按订阅分组
    final bySub = <String?, List<ProfileItem>>{};
    for (final p in filtered) {
      bySub.putIfAbsent(p.subscriptionId, () => []).add(p);
    }

    // 搜索时强制展开所有分组，方便查看结果
    bool isExpanded(String id) => query.isNotEmpty || !_collapsed.contains(id);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页头：标题 + 一键测速 + 添加
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tabNodes,
                      style: Theme.of(context).appBarTheme.titleTextStyle,
                    ),
                  ),
                  _headerIconButton(
                    Icons.bolt_outlined,
                    l10n.testAllSpeeds,
                    _testAll,
                  ),
                  const SizedBox(width: 8),
                  _headerIconButton(
                    Icons.qr_code_scanner,
                    l10n.qrScanTitle,
                    _openQrScan,
                  ),
                  const SizedBox(width: 8),
                  _headerIconButton(
                    Icons.add,
                    l10n.importNodes,
                    () => _showImportDialog(context, l10n),
                  ),
                ],
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l10n.searchNodes,
                  hintStyle: const TextStyle(
                    color: FlowGateTheme.textTertiary,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: FlowGateTheme.textTertiary,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: FlowGateTheme.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // 节点列表
            Expanded(
              child: filtered.isEmpty
                  ? _emptyState(l10n)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        // 订阅分组
                        for (final sub in subs)
                          if (bySub[sub.id] != null) ...[
                            _SubscriptionHeader(
                              sub: sub,
                              count: bySub[sub.id]!.length,
                              expanded: isExpanded(sub.id),
                              onToggle: () => _toggleGroup(sub.id),
                              onRefresh: () => _refreshSub(sub.id),
                              onTestSpeed: () => _testGroup(bySub[sub.id]!),
                              onRename: () => _showRenameDialog(
                                  context, l10n, sub.id, sub.name),
                              onDelete: () => _confirmDeleteSub(
                                  context, l10n, sub.id, sub.name),
                            ),
                            if (isExpanded(sub.id))
                              for (final p in bySub[sub.id]!)
                                _NodeRow(
                                  profile: p,
                                  selected: app.selectedProfileId == p.id,
                                  onTap: () => ref
                                      .read(appProvider.notifier)
                                      .selectProfile(p),
                                  onTestSpeed: () => _testSpeed(p),
                                  onShare: () => _shareNode(p),
                                ),
                          ],
                        // 手动节点组
                        if (bySub[null] != null) ...[
                          _GroupHeader(
                            title: l10n.manualNodes,
                            count: bySub[null]!.length,
                            expanded: isExpanded(_manualGroupId),
                            onToggle: () => _toggleGroup(_manualGroupId),
                            onTestSpeed: () => _testGroup(bySub[null]!),
                          ),
                          if (isExpanded(_manualGroupId))
                            for (final p in bySub[null]!)
                              _NodeRow(
                                profile: p,
                                selected: app.selectedProfileId == p.id,
                                onTap: () => ref
                                    .read(appProvider.notifier)
                                    .selectProfile(p),
                                onTestSpeed: () => _testSpeed(p),
                                onShare: () => _shareNode(p),
                              ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleGroup(String id) {
    setState(() {
      if (_collapsed.contains(id)) {
        _collapsed.remove(id);
      } else {
        _collapsed.add(id);
      }
    });
  }

  Widget _headerIconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: FlowGateTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: FlowGateTheme.textPrimary),
          ),
        ),
      ),
    );
  }

  Future<void> _testSpeed(ProfileItem p) async {
    final delay = await ref.read(appProvider.notifier).testDelay(p);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(delay == null
          ? '${p.name}: ${AppLocalizations.of(context).testSpeedFailed}'
          : '${p.name}: ${delay}ms'),
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _testAll() async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.testAllStarted),
      duration: const Duration(seconds: 1),
    ));
    // 后台串行测速，结果逐个写回
    await ref.read(appProvider.notifier).testAllDelays();
  }

  void _openQrScan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
  }

  void _shareNode(ProfileItem p) {
    // 导出为分享链接（优先用 rawConfig，否则用基本信息）
    final content = p.rawConfig ?? '${p.type.scheme}://${p.server}:${p.port}#${Uri.encodeComponent(p.name)}';
    Share.share(content, subject: p.name);
  }

  /// 按分组测速：只测该分组内的节点
  Future<void> _testGroup(List<ProfileItem> nodes) async {
    if (nodes.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.testAllStarted),
      duration: const Duration(seconds: 1),
    ));
    await ref.read(appProvider.notifier).testAllDelays(nodes);
  }

  Future<void> _refreshSub(String id) async {
    final l10n = AppLocalizations.of(context);
    try {
      final count =
          await ref.read(subscriptionsProvider.notifier).refreshSubscription(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count > 0
            ? l10n.refreshedNodes(count)
            : l10n.refreshFailed),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${l10n.refreshFailed}: $e'),
        backgroundColor: FlowGateTheme.danger,
      ));
    }
  }

  Widget _emptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_queue,
              size: 56, color: FlowGateTheme.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            _query.isEmpty ? l10n.noNodesYet : l10n.noSearchResult,
            style: const TextStyle(color: FlowGateTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context, AppLocalizations l10n) async {
    _urlController.clear();
    _rawController.clear();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importNodes),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: l10n.subscriptionUrl,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rawController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l10n.rawConfig,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null && data!.text!.isNotEmpty) {
                        _rawController.text = data.text!;
                      }
                    },
                    icon: const Icon(Icons.paste, size: 16),
                    label: Text(l10n.pasteFromClipboard),
                    style: TextButton.styleFrom(
                      foregroundColor: FlowGateTheme.primary,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _importing ? null : () => Navigator.of(ctx).pop('ok'),
            child: _importing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.import),
          ),
        ],
      ),
    );
    if (result != 'ok') return;
    await _doImport(context, l10n);
  }

  Future<void> _doImport(BuildContext context, AppLocalizations l10n) async {
    final url = _urlController.text.trim();
    final raw = _rawController.text.trim();
    if (url.isEmpty && raw.isEmpty) return;

    setState(() => _importing = true);
    try {
      int count;
      if (url.isNotEmpty) {
        // URL → 保存为订阅，节点自动归入该订阅分组
        count =
            await ref.read(subscriptionsProvider.notifier).addSubscription(url);
      } else {
        count = await ref.read(profilesProvider.notifier).importBatch(raw);
      }
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count > 0
            ? l10n.importedCount(count)
            : l10n.noValidNodes),
        backgroundColor:
            count > 0 ? FlowGateTheme.success : FlowGateTheme.danger,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.importFailed(e.toString())),
        backgroundColor: FlowGateTheme.danger,
      ));
    }
  }

  Future<void> _showRenameDialog(
      BuildContext context, AppLocalizations l10n, String subId, String currentName) async {
    _renameController.text = currentName;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameGroup),
        content: TextField(
          controller: _renameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.groupName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_renameController.text),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    await ref.read(subscriptionsProvider.notifier).renameSubscription(subId, result);
  }

  Future<void> _confirmDeleteSub(
      BuildContext context, AppLocalizations l10n, String subId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSubscription),
        content: Text(l10n.deleteSubscriptionConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FlowGateTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(subscriptionsProvider.notifier).deleteSubscription(subId);
  }
}

/// 订阅分组头（可折叠 + 刷新/改名/删除）
class _SubscriptionHeader extends StatelessWidget {
  final SubscriptionItem sub;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;
  final VoidCallback onTestSpeed;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SubscriptionHeader({
    required this.sub,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.onRefresh,
    required this.onTestSpeed,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedRotation(
                        turns: expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: const Icon(Icons.chevron_right,
                            size: 18, color: FlowGateTheme.textTertiary),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.link, size: 14, color: FlowGateTheme.secondary),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          sub.name.isEmpty ? sub.id : sub.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: FlowGateTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: const TextStyle(
                            fontSize: 12, color: FlowGateTheme.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _miniIcon(Icons.bolt_outlined, onTestSpeed),
              _miniIcon(Icons.refresh, onRefresh),
              _miniIcon(Icons.edit_outlined, onRename),
              _miniIcon(Icons.delete_outline, onDelete),
            ],
          ),
          // 流量元数据展示
          if (sub.total > 0) ..._buildUsageInfo(context),
        ],
      ),
    );
  }

  List<Widget> _buildUsageInfo(BuildContext context) {
    final usedStr = _formatBytes(sub.used);
    final totalStr = _formatBytes(sub.total);
    final ratio = sub.usageRatio;
    final barColor = ratio > 0.9
        ? FlowGateTheme.danger
        : ratio > 0.7
            ? Colors.orange
            : FlowGateTheme.secondary;

    return [
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.only(left: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 流量进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                width: 120,
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  backgroundColor: FlowGateTheme.line,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  '$usedStr / $totalStr',
                  style: const TextStyle(
                      fontSize: 10, color: FlowGateTheme.textTertiary),
                ),
                if (sub.expire > 0) ...[
                  const SizedBox(width: 10),
                  Icon(
                    sub.isExpired ? Icons.event_busy : Icons.event,
                    size: 11,
                    color: sub.isExpired
                        ? FlowGateTheme.danger
                        : FlowGateTheme.textTertiary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatExpire(sub.expire),
                    style: TextStyle(
                      fontSize: 10,
                      color: sub.isExpired
                          ? FlowGateTheme.danger
                          : FlowGateTheme.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ];
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  static String _formatExpire(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Widget _miniIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 15, color: FlowGateTheme.textTertiary),
      ),
    );
  }
}

/// 普通分组头（手动节点，可折叠）
class _GroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onTestSpeed;

  const _GroupHeader({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.onTestSpeed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(Icons.chevron_right,
                    size: 18, color: FlowGateTheme.textTertiary),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.person_outline,
                  size: 14, color: FlowGateTheme.textTertiary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FlowGateTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style:
                    const TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onTestSpeed,
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(Icons.bolt_outlined,
                      size: 15, color: FlowGateTheme.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 节点行：名称 + 服务器/端口 + 延迟 + 测速按钮
class _NodeRow extends StatelessWidget {
  final ProfileItem profile;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onTestSpeed;
  final VoidCallback onShare;

  const _NodeRow({
    required this.profile,
    required this.selected,
    required this.onTap,
    required this.onTestSpeed,
    required this.onShare,
  });

  Color _latencyColor(int ms) {
    if (ms < 200) return FlowGateTheme.success;
    if (ms < 500) return FlowGateTheme.warning;
    return FlowGateTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? FlowGateTheme.primarySoft : FlowGateTheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? FlowGateTheme.primary
                      : FlowGateTheme.textTertiary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? FlowGateTheme.primary
                              : FlowGateTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${profile.server}:${profile.port} · ${profile.type.label}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: FlowGateTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 延迟标签：仅显示有效（非负）延迟
                if (profile.latencyMs != null && profile.latencyMs! >= 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _latencyColor(profile.latencyMs!).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${profile.latencyMs}ms',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _latencyColor(profile.latencyMs!),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                // 分享按钮
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onShare,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.share_outlined,
                      size: 17,
                      color: selected
                          ? FlowGateTheme.primary
                          : FlowGateTheme.textTertiary,
                    ),
                  ),
                ),
                // 测速按钮
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onTestSpeed,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.speed_outlined,
                      size: 18,
                      color: selected
                          ? FlowGateTheme.primary
                          : FlowGateTheme.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
