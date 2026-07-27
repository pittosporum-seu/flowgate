import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../service/log_service.dart';
import 'api_models.dart';

/// FlowGate 本地 REST API 客户端
///
/// 与 Android 后端 Ktor Server (127.0.0.1:19840) 通信。
/// Flutter UI 和 AI Agent 地位平等，都通过此 API 操作。
class FlowGateApiClient {
  static const _defaultPort = 19840;
  static const _host = '127.0.0.1';

  final int port;
  final http.Client _client = http.Client();
  final _log = LogService.instance;

  FlowGateApiClient({this.port = _defaultPort});

  String get _baseUrl => 'http://$_host:$port/api/v1';

  // ─── Health ───────────────────────────────────────────────────────────

  /// 检查 API Server 是否可达
  Future<bool> isAvailable() async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── VPN ──────────────────────────────────────────────────────────────

  Future<VpnStatusDto?> getVpnStatus() async {
    final json = await _get('/vpn/status');
    if (json == null) return null;
    return VpnStatusDto.fromJson(json);
  }

  Future<bool> startVpn({String? config, String? remark, bool proxyOnly = false}) async {
    final json = await _post('/vpn/start', {
      if (config != null) 'config': config,
      if (remark != null) 'remark': remark,
      'proxyOnly': proxyOnly,
    });
    return json != null;
  }

  Future<bool> stopVpn() async {
    final json = await _post('/vpn/stop', {});
    return json != null;
  }

  /// SSE 事件流：实时接收 VPN 状态变化
  Stream<SseEvent> watchEvents() async* {
    final uri = Uri.parse('$_baseUrl/vpn/events');
    try {
      final request = http.Request('GET', uri);
      final response = await _client.send(request);

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String? eventType;
      await for (final line in lines) {
        if (line.startsWith('event: ')) {
          eventType = line.substring(7).trim();
        } else if (line.startsWith('data: ')) {
          final data = line.substring(6);
          yield SseEvent(type: eventType ?? 'message', data: data);
          eventType = null;
        }
      }
    } catch (e) {
      _log.warn('ApiClient', 'SSE stream error: $e');
    }
  }

  // ─── Nodes ────────────────────────────────────────────────────────────

  Future<List<NodeDto>> getNodes() async {
    final json = await _get('/nodes');
    if (json == null) return [];
    final nodes = json['nodes'] as List<dynamic>? ?? [];
    return nodes
        .map((e) => NodeDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NodeDto?> getNode(String id) async {
    final json = await _get('/nodes/$id');
    if (json == null) return null;
    return NodeDto.fromJson(json);
  }

  Future<NodeDto?> addNode(NodeDto node) async {
    final json = await _post('/nodes', node.toJson());
    if (json == null) return null;
    return NodeDto.fromJson(json);
  }

  /// 双写同步用：直接传 JSON map 添加节点
  Future<void> addNodeRaw(Map<String, dynamic> nodeJson) async {
    await _post('/nodes', nodeJson);
  }

  Future<int> importNodes(String content, {String? type, String? subscriptionId}) async {
    final json = await _post('/nodes/import', {
      'content': content,
      if (type != null) 'type': type,
      if (subscriptionId != null) 'subscriptionId': subscriptionId,
    });
    if (json == null) return 0;
    return (json['imported'] as num?)?.toInt() ?? 0;
  }

  Future<bool> deleteNode(String id) async {
    final ok = await _delete('/nodes/$id');
    return ok;
  }

  Future<NodeTestResponse?> testNode(String id) async {
    final json = await _post('/nodes/$id/test', {});
    if (json == null) return null;
    return NodeTestResponse.fromJson(json);
  }

  Future<String?> startTestAll() async {
    final json = await _post('/nodes/test-all', {});
    if (json == null) return null;
    return json['taskId'] as String?;
  }

  // ─── Subscriptions ────────────────────────────────────────────────────

  Future<List<SubscriptionDto>> getSubscriptions() async {
    final json = await _get('/subscriptions');
    if (json == null) return [];
    // _parseResponse wraps List data as {'_list': [...]}
    final list = json['_list'] as List<dynamic>? ?? [];
    return list
        .map((e) => SubscriptionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubscriptionDto?> addSubscription({
    required String name,
    required String url,
    bool autoUpdate = false,
  }) async {
    final json = await _post('/subscriptions', {
      'name': name,
      'url': url,
      'autoUpdate': autoUpdate,
    });
    if (json == null) return null;
    return SubscriptionDto.fromJson(json);
  }

  Future<bool> deleteSubscription(String id, {bool deleteNodes = false}) async {
    final ok = await _delete('/subscriptions/$id?deleteNodes=$deleteNodes');
    return ok;
  }

  Future<bool> refreshSubscription(String id) async {
    final json = await _post('/subscriptions/$id/update', {});
    return json != null;
  }

  // ─── Routing ──────────────────────────────────────────────────────────

  Future<RoutingRulesDto?> getRouting() async {
    final json = await _get('/routing');
    if (json == null) return null;
    return RoutingRulesDto.fromJson(json);
  }

  Future<RoutingRulesDto?> updateRouting(Map<String, dynamic> updates) async {
    final json = await _put('/routing', updates);
    if (json == null) return null;
    return RoutingRulesDto.fromJson(json);
  }

  // ─── System ───────────────────────────────────────────────────────────

  Future<SystemInfoDto?> getSystemInfo() async {
    final json = await _get('/system/info');
    if (json == null) return null;
    return SystemInfoDto.fromJson(json);
  }

  Future<List<Map<String, dynamic>>> getLogs({int limit = 100}) async {
    final json = await _get('/system/logs?limit=$limit');
    if (json == null) return [];
    final logs = json['logs'] as List<dynamic>? ?? [];
    return logs.map((e) => e as Map<String, dynamic>).toList();
  }

  // ─── HTTP helpers ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl$path'))
          .timeout(const Duration(seconds: 10));
      return _parseResponse(res);
    } catch (e) {
      _log.warn('ApiClient', 'GET $path failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      return _parseResponse(res);
    } catch (e) {
      _log.warn('ApiClient', 'POST $path failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _put(String path, Map<String, dynamic> body) async {
    try {
      final res = await _client
          .put(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return _parseResponse(res);
    } catch (e) {
      _log.warn('ApiClient', 'PUT $path failed: $e');
      return null;
    }
  }

  Future<bool> _delete(String path) async {
    try {
      final res = await _client
          .delete(Uri.parse('$_baseUrl$path'))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      _log.warn('ApiClient', 'DELETE $path failed: $e');
      return false;
    }
  }

  /// 解析 ApiResponse 包装：{"ok":true,"data":{...}}
  Map<String, dynamic>? _parseResponse(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log.warn('ApiClient', 'HTTP ${res.statusCode}: ${res.body}');
      return null;
    }
    try {
      final wrapper = jsonDecode(res.body) as Map<String, dynamic>;
      if (wrapper['ok'] == true) {
        final data = wrapper['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is List) return {'_list': data};
        return wrapper;
      }
      _log.warn('ApiClient', 'API error: ${wrapper['error']}');
      return null;
    } catch (e) {
      _log.warn('ApiClient', 'Parse error: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}

/// SSE 事件
class SseEvent {
  final String type;
  final String data;

  const SseEvent({required this.type, required this.data});

  Map<String, dynamic>? get jsonData {
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
