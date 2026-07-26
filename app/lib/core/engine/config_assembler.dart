import 'dart:convert';
import '../../features/routing/model/routing_models.dart';
import '../service/log_service.dart';

/// 配置组装器
/// 将「节点 rawConfig」+「RulePipeline 路由规则」组装为最终 Xray config JSON
/// 供 flutter_vless.startVless 使用
class ConfigAssembler {
  /// 组装最终 Xray config
  /// [profileConfig] 节点的 rawConfig (getFullConfiguration 产物)
  /// [rules] RulePipeline 编译出的路由规则
  static String assemble({
    required String profileConfig,
    required List<RulesetItem> rules,
  }) {
    final config = jsonDecode(profileConfig) as Map<String, dynamic>;

    _ensureOutbounds(config);
    _injectRouting(config, rules);
    _injectPolicyTimeouts(config);
    _enableSniffing(config);

    final outboundList = (config['outbounds'] as List?) ?? [];
    final outbounds = outboundList.length;
    final outboundTags = outboundList
        .map((o) => '${(o as Map)['protocol']}@${o['tag']}')
        .join(',');
    LogService.instance.info('ConfigAssembler',
        'Assembled: rules=${rules.length} outbounds=$outbounds [$outboundTags]');

    return jsonEncode(config);
  }

  /// 组装测速专用 config：强制所有流量走 proxy 出站
  /// 避免 AsIs 空规则下默认出站不明确，导致测速请求走直连被 GFW 重置
  static String assembleDelayTest(String profileConfig) {
    final config = jsonDecode(profileConfig) as Map<String, dynamic>;
    _ensureOutbounds(config);
    _injectPolicyTimeouts(config);
    _enableSniffing(config);
    final routing = (config['routing'] as Map<String, dynamic>?) ?? {};
    routing['domainStrategy'] = 'AsIs';
    routing['rules'] = [
      // 兑底规则：所有 TCP/UDP 流量 → proxy（测速必须经过代理节点）
      {'type': 'field', 'network': 'tcp,udp', 'outboundTag': 'proxy'},
    ];
    config['routing'] = routing;
    return jsonEncode(config);
  }

  /// 确保 outbounds 含 proxy/direct/block 三个 tag
  static void _ensureOutbounds(Map<String, dynamic> config) {
    final outbounds = (config['outbounds'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // 主出站标记为 proxy
    bool hasProxy = false;
    for (final ob in outbounds) {
      final proto = ob['protocol'];
      if (proto != null && proto != 'freedom' && proto != 'blackhole') {
        ob['tag'] = 'proxy';
        hasProxy = true;
        break;
      }
    }
    // 若没有明确主出站，把第一个标记为 proxy
    if (!hasProxy && outbounds.isNotEmpty) {
      outbounds.first['tag'] = 'proxy';
    }

    // 补充 direct / block 出站
    if (!outbounds.any((o) => o['tag'] == 'direct')) {
      outbounds.add({
        'protocol': 'freedom',
        'tag': 'direct',
        'settings': {'domainStrategy': 'UseIP'},
      });
    }
    if (!outbounds.any((o) => o['tag'] == 'block')) {
      outbounds.add({
        'protocol': 'blackhole',
        'tag': 'block',
      });
    }

    config['outbounds'] = outbounds;
  }

  /// 注入路由规则到 config["routing"]
  static void _injectRouting(Map<String, dynamic> config, List<RulesetItem> rules) {
    final routing = (config['routing'] as Map<String, dynamic>?) ?? {};
    routing['domainStrategy'] ??= 'AsIs';

    final xrayRules = rules.map(toXrayRule).toList();
    routing['rules'] = xrayRules;

    config['routing'] = routing;
  }

  /// RulesetItem → Xray routing rule
  static Map<String, dynamic> toXrayRule(RulesetItem item) {
    final rule = <String, dynamic>{
      'type': 'field',
      'outboundTag': item.outboundTag.value,
    };
    if (item.domain.isNotEmpty) rule['domain'] = item.domain;
    if (item.ip.isNotEmpty) rule['ip'] = item.ip;
    if (item.port != null && item.port!.isNotEmpty) rule['port'] = item.port;
    if (item.network != null && item.network!.isNotEmpty) rule['network'] = item.network;
    return rule;
  }

  /// 生成 Xray routing 段预览 JSON (供 Routing 页展示)
  static String buildRoutingPreview(List<RulesetItem> rules) {
    final routing = {
      'domainStrategy': 'AsIs',
      'rules': rules.map(toXrayRule).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(routing);
  }

  /// 注入 Xray policy 超时配置：防止空闲连接累积导致 fd 耗尽
  /// 原生层会注入 policy 但只含 stats 开关，不含超时；这里补充超时参数
  static void _injectPolicyTimeouts(Map<String, dynamic> config) {
    final policy = (config['policy'] as Map<String, dynamic>?) ?? {};
    final levels = (policy['levels'] as Map<String, dynamic>?) ?? {};
    // level 0 = 默认级别，应用到所有连接
    final level0 = (levels['0'] as Map<String, dynamic>?) ?? {};
    level0['handshake'] = 4;        // 握手超时 4s
    level0['connIdle'] = 30;        // 连接空闲超时 30s
    level0['uplinkOnly'] = 2;       // 上行结束后 2s 关闭
    level0['downlinkOnly'] = 4;     // 下行结束后 4s 关闭
    level0['statsUserUplink'] = true;
    level0['statsUserDownlink'] = true;
    levels['0'] = level0;
    policy['levels'] = levels;
    // system 级别超时
    final system = (policy['system'] as Map<String, dynamic>?) ?? {};
    system['statsInboundUplink'] = true;
    system['statsInboundDownlink'] = true;
    system['statsOutboundUplink'] = true;
    system['statsOutboundDownlink'] = true;
    policy['system'] = system;
    config['policy'] = policy;
  }

  /// 为所有 SOCKS/HTTP inbound 启用 sniffing
  /// 让 Xray 从 TLS SNI / HTTP Host 中嗅探真实域名，配合路由规则使用
  static void _enableSniffing(Map<String, dynamic> config) {
    final inbounds = (config['inbounds'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (final ib in inbounds) {
      final proto = ib['protocol'];
      if (proto == 'socks' || proto == 'http') {
        ib['sniffing'] = {
          'enabled': true,
          'destOverride': ['http', 'tls'],
        };
      }
    }
  }
}
