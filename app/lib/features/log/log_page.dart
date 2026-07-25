import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/service/log_service.dart';
import '../../core/theme.dart';

/// 日志页：实时查看 + 筛选 + 分享/复制
class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final _log = LogService.instance;
  late List<LogEntry> _entries;
  LogLevel? _filter;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _entries = _log.snapshot();
    _log.stream.listen((entry) {
      if (!mounted) return;
      setState(() {
        _entries.add(entry);
        if (_entries.length > 1000) _entries.removeAt(0);
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<LogEntry> get _filtered =>
      _filter == null ? _entries : _entries.where((e) => e.level == _filter).toList();

  Future<void> _share() async {
    final file = await _log.exportFile();
    if (file == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No log file available')),
        );
      }
      return;
    }
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'FlowGate logs',
    );
  }

  Future<void> _copy() async {
    final text = _filtered.map((e) => e.formatted).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs copied to clipboard')),
      );
    }
  }

  Future<void> _clear() async {
    await _log.clear();
    setState(() => _entries.clear());
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(icon: const Icon(Icons.copy_rounded), tooltip: 'Copy', onPressed: _copy),
          IconButton(icon: const Icon(Icons.share_rounded), tooltip: 'Share', onPressed: _share),
          IconButton(icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Clear', onPressed: _clear),
        ],
      ),
      body: Column(
        children: [
          // 级别筛选
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(label: 'All', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                const SizedBox(width: 8),
                ...LogLevel.values.map((lv) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: lv.label,
                        selected: _filter == lv,
                        color: _colorFor(lv),
                        onTap: () => setState(() => _filter = _filter == lv ? null : lv),
                      ),
                    )),
                const Spacer(),
                Text('${list.length} entries',
                    style: const TextStyle(fontSize: 12, color: FlowGateTheme.textTertiary)),
              ],
            ),
          ),
          const Divider(height: 1),
          // 日志列表
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('No logs yet',
                        style: TextStyle(color: FlowGateTheme.textTertiary)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final e = list[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(
                                color: _colorFor(e.level),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SelectableText(
                                e.formatted,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: e.level == LogLevel.error
                                      ? FlowGateTheme.danger
                                      : FlowGateTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(LogLevel level) => switch (level) {
        LogLevel.debug => FlowGateTheme.textTertiary,
        LogLevel.info => FlowGateTheme.primary,
        LogLevel.warn => FlowGateTheme.warning,
        LogLevel.error => FlowGateTheme.danger,
      };
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? FlowGateTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: 0.15) : FlowGateTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? activeColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? activeColor : FlowGateTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
