import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgate/features/profiles/model/profile_item.dart';
import 'package:flowgate/features/profiles/parser/vless_import_adapter.dart';

void main() {
  group('VlessImportAdapter - representative links', () {
    test('parses a trojan:// link', () {
      const link =
          'trojan://password123@1.2.3.4:443?allowInsecure=1&peer=example.com#My%20Trojan';
      final p = VlessImportAdapter.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.type, ProfileType.trojan);
      expect(p.server, '1.2.3.4');
      expect(p.port, 443);
      expect(p.name, 'My Trojan');
      expect(p.rawConfig, isNotNull);
      expect(p.rawConfig, contains('trojan'));
    });

    test('parses a vless:// link', () {
      const link =
          'vless://uuid-1234@5.6.7.8:8443?type=ws&path=%2Fws&host=cdn.example.com&security=tls#Vless%20Node';
      final p = VlessImportAdapter.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.type, ProfileType.vless);
      expect(p.server, '5.6.7.8');
      expect(p.port, 8443);
      expect(p.rawConfig, isNotNull);
    });

    test('returns null for garbage input', () {
      expect(VlessImportAdapter.parseSingle('not a valid link'), isNull);
    });
  });

  group('VlessImportAdapter - hysteria2', () {
    test('parses a hysteria2:// link', () {
      const link =
          'hysteria2://mypassword@10.0.0.1:443?sni=example.com&insecure=1#My%20HY2';
      final p = VlessImportAdapter.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.type, ProfileType.hysteria2);
      expect(p.server, '10.0.0.1');
      expect(p.port, 443);
      expect(p.password, 'mypassword');
      expect(p.name, 'My HY2');
      expect(p.rawConfig, isNotNull);
      expect(p.rawConfig, contains('hysteria2'));
      expect(p.rawConfig, contains('example.com'));
    });

    test('parses a hy2:// link', () {
      const link = 'hy2://pass123@192.168.1.1:8443#HY2%20Short';
      final p = VlessImportAdapter.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.type, ProfileType.hysteria2);
      expect(p.server, '192.168.1.1');
      expect(p.port, 8443);
      expect(p.password, 'pass123');
      expect(p.name, 'HY2 Short');
    });

    test('parses hysteria2 with obfs params', () {
      const link =
          'hysteria2://secret@1.2.3.4:443?obfs=salamander&obfs-password=obfspass&sni=cdn.com#Obfs%20Node';
      final p = VlessImportAdapter.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.type, ProfileType.hysteria2);
      expect(p.rawConfig, contains('salamander'));
      expect(p.rawConfig, contains('obfspass'));
    });

    test('hysteria2 default name when no fragment', () {
      const link = 'hysteria2://pass@1.2.3.4:443';
      final p = VlessImportAdapter.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.name, 'Hysteria2 Node');
    });

    test('batch parse includes hysteria2 links', () {
      const content = 'trojan://t@1.1.1.1:443#TrojanNode\nhysteria2://h@2.2.2.2:443#HY2Node';
      final results = VlessImportAdapter.parseBatch(content);
      expect(results.length, 2);
      expect(results.any((p) => p.type == ProfileType.hysteria2), isTrue);
      expect(results.any((p) => p.type == ProfileType.trojan), isTrue);
    });
  });

  group('VlessImportAdapter - wireguard', () {
    test('parses wireguard .conf format', () {
      const conf = '''
[Interface]
PrivateKey = YKkRBEr2LmWEj1B3r+WGn9S8V0Ux5T6q7dF8g9h0i1j=
Address = 10.0.0.2/32
DNS = 1.1.1.1
MTU = 1280

[Peer]
PublicKey = xTIBA5r5U0qt4j7dF8g9h0i1j2k3l4m5n6o7p8q9r0s=
PresharedKey = abcd1234efgh5678ijkl9012mnop3456qrst7890uvwx=
Endpoint = 5.6.7.8:51820
AllowedIPs = 0.0.0.0/0, ::/0
''';
      final p = VlessImportAdapter.parseSingle(conf);
      expect(p, isNotNull);
      expect(p!.type, ProfileType.wireguard);
      expect(p.server, '5.6.7.8');
      expect(p.port, 51820);
      expect(p.password, 'YKkRBEr2LmWEj1B3r+WGn9S8V0Ux5T6q7dF8g9h0i1j=');
      expect(p.rawConfig, contains('wireguard'));
      expect(p.rawConfig, contains('5.6.7.8:51820'));
      expect(p.rawConfig, contains('xTIBA5r5U0qt4j7dF8g9h0i1j2k3l4m5n6o7p8q9r0s='));
    });

    test('parses wireguard:// URL format', () {
      const link = 'wireguard://myPrivateKey@10.0.0.1:51820?publickey=peerPubKey123&allowedips=0.0.0.0/0&address=10.0.0.2/32#My%20WG';
      final p = VlessImportAdapter.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.type, ProfileType.wireguard);
      expect(p.server, '10.0.0.1');
      expect(p.port, 51820);
      expect(p.name, 'My WG');
      expect(p.rawConfig, contains('wireguard'));
      expect(p.rawConfig, contains('peerPubKey123'));
    });

    test('parses wg:// short scheme', () {
      const link = 'wg://secretKey@192.168.1.1:51820?publickey=abc123#ShortWG';
      final p = VlessImportAdapter.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.type, ProfileType.wireguard);
      expect(p.name, 'ShortWG');
    });

    test('wireguard conf with IPv6 endpoint', () {
      const conf = '''
[Interface]
PrivateKey = testKey123=
Address = fd00::2/128

[Peer]
PublicKey = peerKey456=
Endpoint = [2001:db8::1]:51820
AllowedIPs = ::/0
''';
      final p = VlessImportAdapter.parseSingle(conf);
      expect(p, isNotNull);
      expect(p!.type, ProfileType.wireguard);
      expect(p.server, '2001:db8::1');
      expect(p.port, 51820);
    });

    test('returns null for invalid wireguard conf (no endpoint)', () {
      const conf = '''
[Interface]
PrivateKey = testKey123=

[Peer]
PublicKey = peerKey456=
''';
      final p = VlessImportAdapter.parseSingle(conf);
      expect(p, isNull);
    });
  });

  group('VlessImportAdapter - real subscription file', () {
    test('parses base64 trojan subscription (if fixture present)', () {
      final file = File('test/sub_raw.txt');
      if (!file.existsSync()) {
        // 凭证文件不存在则跳过（不入库）
        return;
      }
      final content = file.readAsStringSync();
      final profiles = VlessImportAdapter.parseBatch(content);
      // ignore: avoid_print
      print('Parsed ${profiles.length} nodes from real subscription');
      expect(profiles, isNotEmpty);
      // 全部应为 trojan 节点（订阅 URL 指定 net_type=TROJAN）
      expect(profiles.every((p) => p.type == ProfileType.trojan), isTrue);
      expect(profiles.every((p) => p.rawConfig != null), isTrue);
      // 打印前 3 个节点概要（不含密码）
      for (final p in profiles.take(3)) {
        // ignore: avoid_print
        print('  - ${p.name} | ${p.server}:${p.port}');
      }
    });
  });
}
