import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'model/routing_models.dart';
import 'pipeline/rule_pipeline.dart';
import 'strategy/routing_strategy.dart';

const _keyRouteMode = 'route_mode';
const _keyDecisions = 'service_decisions';

/// 默认服务探测目标
const defaultServiceTargets = [
  ServiceTarget(
    id: 'openai',
    title: 'OpenAI / ChatGPT',
    domains: ['domain:chatgpt.com', 'domain:openai.com', 'domain:api.openai.com'],
    probeUrl: 'https://api.openai.com',
    preferProxy: true,
  ),
  ServiceTarget(
    id: 'google',
    title: 'Google',
    domains: ['domain:google.com', 'domain:googleapis.com', 'domain:gstatic.com'],
    probeUrl: 'https://www.gstatic.com/generate_204',
    preferProxy: true,
  ),
  ServiceTarget(
    id: 'deepseek',
    title: 'DeepSeek',
    domains: ['domain:deepseek.com', 'domain:api.deepseek.com'],
    probeUrl: 'https://api.deepseek.com',
  ),
  ServiceTarget(
    id: 'github',
    title: 'GitHub',
    domains: ['domain:github.com', 'domain:githubusercontent.com'],
    probeUrl: 'https://github.com',
  ),
];

/// Routing 状态
class RoutingState {
  final RouteMode mode;
  final List<RulesetItem> compiledRules;
  final List<ServiceRoutingDecision> decisions;
  final bool isProbing;

  const RoutingState({
    this.mode = RouteMode.smart,
    this.compiledRules = const [],
    this.decisions = const [],
    this.isProbing = false,
  });

  RoutingState copyWith({
    RouteMode? mode,
    List<RulesetItem>? compiledRules,
    List<ServiceRoutingDecision>? decisions,
    bool? isProbing,
  }) {
    return RoutingState(
      mode: mode ?? this.mode,
      compiledRules: compiledRules ?? this.compiledRules,
      decisions: decisions ?? this.decisions,
      isProbing: isProbing ?? this.isProbing,
    );
  }
}

/// Routing Notifier
class RoutingNotifier extends Notifier<RoutingState> {
  final _pipeline = buildDefaultPipeline();
  final _strategyResolver = RoutingStrategyResolver();

  @override
  RoutingState build() {
    return const RoutingState();
  }

  /// 启动时恢复
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_keyRouteMode);
    final mode = RouteMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => RouteMode.smart,
    );

    List<ServiceRoutingDecision> decisions = const [];
    final rawDecisions = prefs.getString(_keyDecisions);
    if (rawDecisions != null && rawDecisions.isNotEmpty) {
      final list = jsonDecode(rawDecisions) as List;
      decisions = list
          .map((e) => ServiceRoutingDecision.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final rules = _compile(mode, decisions);
    state = RoutingState(mode: mode, compiledRules: rules, decisions: decisions);
  }

  /// 切换路由模式
  Future<void> setMode(RouteMode mode) async {
    final rules = _compile(mode, state.decisions);
    state = state.copyWith(mode: mode, compiledRules: rules);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRouteMode, mode.name);
  }

  /// 运行自适应探测 (当前为模拟，Epic 5 接入真实 HTTP 探测)
  Future<void> probeServices() async {
    if (state.isProbing) return;
    state = state.copyWith(isProbing: true);

    // 模拟探测耗时
    await Future.delayed(const Duration(seconds: 2));

    final decisions = <ServiceRoutingDecision>[];

    for (final target in defaultServiceTargets) {
      final strategy = _strategyResolver.resolve(target.policy);
      // 模拟探测结果: 国内服务直连可用，海外服务需代理
      final isCnService = target.id == 'deepseek';
      final bundle = ServiceProbeBundle(
        service: target,
        direct: ServiceProbeResult(
          serviceId: target.id,
          route: CandidateRoute.direct,
          success: isCnService,
          latencyMs: isCnService ? 45 : null,
        ),
        proxy: ServiceProbeResult(
          serviceId: target.id,
          route: CandidateRoute.proxy,
          success: true,
          latencyMs: 180,
        ),
      );
      final lastGood = state.decisions.firstWhere(
        (d) => d.serviceId == target.id,
        orElse: () => ServiceRoutingDecision(
            serviceId: target.id, action: RouteAction.unavailable),
      );
      decisions.add(strategy.decide(target, bundle, lastGood));
    }

    final rules = _compile(state.mode, decisions);
    state = state.copyWith(decisions: decisions, compiledRules: rules, isProbing: false);

    // 持久化决策
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyDecisions,
      jsonEncode(decisions.map((d) => d.toJson()).toList()),
    );
  }

  List<RulesetItem> _compile(RouteMode mode, List<ServiceRoutingDecision> decisions) {
    if (mode == RouteMode.custom) return state.compiledRules;
    return _pipeline.compile(
      mode: mode,
      decisions: decisions,
      targets: defaultServiceTargets,
    );
  }
}

/// Routing Provider
final routingProvider =
    NotifierProvider<RoutingNotifier, RoutingState>(RoutingNotifier.new);
