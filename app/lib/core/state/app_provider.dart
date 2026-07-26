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

  // 本地精确计时：原生 CountDownTimer 用 seconds++ 累加会漂移（走时偏慢），
  // 改用连接起始时间戳 + 本地 1s 计时器，按墙钟差值计算精确时长
  DateTime? _connectedAt;
  Timer? _durationTicker;

  // 保活心跳：检测 Xray 子进程是否被系统杀死
  // 小米 HyperOS 等系统会因内存压力杀 Xray 进程，但 Dart 层收不到断开事件
  DateTime? _lastStatusAt;
  Timer? _keepaliveTimer;
  static const _keepaliveInterval = Duration(seconds: 30);
  static const _keepaliveThreshold = Duration(seconds: 90);

  @override
  AppState build() {
    // 订阅核心状态变化
    _engine.onStatus = _handleStatus;
    ref.onDispose(() {
      _engine.onStatus = null;
      _connectWatchdog?.cancel();
      _stopDurationTicker();
      _stopKeepalive();
    });
    return const AppState();
  }

  /// 启动本地计时器：每秒按墙钟差值刷新已连接时长
  void _startDurationTicker() {
    _connectedAt = DateTime.now();
    _durationTicker?.cancel();
    _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final at = _connectedAt;
      if (at == null) return;
      state = state.copyWith(
        durationSeconds: DateTime.now().difference(at).inSeconds,
      );
    });
  }

  void _stopDurationTicker() {
    _durationTicker?.cancel();
    _durationTicker = null;
    _connectedAt = null;
  }

  /// 启动保活心跳：定期检查 Xray 是否还活着
  void _startKeepalive() {
    _lastStatusAt = DateTime.now();
    _keepaliveTimer?.cancel();
    _keepaliveTimer = Timer.periodic(_keepaliveInterval, (_) {
      if (state.connectionState != VpnConnectionState.connected) return;
      final last = _lastStatusAt;
      if (last == null) return;
      final elapsed = DateTime.now().difference(last);
      if (elapsed > _keepaliveThreshold) {
        _log.warn('AppNotifier',
            'keepalive: no status callback for ${elapsed.inSeconds}s, Xray likely killed, reconnecting');
        _reconnect();
      }
    });
  }

  void _stopKeepalive() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    _lastStatusAt = null;
  }

  /// 自动重连：先断开再连接
  Future<void> _reconnect() async {
    _stopKeepalive();
    _stopDurationTicker();
    state = state.copyWith(connectionState: VpnConnectionState.disconnected, durationSeconds: 0);
    // 等一下让原生层清理
    await Future.delayed(const Duration(seconds: 2));
    await connect();
  }

  /// 核心状态回调 → 更新 AppState
  /// 注意：status 必须显式标注为 VlessStatus，否则扩展方法 toDomainState()
  /// 无法在 dynamic 接收者上分发，会抛 noSuchMethod 导致状态永远不更新
  void _handleStatus(VlessStatus status) {
    final newState = status.toDomainState();
    final wasRunning = state.connectionState == VpnConnectionState.connected;
    // 每次收到状态回调都更新时间戳（保活心跳用）
    _lastStatusAt = DateTime.now();
    // 收到 connected/disconnected 后取消超时看门狗
    if (newState == VpnConnectionState.connected ||
        newState == VpnConnectionState.disconnected) {
      _connectWatchdog?.cancel();
    }
    // 进入 connected：启动本地精确计时 + 保活心跳
    if (newState == VpnConnectionState.connected && !wasRunning) {
      _startDurationTicker();
      _startKeepalive();
    } else if (newState != VpnConnectionState.connected && wasRunning) {
      _stopDurationTicker();
      _stopKeepalive();
    }
    state = state.copyWith(
      connectionState: newState,
      traffic: status.toTraffic(),
      // 时长由本地计时器维护；断开时清零
      durationSeconds: newState == VpnConnectionState.connected
          ? state.durationSeconds
          : 0,
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

    _log.info('AppNotifier', 'connect: node="${profile.name}"');
    state = state.copyWith(
      connectionState: VpnConnectionState.connecting,
      errorMessage: null,
    );

    try {
      // Android VPN 模式：先请求 VPN 权限（会弹系统授权框）
      // 授权成功 → VPN 模式（真实 VPN，有状态栏图标，全局路由）
      // 不支持/拒绝 → 回退 proxy-only
      var proxyOnly = false;
      try {
        final granted = await _engine.requestPermission();
        if (!granted) {
          _log.warn('AppNotifier', 'VPN permission denied, fallback to proxy-only');
          proxyOnly = true;
        }
      } catch (e) {
        _log.warn('AppNotifier', 'requestPermission unsupported, fallback to proxy-only', e);
        proxyOnly = true;
      }
      _log.info('AppNotifier', 'connect: mode=${proxyOnly ? "proxy-only" : "vpn"}');

      // 组装最终 Xray config: 节点配置 + 路由规则
      final routing = ref.read(routingProvider);
      final config = ConfigAssembler.assemble(
        profileConfig: rawConfig,
        rules: routing.compiledRules,
      );

      await _engine.connect(
        remark: profile.name,
        config: config,
        proxyOnly: proxyOnly,
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
    _stopKeepalive();
    _stopDurationTicker();
    state = state.copyWith(connectionState: VpnConnectionState.disconnecting);
    try {
      await _engine.disconnect();
    } catch (e) {
      _log.error('AppNotifier', 'disconnect failed', e);
    }
    // 不依赖状态回调，直接置为已断开，避免卡在 disconnecting
    state = state.copyWith(
      connectionState: VpnConnectionState.disconnected,
      durationSeconds: 0,
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

  /// 测试节点延迟。返回延迟 ms；失败返回 null（不保存负值）
  Future<int?> testDelay(ProfileItem profile) async {
    final rawConfig = profile.rawConfig;
    if (rawConfig == null || rawConfig.isEmpty) return null;
    try {
      await _engine.init();
      // 用测速专用配置（强制走 proxy），避免请求走直连被 GFW 重置
      final delayConfig = ConfigAssembler.assembleDelayTest(rawConfig);
      final delay = await _engine.testDelay(config: delayConfig);
      // 只有非负延迟才是有效结果；-1 表示失败，不保存
      if (delay >= 0) {
        await ref.read(profilesProvider.notifier).updateLatency(profile.id, delay);
        return delay;
      }
      _log.warn('AppNotifier', 'testDelay failed for ${profile.name} (delay=$delay)');
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 一键测速：逐个测试节点（串行，避免并发冲突）
  /// [nodes] 为 null 时测所有节点；否则只测指定分组/列表
  Future<void> testAllDelays([List<ProfileItem>? nodes]) async {
    final all = ref.read(profilesProvider);
    final List<ProfileItem> profiles = nodes ?? all;
    _log.info('AppNotifier', 'testAllDelays: ${profiles.length} nodes');
    for (final p in profiles) {
      await testDelay(p);
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
