/// 路由领域模型
library;

/// 路由模式
enum RouteMode {
  smart,
  global,
  blockCn,
  custom;

  String get label => switch (this) {
        RouteMode.smart => 'Smart',
        RouteMode.global => 'Global',
        RouteMode.blockCn => 'Block CN',
        RouteMode.custom => 'Custom',
      };

  String get description => switch (this) {
        RouteMode.smart => 'CN direct, overseas proxy',
        RouteMode.global => 'All traffic via proxy',
        RouteMode.blockCn => 'Block CN, proxy others',
        RouteMode.custom => 'User-defined rules',
      };
}

/// 出站标签
enum OutboundTag {
  proxy,
  direct,
  block;

  String get value => switch (this) {
        OutboundTag.proxy => 'proxy',
        OutboundTag.direct => 'direct',
        OutboundTag.block => 'block',
      };
}

/// 单条路由规则
class RulesetItem {
  final String remarks;
  final List<String> domain;
  final List<String> ip;
  final String? port;
  final String? network;
  final OutboundTag outboundTag;

  const RulesetItem({
    this.remarks = '',
    this.domain = const [],
    this.ip = const [],
    this.port,
    this.network,
    required this.outboundTag,
  });

  Map<String, dynamic> toJson() => {
        'remarks': remarks,
        'domain': domain,
        'ip': ip,
        'port': port,
        'network': network,
        'outboundTag': outboundTag.value,
      };

  factory RulesetItem.fromJson(Map<String, dynamic> json) => RulesetItem(
        remarks: json['remarks'] as String? ?? '',
        domain: (json['domain'] as List?)?.cast<String>() ?? const [],
        ip: (json['ip'] as List?)?.cast<String>() ?? const [],
        port: json['port'] as String?,
        network: json['network'] as String?,
        outboundTag: OutboundTag.values.firstWhere(
          (t) => t.value == json['outboundTag'],
          orElse: () => OutboundTag.proxy,
        ),
      );
}

/// 服务探测目标
class ServiceTarget {
  final String id;
  final String title;
  final List<String> domains;
  final String probeUrl;
  final AdaptiveRoutePolicy policy;
  final bool preferProxy;
  final bool enabled;

  const ServiceTarget({
    required this.id,
    required this.title,
    this.domains = const [],
    this.probeUrl = '',
    this.policy = AdaptiveRoutePolicy.auto,
    this.preferProxy = false,
    this.enabled = true,
  });
}

/// 自适应路由策略
enum AdaptiveRoutePolicy {
  auto,
  forceDirect,
  forceProxy,
  disabled;
}

/// 路由动作
enum RouteAction {
  proxy,
  direct,
  block,
  unavailable;

  OutboundTag? get outboundTag => switch (this) {
        RouteAction.proxy => OutboundTag.proxy,
        RouteAction.direct => OutboundTag.direct,
        RouteAction.block => OutboundTag.block,
        RouteAction.unavailable => null,
      };
}

/// 探测候选路径
enum CandidateRoute { direct, proxy }

/// 单次探测结果
class ServiceProbeResult {
  final String serviceId;
  final CandidateRoute route;
  final bool success;
  final int? latencyMs;
  final String? errorMessage;

  const ServiceProbeResult({
    required this.serviceId,
    required this.route,
    required this.success,
    this.latencyMs,
    this.errorMessage,
  });
}

/// 探测包 (直连 + 代理)
class ServiceProbeBundle {
  final ServiceTarget service;
  final ServiceProbeResult? direct;
  final ServiceProbeResult? proxy;

  const ServiceProbeBundle({required this.service, this.direct, this.proxy});
}

/// 路由决策
class ServiceRoutingDecision {
  final String serviceId;
  final RouteAction action;
  final String reason;
  final int validUntil;

  const ServiceRoutingDecision({
    required this.serviceId,
    required this.action,
    this.reason = '',
    this.validUntil = 0,
  });

  Map<String, dynamic> toJson() => {
        'serviceId': serviceId,
        'action': action.name,
        'reason': reason,
        'validUntil': validUntil,
      };

  factory ServiceRoutingDecision.fromJson(Map<String, dynamic> json) =>
      ServiceRoutingDecision(
        serviceId: json['serviceId'] as String,
        action: RouteAction.values.firstWhere(
          (a) => a.name == json['action'],
          orElse: () => RouteAction.unavailable,
        ),
        reason: json['reason'] as String? ?? '',
        validUntil: json['validUntil'] as int? ?? 0,
      );
}
