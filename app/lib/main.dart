import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/state/app_provider.dart';
import 'core/theme.dart';
import 'shared/widgets/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: FlowGateApp()));
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
