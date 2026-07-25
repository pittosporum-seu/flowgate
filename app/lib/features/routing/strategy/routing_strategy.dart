import '../model/routing_models.dart';

/// 路由决策策略接口 (Strategy Pattern)
abstract class RoutingStrategy {
  ServiceRoutingDecision decide(
    ServiceTarget service,
    ServiceProbeBundle bundle,
    ServiceRoutingDecision? lastKnownGood,
  );
}

/// 自动决策: 根据探测结果选择直连/代理
class AutoRoutingStrategy implements RoutingStrategy {
  static const decisionTtlMs = 15 * 60 * 1000;

  @override
  ServiceRoutingDecision decide(
    ServiceTarget service,
    ServiceProbeBundle bundle,
    ServiceRoutingDecision? lastKnownGood,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final directOk = bundle.direct?.success ?? false;
    final proxyOk = bundle.proxy?.success ?? false;

    RouteAction action;
    String reason;

    if (directOk && !proxyOk) {
      action = RouteAction.direct;
      reason = 'direct_only_works';
    } else if (!directOk && proxyOk) {
      action = RouteAction.proxy;
      reason = 'proxy_only_works';
    } else if (directOk && proxyOk) {
      action = service.preferProxy ? RouteAction.proxy : RouteAction.direct;
      reason = service.preferProxy ? 'both_work_proxy_preferred' : 'both_work_direct_preferred';
    } else {
      // 两者都失败: 沿用上次已知良好的决策
      if (lastKnownGood != null && lastKnownGood.action != RouteAction.unavailable) {
        return ServiceRoutingDecision(
          serviceId: service.id,
          action: lastKnownGood.action,
          reason: 'both_failed_last_known_good',
          validUntil: now + decisionTtlMs,
        );
      }
      action = RouteAction.unavailable;
      reason = 'both_failed_no_route';
    }

    return ServiceRoutingDecision(
      serviceId: service.id,
      action: action,
      reason: reason,
      validUntil: now + decisionTtlMs,
    );
  }
}

/// 强制直连
class ForceDirectStrategy implements RoutingStrategy {
  @override
  ServiceRoutingDecision decide(
    ServiceTarget service,
    ServiceProbeBundle bundle,
    ServiceRoutingDecision? lastKnownGood,
  ) {
    return ServiceRoutingDecision(
      serviceId: service.id,
      action: RouteAction.direct,
      reason: 'user_forced_direct',
      validUntil: DateTime.now().millisecondsSinceEpoch + 365 * 24 * 3600 * 1000,
    );
  }
}

/// 强制代理
class ForceProxyStrategy implements RoutingStrategy {
  @override
  ServiceRoutingDecision decide(
    ServiceTarget service,
    ServiceProbeBundle bundle,
    ServiceRoutingDecision? lastKnownGood,
  ) {
    return ServiceRoutingDecision(
      serviceId: service.id,
      action: RouteAction.proxy,
      reason: 'user_forced_proxy',
      validUntil: DateTime.now().millisecondsSinceEpoch + 365 * 24 * 3600 * 1000,
    );
  }
}

/// 禁用
class DisabledStrategy implements RoutingStrategy {
  @override
  ServiceRoutingDecision decide(
    ServiceTarget service,
    ServiceProbeBundle bundle,
    ServiceRoutingDecision? lastKnownGood,
  ) {
    return ServiceRoutingDecision(
      serviceId: service.id,
      action: RouteAction.unavailable,
      reason: 'user_disabled',
    );
  }
}

/// 策略选择器
class RoutingStrategyResolver {
  RoutingStrategy resolve(AdaptiveRoutePolicy policy) {
    return switch (policy) {
      AdaptiveRoutePolicy.auto => AutoRoutingStrategy(),
      AdaptiveRoutePolicy.forceDirect => ForceDirectStrategy(),
      AdaptiveRoutePolicy.forceProxy => ForceProxyStrategy(),
      AdaptiveRoutePolicy.disabled => DisabledStrategy(),
    };
  }
}
