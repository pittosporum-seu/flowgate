import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/service/log_service.dart';
import '../../../core/service/subscription_fetcher.dart';
import '../model/subscription_item.dart';
import '../parser/vless_import_adapter.dart';
import '../profiles_provider.dart';
import '../repository/profile_repository.dart';
import '../repository/subscription_repository.dart';

/// 订阅存储 Provider
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  throw UnimplementedError('Must override with initialized repository');
});

/// 订阅列表状态
final subscriptionsProvider =
    NotifierProvider<SubscriptionsNotifier, List<SubscriptionItem>>(
        SubscriptionsNotifier.new);

class SubscriptionsNotifier extends Notifier<List<SubscriptionItem>> {
  final _log = LogService.instance;

  SubscriptionRepository get _subRepo => ref.read(subscriptionRepositoryProvider);
  ProfileRepository get _profileRepo => ref.read(profileRepositoryProvider);

  @override
  List<SubscriptionItem> build() {
    return _subRepo.getAll();
  }

  void refresh() {
    state = _subRepo.getAll();
  }

  /// 添加订阅：拉取 URL → 解析节点 → 入库（节点打上 subscriptionId）
  Future<int> addSubscription(String url) async {
    final result = await SubscriptionFetcher.fetchWithMeta(url);
    final nodes = VlessImportAdapter.parseBatch(result.body);
    if (nodes.isEmpty) {
      _log.warn('Subscriptions', 'addSubscription: no nodes parsed from $url');
      return 0;
    }

    final id = 'sub_${DateTime.now().millisecondsSinceEpoch}';
    final sub = SubscriptionItem(
      id: id,
      url: url,
      name: _deriveName(url, nodes.length),
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      upload: result.upload,
      download: result.download,
      total: result.total,
      expire: result.expire,
    );

    // 节点打上订阅标记
    final tagged = nodes.map((n) => n.copyWith(subscriptionId: id)).toList();
    await _profileRepo.saveAll(tagged);
    await _subRepo.save(sub);

    _log.info('Subscriptions', 'addSubscription: ${nodes.length} nodes from $url');
    refresh();
    ref.read(profilesProvider.notifier).refresh();
    return nodes.length;
  }

  /// 刷新订阅：重新拉取，替换该订阅下的旧节点
  Future<int> refreshSubscription(String id) async {
    final sub = _subRepo.getById(id);
    if (sub == null) return 0;

    final result = await SubscriptionFetcher.fetchWithMeta(sub.url);
    final nodes = VlessImportAdapter.parseBatch(result.body);
    if (nodes.isEmpty) {
      _log.warn('Subscriptions', 'refreshSubscription: no nodes parsed for ${sub.name}');
      return 0;
    }

    // 删除该订阅的旧节点
    final existing = _profileRepo.getAll();
    for (final p in existing) {
      if (p.subscriptionId == id) {
        await _profileRepo.delete(p.id);
      }
    }

    // 写入新节点（打上订阅标记）
    final tagged = nodes.map((n) => n.copyWith(subscriptionId: id)).toList();
    await _profileRepo.saveAll(tagged);

    // 更新订阅时间 + 元数据
    await _subRepo.save(sub.copyWith(
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      upload: result.upload,
      download: result.download,
      total: result.total,
      expire: result.expire,
    ));

    _log.info('Subscriptions', 'refreshSubscription: ${nodes.length} nodes for ${sub.name}');
    refresh();
    ref.read(profilesProvider.notifier).refresh();
    return nodes.length;
  }

  /// 删除订阅及其所有节点
  Future<void> deleteSubscription(String id) async {
    final existing = _profileRepo.getAll();
    for (final p in existing) {
      if (p.subscriptionId == id) {
        await _profileRepo.delete(p.id);
      }
    }
    await _subRepo.delete(id);
    _log.info('Subscriptions', 'deleteSubscription: $id');
    refresh();
    ref.read(profilesProvider.notifier).refresh();
  }

  /// 重命名订阅分组
  Future<void> renameSubscription(String id, String newName) async {
    final sub = _subRepo.getById(id);
    if (sub == null) return;
    final name = newName.trim();
    if (name.isEmpty) return;
    await _subRepo.save(sub.copyWith(name: name));
    _log.info('Subscriptions', 'renameSubscription: $id -> $name');
    refresh();
  }

  String _deriveName(String url, int nodeCount) {
    try {
      final host = Uri.parse(url).host;
      return host.isEmpty ? 'Subscription ($nodeCount)' : host;
    } catch (_) {
      return 'Subscription ($nodeCount)';
    }
  }
}
