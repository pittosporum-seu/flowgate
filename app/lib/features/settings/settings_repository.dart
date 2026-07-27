import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用设置模型
class Settings {
  final bool notifications;
  final bool fakeDns;
  final String remoteDns;
  final String domesticDns;
  final String speedTestUrl;

  const Settings({
    this.notifications = true,
    this.fakeDns = false,
    this.remoteDns = '8.8.8.8',
    this.domesticDns = '223.5.5.5',
    this.speedTestUrl = 'gstatic.com/generate_204',
  });

  Settings copyWith({
    bool? notifications,
    bool? fakeDns,
    String? remoteDns,
    String? domesticDns,
    String? speedTestUrl,
  }) {
    return Settings(
      notifications: notifications ?? this.notifications,
      fakeDns: fakeDns ?? this.fakeDns,
      remoteDns: remoteDns ?? this.remoteDns,
      domesticDns: domesticDns ?? this.domesticDns,
      speedTestUrl: speedTestUrl ?? this.speedTestUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'notifications': notifications,
        'fakeDns': fakeDns,
        'remoteDns': remoteDns,
        'domesticDns': domesticDns,
        'speedTestUrl': speedTestUrl,
      };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        notifications: json['notifications'] as bool? ?? true,
        fakeDns: json['fakeDns'] as bool? ?? false,
        remoteDns: json['remoteDns'] as String? ?? '8.8.8.8',
        domesticDns: json['domesticDns'] as String? ?? '223.5.5.5',
        speedTestUrl:
            json['speedTestUrl'] as String? ?? 'gstatic.com/generate_204',
      );
}

/// 设置本地存储 (SharedPreferences)
class SettingsRepository {
  static const _key = 'app_settings';

  Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const Settings();
    try {
      return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const Settings();
    }
  }

  Future<void> save(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
