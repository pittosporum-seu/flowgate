/// 订阅配置模型
class SubscriptionItem {
  final String id;
  final String url;
  final String name;
  final int lastUpdated; // 上次更新时间戳
  final bool autoUpdate;

  const SubscriptionItem({
    required this.id,
    required this.url,
    required this.name,
    this.lastUpdated = 0,
    this.autoUpdate = true,
  });

  SubscriptionItem copyWith({
    String? id,
    String? url,
    String? name,
    int? lastUpdated,
    bool? autoUpdate,
  }) {
    return SubscriptionItem(
      id: id ?? this.id,
      url: url ?? this.url,
      name: name ?? this.name,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      autoUpdate: autoUpdate ?? this.autoUpdate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'name': name,
        'lastUpdated': lastUpdated,
        'autoUpdate': autoUpdate,
      };

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) =>
      SubscriptionItem(
        id: json['id'] as String,
        url: json['url'] as String,
        name: json['name'] as String? ?? '',
        lastUpdated: json['lastUpdated'] as int? ?? 0,
        autoUpdate: json['autoUpdate'] as bool? ?? true,
      );
}
