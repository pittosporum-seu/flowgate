import 'package:http/http.dart' as http;
import 'log_service.dart';

/// 订阅拉取结果
class SubscriptionFetchResult {
  final String body;
  final int upload;
  final int download;
  final int total;
  final int expire;

  const SubscriptionFetchResult({
    required this.body,
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expire = 0,
  });
}

/// 订阅拉取服务 (Core 服务层)
/// 负责把订阅 URL 拉取为原始内容（base64/明文），供解析器使用
class SubscriptionFetcher {
  static final http.Client _client = http.Client();

  /// 判断输入是否为订阅 URL
  static bool isUrl(String s) {
    final t = s.trim();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  /// 拉取订阅内容（含元数据）
  static Future<SubscriptionFetchResult> fetchWithMeta(String url) async {
    final uri = Uri.parse(url.trim());
    LogService.instance.info('SubscriptionFetcher', 'Fetching $url');
    try {
      final resp = await _client.get(uri, headers: {
        'User-Agent': 'FlowGate/0.1.0',
        'Accept': '*/*',
      }).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        LogService.instance.error('SubscriptionFetcher',
            'HTTP ${resp.statusCode} for $url');
        throw SubscriptionFetchException(
          'HTTP ${resp.statusCode}',
          statusCode: resp.statusCode,
        );
      }

      // 解析 subscription-userinfo header
      final meta = _parseUserInfo(resp.headers['subscription-userinfo']);
      LogService.instance.info('SubscriptionFetcher',
          'Fetched OK, ${resp.body.length} bytes, meta=$meta');

      return SubscriptionFetchResult(
        body: resp.body,
        upload: meta['upload'] ?? 0,
        download: meta['download'] ?? 0,
        total: meta['total'] ?? 0,
        expire: meta['expire'] ?? 0,
      );
    } on SubscriptionFetchException {
      rethrow;
    } catch (e) {
      LogService.instance.error('SubscriptionFetcher', 'Fetch failed: $url', e);
      rethrow;
    }
  }

  /// 拉取订阅内容（兼容旧接口）
  static Future<String> fetch(String url) async {
    final result = await fetchWithMeta(url);
    return result.body;
  }

  /// 解析 subscription-userinfo header
  /// 格式: upload=123; download=456; total=1024; expire=1234567890
  static Map<String, int> _parseUserInfo(String? header) {
    final result = <String, int>{};
    if (header == null || header.isEmpty) return result;
    for (final part in header.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length == 2) {
        final key = kv[0].trim().toLowerCase();
        final value = int.tryParse(kv[1].trim());
        if (value != null) result[key] = value;
      }
    }
    return result;
  }
}

/// 订阅拉取异常
class SubscriptionFetchException implements Exception {
  final String message;
  final int? statusCode;
  const SubscriptionFetchException(this.message, {this.statusCode});

  @override
  String toString() => 'Subscription fetch failed: $message';
}
