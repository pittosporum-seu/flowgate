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
