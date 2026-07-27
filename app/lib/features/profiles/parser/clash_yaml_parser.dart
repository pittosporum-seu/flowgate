import 'dart:convert';
import 'package:yaml/yaml.dart';
import '../../../core/service/log_service.dart';
import '../model/profile_item.dart';

/// Clash YAML 订阅/配置文件解析器
/// 支持 Clash Meta (mihomo) 格式的 proxies 列表
class ClashYamlParser {
  static int _counter = 0;

  /// 判断内容是否为 Clash YAML 格式
  static bool isClashYaml(String content) {
    final trimmed = content.trim();
    // 必须包含 proxies: 关键字，且不是 JSON
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) return false;
    return trimmed.contains('proxies:') ||
        trimmed.contains('proxies :');
  }

  /// 解析 Clash YAML 内容，返回节点列表
  static List<ProfileItem> parse(String content, {String? subscriptionId}) {
    try {
      final doc = loadYaml(content);
      if (doc is! YamlMap) return [];

      final proxies = doc['proxies'];
      if (proxies is! YamlList) return [];

      final results = <ProfileItem>[];
      for (final proxy in proxies) {
        if (proxy is! YamlMap) continue;
        final item = _parseProxy(proxy, subscriptionId: subscriptionId);
        if (item != null) results.add(item);
      }

      LogService.instance.info('ClashYaml',
          'parse: proxies=${proxies.length} parsed=${results.length}');
      return results;
    } catch (e) {
      LogService.instance.warn('ClashYaml', 'parse failed: $e');
      return [];
    }
  }

  /// 解析单个 Clash proxy 条目
  static ProfileItem? _parseProxy(YamlMap proxy, {String? subscriptionId}) {
    final type = (proxy['type'] as String?)?.toLowerCase() ?? '';
    final name = (proxy['name'] as String?) ?? 'Clash Node';
    final server = (proxy['server'] as String?) ?? '';
    final port = proxy['port'] as int? ?? 0;

    if (server.isEmpty || port == 0) return null;

    final String rawConfig;
    final ProfileType profileType;

    switch (type) {
      case 'trojan':
        profileType = ProfileType.trojan;
        rawConfig = _buildTrojanConfig(proxy, server, port);
      case 'vmess':
        profileType = ProfileType.vmess;
        rawConfig = _buildVmessConfig(proxy, server, port);
      case 'vless':
        profileType = ProfileType.vless;
        rawConfig = _buildVlessConfig(proxy, server, port);
      case 'ss':
      case 'shadowsocks':
        profileType = ProfileType.shadowsocks;
        rawConfig = _buildShadowsocksConfig(proxy, server, port);
      case 'socks5':
      case 'socks':
        profileType = ProfileType.socks;
        rawConfig = _buildSocksConfig(proxy, server, port);
      case 'hysteria2':
      case 'hy2':
        profileType = ProfileType.hysteria2;
        rawConfig = _buildHysteria2Config(proxy, server, port);
      case 'wireguard':
        profileType = ProfileType.wireguard;
        rawConfig = _buildWireguardConfig(proxy, server, port);
      default:
        // 不支持的类型跳过
        return null;
    }

    final password = (proxy['password'] as String?) ??
        (proxy['uuid'] as String?) ??
        '';

    return ProfileItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
      name: name,
      type: profileType,
      server: server,
      port: port,
      password: password,
      subscriptionId: subscriptionId,
      rawConfig: rawConfig,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ─── Config Builders ──────────────────────────────────────────────────────

  static String _buildTrojanConfig(YamlMap proxy, String server, int port) {
    final password = proxy['password'] as String? ?? '';
    final sni = proxy['sni'] as String? ?? '';
    final udp = proxy['udp'] as bool? ?? true;
    final skipCertVerify = proxy['skip-cert-verify'] as bool? ?? false;
    final network = proxy['network'] as String? ?? 'tcp';
    final wsPath = _nestedStr(proxy, 'ws-opts', 'path') ?? '';
    final wsHeaders = _nestedMap(proxy, 'ws-opts', 'headers');
    final grpcService = _nestedStr(proxy, 'grpc-opts', 'grpc-service-name') ?? '';

    final streamSettings = <String, dynamic>{
      'network': network,
      'security': 'tls',
      'tlsSettings': {
        if (sni.isNotEmpty) 'serverName': sni,
        'allowInsecure': skipCertVerify,
      },
      if (network == 'ws') 'wsSettings': {
        if (wsPath.isNotEmpty) 'path': wsPath,
        if (wsHeaders != null) 'headers': _yamlMapToJson(wsHeaders),
      },
      if (network == 'grpc') 'grpcSettings': {
        if (grpcService.isNotEmpty) 'serviceName': grpcService,
      },
    };

    return jsonEncode({
      'outbounds': [{
        'protocol': 'trojan',
        'settings': {
          'servers': [{
            'address': server,
            'port': port,
            'password': password,
          }],
        },
        'streamSettings': streamSettings,
      }],
    });
  }

  static String _buildVmessConfig(YamlMap proxy, String server, int port) {
    final uuid = proxy['uuid'] as String? ?? '';
    final alterId = proxy['alterId'] as int? ?? 0;
    final cipher = proxy['cipher'] as String? ?? 'auto';
    final network = proxy['network'] as String? ?? 'tcp';
    final tls = proxy['tls'] as bool? ?? false;
    final sni = proxy['servername'] as String? ?? proxy['sni'] as String? ?? '';
    final skipCertVerify = proxy['skip-cert-verify'] as bool? ?? false;
    final wsPath = _nestedStr(proxy, 'ws-opts', 'path') ?? '';
    final wsHeaders = _nestedMap(proxy, 'ws-opts', 'headers');

    final streamSettings = <String, dynamic>{
      'network': network,
      if (tls) 'security': 'tls',
      if (tls) 'tlsSettings': {
        if (sni.isNotEmpty) 'serverName': sni,
        'allowInsecure': skipCertVerify,
      },
      if (network == 'ws') 'wsSettings': {
        if (wsPath.isNotEmpty) 'path': wsPath,
        if (wsHeaders != null) 'headers': _yamlMapToJson(wsHeaders),
      },
    };

    return jsonEncode({
      'outbounds': [{
        'protocol': 'vmess',
        'settings': {
          'vnext': [{
            'address': server,
            'port': port,
            'users': [{
              'id': uuid,
              'alterId': alterId,
              'security': cipher,
            }],
          }],
        },
        'streamSettings': streamSettings,
      }],
    });
  }

  static String _buildVlessConfig(YamlMap proxy, String server, int port) {
    final uuid = proxy['uuid'] as String? ?? '';
    final network = proxy['network'] as String? ?? 'tcp';
    final tls = proxy['tls'] as bool? ?? true;
    final sni = proxy['servername'] as String? ?? proxy['sni'] as String? ?? '';
    final flow = proxy['flow'] as String? ?? '';
    final skipCertVerify = proxy['skip-cert-verify'] as bool? ?? false;
    final wsPath = _nestedStr(proxy, 'ws-opts', 'path') ?? '';
    final wsHeaders = _nestedMap(proxy, 'ws-opts', 'headers');
    final grpcService = _nestedStr(proxy, 'grpc-opts', 'grpc-service-name') ?? '';
    final realityPublicKey = _nestedStr(proxy, 'reality-opts', 'public-key') ?? '';
    final realityShortId = _nestedStr(proxy, 'reality-opts', 'short-id') ?? '';

    final isReality = realityPublicKey.isNotEmpty;
    final streamSettings = <String, dynamic>{
      'network': network,
      if (tls) 'security': isReality ? 'reality' : 'tls',
      if (tls && !isReality) 'tlsSettings': {
        if (sni.isNotEmpty) 'serverName': sni,
        'allowInsecure': skipCertVerify,
      },
      if (isReality) 'realitySettings': {
        'publicKey': realityPublicKey,
        if (realityShortId.isNotEmpty) 'shortId': realityShortId,
        if (sni.isNotEmpty) 'serverName': sni,
      },
      if (network == 'ws') 'wsSettings': {
        if (wsPath.isNotEmpty) 'path': wsPath,
        if (wsHeaders != null) 'headers': _yamlMapToJson(wsHeaders),
      },
      if (network == 'grpc') 'grpcSettings': {
        if (grpcService.isNotEmpty) 'serviceName': grpcService,
      },
    };

    return jsonEncode({
      'outbounds': [{
        'protocol': 'vless',
        'settings': {
          'vnext': [{
            'address': server,
            'port': port,
            'users': [{
              'id': uuid,
              if (flow.isNotEmpty) 'flow': flow,
            }],
          }],
        },
        'streamSettings': streamSettings,
      }],
    });
  }

  static String _buildShadowsocksConfig(YamlMap proxy, String server, int port) {
    final password = proxy['password'] as String? ?? '';
    final cipher = proxy['cipher'] as String? ?? 'aes-256-gcm';

    return jsonEncode({
      'outbounds': [{
        'protocol': 'shadowsocks',
        'settings': {
          'servers': [{
            'address': server,
            'port': port,
            'password': password,
            'method': cipher,
          }],
        },
      }],
    });
  }

  static String _buildSocksConfig(YamlMap proxy, String server, int port) {
    final username = proxy['username'] as String? ?? '';
    final password = proxy['password'] as String? ?? '';

    return jsonEncode({
      'outbounds': [{
        'protocol': 'socks',
        'settings': {
          'servers': [{
            'address': server,
            'port': port,
            if (username.isNotEmpty || password.isNotEmpty)
              'users': [{'user': username, 'pass': password}],
          }],
        },
      }],
    });
  }

  static String _buildHysteria2Config(YamlMap proxy, String server, int port) {
    final password = proxy['password'] as String? ?? '';
    final sni = proxy['sni'] as String? ?? '';
    final skipCertVerify = proxy['skip-cert-verify'] as bool? ?? false;
    final obfs = proxy['obfs'] as String? ?? '';
    final obfsPassword = proxy['obfs-password'] as String? ?? '';

    return jsonEncode({
      'outbounds': [{
        'protocol': 'hysteria2',
        'settings': {
          'servers': [{
            'address': server,
            'port': port,
            'password': password,
          }],
        },
        'streamSettings': {
          'network': 'udp',
          'security': 'tls',
          'tlsSettings': {
            if (sni.isNotEmpty) 'serverName': sni,
            'allowInsecure': skipCertVerify,
          },
          if (obfs.isNotEmpty) 'obfsSettings': {
            'type': obfs,
            if (obfsPassword.isNotEmpty) 'password': obfsPassword,
          },
        },
      }],
    });
  }

  static String _buildWireguardConfig(YamlMap proxy, String server, int port) {
    final privateKey = proxy['private-key'] as String? ?? '';
    final publicKey = proxy['public-key'] as String? ?? '';
    final presharedKey = proxy['preshared-key'] as String? ?? '';
    final ip = proxy['ip'] as String? ?? '';
    final ipv6 = proxy['ipv6'] as String? ?? '';
    final mtu = proxy['mtu'] as int? ?? 1420;

    final addresses = <String>[
      if (ip != null && ip.isNotEmpty) ip,
      if (ipv6 != null && ipv6.isNotEmpty) ipv6,
    ];

    return jsonEncode({
      'outbounds': [{
        'protocol': 'wireguard',
        'settings': {
          'secretKey': privateKey,
          if (addresses.isNotEmpty) 'address': addresses,
          'peers': [{
            'publicKey': publicKey,
            if (presharedKey.isNotEmpty) 'preSharedKey': presharedKey,
            'endpoint': '$server:$port',
            'allowedIPs': ['0.0.0.0/0', '::/0'],
          }],
          'mtu': mtu,
        },
      }],
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String? _nestedStr(YamlMap map, String key, String subKey) {
    final nested = map[key];
    if (nested is YamlMap) return nested[subKey] as String?;
    return null;
  }

  static YamlMap? _nestedMap(YamlMap map, String key, String subKey) {
    final nested = map[key];
    if (nested is YamlMap) {
      final sub = nested[subKey];
      if (sub is YamlMap) return sub;
    }
    return null;
  }

  static Map<String, dynamic> _yamlMapToJson(YamlMap yamlMap) {
    final result = <String, dynamic>{};
    for (final entry in yamlMap.entries) {
      result[entry.key.toString()] = entry.value;
    }
    return result;
  }
}
