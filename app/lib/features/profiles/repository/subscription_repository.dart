import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/subscription_item.dart';

/// 订阅本地存储 (Hive)
class SubscriptionRepository {
  static const _boxName = 'subscriptions';
  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  List<SubscriptionItem> getAll() {
    return _box.values
        .map((raw) => SubscriptionItem.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
  }

  SubscriptionItem? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return SubscriptionItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(SubscriptionItem sub) async {
    await _box.put(sub.id, jsonEncode(sub.toJson()));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
