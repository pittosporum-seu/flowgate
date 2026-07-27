import 'dart:async';
import 'package:flutter/services.dart';
import 'xray_status.dart';

/// Flutter plugin interface for Xray-core JNI in-process VPN.
class FlowgateXray {
  static const _methodChannel = MethodChannel('com.flowgate.xray/methods');
  static const _eventChannel = EventChannel('com.flowgate.xray/status');

  Stream<XrayStatus>? _statusStream;

  /// Initialize the Xray core environment. Must be called before any other method.
  Future<void> init() async {
    await _methodChannel.invokeMethod('init');
  }

  /// Start VPN with the given Xray JSON config.
  Future<bool> startVpn({
    required String config,
    required String remark,
  }) async {
    final result = await _methodChannel.invokeMethod<bool>('startVpn', {
      'config': config,
      'remark': remark,
    });
    return result ?? false;
  }

  /// Stop the VPN connection.
  Future<void> stopVpn() async {
    await _methodChannel.invokeMethod('stopVpn');
  }

  /// Check if Xray core is currently running.
  Future<bool> get isRunning async {
    final result = await _methodChannel.invokeMethod<bool>('isRunning');
    return result ?? false;
  }

  /// Measure outbound delay for a given config (does not require active VPN).
  /// Returns delay in ms, or -1 on failure.
  Future<int> measureDelay({
    required String config,
    String url = 'https://www.google.com/generate_204',
  }) async {
    final result = await _methodChannel.invokeMethod<int>('measureDelay', {
      'config': config,
      'url': url,
    });
    return result ?? -1;
  }

  /// Get Xray core version string.
  Future<String> getCoreVersion() async {
    final result = await _methodChannel.invokeMethod<String>('getCoreVersion');
    return result ?? 'unknown';
  }

  /// Request VPN permission from the user.
  /// Returns true if permission was granted.
  Future<bool> requestVpnPermission() async {
    final result =
        await _methodChannel.invokeMethod<bool>('requestVpnPermission');
    return result ?? false;
  }

  /// Stream of connection status updates.
  Stream<XrayStatus> get onStatus {
    _statusStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => XrayStatus.fromMap(Map<String, dynamic>.from(event as Map)));
    return _statusStream!;
  }
}
