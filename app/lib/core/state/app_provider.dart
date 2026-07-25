import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state.dart';

/// AppState 的 Riverpod Notifier
/// 当前为 Mock 实现，后续 Epic 5 替换为真实 CoreEngine
class AppNotifier extends Notifier<AppState> {
  Timer? _trafficTimer;
  final _random = Random();

  @override
  AppState build() {
    ref.onDispose(() => _trafficTimer?.cancel());
    return const AppState(
      currentNodeName: 'HK-01 | Azure',
      latencyMs: 42,
    );
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

  /// 模拟流量增长 (真实实现: CoreEngine.queryStats 轮询)
  void _startTrafficSimulation() {
    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isRunning) return;

      final upSpeed = 20000 + _random.nextInt(180000); // 20~200 KB/s
      final downSpeed = 80000 + _random.nextInt(900000); // 80~980 KB/s

      state = state.copyWith(
        traffic: state.traffic.copyWith(
          uplinkBytes: state.traffic.uplinkBytes + upSpeed,
          downlinkBytes: state.traffic.downlinkBytes + downSpeed,
          uplinkSpeed: upSpeed,
          downlinkSpeed: downSpeed,
        ),
        latencyMs: 38 + _random.nextInt(20),
      );
    });
  }
}

/// 全局 Provider
final appProvider = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);
