import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全局 Tab 索引 Provider
/// 用于跨页面切换底部导航 Tab（如 Dashboard 节点卡跳转到节点页）
/// 0=主页 1=节点 2=路由 3=设置
final tabIndexProvider = StateProvider<int>((ref) => 0);
