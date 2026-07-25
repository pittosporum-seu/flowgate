import 'dart:convert';
import 'package:flutter_vless/flutter_vless.dart';
import '../model/profile_item.dart';

/// 基于 flutter_vless 的导入适配器
/// 替代自研 LinkParser，支持 vmess/vless/trojan/ss/socks/hysteria2
/// + 原始 Xray JSON + base64 订阅 + Clash YAML + sing-box JSON
class VlessImportAdapter {
  static int _counter = 0;

  /// 解析单条链接/配置，失败返回 null
  static ProfileItem? parseSingle(String raw) {
    try {
      final parsed = FlutterVless.parse(raw.trim());
      return _toProfileItem(parsed);
    } catch (_) {
      return null;
    }
  }

  /// 批量解析订阅内容，自动去重
  static List<ProfileItem> parseBatch(String content, {String? subscriptionId}) {
    try {
      final parsedList = FlutterVless.parseMany(content.trim());
      final results = <ProfileItem>[];
      final seen = <String>{};

      for (final parsed in parsedList) {
        final item = _toProfileItem(parsed, subscriptionId: subscriptionId);
        if (item == null) continue;
        final key = '${item.server}:${item.port}:${item.password}';
        if (seen.add(key)) {
          results.add(item);
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// 将 FlutterVlessURL 转换为 ProfileItem
  static ProfileItem? _toProfileItem(
    FlutterVlessURL parsed, {
    String? subscriptionId,
  }) {
    String config;
    try {
      config = parsed.getFullConfiguration();
    } catch (_) {
      return null;
    }

    final meta = _extractMeta(config);
    final remark = parsed.remark.trim();

    return ProfileItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
      name: remark.isEmpty ? '${meta.type.label} Node' : remark,
      type: meta.type,
      server: meta.server,
      port: meta.port,
      password: meta.password,
      subscriptionId: subscriptionId,
      rawConfig: config,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 从 Xray config JSON 提取协议/服务器/端口/密码元数据
  static _Meta _extractMeta(String configJson) {
    try {
      final config = jsonDecode(configJson) as Map<String, dynamic>;
      final outbounds = (config['outbounds'] as List?)?.cast<Map<String, dynamic>>();
      if (outbounds == null || outbounds.isEmpty) {
        return _Meta(type: ProfileType.vmess, server: '', port: 0, password: '');
      }

      Map<String, dynamic> first = outbounds.first;
      for (final o in outbounds) {
        final proto = o['protocol'];
        if (proto != null && proto != 'freedom' && proto != 'blackhole') {
          first = o;
          break;
        }
      }

      final protocol = (first['protocol'] as String?) ?? 'vmess';
      final settings = (first['settings'] as Map<String, dynamic>?) ?? {};

      final type = _mapProtocol(protocol);
      String server = '';
      int port = 0;
      String password = '';

      // vless/vmess 使用 vnext
      final vnext = (settings['vnext'] as List?)?.cast<Map<String, dynamic>>();
      if (vnext != null && vnext.isNotEmpty) {
        server = (vnext.first['address'] as String?) ?? '';
        port = (vnext.first['port'] as int?) ?? 0;
        final users = (vnext.first['users'] as List?)?.cast<Map<String, dynamic>>();
        if (users != null && users.isNotEmpty) {
          password = (users.first['id'] as String?) ?? (users.first['password'] as String?) ?? '';
        }
      }

      // trojan/shadowsocks/socks 使用 servers
      final servers = (settings['servers'] as List?)?.cast<Map<String, dynamic>>();
      if (servers != null && servers.isNotEmpty) {
        server = (servers.first['address'] as String?) ?? '';
        port = (servers.first['port'] as int?) ?? 0;
        password = (servers.first['password'] as String?) ?? '';
      }

      return _Meta(type: type, server: server, port: port, password: password);
    } catch (_) {
      return _Meta(type: ProfileType.vmess, server: '', port: 0, password: '');
    }
  }

  static ProfileType _mapProtocol(String protocol) {
    return switch (protocol.toLowerCase()) {
      'vmess' => ProfileType.vmess,
      'vless' => ProfileType.vless,
      'trojan' => ProfileType.trojan,
      'shadowsocks' => ProfileType.shadowsocks,
      'socks' => ProfileType.socks,
      'hysteria2' || 'hy2' => ProfileType.hysteria2,
      _ => ProfileType.vmess,
    };
  }
}

class _Meta {
  final ProfileType type;
  final String server;
  final int port;
  final String password;
  const _Meta({
    required this.type,
    required this.server,
    required this.port,
    required this.password,
  });
}
