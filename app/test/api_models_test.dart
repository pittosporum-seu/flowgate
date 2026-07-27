import 'package:flutter_test/flutter_test.dart';
import 'package:flowgate/core/api/api_models.dart';

void main() {
  group('ApiResponse', () {
    test('parses success response with data', () {
      final json = {'ok': true, 'data': {'state': 'connected'}};
      final res = ApiResponse<Map<String, dynamic>>.fromJson(
        json,
        (d) => d as Map<String, dynamic>,
      );
      expect(res.ok, isTrue);
      expect(res.data!['state'], 'connected');
      expect(res.error, isNull);
    });

    test('parses error response', () {
      final json = {'ok': false, 'error': 'Node not found'};
      final res = ApiResponse.fromJson(json, null);
      expect(res.ok, isFalse);
      expect(res.error, 'Node not found');
      expect(res.data, isNull);
    });

    test('handles missing ok field', () {
      final json = <String, dynamic>{};
      final res = ApiResponse.fromJson(json, null);
      expect(res.ok, isFalse);
    });
  });

  group('VpnStatusDto', () {
    test('parses full JSON', () {
      final json = {
        'state': 'connected',
        'duration': '01:23:45',
        'uploadSpeed': 1024,
        'downloadSpeed': 2048,
        'uploadTotal': 100000,
        'downloadTotal': 200000,
        'nodeId': 'node-1',
        'nodeName': 'My Node',
      };
      final dto = VpnStatusDto.fromJson(json);
      expect(dto.state, 'connected');
      expect(dto.duration, '01:23:45');
      expect(dto.uploadSpeed, 1024);
      expect(dto.downloadSpeed, 2048);
      expect(dto.uploadTotal, 100000);
      expect(dto.downloadTotal, 200000);
      expect(dto.nodeId, 'node-1');
      expect(dto.nodeName, 'My Node');
    });

    test('handles empty JSON with defaults', () {
      final dto = VpnStatusDto.fromJson({});
      expect(dto.state, 'disconnected');
      expect(dto.duration, '00:00:00');
      expect(dto.uploadSpeed, 0);
      expect(dto.downloadSpeed, 0);
      expect(dto.nodeId, isNull);
    });
  });

  group('NodeDto', () {
    test('parses full node JSON', () {
      final json = {
        'id': 'abc-123',
        'name': 'HK Trojan',
        'type': 'trojan',
        'server': '1.2.3.4',
        'port': 443,
        'password': 'secret',
        'sni': 'example.com',
        'allowInsecure': true,
        'latencyMs': 55,
        'createdAt': 1700000000000,
        'rawConfig': 'trojan://secret@1.2.3.4:443',
      };
      final node = NodeDto.fromJson(json);
      expect(node.id, 'abc-123');
      expect(node.name, 'HK Trojan');
      expect(node.type, 'trojan');
      expect(node.server, '1.2.3.4');
      expect(node.port, 443);
      expect(node.password, 'secret');
      expect(node.sni, 'example.com');
      expect(node.allowInsecure, isTrue);
      expect(node.latencyMs, 55);
      expect(node.rawConfig, contains('trojan://'));
    });

    test('handles minimal JSON', () {
      final node = NodeDto.fromJson({'id': 'x', 'name': 'N', 'type': 'vless', 'server': 's', 'port': 80});
      expect(node.password, '');
      expect(node.method, isNull);
      expect(node.allowInsecure, isFalse);
      expect(node.latencyMs, isNull);
      expect(node.createdAt, 0);
    });

    test('toJson roundtrip', () {
      const original = NodeDto(
        id: 'rt-1',
        name: 'Roundtrip',
        type: 'vmess',
        server: '10.0.0.1',
        port: 8080,
        password: 'pw',
        network: 'ws',
        path: '/ws',
      );
      final json = original.toJson();
      final restored = NodeDto.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.type, original.type);
      expect(restored.server, original.server);
      expect(restored.port, original.port);
      expect(restored.network, 'ws');
      expect(restored.path, '/ws');
    });

    test('toJson omits null fields', () {
      const node = NodeDto(id: 'x', name: 'N', type: 'ss', server: 's', port: 1);
      final json = node.toJson();
      expect(json.containsKey('method'), isFalse);
      expect(json.containsKey('sni'), isFalse);
      expect(json.containsKey('latencyMs'), isFalse);
      expect(json.containsKey('rawConfig'), isFalse);
    });
  });

  group('NodeTestResponse', () {
    test('parses success result', () {
      final r = NodeTestResponse.fromJson({'nodeId': 'n1', 'delay': 42});
      expect(r.nodeId, 'n1');
      expect(r.delay, 42);
      expect(r.error, isNull);
    });

    test('parses failure result', () {
      final r = NodeTestResponse.fromJson({'nodeId': 'n2', 'delay': null, 'error': 'timeout'});
      expect(r.delay, isNull);
      expect(r.error, 'timeout');
    });
  });

  group('SubscriptionDto', () {
    test('parses full JSON', () {
      final json = {
        'id': 'sub-1',
        'name': 'Airport',
        'url': 'https://example.com/sub',
        'autoUpdate': true,
        'updateIntervalHours': 12,
        'lastUpdated': 1700000000000,
        'nodeCount': 20,
        'trafficUsed': 5000000,
        'trafficTotal': 100000000,
        'expireAt': 1800000000000,
        'createdAt': 1699000000000,
      };
      final sub = SubscriptionDto.fromJson(json);
      expect(sub.id, 'sub-1');
      expect(sub.name, 'Airport');
      expect(sub.autoUpdate, isTrue);
      expect(sub.updateIntervalHours, 12);
      expect(sub.nodeCount, 20);
      expect(sub.trafficUsed, 5000000);
      expect(sub.expireAt, 1800000000000);
    });

    test('handles minimal JSON with defaults', () {
      final sub = SubscriptionDto.fromJson({'id': 's', 'name': 'S', 'url': 'u'});
      expect(sub.autoUpdate, isFalse);
      expect(sub.updateIntervalHours, 24);
      expect(sub.nodeCount, 0);
      expect(sub.lastUpdated, isNull);
    });
  });

  group('RoutingRulesDto', () {
    test('parses full routing config', () {
      final json = {
        'domainStrategy': 'IPOnDemand',
        'rules': [
          {
            'id': 'r1',
            'type': 'field',
            'outboundTag': 'direct',
            'domain': ['geosite:cn'],
            'ip': ['geoip:cn'],
            'enabled': true,
            'priority': 1,
          }
        ],
        'bypassLan': true,
        'bypassChina': true,
        'proxyDomains': ['google.com'],
        'directDomains': ['baidu.com'],
      };
      final routing = RoutingRulesDto.fromJson(json);
      expect(routing.domainStrategy, 'IPOnDemand');
      expect(routing.rules.length, 1);
      expect(routing.rules[0].outboundTag, 'direct');
      expect(routing.rules[0].domain, ['geosite:cn']);
      expect(routing.bypassLan, isTrue);
      expect(routing.bypassChina, isTrue);
      expect(routing.proxyDomains, ['google.com']);
    });

    test('handles empty JSON with defaults', () {
      final routing = RoutingRulesDto.fromJson({});
      expect(routing.domainStrategy, 'IPIfNonMatch');
      expect(routing.rules, isEmpty);
      expect(routing.bypassLan, isTrue);
      expect(routing.bypassChina, isFalse);
    });
  });

  group('RoutingRuleDto', () {
    test('parses rule with all fields', () {
      final json = {
        'id': 'rule-block',
        'type': 'field',
        'outboundTag': 'block',
        'domain': ['geosite:category-ads-all'],
        'ip': [],
        'enabled': false,
        'priority': 99,
      };
      final rule = RoutingRuleDto.fromJson(json);
      expect(rule.id, 'rule-block');
      expect(rule.outboundTag, 'block');
      expect(rule.enabled, isFalse);
      expect(rule.priority, 99);
    });
  });

  group('SystemInfoDto', () {
    test('parses system info', () {
      final json = {
        'version': '1.0.0',
        'coreVersion': 'Xray 1.8.6',
        'platform': 'android',
        'apiPort': 19840,
      };
      final info = SystemInfoDto.fromJson(json);
      expect(info.version, '1.0.0');
      expect(info.coreVersion, 'Xray 1.8.6');
      expect(info.platform, 'android');
      expect(info.apiPort, 19840);
    });

    test('handles missing fields', () {
      final info = SystemInfoDto.fromJson({});
      expect(info.version, '');
      expect(info.platform, 'android');
      expect(info.apiPort, 0);
    });
  });
}
