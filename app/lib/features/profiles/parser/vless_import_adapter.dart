import 'dart:convert';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import '../../../core/service/log_service.dart';
import '../model/profile_item.dart';

/// 基于 flutter_v2ray 的导入适配器
/// 支持 vmess/vless/trojan/ss/socks 单链接 + base64 订阅批量解码
class VlessImportAdapter {
  static int _counter = 0;

  /// 解析单条链接/配置，失败返回 null
  static ProfileItem? parseSingle(String raw) {
    try {
      final trimmed = raw.trim();
      // hysteria2/hy2 链接需自行解析（flutter_v2ray 不支持）
      if (trimmed.startsWith('hysteria2://') || trimmed.startsWith('hy2://')) {
        return _parseHysteria2(trimmed);
      }
      // 尝试作为分享链接解析
      final parsed = FlutterV2ray.parseFromURL(trimmed);
      return _toProfileItem(parsed);
    } catch (_) {
      // 尝试作为原始 Xray JSON 解析
      return _parseRawJson(raw.trim());
    }
  }

  /// 批量解析订阅内容，自动去重
  /// 支持：base64 编码的链接列表、纯文本链接列表、单条 JSON
  static List<ProfileItem> parseBatch(String content, {String? subscriptionId}) {
    final trimmed = content.trim();
    final results = <ProfileItem>[];
    final seen = <String>{};

    // 尝试 base64 解码（订阅链接通常返回 base64）
    String decoded = trimmed;
    try {
      if (_isBase64(trimmed)) {
        // 支持标准 base64 和 URL-safe base64（- 替代 +，_ 替代 /）
        var normalized = trimmed.replaceAll('-', '+').replaceAll('_', '/');
        // 补齐 padding（部分订阅服务商省略尾部 =）
        final remainder = normalized.length % 4;
        if (remainder > 0) {
          normalized += '=' * (4 - remainder);
        }
        decoded = utf8.decode(base64Decode(normalized));
      }
    } catch (_) {
      decoded = trimmed;
    }

    // 按行分割，每行尝试解析为分享链接
    final lines = decoded.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final item = parseSingle(l);
      if (item == null) continue;
      if (subscriptionId != null) {
        // 重建带 subscriptionId 的 item
        final withSub = ProfileItem(
          id: item.id,
          name: item.name,
          type: item.type,
          server: item.server,
          port: item.port,
          password: item.password,
          subscriptionId: subscriptionId,
          rawConfig: item.rawConfig,
          createdAt: item.createdAt,
        );
        final key = '${withSub.server}:${withSub.port}:${withSub.password}';
        if (seen.add(key)) results.add(withSub);
      } else {
        final key = '${item.server}:${item.port}:${item.password}';
        if (seen.add(key)) results.add(item);
      }
    }

    // 如果按行解析无结果，尝试作为单条 JSON 解析
    if (results.isEmpty) {
      final single = _parseRawJson(trimmed, subscriptionId: subscriptionId);
      if (single != null) results.add(single);
    }

    LogService.instance.info('ImportAdapter',
        'parseBatch: input=${trimmed.length}chars decoded=${decoded.length}chars lines=${decoded.split(RegExp(r'[\r\n]+')).length} results=${results.length}');

    return results;
  }

  /// 判断字符串是否为 base64 编码（含 URL-safe 变体）
  static bool _isBase64(String s) {
    if (s.isEmpty || s.length < 16) return false;
    // 包含:// 明显是明文链接
    if (s.contains('://')) return false;
    // 包含 { 或 [ 可能是 JSON
    if (s.startsWith('{') || s.startsWith('[')) return false;
    // 标准 base64: [A-Za-z0-9+/=]  URL-safe: [A-Za-z0-9_-=]
    return RegExp(r'^[A-Za-z0-9+/=_\-\s]+$').hasMatch(s);
  }

  /// 解析 hysteria2:// 或 hy2:// 链接
  /// 格式: hysteria2://password@server:port?params#remark
  static ProfileItem? _parseHysteria2(String raw) {
    try {
      final uri = Uri.parse(raw);
      final password = uri.userInfo;
      final server = uri.host;
      final port = uri.port;
      if (server.isEmpty || port == 0) return null;

      final remark = uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : 'Hysteria2 Node';

      // 提取 TLS/传输参数
      final sni = uri.queryParameters['sni'] ?? '';
      final alpn = uri.queryParameters['alpn'] ?? '';
      final insecure = uri.queryParameters['insecure'] == '1' ||
          uri.queryParameters['allowInsecure'] == '1';
      final obfs = uri.queryParameters['obfs'] ?? '';
      final obfsPassword = uri.queryParameters['obfs-password'] ?? '';

      // 构建 Xray hysteria2 outbound config
      final tlsSettings = <String, dynamic>{
        if (sni.isNotEmpty) 'serverName': sni,
        'allowInsecure': insecure,
        if (alpn.isNotEmpty) 'alpn': alpn.split(',').where((a) => a.isNotEmpty).toList(),
      };

      final outbound = <String, dynamic>{
        'protocol': 'hysteria2',
        'settings': {
          'servers': [
            {
              'address': server,
              'port': port,
              'password': password,
            }
          ],
        },
        'streamSettings': {
          'network': 'udp',
          'security': 'tls',
          'tlsSettings': tlsSettings,
          if (obfs.isNotEmpty) 'obfsSettings': {
            'type': obfs,
            if (obfsPassword.isNotEmpty) 'password': obfsPassword,
          },
        },
      };

      final config = jsonEncode({
        'outbounds': [outbound],
      });

      return ProfileItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
        name: remark,
        type: ProfileType.hysteria2,
        server: server,
        port: port,
        password: password,
        rawConfig: config,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  /// 解析原始 Xray JSON 配置
  static ProfileItem? _parseRawJson(String raw, {String? subscriptionId}) {
    try {
      final config = jsonDecode(raw) as Map<String, dynamic>;
      // 必须含 outbounds 才是有效的 Xray config
      if (!config.containsKey('outbounds')) return null;
      final meta = _extractMeta(raw);
      return ProfileItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
        name: '${meta.type.label} Node',
        type: meta.type,
        server: meta.server,
        port: meta.port,
        password: meta.password,
        subscriptionId: subscriptionId,
        rawConfig: raw,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  /// 将 V2RayURL 转换为 ProfileItem
  static ProfileItem? _toProfileItem(
    V2RayURL parsed, {
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
