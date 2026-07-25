import 'package:flutter_vless/flutter_vless.dart';
import '../service/log_service.dart';
import '../state/app_state.dart';

/// flutter_vless 核心引擎封装 (单例)
/// 负责代理核心的初始化、起停、延迟测试，并转发状态变化
class VlessEngine {
  VlessEngine._internal();
  static final VlessEngine instance = VlessEngine._internal();
  final _log = LogService.instance;

  /// 状态变化回调，由 AppNotifier 订阅
  void Function(VlessStatus status)? onStatus;

  late final FlutterVless _vless = FlutterVless(
    onStatusChanged: (status) {
      _log.debug('VlessEngine',
          'status=${status.state} conn=${status.connectionState.name} '
          'up=${status.uploadSpeed}B/s down=${status.downloadSpeed}B/s');
      onStatus?.call(status);
    },
  );

  bool _initialized = false;

  /// 初始化核心 (幂等)
  Future<void> init() async {
    if (_initialized) return;
    _log.info('VlessEngine', 'Initializing core...');
    try {
      await _vless.initializeVless(
        providerBundleIdentifier: 'com.njl.flowgate',
        groupIdentifier: 'group.com.njl.flowgate',
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
      );
      _initialized = true;
      final ver = await _vless.getCoreVersion();
      _log.info('VlessEngine', 'Core initialized, version=$ver');
    } catch (e) {
      _log.error('VlessEngine', 'Core init failed', e);
      rethrow;
    }
  }

  /// 请求 VPN 权限 (VPN 模式需要)
  Future<bool> requestPermission() => _vless.requestPermission();

  /// 启动代理
  Future<void> connect({
    required String remark,
    required String config,
    bool proxyOnly = false,
    List<String> bypassSubnets = const [],
    List<String> blockedApps = const [],
  }) async {
    _log.info('VlessEngine',
        'connect: remark="$remark" proxyOnly=$proxyOnly configLen=${config.length}');
    _log.debug('VlessEngine', 'config=$config');
    try {
      await init();
      await _vless.startVless(
        remark: remark,
        config: config,
        proxyOnly: proxyOnly,
        bypassSubnets: bypassSubnets,
        blockedApps: blockedApps,
      );
      _log.info('VlessEngine', 'startVless called OK');
    } catch (e) {
      _log.error('VlessEngine', 'connect failed', e);
      rethrow;
    }
  }

  /// 停止代理
  Future<void> disconnect() async {
    _log.info('VlessEngine', 'disconnect');
    try {
      await _vless.stopVless();
      _log.info('VlessEngine', 'stopVless OK');
    } catch (e) {
      _log.error('VlessEngine', 'disconnect failed', e);
      rethrow;
    }
  }

  /// 测试未连接节点的延迟
  Future<int> testDelay({required String config}) =>
      _vless.getServerDelay(config: config);

  /// 测试已连接节点的延迟
  Future<int> testConnectedDelay() => _vless.getConnectedServerDelay();

  /// 核心版本
  Future<String> coreVersion() => _vless.getCoreVersion();
}

/// VlessStatus → 领域状态映射
extension VlessStatusMapper on VlessStatus {
  VpnConnectionState toDomainState() {
    return switch (connectionState) {
      VlessConnectionState.connected => VpnConnectionState.connected,
      VlessConnectionState.connecting => VpnConnectionState.connecting,
      VlessConnectionState.disconnecting => VpnConnectionState.disconnecting,
      VlessConnectionState.disconnected => VpnConnectionState.disconnected,
      VlessConnectionState.unknown => VpnConnectionState.disconnected,
    };
  }

  TrafficStats toTraffic() {
    return TrafficStats(
      uplinkBytes: upload,
      downlinkBytes: download,
      uplinkSpeed: uploadSpeed,
      downlinkSpeed: downloadSpeed,
    );
  }
}
