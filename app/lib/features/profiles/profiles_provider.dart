import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model/profile_item.dart';
import 'parser/vless_import_adapter.dart';
import 'repository/profile_repository.dart';

/// ProfileRepository 单例
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  throw UnimplementedError('Must override with initialized repository');
});

/// 节点列表状态
final profilesProvider =
    NotifierProvider<ProfilesNotifier, List<ProfileItem>>(ProfilesNotifier.new);

class ProfilesNotifier extends Notifier<List<ProfileItem>> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  List<ProfileItem> build() {
    return _repo.getAll();
  }

  void refresh() {
    state = _repo.getAll();
  }

  Future<void> add(ProfileItem profile) async {
    await _repo.save(profile);
    refresh();
  }

  /// 从分享链接导入 (单条)
  Future<ProfileItem?> importLink(String link) async {
    final profile = VlessImportAdapter.parseSingle(link);
    if (profile == null) return null;
    await add(profile);
    return profile;
  }

  /// 从订阅内容批量导入，返回新增数量
  Future<int> importBatch(String content, {String? subscriptionId}) async {
    final parsed = VlessImportAdapter.parseBatch(content, subscriptionId: subscriptionId);
    if (parsed.isEmpty) return 0;

    final existing = _repo.getAll();
    final existingKeys = existing
        .map((p) => '${p.server}:${p.port}:${p.password}')
        .toSet();

    final fresh = parsed
        .where((p) =>
            !existingKeys.contains('${p.server}:${p.port}:${p.password}'))
        .toList();

    if (fresh.isNotEmpty) {
      await _repo.saveAll(fresh);
      refresh();
    }
    return fresh.length;
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    refresh();
  }

  Future<void> updateLatency(String id, int latencyMs) async {
    final profile = _repo.getById(id);
    if (profile == null) return;
    await _repo.save(profile.copyWith(latencyMs: latencyMs));
    refresh();
  }
}
