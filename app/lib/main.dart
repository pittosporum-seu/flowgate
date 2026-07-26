import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/service/log_service.dart';
import 'core/state/app_provider.dart';
import 'core/state/locale_provider.dart';
import 'core/theme.dart';
import 'features/profiles/profiles_provider.dart';
import 'features/profiles/repository/profile_repository.dart';
import 'features/profiles/repository/subscription_repository.dart';
import 'features/profiles/subscriptions/subscriptions_provider.dart';
import 'features/routing/routing_provider.dart';
import 'gen_l10n/app_localizations.dart';
import 'shared/widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志服务
  await LogService.instance.init();
  LogService.instance.info('App', 'FlowGate starting...');

  // 全局异常捕获 → 日志
  FlutterError.onError = (details) {
    LogService.instance.error('Flutter', details.exceptionAsString(), details.stack);
    FlutterError.presentError(details);
  };

  // 初始化 Profile 存储 (Epic 3.2)
  final profileRepo = ProfileRepository();
  await profileRepo.init();

  // 初始化订阅存储
  final subscriptionRepo = SubscriptionRepository();
  await subscriptionRepo.init();

  runZonedGuarded(
    () => runApp(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(profileRepo),
          subscriptionRepositoryProvider.overrideWithValue(subscriptionRepo),
        ],
        child: const FlowGateApp(),
      ),
    ),
    (error, stack) {
      LogService.instance.error('Zone', error.toString(), stack);
    },
  );
}

class FlowGateApp extends ConsumerStatefulWidget {
  const FlowGateApp({super.key});

  @override
  ConsumerState<FlowGateApp> createState() => _FlowGateAppState();
}

class _FlowGateAppState extends ConsumerState<FlowGateApp> {
  @override
  void initState() {
    super.initState();
    // 启动时恢复持久化状态 (Epic 2.4)
    Future.microtask(() => ref.read(appProvider.notifier).restoreFromStorage());
    // 恢复路由状态 (Epic 4)
    Future.microtask(() => ref.read(routingProvider.notifier).restore());
    // 恢复语言设置 (i18n)
    Future.microtask(() => ref.read(localeProvider.notifier).restore());
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'FlowGate',
      debugShowCheckedModeBanner: false,
      theme: FlowGateTheme.lightTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}
