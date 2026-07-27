/// FlowGate REST API 响应模型
/// 与 Android 后端 Ktor DTO 一一对应
library;

// ─── 通用响应 ─────────────────────────────────────────────────────────────

class ApiResponse<T> {
  final bool ok;
  final T? data;
  final String? error;

  const ApiResponse({required this.ok, this.data, this.error});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    return ApiResponse(
      ok: json['ok'] as bool? ?? false,
      data: json['data'] != null && fromData != null
          ? fromData(json['data'])
          : json['data'] as T?,
      error: json['error'] as String?,
    );
  }
}

// ─── VPN ──────────────────────────────────────────────────────────────────

class VpnStatusDto {
  final String state;
  final String duration;
  final int uploadSpeed;
  final int downloadSpeed;
  final int uploadTotal;
  final int downloadTotal;
  final String? nodeId;
  final String? nodeName;

  const VpnStatusDto({
    required this.state,
    this.duration = '00:00:00',
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.uploadTotal = 0,
    this.downloadTotal = 0,
    this.nodeId,
    this.nodeName,
  });

  factory VpnStatusDto.fromJson(Map<String, dynamic> json) {
    return VpnStatusDto(
      state: json['state'] as String? ?? 'disconnected',
      duration: json['duration'] as String? ?? '00:00:00',
      uploadSpeed: (json['uploadSpeed'] as num?)?.toInt() ?? 0,
      downloadSpeed: (json['downloadSpeed'] as num?)?.toInt() ?? 0,
      uploadTotal: (json['uploadTotal'] as num?)?.toInt() ?? 0,
      downloadTotal: (json['downloadTotal'] as num?)?.toInt() ?? 0,
      nodeId: json['nodeId'] as String?,
      nodeName: json['nodeName'] as String?,
    );
  }
}

// ─── 节点 ─────────────────────────────────────────────────────────────────

class NodeDto {
  final String id;
  final String name;
  final String type;
  final String server;
  final int port;
  final String password;
  final String? method;
  final String? sni;
  final String? alpn;
  final String? network;
  final String? path;
  final String? host;
  final bool allowInsecure;
  final String? subscriptionId;
  final int? latencyMs;
  final int createdAt;
  final String? rawConfig;

  const NodeDto({
    required this.id,
    required this.name,
    required this.type,
    required this.server,
    required this.port,
    this.password = '',
    this.method,
    this.sni,
    this.alpn,
    this.network,
    this.path,
    this.host,
    this.allowInsecure = false,
    this.subscriptionId,
    this.latencyMs,
    this.createdAt = 0,
    this.rawConfig,
  });

  factory NodeDto.fromJson(Map<String, dynamic> json) {
    return NodeDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      server: json['server'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
      password: json['password'] as String? ?? '',
      method: json['method'] as String?,
      sni: json['sni'] as String?,
      alpn: json['alpn'] as String?,
      network: json['network'] as String?,
      path: json['path'] as String?,
      host: json['host'] as String?,
      allowInsecure: json['allowInsecure'] as bool? ?? false,
      subscriptionId: json['subscriptionId'] as String?,
      latencyMs: (json['latencyMs'] as num?)?.toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      rawConfig: json['rawConfig'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'server': server,
        'port': port,
        'password': password,
        if (method != null) 'method': method,
        if (sni != null) 'sni': sni,
        if (alpn != null) 'alpn': alpn,
        if (network != null) 'network': network,
        if (path != null) 'path': path,
        if (host != null) 'host': host,
        'allowInsecure': allowInsecure,
        if (subscriptionId != null) 'subscriptionId': subscriptionId,
        if (latencyMs != null) 'latencyMs': latencyMs,
        'createdAt': createdAt,
        if (rawConfig != null) 'rawConfig': rawConfig,
      };
}

class NodeTestResponse {
  final String nodeId;
  final int? delay;
  final String? error;

  const NodeTestResponse({required this.nodeId, this.delay, this.error});

  factory NodeTestResponse.fromJson(Map<String, dynamic> json) {
    return NodeTestResponse(
      nodeId: json['nodeId'] as String? ?? '',
      delay: (json['delay'] as num?)?.toInt(),
      error: json['error'] as String?,
    );
  }
}

// ─── 订阅 ─────────────────────────────────────────────────────────────────

class SubscriptionDto {
  final String id;
  final String name;
  final String url;
  final bool autoUpdate;
  final int updateIntervalHours;
  final int? lastUpdated;
  final int nodeCount;
  final int? trafficUsed;
  final int? trafficTotal;
  final int? expireAt;
  final int createdAt;

  const SubscriptionDto({
    required this.id,
    required this.name,
    required this.url,
    this.autoUpdate = false,
    this.updateIntervalHours = 24,
    this.lastUpdated,
    this.nodeCount = 0,
    this.trafficUsed,
    this.trafficTotal,
    this.expireAt,
    this.createdAt = 0,
  });

  factory SubscriptionDto.fromJson(Map<String, dynamic> json) {
    return SubscriptionDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      autoUpdate: json['autoUpdate'] as bool? ?? false,
      updateIntervalHours: (json['updateIntervalHours'] as num?)?.toInt() ?? 24,
      lastUpdated: (json['lastUpdated'] as num?)?.toInt(),
      nodeCount: (json['nodeCount'] as num?)?.toInt() ?? 0,
      trafficUsed: (json['trafficUsed'] as num?)?.toInt(),
      trafficTotal: (json['trafficTotal'] as num?)?.toInt(),
      expireAt: (json['expireAt'] as num?)?.toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── 路由规则 ─────────────────────────────────────────────────────────────

class RoutingRulesDto {
  final String domainStrategy;
  final List<RoutingRuleDto> rules;
  final bool bypassLan;
  final bool bypassChina;
  final List<String> proxyDomains;
  final List<String> directDomains;

  const RoutingRulesDto({
    this.domainStrategy = 'IPIfNonMatch',
    this.rules = const [],
    this.bypassLan = true,
    this.bypassChina = false,
    this.proxyDomains = const [],
    this.directDomains = const [],
  });

  factory RoutingRulesDto.fromJson(Map<String, dynamic> json) {
    return RoutingRulesDto(
      domainStrategy: json['domainStrategy'] as String? ?? 'IPIfNonMatch',
      rules: (json['rules'] as List<dynamic>?)
              ?.map((e) => RoutingRuleDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      bypassLan: json['bypassLan'] as bool? ?? true,
      bypassChina: json['bypassChina'] as bool? ?? false,
      proxyDomains: (json['proxyDomains'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      directDomains: (json['directDomains'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

class RoutingRuleDto {
  final String id;
  final String type;
  final String outboundTag;
  final List<String> domain;
  final List<String> ip;
  final bool enabled;
  final int priority;

  const RoutingRuleDto({
    required this.id,
    this.type = 'field',
    required this.outboundTag,
    this.domain = const [],
    this.ip = const [],
    this.enabled = true,
    this.priority = 0,
  });

  factory RoutingRuleDto.fromJson(Map<String, dynamic> json) {
    return RoutingRuleDto(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'field',
      outboundTag: json['outboundTag'] as String? ?? 'proxy',
      domain: (json['domain'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      ip:
          (json['ip'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      enabled: json['enabled'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── 系统 ─────────────────────────────────────────────────────────────────

class SystemInfoDto {
  final String version;
  final String coreVersion;
  final String platform;
  final int apiPort;

  const SystemInfoDto({
    required this.version,
    required this.coreVersion,
    this.platform = 'android',
    this.apiPort = 0,
  });

  factory SystemInfoDto.fromJson(Map<String, dynamic> json) {
    return SystemInfoDto(
      version: json['version'] as String? ?? '',
      coreVersion: json['coreVersion'] as String? ?? '',
      platform: json['platform'] as String? ?? 'android',
      apiPort: (json['apiPort'] as num?)?.toInt() ?? 0,
    );
  }
}
