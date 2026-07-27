/// 订阅配置模型
class SubscriptionItem {
  final String id;
  final String url;
  final String name;
  final int lastUpdated; // 上次更新时间戳
  final bool autoUpdate;

  // 流量元数据（来自 subscription-userinfo header）
  final int upload; // 已上传字节
  final int download; // 已下载字节
  final int total; // 总流量字节
  final int expire; // 到期时间戳（秒）

  const SubscriptionItem({
    required this.id,
    required this.url,
    required this.name,
    this.lastUpdated = 0,
    this.autoUpdate = true,
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expire = 0,
  });

  /// 已用流量
  int get used => upload + download;

  /// 流量使用比例 (0.0 ~ 1.0)
  double get usageRatio => total > 0 ? used / total : 0.0;

  /// 是否已过期
  bool get isExpired =>
      expire > 0 && DateTime.now().millisecondsSinceEpoch ~/ 1000 > expire;

  SubscriptionItem copyWith({
    String? id,
    String? url,
    String? name,
    int? lastUpdated,
    bool? autoUpdate,
    int? upload,
    int? download,
    int? total,
    int? expire,
  }) {
    return SubscriptionItem(
      id: id ?? this.id,
      url: url ?? this.url,
      name: name ?? this.name,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      upload: upload ?? this.upload,
      download: download ?? this.download,
      total: total ?? this.total,
      expire: expire ?? this.expire,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'name': name,
        'lastUpdated': lastUpdated,
        'autoUpdate': autoUpdate,
        'upload': upload,
        'download': download,
        'total': total,
        'expire': expire,
      };

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) =>
      SubscriptionItem(
        id: json['id'] as String,
        url: json['url'] as String,
        name: json['name'] as String? ?? '',
        lastUpdated: json['lastUpdated'] as int? ?? 0,
        autoUpdate: json['autoUpdate'] as bool? ?? true,
        upload: json['upload'] as int? ?? 0,
        download: json['download'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
        expire: json['expire'] as int? ?? 0,
      );
}
