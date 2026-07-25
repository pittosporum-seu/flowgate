import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';

/// AppState 的 Riverpod Notifier
/// 当前为 Mock 实现，后续 Epic 5 替换为真实 CoreEngine
class AppNotifier extends Notifier<AppState> {
  static const _keyNodeName = 'persisted_node_name';
  static const _keyLatency = 'persisted_latency';

  Timer? _trafficTimer;
  final _random = Random();

  @override
  AppState build() {
    ref.onDispose(() => _trafficTimer?.cancel());
    return const AppState();
  }

  /// 启动时从持久化恢复 (Epic 2.4)
  Future<void> restoreFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final nodeName = prefs.getString(_keyNodeName);
    final latency = prefs.getInt(_keyLatency);
    if (nodeName != null) {
      state = state.copyWith(currentNodeName: nodeName, latencyMs: latency);
    }
  }

  /// 连接/断开切换
  Future<void> toggleConnection() async {
    if (state.isRunning) {
      await disconnect();
    } else {
      await connect();
    }
  }

  Future<void> connect() async {
    if (state.connectionState == VpnConnectionState.connecting) return;

    state = state.copyWith(connectionState: VpnConnectionState.connecting);

    // 模拟连接耗时 (真实实现: CoreEngine.start)
    await Future.delayed(const Duration(milliseconds: 900));

    state = state.copyWith(
      connectionState: VpnConnectionState.connected,
      traffic: const TrafficStats(),
    );

    _startTrafficSimulation();
  }

  Future<void> disconnect() async {
    if (state.connectionState == VpnConnectionState.disconnecting) return;

    state = state.copyWith(connectionState: VpnConnectionState.disconnecting);
    _trafficTimer?.cancel();

    // 模拟断开耗时 (真实实现: CoreEngine.stop)
    await Future.delayed(const Duration(milliseconds: 400));

    state = state.copyWith(
      connectionState: VpnConnectionState.disconnected,
      traffic: state.traffic.copyWith(uplinkSpeed: 0, downlinkSpeed: 0),
    );
  }

  /// 选择节点并持久化
  Future<void> selectNode(String name) async {
    state = state.copyWith(currentNodeName: name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNodeName, name);
  }

  /// 模拟流量增长 (真实实现: CoreEngine.queryStats 轮询)
  void _startTrafficSimulation() {
    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!state.isRunning) return;

      final upSpeed = 20000 + _random.nextInt(180000); // 20~200 KB/s
      final downSpeed = 80000 + _random.nextInt(900000); // 80~980 KB/s
      final latency = 38 + _random.nextInt(20);

      state = state.copyWith(
        traffic: state.traffic.copyWith(
          uplinkBytes: state.traffic.uplinkBytes + upSpeed,
          downlinkBytes: state.traffic.downlinkBytes + downSpeed,
          uplinkSpeed: upSpeed,
          downlinkSpeed: downSpeed,
        ),
        latencyMs: latency,
      );

      // 定期持久化延迟 (节流: 每 5 次写一次)
      if (_random.nextInt(5) == 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyLatency, latency);
      }
    });
  }
}

/// 全局 Provider
final appProvider = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);
