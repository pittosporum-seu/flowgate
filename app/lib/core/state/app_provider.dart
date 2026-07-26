import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
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
  static const _connectTimeout = Duration(seconds: 20);

  VlessEngine get _engine => VlessEngine.instance;
  final _log = LogService.instance;
  Timer? _connectWatchdog;

  @override
  AppState build() {
    // 订阅核心状态变化
    _engine.onStatus = _handleStatus;
    ref.onDispose(() {
      _engine.onStatus = null;
      _connectWatchdog?.cancel();
    });
    return const AppState();
  }

  /// 核心状态回调 → 更新 AppState
  /// 注意：status 必须显式标注为 VlessStatus，否则扩展方法 toDomainState()
  /// 无法在 dynamic 接收者上分发，会抛 noSuchMethod 导致状态永远不更新
  void _handleStatus(VlessStatus status) {
    final newState = status.toDomainState();
    // 收到 connected/disconnected 后取消超时看门狗
    if (newState == VpnConnectionState.connected ||
        newState == VpnConnectionState.disconnected) {
      _connectWatchdog?.cancel();
    }
    state = state.copyWith(
      connectionState: newState,
      traffic: status.toTraffic(),
      durationSeconds: status.duration,
      errorMessage: newState == VpnConnectionState.connected ? null : state.errorMessage,
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

  /// 连接/断开切换（connecting 状态下可中断）
  Future<void> toggleConnection() async {
    // 正在断开时忽略，避免重复触发
    if (state.connectionState == VpnConnectionState.disconnecting) return;
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

      // 超时看门狗：若 20s 内未收到 connected 状态 → 判定超时
      _connectWatchdog?.cancel();
      _connectWatchdog = Timer(_connectTimeout, () {
        if (state.connectionState == VpnConnectionState.connecting) {
          _log.error('AppNotifier', 'connect timeout after ${_connectTimeout.inSeconds}s');
          state = state.copyWith(
            connectionState: VpnConnectionState.error,
            errorMessage: '连接超时，请检查节点或网络',
          );
          // 清理未成功的连接
          _engine.disconnect().catchError((_) {});
        }
      });
    } catch (e) {
      _log.error('AppNotifier', 'connect failed', e);
      state = state.copyWith(
        connectionState: VpnConnectionState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 断开代理（可中断 connecting）
  Future<void> disconnect() async {
    _log.info('AppNotifier', 'disconnect (was ${state.connectionState.name})');
    _connectWatchdog?.cancel();
    state = state.copyWith(connectionState: VpnConnectionState.disconnecting);
    try {
      await _engine.disconnect();
    } catch (e) {
      _log.error('AppNotifier', 'disconnect failed', e);
    }
    // 不依赖状态回调，直接置为已断开，避免卡在 disconnecting
    state = state.copyWith(
      connectionState: VpnConnectionState.disconnected,
      traffic: state.traffic.copyWith(uplinkSpeed: 0, downlinkSpeed: 0),
    );
  }

  /// 选择节点并持久化
  /// - connecting 中重选 → 中断并重置为未连接
  /// - 已连接重选 → 直接切换到新节点
  Future<void> selectProfile(ProfileItem profile) async {
    final wasConnecting = state.connectionState == VpnConnectionState.connecting;
    final wasConnected = state.isRunning;

    _log.info('AppNotifier',
        'selectProfile: "${profile.name}" (was ${state.connectionState.name})');
    state = state.copyWith(
      selectedProfileId: profile.id,
      currentNodeName: profile.name,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfileId, profile.id);
    await prefs.setString(_keyNodeName, profile.name);

    if (wasConnecting) {
      // 连接中重选 → 中断尝试，重置为未连接
      await disconnect();
    } else if (wasConnected) {
      // 已连接重选 → 断开旧节点并连接新节点
      await disconnect();
      await connect();
    }
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
