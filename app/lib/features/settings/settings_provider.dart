import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_repository.dart';

/// 设置状态 Provider
final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<Settings> {
  final _repo = SettingsRepository();

  @override
  Settings build() {
    // 先用默认值渲染，异步加载持久化值后刷新
    _repo.load().then((loaded) => state = loaded);
    return const Settings();
  }

  Future<void> update(Settings settings) async {
    state = settings;
    await _repo.save(settings);
  }

  Future<void> setNotifications(bool value) =>
      update(state.copyWith(notifications: value));

  Future<void> setFakeDns(bool value) => update(state.copyWith(fakeDns: value));

  Future<void> setRemoteDns(String value) =>
      update(state.copyWith(remoteDns: value));

  Future<void> setDomesticDns(String value) =>
      update(state.copyWith(domesticDns: value));

  Future<void> setSpeedTestUrl(String value) =>
      update(state.copyWith(speedTestUrl: value));
}
