import 'package:http/http.dart' as http;
import 'log_service.dart';

/// 订阅拉取服务 (Core 服务层)
/// 负责把订阅 URL 拉取为原始内容（base64/明文），供解析器使用
class SubscriptionFetcher {
  static final http.Client _client = http.Client();

  /// 判断输入是否为订阅 URL
  static bool isUrl(String s) {
    final t = s.trim();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  /// 拉取订阅内容
  /// 返回原始响应体（通常是 base64 编码的节点链接，或明文链接）
  static Future<String> fetch(String url) async {
    final uri = Uri.parse(url.trim());
    LogService.instance.info('SubscriptionFetcher', 'Fetching $url');
    try {
      final resp = await _client.get(uri, headers: {
        // 部分订阅服务商校验 User-Agent
        'User-Agent': 'FlowGate/0.0.1',
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
      LogService.instance.info('SubscriptionFetcher',
          'Fetched OK, ${resp.body.length} bytes');
      return resp.body;
    } on SubscriptionFetchException {
      rethrow;
    } catch (e) {
      LogService.instance.error('SubscriptionFetcher', 'Fetch failed: $url', e);
      rethrow;
    }
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
