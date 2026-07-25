import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'model/profile_item.dart';
import 'profiles_provider.dart';

/// 手动添加/编辑节点
class ServerEditPage extends ConsumerStatefulWidget {
  final ProfileItem? existing;
  const ServerEditPage({super.key, this.existing});

  @override
  ConsumerState<ServerEditPage> createState() => _ServerEditPageState();
}

class _ServerEditPageState extends ConsumerState<ServerEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _server;
  late final TextEditingController _port;
  late final TextEditingController _password;
  late final TextEditingController _sni;
  late final TextEditingController _path;
  ProfileType _type = ProfileType.trojan;
  String _network = 'tcp';

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _server = TextEditingController(text: e?.server ?? '');
    _port = TextEditingController(text: e?.port.toString() ?? '');
    _password = TextEditingController(text: e?.password ?? '');
    _sni = TextEditingController(text: e?.sni ?? '');
    _path = TextEditingController(text: e?.path ?? '');
    if (e != null) {
      _type = e.type;
      _network = e.network ?? 'tcp';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    _port.dispose();
    _password.dispose();
    _sni.dispose();
    _path.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = ProfileItem(
      id: widget.existing?.id ??
          '${DateTime.now().millisecondsSinceEpoch}_manual',
      name: _name.text.trim(),
      type: _type,
      server: _server.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 0,
      password: _password.text.trim(),
      sni: _sni.text.trim().isEmpty ? null : _sni.text.trim(),
      network: _network,
      path: _path.text.trim().isEmpty ? null : _path.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );

    await ref.read(profilesProvider.notifier).add(profile);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Node' : 'Add Node'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // 协议类型
            _label('Protocol'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ProfileType.values.map((t) {
                final selected = t == _type;
                return ChoiceChip(
                  label: Text(t.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t),
                  selectedColor: FlowGateTheme.primarySoft,
                  labelStyle: TextStyle(
                    color: selected ? FlowGateTheme.primary : FlowGateTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _label('Name'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'My Node'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Server'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _server,
                        decoration: const InputDecoration(hintText: 'example.com'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Port'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _port,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '443'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final p = int.tryParse(v.trim());
                          return (p == null || p <= 0 || p > 65535) ? 'Invalid' : null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _label(_type == ProfileType.vmess || _type == ProfileType.vless ? 'UUID' : 'Password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(hintText: 'uuid or password'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            _label('Network'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'tcp', label: Text('TCP')),
                ButtonSegment(value: 'ws', label: Text('WS')),
                ButtonSegment(value: 'grpc', label: Text('gRPC')),
              ],
              selected: {_network},
              onSelectionChanged: (s) => setState(() => _network = s.first),
            ),
            const SizedBox(height: 20),
            _label('SNI (optional)'),
            const SizedBox(height: 8),
            TextFormField(controller: _sni, decoration: const InputDecoration(hintText: 'sni.example.com')),
            if (_network == 'ws') ...[
              const SizedBox(height: 20),
              _label('WS Path (optional)'),
              const SizedBox(height: 8),
              TextFormField(controller: _path, decoration: const InputDecoration(hintText: '/ws')),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FlowGateTheme.textSecondary),
      );
}
