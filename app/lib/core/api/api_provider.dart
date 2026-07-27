import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// 全局 FlowGateApiClient Provider
/// 默认连接 127.0.0.1:19840（Ktor Server 固定端口）
final apiClientProvider = Provider<FlowGateApiClient>((ref) {
  final client = FlowGateApiClient();
  ref.onDispose(() => client.dispose());
  return client;
});
