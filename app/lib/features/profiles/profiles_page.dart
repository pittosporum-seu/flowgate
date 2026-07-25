import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/state/app_provider.dart';
import '../../core/theme.dart';
import 'model/profile_item.dart';
import 'profiles_provider.dart';

/// Profiles - 节点列表 (真实数据)
class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final selectedNode = ref.watch(appProvider.select((s) => s.currentNodeName));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: profiles.isEmpty
                  ? _buildEmpty(context)
                  : _buildList(context, ref, profiles, selectedNode),
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
          const Text(
            'No nodes yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: FlowGateTheme.textSecondary),
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
    String? selectedNode,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final p = profiles[index];
        final active = p.name == selectedNode;
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
            onTap: () => ref.read(appProvider.notifier).selectNode(p.name),
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
                  if (active) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded, color: FlowGateTheme.primary, size: 20),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Nodes'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Paste vmess:// vless:// trojan:// ss:// link\nor base64 subscription content',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.paste_rounded, size: 16),
                  label: const Text('Paste from clipboard'),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) controller.text = data!.text!;
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final count = await ref.read(profilesProvider.notifier).importBatch(text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(count > 0 ? 'Imported $count node(s)' : 'No valid nodes found')),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
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
