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

    final outboundList = (config['outbounds'] as List?) ?? [];
    final outbounds = outboundList.length;
    final outboundTags = outboundList
        .map((o) => '${(o as Map)['protocol']}@${o['tag']}')
        .join(',');
    LogService.instance.info('ConfigAssembler',
        'Assembled: rules=${rules.length} outbounds=$outbounds [$outboundTags]');

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
}
