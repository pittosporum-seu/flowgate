/// 节点配置模型
library;

enum ProfileType {
  vmess,
  vless,
  trojan,
  shadowsocks,
  socks,
  hysteria2,
  wireguard,
}

extension ProfileTypeExt on ProfileType {
  String get label => switch (this) {
        ProfileType.vmess => 'VMess',
        ProfileType.vless => 'VLESS',
        ProfileType.trojan => 'Trojan',
        ProfileType.shadowsocks => 'SS',
        ProfileType.socks => 'SOCKS',
        ProfileType.hysteria2 => 'HY2',
        ProfileType.wireguard => 'WG',
      };

  String get scheme => switch (this) {
        ProfileType.vmess => 'vmess://',
        ProfileType.vless => 'vless://',
        ProfileType.trojan => 'trojan://',
        ProfileType.shadowsocks => 'ss://',
        ProfileType.socks => 'socks://',
        ProfileType.hysteria2 => 'hysteria2://',
        ProfileType.wireguard => 'wireguard://',
      };
}

class ProfileItem {
  final String id;
  final String name;
  final ProfileType type;
  final String server;
  final int port;
  final String password; // uuid / password / trojan pwd
  final String? method; // shadowsocks method
  final String? sni;
  final String? alpn;
  final String? network; // tcp / ws / grpc
  final String? path; // ws path
  final String? host; // ws host header
  final bool allowInsecure;
  final String? subscriptionId;
  final int? latencyMs;
  final int createdAt;

  /// 完整的 Xray JSON config (来自 flutter_v2ray getFullConfiguration)
  /// 连接时直接使用，避免重复解析
  final String? rawConfig;

  const ProfileItem({
    required this.id,
    required this.name,
    required this.type,
    required this.server,
    required this.port,
    this.password = '',
    this.method,
    this.sni,
    this.alpn,
    this.network,
    this.path,
    this.host,
    this.allowInsecure = false,
    this.subscriptionId,
    this.latencyMs,
    int? createdAt,
    this.rawConfig,
  }) : createdAt = createdAt ?? 0;

  ProfileItem copyWith({
    String? id,
    String? name,
    ProfileType? type,
    String? server,
    int? port,
    String? password,
    String? method,
    String? sni,
    String? alpn,
    String? network,
    String? path,
    String? host,
    bool? allowInsecure,
    String? subscriptionId,
    int? latencyMs,
    int? createdAt,
    String? rawConfig,
  }) {
    return ProfileItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      server: server ?? this.server,
      port: port ?? this.port,
      password: password ?? this.password,
      method: method ?? this.method,
      sni: sni ?? this.sni,
      alpn: alpn ?? this.alpn,
      network: network ?? this.network,
      path: path ?? this.path,
      host: host ?? this.host,
      allowInsecure: allowInsecure ?? this.allowInsecure,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      latencyMs: latencyMs ?? this.latencyMs,
      createdAt: createdAt ?? this.createdAt,
      rawConfig: rawConfig ?? this.rawConfig,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'server': server,
        'port': port,
        'password': password,
        'method': method,
        'sni': sni,
        'alpn': alpn,
        'network': network,
        'path': path,
        'host': host,
        'allowInsecure': allowInsecure,
        'subscriptionId': subscriptionId,
        'latencyMs': latencyMs,
        'createdAt': createdAt,
        'rawConfig': rawConfig,
      };

  factory ProfileItem.fromJson(Map<String, dynamic> json) => ProfileItem(
        id: json['id'] as String,
        name: json['name'] as String,
        type: ProfileType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ProfileType.vmess,
        ),
        server: json['server'] as String,
        port: json['port'] as int,
        password: json['password'] as String? ?? '',
        method: json['method'] as String?,
        sni: json['sni'] as String?,
        alpn: json['alpn'] as String?,
        network: json['network'] as String?,
        path: json['path'] as String?,
        host: json['host'] as String?,
        allowInsecure: json['allowInsecure'] as bool? ?? false,
        subscriptionId: json['subscriptionId'] as String?,
        latencyMs: json['latencyMs'] as int?,
        createdAt: json['createdAt'] as int? ?? 0,
        rawConfig: json['rawConfig'] as String?,
      );
}
