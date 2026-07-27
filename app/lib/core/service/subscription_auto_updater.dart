import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'log_service.dart';
import '../../features/profiles/model/subscription_item.dart';
import '../../features/profiles/repository/subscription_repository.dart';
import '../../features/profiles/subscriptions/subscriptions_provider.dart';

/// 订阅自动更新服务
/// 在 App 启动时检查所有 autoUpdate=true 的订阅，
/// 若距上次更新超过设定间隔则自动刷新
class SubscriptionAutoUpdater {
  static final _log = LogService.instance;

  /// 默认更新间隔：24 小时
  static const defaultIntervalHours = 24;

  /// 启动时检查并执行自动更新
  static Future<void> checkAndRefresh(WidgetRef ref) async {
    try {
      final subRepo = ref.read(subscriptionRepositoryProvider);
      final allSubs = subRepo.getAll();
      final now = DateTime.now().millisecondsSinceEpoch;
      final intervalMs = defaultIntervalHours * 3600 * 1000;

      final dueSubs = allSubs.where((sub) {
        if (!sub.autoUpdate) return false;
        if (sub.lastUpdated == 0) return true; // 从未更新过
        return (now - sub.lastUpdated) > intervalMs;
      }).toList();

      if (dueSubs.isEmpty) {
        _log.info('AutoUpdater', 'No subscriptions due for update');
        return;
      }

      _log.info('AutoUpdater',
          'Auto-refreshing ${dueSubs.length} subscription(s)');

      final notifier = ref.read(subscriptionsProvider.notifier);
      for (final sub in dueSubs) {
        try {
          final count = await notifier.refreshSubscription(sub.id);
          _log.info('AutoUpdater',
              'Refreshed "${sub.name}": $count nodes');
        } catch (e) {
          _log.warn('AutoUpdater',
              'Failed to refresh "${sub.name}": $e');
        }
        // 间隔 2 秒避免并发请求
        await Future.delayed(const Duration(seconds: 2));
      }

      _log.info('AutoUpdater', 'Auto-update complete');
    } catch (e) {
      _log.error('AutoUpdater', 'checkAndRefresh failed', e);
    }
  }
}
