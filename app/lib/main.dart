import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'shared/widgets/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: FlowGateApp()));
}

class FlowGateApp extends StatelessWidget {
  const FlowGateApp({super.key});

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
