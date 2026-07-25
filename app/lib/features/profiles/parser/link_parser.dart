import 'dart:convert';
import '../model/profile_item.dart';

/// 分享链接解析器
/// 支持 vmess:// vless:// trojan:// ss:// socks://
class LinkParser {
  /// 解析单条链接，失败返回 null
  static ProfileItem? parse(String raw) {
    final link = raw.trim();
    if (link.startsWith('vmess://')) return _parseVmess(link);
    if (link.startsWith('vless://')) return _parseVless(link);
    if (link.startsWith('trojan://')) return _parseTrojan(link);
    if (link.startsWith('ss://')) return _parseShadowsocks(link);
    if (link.startsWith('socks://')) return _parseSocks(link);
    return null;
  }

  /// 批量解析 (订阅内容，可能为 base64 或多行)
  static List<ProfileItem> parseBatch(String content) {
    var text = content.trim();

    // 尝试 base64 解码
    if (!text.contains('://')) {
      final decoded = _tryBase64(text);
      if (decoded != null) text = decoded;
    }

    final results = <ProfileItem>[];
    final seen = <String>{};
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final profile = parse(line);
      if (profile != null && seen.add('${profile.server}:${profile.port}:${profile.password}')) {
        results.add(profile);
      }
    }
    return results;
  }

  // ---- vmess:// (base64 JSON) ----
  static ProfileItem? _parseVmess(String link) {
    try {
      final b64 = link.substring('vmess://'.length).trim();
      final json = jsonDecode(_tryBase64(b64) ?? b64) as Map<String, dynamic>;
      return ProfileItem(
        id: _newId(),
        name: (json['ps'] as String?) ?? 'VMess Node',
        type: ProfileType.vmess,
        server: json['add'] as String? ?? '',
        port: int.tryParse('${json['port']}') ?? 0,
        password: json['id'] as String? ?? '',
        network: json['net'] as String?,
        path: json['path'] as String?,
        host: json['host'] as String?,
        sni: json['sni'] as String?,
        allowInsecure: json['tls'] == 'tls' && json['verify_cert'] == false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  // ---- vless://uuid@host:port?query#name ----
  static ProfileItem? _parseVless(String link) {
    try {
      final uri = Uri.parse(link);
      final query = uri.queryParameters;
      return ProfileItem(
        id: _newId(),
        name: _decodeName(uri.fragment) ?? 'VLESS Node',
        type: ProfileType.vless,
        server: uri.host,
        port: uri.port,
        password: uri.userInfo,
        network: query['type'] ?? query['network'] ?? 'tcp',
        path: query['path'],
        host: query['host'],
        sni: query['sni'] ?? query['peer'],
        alpn: query['alpn'],
        allowInsecure: _isTrue(query['allowInsecure'] ?? query['insecure']),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  // ---- trojan://password@host:port?query#name ----
  static ProfileItem? _parseTrojan(String link) {
    try {
      final uri = Uri.parse(link);
      final query = uri.queryParameters;
      return ProfileItem(
        id: _newId(),
        name: _decodeName(uri.fragment) ?? 'Trojan Node',
        type: ProfileType.trojan,
        server: uri.host,
        port: uri.port,
        password: Uri.decodeComponent(uri.userInfo),
        network: query['type'] ?? query['network'] ?? 'tcp',
        path: query['path'],
        host: query['host'],
        sni: query['sni'] ?? query['peer'],
        alpn: query['alpn'],
        allowInsecure: _isTrue(
            query['allowInsecure'] ?? query['insecure'] ?? query['skip-cert-verify']),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  // ---- ss:// (SIP002: base64(method:password)@host:port#name) ----
  static ProfileItem? _parseShadowsocks(String link) {
    try {
      final body = link.substring('ss://'.length);
      final hashIdx = body.indexOf('#');
      final main = hashIdx >= 0 ? body.substring(0, hashIdx) : body;
      final name = hashIdx >= 0 ? _decodeName(body.substring(hashIdx + 1)) : null;

      String userInfo;
      String hostPort;
      final atIdx = main.lastIndexOf('@');
      if (atIdx >= 0) {
        userInfo = _tryBase64(main.substring(0, atIdx)) ?? main.substring(0, atIdx);
        hostPort = main.substring(atIdx + 1);
      } else {
        // 旧格式: base64(method:password@host:port)
        final decoded = _tryBase64(main) ?? main;
        final innerAt = decoded.lastIndexOf('@');
        userInfo = decoded.substring(0, innerAt);
        hostPort = decoded.substring(innerAt + 1);
      }

      final colonIdx = userInfo.indexOf(':');
      final method = userInfo.substring(0, colonIdx);
      final password = userInfo.substring(colonIdx + 1);

      final hp = hostPort.split(':');
      return ProfileItem(
        id: _newId(),
        name: name ?? 'SS Node',
        type: ProfileType.shadowsocks,
        server: hp[0],
        port: int.tryParse(hp.length > 1 ? hp[1] : '') ?? 0,
        password: password,
        method: method,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  // ---- socks://user:pass@host:port#name ----
  static ProfileItem? _parseSocks(String link) {
    try {
      final uri = Uri.parse(link);
      return ProfileItem(
        id: _newId(),
        name: _decodeName(uri.fragment) ?? 'SOCKS Node',
        type: ProfileType.socks,
        server: uri.host,
        port: uri.port,
        password: uri.userInfo.contains(':')
            ? uri.userInfo.split(':').last
            : uri.userInfo,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  // ---- helpers ----
  static String? _tryBase64(String input) {
    try {
      var compact = input.replaceAll(RegExp(r'\s'), '');
      compact = compact.replaceAll('-', '+').replaceAll('_', '/');
      final pad = (4 - compact.length % 4) % 4;
      if (pad > 0) compact += '=' * pad;
      return utf8.decode(base64Decode(compact));
    } catch (_) {
      return null;
    }
  }

  static String? _decodeName(String? fragment) {
    if (fragment == null || fragment.isEmpty) return null;
    try {
      return Uri.decodeComponent(fragment.replaceAll('+', ' '));
    } catch (_) {
      return fragment;
    }
  }

  static bool _isTrue(String? value) {
    if (value == null) return false;
    return ['1', 'true', 'yes', 'y'].contains(value.toLowerCase());
  }

  static int _idCounter = 0;
  static String _newId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
}
