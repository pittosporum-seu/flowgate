import 'package:flutter_v2ray/flutter_v2ray.dart';
import '../service/log_service.dart';
import '../state/app_state.dart';

/// flutter_v2ray 核心引擎封装 (单例)
/// Xray 通过 JNI 在 VpnService 进程内运行 (in-process)，受前台服务保护，不会被 LMK 回收
class VlessEngine {
  VlessEngine._internal();
  static final VlessEngine instance = VlessEngine._internal();
  final _log = LogService.instance;

  /// 状态变化回调，由 AppNotifier 订阅
  void Function(V2RayStatus status)? onStatus;

  String? _lastState;

  late final FlutterV2ray _v2ray = FlutterV2ray(
    onStatusChanged: (status) {
      // 连接状态变化记 info（便于诊断），其余记 debug
      if (status.state != _lastState) {
        _lastState = status.state;
        _log.info('VlessEngine', 'state=${status.state}');
      } else {
        _log.debug('VlessEngine',
            'state=${status.state} up=${status.uploadSpeed}B/s down=${status.downloadSpeed}B/s');
      }
      onStatus?.call(status);
    },
  );

  bool _initialized = false;

  /// 初始化核心 (幂等)
  Future<void> init() async {
    if (_initialized) return;
    _log.info('VlessEngine', 'Initializing core...');
    try {
      await _v2ray.initializeV2Ray(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
      );
      _initialized = true;
      final ver = await _v2ray.getCoreVersion();
      _log.info('VlessEngine', 'Core initialized, version=$ver');
    } catch (e) {
      _log.error('VlessEngine', 'Core init failed', e);
      rethrow;
    }
  }

  /// 请求 VPN 权限 (VPN 模式需要)
  Future<bool> requestPermission() => _v2ray.requestPermission();

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
      await _v2ray.startV2Ray(
        remark: remark,
        config: config,
        proxyOnly: proxyOnly,
        bypassSubnets: bypassSubnets.isEmpty ? null : bypassSubnets,
        blockedApps: blockedApps.isEmpty ? null : blockedApps,
      );
      _log.info('VlessEngine', 'startV2Ray called OK');
    } catch (e) {
      _log.error('VlessEngine', 'connect failed', e);
      rethrow;
    }
  }

  /// 停止代理
  Future<void> disconnect() async {
    _log.info('VlessEngine', 'disconnect');
    try {
      await _v2ray.stopV2Ray();
      _log.info('VlessEngine', 'stopV2Ray OK');
    } catch (e) {
      _log.error('VlessEngine', 'disconnect failed', e);
      rethrow;
    }
  }

  /// 测试未连接节点的延迟
  Future<int> testDelay({required String config}) =>
      _v2ray.getServerDelay(config: config);

  /// 测试已连接节点的延迟
  Future<int> testConnectedDelay() => _v2ray.getConnectedServerDelay();

  /// 核心版本
  Future<String> coreVersion() => _v2ray.getCoreVersion();
}

/// V2RayStatus → 领域状态映射
extension V2RayStatusMapper on V2RayStatus {
  VpnConnectionState toDomainState() {
    return switch (state) {
      'CONNECTED' => VpnConnectionState.connected,
      'CONNECTING' => VpnConnectionState.connecting,
      'DISCONNECTED' => VpnConnectionState.disconnected,
      _ => VpnConnectionState.disconnected,
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
