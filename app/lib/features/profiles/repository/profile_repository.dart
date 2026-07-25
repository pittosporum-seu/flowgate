import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/profile_item.dart';

/// Profile 本地存储 (Hive, JSON 序列化)
class ProfileRepository {
  static const _boxName = 'profiles';
  late Box<String> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
  }

  List<ProfileItem> getAll() {
    return _box.values
        .map((raw) => ProfileItem.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  ProfileItem? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return ProfileItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(ProfileItem profile) async {
    await _box.put(profile.id, jsonEncode(profile.toJson()));
  }

  Future<void> saveAll(List<ProfileItem> profiles) async {
    final entries = {for (final p in profiles) p.id: jsonEncode(p.toJson())};
    await _box.putAll(entries);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clear() async {
    await _box.clear();
  }

  int get count => _box.length;
}
