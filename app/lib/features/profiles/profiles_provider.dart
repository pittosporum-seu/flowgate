import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_provider.dart';
import '../../core/service/log_service.dart';
import '../../core/service/subscription_fetcher.dart';
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
  final _log = LogService.instance;

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
    _syncNodeToApi(profile);
  }

  /// 从分享链接导入 (单条)
  Future<ProfileItem?> importLink(String link) async {
    final profile = VlessImportAdapter.parseSingle(link);
    if (profile == null) return null;
    await add(profile);
    return profile;
  }

  /// 从订阅导入，返回新增数量
  /// [input] 可以是订阅 URL（自动拉取）或直接的链接/订阅内容
  Future<int> importBatch(String input, {String? subscriptionId}) async {
    var content = input;
    // 如果是 URL，先拉取订阅内容
    if (SubscriptionFetcher.isUrl(input)) {
      content = await SubscriptionFetcher.fetch(input);
    }

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

    LogService.instance.info('Profiles',
        'import: parsed=${parsed.length} fresh=${fresh.length} url=${SubscriptionFetcher.isUrl(input)}');

    if (fresh.isNotEmpty) {
      await _repo.saveAll(fresh);
      refresh();
    }
    return fresh.length;
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    refresh();
    // 同步删除到 API 后端
    try {
      await ref.read(apiClientProvider).deleteNode(id);
    } catch (_) {}
  }

  Future<void> updateLatency(String id, int latencyMs) async {
    final profile = _repo.getById(id);
    if (profile == null) return;
    await _repo.save(profile.copyWith(latencyMs: latencyMs));
    refresh();
  }

  /// 双写同步：将节点推送到 Ktor API 后端（渐进迁移 Phase 1）
  /// 失败不影响本地操作，仅记日志
  void _syncNodeToApi(ProfileItem profile) {
    ref.read(apiClientProvider).addNodeRaw(_toNodeDto(profile)).catchError((e) {
      _log.debug('Profiles', 'API sync failed (non-critical): $e');
      return;
    });
  }

  /// ProfileItem → API NodeDto 映射
  static Map<String, dynamic> _toNodeDto(ProfileItem p) => {
        'id': p.id,
        'name': p.name,
        'type': p.type.name,
        'server': p.server,
        'port': p.port,
        'password': p.password,
        if (p.method != null) 'method': p.method,
        if (p.sni != null) 'sni': p.sni,
        if (p.network != null) 'network': p.network,
        if (p.path != null) 'path': p.path,
        if (p.subscriptionId != null) 'subscriptionId': p.subscriptionId,
        if (p.latencyMs != null) 'latencyMs': p.latencyMs,
        'createdAt': p.createdAt,
        if (p.rawConfig != null) 'rawConfig': p.rawConfig,
      };
}
