import 'dart:convert';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import '../../../core/service/log_service.dart';
import '../model/profile_item.dart';
import 'clash_yaml_parser.dart';

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
      // wireguard:// 链接或 .conf 格式
      if (trimmed.startsWith('wireguard://') || trimmed.startsWith('wg://')) {
        return _parseWireguardUrl(trimmed);
      }
      if (_isWireguardConf(trimmed)) {
        return _parseWireguardConf(trimmed);
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
  /// 支持：base64 编码的链接列表、纯文本链接列表、单条 JSON、Clash YAML
  static List<ProfileItem> parseBatch(String content, {String? subscriptionId}) {
    final trimmed = content.trim();
    final results = <ProfileItem>[];
    final seen = <String>{};

    // Clash YAML 格式检测（优先级最高）
    if (ClashYamlParser.isClashYaml(trimmed)) {
      return ClashYamlParser.parse(trimmed, subscriptionId: subscriptionId);
    }

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

  // ─── WireGuard ──────────────────────────────────────────────────────────

  /// 判断是否为 WireGuard .conf 格式
  static bool _isWireguardConf(String s) {
    return s.contains('[Interface]') && s.contains('[Peer]');
  }

  /// 解析 wireguard:// 或 wg:// URL
  /// 格式: wireguard://base64(conf)#remark 或 wireguard://privateKey@server:port?params#remark
  static ProfileItem? _parseWireguardUrl(String raw) {
    try {
      final uri = Uri.parse(raw);
      final remark = uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : 'WireGuard Node';

      // 尝试 base64 编码的 conf 格式: wireguard://base64conf#remark
      if (uri.host.isEmpty || uri.host.contains('=')) {
        final b64 = raw.replaceFirst(RegExp(r'^wireguard://|^wg://'), '');
        final hashIdx = b64.indexOf('#');
        final encoded = hashIdx >= 0 ? b64.substring(0, hashIdx) : b64;
        try {
          final conf = utf8.decode(base64Decode(encoded));
          if (_isWireguardConf(conf)) {
            final item = _parseWireguardConf(conf);
            if (item != null && remark != 'WireGuard Node') {
              return ProfileItem(
                id: item.id,
                name: remark,
                type: item.type,
                server: item.server,
                port: item.port,
                password: item.password,
                rawConfig: item.rawConfig,
                createdAt: item.createdAt,
              );
            }
            return item;
          }
        } catch (_) {}
      }

      // URL 参数格式: wireguard://privateKey@server:port?params#remark
      final privateKey = uri.userInfo;
      final server = uri.host;
      final port = uri.port;
      if (server.isEmpty || port == 0 || privateKey.isEmpty) return null;

      final publicKey = uri.queryParameters['publickey'] ?? uri.queryParameters['publicKey'] ?? '';
      final presharedKey = uri.queryParameters['presharedkey'] ?? uri.queryParameters['presharedKey'] ?? '';
      final allowedIps = uri.queryParameters['allowedips'] ?? uri.queryParameters['allowedIps'] ?? '0.0.0.0/0';
      final address = uri.queryParameters['address'] ?? '';
      final mtu = uri.queryParameters['mtu'] ?? '1420';

      final config = _buildWireguardXrayConfig(
        privateKey: privateKey,
        address: address,
        peerPublicKey: publicKey,
        presharedKey: presharedKey,
        server: server,
        port: port,
        allowedIps: allowedIps.split(',').map((s) => s.trim()).toList(),
        mtu: int.tryParse(mtu) ?? 1420,
      );

      return ProfileItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
        name: remark,
        type: ProfileType.wireguard,
        server: server,
        port: port,
        password: privateKey,
        rawConfig: config,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  /// 解析 WireGuard .conf 文件格式
  static ProfileItem? _parseWireguardConf(String conf) {
    try {
      final lines = conf.split(RegExp(r'[\r\n]+'));
      String privateKey = '';
      String address = '';
      String peerPublicKey = '';
      String presharedKey = '';
      String endpoint = '';
      List<String> allowedIps = ['0.0.0.0/0'];
      int mtu = 1420;
      String section = '';

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('#') || trimmed.isEmpty) continue;
        if (trimmed == '[Interface]') { section = 'interface'; continue; }
        if (trimmed == '[Peer]') { section = 'peer'; continue; }

        final eqIdx = trimmed.indexOf('=');
        if (eqIdx < 0) continue;
        final key = trimmed.substring(0, eqIdx).trim().toLowerCase();
        final value = trimmed.substring(eqIdx + 1).trim();

        if (section == 'interface') {
          switch (key) {
            case 'privatekey': privateKey = value;
            case 'address': address = value.split(',').first.trim();
            case 'mtu': mtu = int.tryParse(value) ?? 1420;
          }
        } else if (section == 'peer') {
          switch (key) {
            case 'publickey': peerPublicKey = value;
            case 'presharedkey': presharedKey = value;
            case 'endpoint': endpoint = value;
            case 'allowedips': allowedIps = value.split(',').map((s) => s.trim()).toList();
          }
        }
      }

      if (privateKey.isEmpty || endpoint.isEmpty) return null;

      // 解析 endpoint (host:port)
      final lastColon = endpoint.lastIndexOf(':');
      if (lastColon < 0) return null;
      String server;
      int port;
      if (endpoint.startsWith('[')) {
        // IPv6: [::1]:51820
        final bracket = endpoint.indexOf(']');
        server = endpoint.substring(1, bracket);
        port = int.tryParse(endpoint.substring(bracket + 2)) ?? 0;
      } else {
        server = endpoint.substring(0, lastColon);
        port = int.tryParse(endpoint.substring(lastColon + 1)) ?? 0;
      }
      if (port == 0) return null;

      final config = _buildWireguardXrayConfig(
        privateKey: privateKey,
        address: address,
        peerPublicKey: peerPublicKey,
        presharedKey: presharedKey,
        server: server,
        port: port,
        allowedIps: allowedIps,
        mtu: mtu,
      );

      return ProfileItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
        name: 'WireGuard $server',
        type: ProfileType.wireguard,
        server: server,
        port: port,
        password: privateKey,
        rawConfig: config,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  /// 构建 Xray wireguard outbound JSON config
  static String _buildWireguardXrayConfig({
    required String privateKey,
    required String address,
    required String peerPublicKey,
    required String presharedKey,
    required String server,
    required int port,
    required List<String> allowedIps,
    required int mtu,
  }) {
    final peer = <String, dynamic>{
      'publicKey': peerPublicKey,
      if (presharedKey.isNotEmpty) 'preSharedKey': presharedKey,
      'endpoint': '$server:$port',
      'allowedIPs': allowedIps,
    };

    final outbound = <String, dynamic>{
      'protocol': 'wireguard',
      'settings': {
        'secretKey': privateKey,
        if (address.isNotEmpty) 'address': address.split(',').map((s) => s.trim()).toList(),
        'peers': [peer],
        'mtu': mtu,
      },
    };

    return jsonEncode({'outbounds': [outbound]});
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
      'wireguard' => ProfileType.wireguard,
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
