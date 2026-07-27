/// Connection status emitted by the Xray core.
enum XrayConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// Snapshot of Xray connection status + traffic.
class XrayStatus {
  final XrayConnectionState state;
  final int durationSeconds;
  final int uplinkSpeed; // bytes/sec
  final int downlinkSpeed; // bytes/sec
  final int uplinkTotal; // bytes
  final int downlinkTotal; // bytes

  const XrayStatus({
    this.state = XrayConnectionState.disconnected,
    this.durationSeconds = 0,
    this.uplinkSpeed = 0,
    this.downlinkSpeed = 0,
    this.uplinkTotal = 0,
    this.downlinkTotal = 0,
  });

  factory XrayStatus.fromMap(Map<String, dynamic> map) {
    final stateStr = (map['state'] as String? ?? 'DISCONNECTED').toUpperCase();
    return XrayStatus(
      state: switch (stateStr) {
        'CONNECTED' => XrayConnectionState.connected,
        'CONNECTING' => XrayConnectionState.connecting,
        'DISCONNECTING' => XrayConnectionState.disconnecting,
        _ => XrayConnectionState.disconnected,
      },
      durationSeconds: map['duration'] as int? ?? 0,
      uplinkSpeed: map['uplinkSpeed'] as int? ?? 0,
      downlinkSpeed: map['downlinkSpeed'] as int? ?? 0,
      uplinkTotal: map['uplinkTotal'] as int? ?? 0,
      downlinkTotal: map['downlinkTotal'] as int? ?? 0,
    );
  }

  @override
  String toString() =>
      'XrayStatus(state=$state, dur=${durationSeconds}s, '
      'up=${uplinkSpeed}B/s, down=${downlinkSpeed}B/s)';
}
