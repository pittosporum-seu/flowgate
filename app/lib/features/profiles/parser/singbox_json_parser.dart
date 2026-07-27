import 'dart:convert';
import '../../../core/service/log_service.dart';
import '../model/profile_item.dart';

/// sing-box JSON 配置解析器
/// 支持 sing-box 格式的 outbounds 列表
class SingboxJsonParser {
  static int _counter = 0;

  /// 判断内容是否为 sing-box JSON 格式
  static bool isSingboxJson(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith('{')) return false;
    try {
      final json = jsonDecode(trimmed);
      if (json is! Map<String, dynamic>) return false;
      // sing-box 特征：有 outbounds 数组且包含 type 字段
      final outbounds = json['outbounds'];
      if (outbounds is! List || outbounds.isEmpty) return false;
      final first = outbounds.first;
      return first is Map<String, dynamic> && first.containsKey('type');
    } catch (_) {
      return false;
    }
  }

  /// 解析 sing-box JSON 内容，返回节点列表
  static List<ProfileItem> parse(String content, {String? subscriptionId}) {
    try {
      final json = jsonDecode(content.trim());
      if (json is! Map<String, dynamic>) return [];

      final outbounds = json['outbounds'];
      if (outbounds is! List) return [];

      final results = <ProfileItem>[];
      for (final outbound in outbounds) {
        if (outbound is! Map<String, dynamic>) continue;
        final item = _parseOutbound(outbound, subscriptionId: subscriptionId);
        if (item != null) results.add(item);
      }

      LogService.instance.info('SingboxJson',
          'parse: outbounds=${outbounds.length} parsed=${results.length}');
      return results;
    } catch (e) {
      LogService.instance.warn('SingboxJson', 'parse failed: $e');
      return [];
    }
  }

  /// 解析单个 sing-box outbound 条目
  static ProfileItem? _parseOutbound(Map<String, dynamic> outbound,
      {String? subscriptionId}) {
    final type = (outbound['type'] as String?)?.toLowerCase() ?? '';
    final tag = (outbound['tag'] as String?) ?? 'Sing-box Node';
    final server = outbound['server'] as String? ?? '';
    final serverPort = outbound['server_port'] as int? ?? 0;

    // 跳过 direct/block/dns 等内置 outbound
    if (type == 'direct' || type == 'block' || type == 'dns') return null;
    if (server.isEmpty || serverPort == 0) return null;

    final String rawConfig;
    final ProfileType profileType;

    switch (type) {
      case 'trojan':
        profileType = ProfileType.trojan;
        rawConfig = _buildTrojanConfig(outbound, server, serverPort);
      case 'vmess':
        profileType = ProfileType.vmess;
        rawConfig = _buildVmessConfig(outbound, server, serverPort);
      case 'vless':
        profileType = ProfileType.vless;
        rawConfig = _buildVlessConfig(outbound, server, serverPort);
      case 'shadowsocks':
        profileType = ProfileType.shadowsocks;
        rawConfig = _buildShadowsocksConfig(outbound, server, serverPort);
      case 'socks':
        profileType = ProfileType.socks;
        rawConfig = _buildSocksConfig(outbound, server, serverPort);
      case 'hysteria2':
        profileType = ProfileType.hysteria2;
        rawConfig = _buildHysteria2Config(outbound, server, serverPort);
      case 'wireguard':
        profileType = ProfileType.wireguard;
        rawConfig = _buildWireguardConfig(outbound, server, serverPort);
      default:
        return null;
    }

    final password = outbound['password'] as String? ??
        outbound['uuid'] as String? ??
        '';

    return ProfileItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
      name: tag,
      type: profileType,
      server: server,
      port: serverPort,
      password: password,
      subscriptionId: subscriptionId,
      rawConfig: rawConfig,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ─── Config Builders (转换为 Xray 格式) ─────────────────────────────────────

  static String _buildTrojanConfig(
      Map<String, dynamic> ob, String server, int port) {
    final password = ob['password'] as String? ?? '';
    final tls = ob['tls'] as Map<String, dynamic>?;
    final sni = tls?['server_name'] as String? ?? '';
    final insecure = tls?['insecure'] as bool? ?? false;
    final transport = ob['transport'] as Map<String, dynamic>?;
    final network = transport?['type'] as String? ?? 'tcp';

    final streamSettings = <String, dynamic>{
      'network': network,
      'security': 'tls',
      'tlsSettings': {
        if (sni.isNotEmpty) 'serverName': sni,
        'allowInsecure': insecure,
      },
      if (network == 'ws')
        'wsSettings': {
          if (transport?['path'] != null) 'path': transport!['path'],
          if (transport?['headers'] != null) 'headers': transport!['headers'],
        },
      if (network == 'grpc')
        'grpcSettings': {
          if (transport?['service_name'] != null)
            'serviceName': transport!['service_name'],
        },
    };

    return jsonEncode({
      'outbounds': [
        {
          'protocol': 'trojan',
          'settings': {
            'servers': [
              {'address': server, 'port': port, 'password': password}
            ],
          },
          'streamSettings': streamSettings,
        }
      ],
    });
  }

  static String _buildVmessConfig(
      Map<String, dynamic> ob, String server, int port) {
    final uuid = ob['uuid'] as String? ?? '';
    final alterId = ob['alter_id'] as int? ?? 0;
    final security = ob['security'] as String? ?? 'auto';
    final tls = ob['tls'] as Map<String, dynamic>?;
    final sni = tls?['server_name'] as String? ?? '';
    final transport = ob['transport'] as Map<String, dynamic>?;
    final network = transport?['type'] as String? ?? 'tcp';

    final streamSettings = <String, dynamic>{
      'network': network,
      if (tls != null) 'security': 'tls',
      if (tls != null)
        'tlsSettings': {
          if (sni.isNotEmpty) 'serverName': sni,
          'allowInsecure': tls['insecure'] as bool? ?? false,
        },
      if (network == 'ws')
        'wsSettings': {
          if (transport?['path'] != null) 'path': transport!['path'],
          if (transport?['headers'] != null) 'headers': transport!['headers'],
        },
    };

    return jsonEncode({
      'outbounds': [
        {
          'protocol': 'vmess',
          'settings': {
            'vnext': [
              {
                'address': server,
                'port': port,
                'users': [
                  {'id': uuid, 'alterId': alterId, 'security': security}
                ],
              }
            ],
          },
          'streamSettings': streamSettings,
        }
      ],
    });
  }

  static String _buildVlessConfig(
      Map<String, dynamic> ob, String server, int port) {
    final uuid = ob['uuid'] as String? ?? '';
    final flow = ob['flow'] as String? ?? '';
    final tls = ob['tls'] as Map<String, dynamic>?;
    final sni = tls?['server_name'] as String? ?? '';
    final transport = ob['transport'] as Map<String, dynamic>?;
    final network = transport?['type'] as String? ?? 'tcp';

    // reality 检测
    final realityEnabled = tls?['reality'] as Map<String, dynamic>?;
    final isReality = realityEnabled != null &&
        (realityEnabled['enabled'] as bool? ?? false);

    final streamSettings = <String, dynamic>{
      'network': network,
      if (tls != null) 'security': isReality ? 'reality' : 'tls',
      if (tls != null && !isReality)
        'tlsSettings': {
          if (sni.isNotEmpty) 'serverName': sni,
          'allowInsecure': tls['insecure'] as bool? ?? false,
        },
      if (isReality)
        'realitySettings': {
          'publicKey': realityEnabled['public_key'] as String? ?? '',
          if ((realityEnabled['short_id'] as String? ?? '').isNotEmpty)
            'shortId': realityEnabled['short_id'],
          if (sni.isNotEmpty) 'serverName': sni,
        },
      if (network == 'ws')
        'wsSettings': {
          if (transport?['path'] != null) 'path': transport!['path'],
          if (transport?['headers'] != null) 'headers': transport!['headers'],
        },
      if (network == 'grpc')
        'grpcSettings': {
          if (transport?['service_name'] != null)
            'serviceName': transport!['service_name'],
        },
    };

    return jsonEncode({
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {
                'address': server,
                'port': port,
                'users': [
                  {'id': uuid, if (flow.isNotEmpty) 'flow': flow}
                ],
              }
            ],
          },
          'streamSettings': streamSettings,
        }
      ],
    });
  }

  static String _buildShadowsocksConfig(
      Map<String, dynamic> ob, String server, int port) {
    final password = ob['password'] as String? ?? '';
    final method = ob['method'] as String? ?? 'aes-256-gcm';

    return jsonEncode({
      'outbounds': [
        {
          'protocol': 'shadowsocks',
          'settings': {
            'servers': [
              {
                'address': server,
                'port': port,
                'password': password,
                'method': method,
              }
            ],
          },
        }
      ],
    });
  }

  static String _buildSocksConfig(
      Map<String, dynamic> ob, String server, int port) {
    final username = ob['username'] as String? ?? '';
    final password = ob['password'] as String? ?? '';

    return jsonEncode({
      'outbounds': [
        {
          'protocol': 'socks',
          'settings': {
            'servers': [
              {
                'address': server,
                'port': port,
                if (username.isNotEmpty || password.isNotEmpty)
                  'users': [
                    {'user': username, 'pass': password}
                  ],
              }
            ],
          },
        }
      ],
    });
  }

  static String _buildHysteria2Config(
      Map<String, dynamic> ob, String server, int port) {
    final password = ob['password'] as String? ?? '';
    final tls = ob['tls'] as Map<String, dynamic>?;
    final sni = tls?['server_name'] as String? ?? '';
    final insecure = tls?['insecure'] as bool? ?? false;
    final obfs = ob['obfs'] as Map<String, dynamic>?;
    final obfsType = obfs?['type'] as String? ?? '';
    final obfsPassword = obfs?['password'] as String? ?? '';

    return jsonEncode({
      'outbounds': [
        {
          'protocol': 'hysteria2',
          'settings': {
            'servers': [
              {'address': server, 'port': port, 'password': password}
            ],
          },
          'streamSettings': {
            'network': 'udp',
            'security': 'tls',
            'tlsSettings': {
              if (sni.isNotEmpty) 'serverName': sni,
              'allowInsecure': insecure,
            },
            if (obfsType.isNotEmpty)
              'obfsSettings': {
                'type': obfsType,
                if (obfsPassword.isNotEmpty) 'password': obfsPassword,
              },
          },
        }
      ],
    });
  }

  static String _buildWireguardConfig(
      Map<String, dynamic> ob, String server, int port) {
    final privateKey = ob['private_key'] as String? ?? '';
    final publicKey = ob['peer_public_key'] as String? ?? '';
    final preSharedKey = ob['pre_shared_key'] as String? ?? '';
    final localAddress = ob['local_address'];
    final mtu = ob['mtu'] as int? ?? 1420;

    final addresses = <String>[];
    if (localAddress is List) {
      addresses.addAll(localAddress.cast<String>());
    } else if (localAddress is String && localAddress.isNotEmpty) {
      addresses.add(localAddress);
    }

    return jsonEncode({
      'outbounds': [
        {
          'protocol': 'wireguard',
          'settings': {
            'secretKey': privateKey,
            if (addresses.isNotEmpty) 'address': addresses,
            'peers': [
              {
                'publicKey': publicKey,
                if (preSharedKey.isNotEmpty) 'preSharedKey': preSharedKey,
                'endpoint': '$server:$port',
                'allowedIPs': ['0.0.0.0/0', '::/0'],
              }
            ],
            'mtu': mtu,
          },
        }
      ],
    });
  }
}
