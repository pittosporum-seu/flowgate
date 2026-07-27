import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowgate/main.dart';
import 'package:flowgate/features/profiles/profiles_provider.dart';
import 'package:flowgate/features/profiles/repository/profile_repository.dart';
import 'package:flowgate/features/profiles/repository/subscription_repository.dart';
import 'package:flowgate/features/profiles/subscriptions/subscriptions_provider.dart';

void main() {
  // 此测试需要 Hive + 平台通道 (VlessEngine)，仅在 integration test 或设备上运行
  testWidgets('App renders shell', (WidgetTester tester) async {
    // Mock SharedPreferences (used by restoreFromStorage)
    SharedPreferences.setMockInitialValues({});

    // 使用内存 mock repository
    final profileRepo = ProfileRepository();
    await profileRepo.init();
    final subscriptionRepo = SubscriptionRepository();
    await subscriptionRepo.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(profileRepo),
          subscriptionRepositoryProvider.overrideWithValue(subscriptionRepo),
        ],
        child: const FlowGateApp(),
      ),
    );
    await tester.pumpAndSettle();

    // App title 或底部导航栏应存在
    expect(find.byType(MaterialApp), findsOneWidget);
  }, skip: true); // requires Hive + platform channels, run as integration test on device
}
