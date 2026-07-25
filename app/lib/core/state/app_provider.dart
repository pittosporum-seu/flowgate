import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/profiles/model/profile_item.dart';
import '../../features/profiles/profiles_provider.dart';
import '../../features/routing/routing_provider.dart';
import '../engine/config_assembler.dart';
import '../engine/vless_engine.dart';
import '../service/log_service.dart';
import 'app_state.dart';

/// AppState 的 Riverpod Notifier
/// 通过 VlessEngine (flutter_vless) 驱动真实代理核心
class AppNotifier extends Notifier<AppState> {
  static const _keyProfileId = 'persisted_profile_id';
  static const _keyNodeName = 'persisted_node_name';

  VlessEngine get _engine => VlessEngine.instance;
  final _log = LogService.instance;

  @override
  AppState build() {
    // 订阅核心状态变化
    _engine.onStatus = _handleStatus;
    ref.onDispose(() => _engine.onStatus = null);
    return const AppState();
  }

  /// 核心状态回调 → 更新 AppState
  void _handleStatus(status) {
    state = state.copyWith(
      connectionState: status.toDomainState(),
      traffic: status.toTraffic(),
      durationSeconds: status.duration,
    );
  }

  /// 启动时从持久化恢复
  Future<void> restoreFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString(_keyProfileId);
    final nodeName = prefs.getString(_keyNodeName);
    if (profileId != null || nodeName != null) {
      state = state.copyWith(
        selectedProfileId: profileId,
        currentNodeName: nodeName,
      );
    }
  }

  /// 连接/断开切换
  Future<void> toggleConnection() async {
    if (state.isRunning ||
        state.connectionState == VpnConnectionState.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  /// 连接代理
  Future<void> connect() async {
    final profile = _selectedProfile();
    if (profile == null) {
      _log.warn('AppNotifier', 'connect: no node selected');
      state = state.copyWith(errorMessage: 'No node selected');
      return;
    }
    final rawConfig = profile.rawConfig;
    if (rawConfig == null || rawConfig.isEmpty) {
      _log.warn('AppNotifier', 'connect: node config missing for ${profile.name}');
      state = state.copyWith(errorMessage: 'Node config missing');
      return;
    }

    _log.info('AppNotifier', 'connect: node="${profile.name}" mode=proxy-only');
    state = state.copyWith(
      connectionState: VpnConnectionState.connecting,
      errorMessage: null,
    );

    try {
      // 组装最终 Xray config: 节点配置 + 路由规则
      final routing = ref.read(routingProvider);
      final config = ConfigAssembler.assemble(
        profileConfig: rawConfig,
        rules: routing.compiledRules,
      );

      await _engine.connect(
        remark: profile.name,
        config: config,
        proxyOnly: true, // Windows 先用 proxy-only；Android VPN 后续
      );
    } catch (e) {
      _log.error('AppNotifier', 'connect failed', e);
      state = state.copyWith(
        connectionState: VpnConnectionState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 断开代理
  Future<void> disconnect() async {
    _log.info('AppNotifier', 'disconnect');
    state = state.copyWith(connectionState: VpnConnectionState.disconnecting);
    try {
      await _engine.disconnect();
    } catch (e) {
      _log.error('AppNotifier', 'disconnect failed', e);
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// 选择节点并持久化
  Future<void> selectProfile(ProfileItem profile) async {
    _log.info('AppNotifier', 'selectProfile: "${profile.name}" (${profile.type.label})');
    state = state.copyWith(
      selectedProfileId: profile.id,
      currentNodeName: profile.name,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfileId, profile.id);
    await prefs.setString(_keyNodeName, profile.name);
  }

  /// 测试节点延迟
  Future<int?> testDelay(ProfileItem profile) async {
    final rawConfig = profile.rawConfig;
    if (rawConfig == null || rawConfig.isEmpty) return null;
    try {
      await _engine.init();
      final delay = await _engine.testDelay(config: rawConfig);
      await ref.read(profilesProvider.notifier).updateLatency(profile.id, delay);
      return delay;
    } catch (_) {
      return null;
    }
  }

  /// 获取当前选中的节点
  ProfileItem? _selectedProfile() {
    final id = state.selectedProfileId;
    if (id == null) return null;
    final profiles = ref.read(profilesProvider);
    return profiles.where((p) => p.id == id).firstOrNull;
  }
}

/// 全局 Provider
final appProvider = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);
