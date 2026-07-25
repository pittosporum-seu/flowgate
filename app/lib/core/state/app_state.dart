/// FlowGate 全局状态模型
library;

enum VpnConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class TrafficStats {
  final int uplinkBytes;
  final int downlinkBytes;
  final int uplinkSpeed; // bytes/sec
  final int downlinkSpeed; // bytes/sec

  const TrafficStats({
    this.uplinkBytes = 0,
    this.downlinkBytes = 0,
    this.uplinkSpeed = 0,
    this.downlinkSpeed = 0,
  });

  TrafficStats copyWith({
    int? uplinkBytes,
    int? downlinkBytes,
    int? uplinkSpeed,
    int? downlinkSpeed,
  }) {
    return TrafficStats(
      uplinkBytes: uplinkBytes ?? this.uplinkBytes,
      downlinkBytes: downlinkBytes ?? this.downlinkBytes,
      uplinkSpeed: uplinkSpeed ?? this.uplinkSpeed,
      downlinkSpeed: downlinkSpeed ?? this.downlinkSpeed,
    );
  }
}

class AppState {
  final VpnConnectionState connectionState;
  final TrafficStats traffic;
  final int? latencyMs;
  final String? currentNodeName;
  final String? errorMessage;

  const AppState({
    this.connectionState = VpnConnectionState.disconnected,
    this.traffic = const TrafficStats(),
    this.latencyMs,
    this.currentNodeName,
    this.errorMessage,
  });

  bool get isRunning => connectionState == VpnConnectionState.connected;

  AppState copyWith({
    VpnConnectionState? connectionState,
    TrafficStats? traffic,
    int? latencyMs,
    String? currentNodeName,
    String? errorMessage,
  }) {
    return AppState(
      connectionState: connectionState ?? this.connectionState,
      traffic: traffic ?? this.traffic,
      latencyMs: latencyMs ?? this.latencyMs,
      currentNodeName: currentNodeName ?? this.currentNodeName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 流量格式化工具
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String formatSpeed(int bytesPerSec) {
  return '${formatBytes(bytesPerSec)}/s';
}
