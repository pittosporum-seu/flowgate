import '../model/routing_models.dart';

/// 规则编译上下文
class RuleContext {
  final RouteMode mode;
  final List<ServiceRoutingDecision> serviceDecisions;
  final List<ServiceTarget> serviceTargets;
  final List<RulesetItem> rules;

  RuleContext({
    required this.mode,
    this.serviceDecisions = const [],
    this.serviceTargets = const [],
    List<RulesetItem>? rules,
  }) : rules = rules ?? [];
}

/// 责任链节点
class RuleChain {
  final List<RuleFilter> _filters;
  int _index = 0;

  RuleChain(this._filters);

  void proceed(RuleContext context) {
    if (_index < _filters.length) {
      _filters[_index++].process(context, this);
    }
  }
}

/// 规则过滤器接口 (责任链)
abstract class RuleFilter {
  void process(RuleContext context, RuleChain chain);
}

/// 规则管线 - 按顺序执行 Filter 链
class RulePipeline {
  final List<RuleFilter> _filters;

  RulePipeline(this._filters);

  List<RulesetItem> compile({
    required RouteMode mode,
    List<ServiceRoutingDecision> decisions = const [],
    List<ServiceTarget> targets = const [],
  }) {
    final context = RuleContext(
      mode: mode,
      serviceDecisions: decisions,
      serviceTargets: targets,
    );
    RuleChain(_filters).proceed(context);
    return context.rules;
  }
}

// ============================================================
// 具体 Filter 实现
// ============================================================

/// 广告拦截 (ADBLOCK 包)
class AdBlockFilter extends RuleFilter {
  @override
  void process(RuleContext context, RuleChain chain) {
    context.rules.add(const RulesetItem(
      remarks: 'Block advertisements',
      domain: ['geosite:category-ads-all'],
      outboundTag: OutboundTag.block,
    ));
    chain.proceed(context);
  }
}

/// 基础直连规则: QUIC 拦截 + 私有网络直连
class BaseDirectFilter extends RuleFilter {
  @override
  void process(RuleContext context, RuleChain chain) {
    context.rules.add(const RulesetItem(
      remarks: 'Block QUIC',
      port: '443',
      network: 'udp',
      outboundTag: OutboundTag.block,
    ));
    context.rules.add(const RulesetItem(
      remarks: 'Private network direct',
      ip: ['geoip:private'],
      domain: ['geosite:private'],
      outboundTag: OutboundTag.direct,
    ));
    chain.proceed(context);
  }
}

/// 服务自适应规则 (根据探测决策)
class ServiceAdaptiveFilter extends RuleFilter {
  @override
  void process(RuleContext context, RuleChain chain) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final targetMap = {for (final t in context.serviceTargets) t.id: t};

    for (final decision in context.serviceDecisions) {
      if (decision.action == RouteAction.unavailable) continue;
      if (decision.validUntil < now) continue;
      final target = targetMap[decision.serviceId];
      if (target == null) continue;
      final tag = decision.action.outboundTag;
      if (tag == null) continue;

      context.rules.add(RulesetItem(
        remarks: '${target.title} -> ${decision.action.name}',
        domain: target.domains,
        outboundTag: tag,
      ));
    }
    chain.proceed(context);
  }
}

/// 地理规则 (CN 分流)
class GeoRuleFilter extends RuleFilter {
  @override
  void process(RuleContext context, RuleChain chain) {
    switch (context.mode) {
      case RouteMode.smart:
        // CN 直连
        context.rules.add(const RulesetItem(
          remarks: 'CN direct',
          ip: ['geoip:cn'],
          domain: ['geosite:cn'],
          outboundTag: OutboundTag.direct,
        ));
        // 海外代理
        context.rules.add(const RulesetItem(
          remarks: 'Overseas proxy',
          domain: ['geosite:geolocation-!cn'],
          outboundTag: OutboundTag.proxy,
        ));
      case RouteMode.blockCn:
        // CN 拦截
        context.rules.add(const RulesetItem(
          remarks: 'Block CN',
          ip: ['geoip:cn'],
          domain: ['geosite:cn'],
          outboundTag: OutboundTag.block,
        ));
      case RouteMode.global:
      case RouteMode.custom:
        break;
    }
    chain.proceed(context);
  }
}

/// 最终兜底规则
class FinalRuleFilter extends RuleFilter {
  @override
  void process(RuleContext context, RuleChain chain) {
    final isDirectFinal = context.mode == RouteMode.smart;
    context.rules.add(RulesetItem(
      remarks: isDirectFinal ? 'Final direct' : 'Final proxy',
      port: '0-65535',
      outboundTag: isDirectFinal ? OutboundTag.direct : OutboundTag.proxy,
    ));
    chain.proceed(context);
  }
}

/// 默认管线工厂
RulePipeline buildDefaultPipeline() {
  return RulePipeline([
    AdBlockFilter(),
    BaseDirectFilter(),
    ServiceAdaptiveFilter(),
    GeoRuleFilter(),
    FinalRuleFilter(),
  ]);
}
