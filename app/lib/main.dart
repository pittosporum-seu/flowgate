import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/state/app_provider.dart';
import 'core/theme.dart';
import 'features/profiles/profiles_provider.dart';
import 'features/profiles/repository/profile_repository.dart';
import 'features/routing/routing_provider.dart';
import 'shared/widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Profile 存储 (Epic 3.2)
  final profileRepo = ProfileRepository();
  await profileRepo.init();

  runApp(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profileRepo),
      ],
      child: const FlowGateApp(),
    ),
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowGate',
      debugShowCheckedModeBanner: false,
      theme: FlowGateTheme.lightTheme,
      home: const AppShell(),
    );
  }
}
