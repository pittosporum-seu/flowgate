import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowgate/features/profiles/model/profile_item.dart';
import 'package:flowgate/features/profiles/parser/vless_import_adapter.dart';
import 'package:flowgate/features/profiles/parser/clash_yaml_parser.dart';

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

  group('ClashYamlParser', () {
    test('isClashYaml detects proxies keyword', () {
      expect(ClashYamlParser.isClashYaml('proxies:\n  - name: test'), isTrue);
      expect(ClashYamlParser.isClashYaml('{"proxies": []}'), isFalse);
      expect(ClashYamlParser.isClashYaml('vmess://abc'), isFalse);
    });

    test('parses trojan proxy', () {
      const yaml = '''
proxies:
  - name: My Trojan
    type: trojan
    server: 1.2.3.4
    port: 443
    password: pass123
    sni: example.com
    skip-cert-verify: true
''';
      final results = ClashYamlParser.parse(yaml);
      expect(results.length, 1);
      expect(results[0].type, ProfileType.trojan);
      expect(results[0].server, '1.2.3.4');
      expect(results[0].port, 443);
      expect(results[0].name, 'My Trojan');
      expect(results[0].rawConfig, contains('trojan'));
    });

    test('parses vmess proxy with ws', () {
      const yaml = '''
proxies:
  - name: VMess WS
    type: vmess
    server: cdn.example.com
    port: 443
    uuid: a3482e88-686a-4a58-8126-99c9034e4b09
    alterId: 0
    cipher: auto
    network: ws
    tls: true
    ws-opts:
      path: /v2ray
      headers:
        Host: cdn.example.com
''';
      final results = ClashYamlParser.parse(yaml);
      expect(results.length, 1);
      expect(results[0].type, ProfileType.vmess);
      expect(results[0].rawConfig, contains('wsSettings'));
      expect(results[0].rawConfig, contains('/v2ray'));
    });

    test('parses vless with reality', () {
      const yaml = '''
proxies:
  - name: VLESS Reality
    type: vless
    server: 5.6.7.8
    port: 443
    uuid: test-uuid-123
    network: tcp
    tls: true
    flow: xtls-rprx-vision
    reality-opts:
      public-key: abc123pubkey
      short-id: deadbeef
    servername: www.microsoft.com
''';
      final results = ClashYamlParser.parse(yaml);
      expect(results.length, 1);
      expect(results[0].type, ProfileType.vless);
      expect(results[0].rawConfig, contains('reality'));
      expect(results[0].rawConfig, contains('xtls-rprx-vision'));
    });

    test('parses shadowsocks proxy', () {
      const yaml = '''
proxies:
  - name: SS Node
    type: ss
    server: 10.0.0.1
    port: 8388
    password: sspass
    cipher: aes-256-gcm
''';
      final results = ClashYamlParser.parse(yaml);
      expect(results.length, 1);
      expect(results[0].type, ProfileType.shadowsocks);
      expect(results[0].rawConfig, contains('aes-256-gcm'));
    });

    test('parses multiple proxies and skips unsupported', () {
      const yaml = '''
proxies:
  - name: Trojan1
    type: trojan
    server: 1.1.1.1
    port: 443
    password: p1
  - name: Unknown
    type: snell
    server: 2.2.2.2
    port: 443
  - name: SS1
    type: ss
    server: 3.3.3.3
    port: 8388
    password: p2
    cipher: chacha20-ietf-poly1305
''';
      final results = ClashYamlParser.parse(yaml);
      expect(results.length, 2); // snell skipped
      expect(results[0].type, ProfileType.trojan);
      expect(results[1].type, ProfileType.shadowsocks);
    });

    test('parseBatch detects clash yaml automatically', () {
      const yaml = '''
proxies:
  - name: AutoDetect
    type: trojan
    server: 9.9.9.9
    port: 443
    password: detect
''';
      final results = VlessImportAdapter.parseBatch(yaml);
      expect(results.length, 1);
      expect(results[0].name, 'AutoDetect');
    });
  });
}
