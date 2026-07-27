import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'FlowGate';

  @override
  String get tabHome => '主页';

  @override
  String get tabNodes => '节点';

  @override
  String get tabRouting => '路由';

  @override
  String get tabSettings => '设置';

  @override
  String get currentNode => '当前节点';

  @override
  String get tapToSelect => '点击选择';

  @override
  String get latency => '延迟';

  @override
  String get down => '下行';

  @override
  String get up => '上行';

  @override
  String get traffic => '流量';

  @override
  String get connected => '已连接';

  @override
  String get connecting => '连接中...';

  @override
  String get disconnecting => '断开中...';

  @override
  String get disconnected => '未连接';

  @override
  String get error => '错误';

  @override
  String get tapToConnect => '点击连接';

  @override
  String get connectToSeeTraffic => '连接后查看实时流量';

  @override
  String get profiles => '节点';

  @override
  String get importNodes => '导入节点';

  @override
  String get importHint => '订阅链接 (https://...)\n或 vmess:// vless:// trojan:// ss:// 链接\n或 base64 订阅内容';

  @override
  String get pasteFromClipboard => '从剪贴板粘贴';

  @override
  String get fetchingSubscription => '正在拉取订阅...';

  @override
  String get cancel => '取消';

  @override
  String get import => '导入';

  @override
  String importedCount(int count) {
    return '已导入 $count 个节点';
  }

  @override
  String get noValidNodes => '未找到有效节点';

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get noNodesYet => '暂无节点';

  @override
  String get manualNodes => '手动节点';

  @override
  String get refreshSubscription => '刷新';

  @override
  String get testSpeed => '测速';

  @override
  String get searchNodes => '搜索节点名称或地址';

  @override
  String get noSearchResult => '未找到匹配的节点';

  @override
  String get testAllSpeeds => '一键测速';

  @override
  String get testAllStarted => '开始批量测速...';

  @override
  String get testSpeedFailed => '测速失败';

  @override
  String get subscriptionUrl => '订阅链接 (https://...)';

  @override
  String get rawConfig => '或粘贴节点链接 / base64 内容';

  @override
  String get renameGroup => '重命名分组';

  @override
  String get groupName => '分组名称';

  @override
  String get confirm => '确定';

  @override
  String get delete => '删除';

  @override
  String get deleteSubscription => '删除订阅';

  @override
  String deleteSubscriptionConfirm(String name) {
    return '确定删除订阅「$name」及其所有节点吗？';
  }

  @override
  String get deleteNode => '删除节点';

  @override
  String deleteNodeConfirm(String name) {
    return '确定删除节点「$name」吗？';
  }

  @override
  String get nodeDeleted => '节点已删除';

  @override
  String refreshedNodes(int count) {
    return '已刷新 $count 个节点';
  }

  @override
  String get refreshFailed => '刷新失败';

  @override
  String get routing => '路由';

  @override
  String get mode => '模式';

  @override
  String get modeSmart => '智能';

  @override
  String get modeGlobal => '全局';

  @override
  String get modeBlockCn => '拦截国内';

  @override
  String get modeCustom => '自定义';

  @override
  String get modeSmartDesc => '国内直连，海外代理';

  @override
  String get modeGlobalDesc => '所有流量走代理';

  @override
  String get modeBlockCnDesc => '拦截国内，其余代理';

  @override
  String get modeCustomDesc => '用户自定义规则';

  @override
  String get serviceAdaptive => '服务自适应';

  @override
  String get probe => '探测';

  @override
  String get probing => '探测中';

  @override
  String get probeHint => '运行探测以检测\n服务可用性';

  @override
  String get actionProxy => '代理';

  @override
  String get actionDirect => '直连';

  @override
  String get actionBlock => '拦截';

  @override
  String get actionUnavailable => '不可用';

  @override
  String get rulePacks => '规则包';

  @override
  String get compiledRules => '编译规则';

  @override
  String get rulesEmptyHint => '切换模式或运行探测以编译规则';

  @override
  String get viewXrayJson => '查看 Xray 路由 JSON';

  @override
  String get xrayRouting => 'Xray 路由';

  @override
  String get close => '关闭';

  @override
  String get settings => '设置';

  @override
  String get general => '通用';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get notifications => '通知';

  @override
  String get dns => 'DNS';

  @override
  String get remoteDns => '远程 DNS';

  @override
  String get domesticDns => '国内 DNS';

  @override
  String get fakeDns => 'FakeDNS';

  @override
  String get advanced => '高级';

  @override
  String get speedTestUrl => '测速地址';

  @override
  String get autoUpdate => '自动更新';

  @override
  String get debug => '调试';

  @override
  String get logs => '日志';

  @override
  String get logsSubtitle => '查看并分享应用日志';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get sourceCode => '源代码';

  @override
  String get followSystem => '跟随系统';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get copy => '复制';

  @override
  String get share => '分享';

  @override
  String get clear => '清空';

  @override
  String get all => '全部';

  @override
  String get noLogsYet => '暂无日志';

  @override
  String entries(int count) {
    return '$count 条';
  }

  @override
  String get logsCopied => '日志已复制到剪贴板';

  @override
  String get noLogFile => '无可用日志文件';

  @override
  String get errNoNodeSelected => '请先选择一个节点';

  @override
  String get errNodeConfigMissing => '节点配置缺失，请重新导入';

  @override
  String get errConnectTimeout => '连接超时，请检查节点或网络';

  @override
  String get qrScanTitle => '扫码导入';

  @override
  String get qrScanHint => '将二维码放入框内自动识别';

  @override
  String get qrProcessing => '正在处理...';

  @override
  String get qrNoNodeDetected => '未识别到有效的节点链接';

  @override
  String qrImportSuccess(String name) {
    return '已导入: $name';
  }

  @override
  String qrImportMultiple(int count) {
    return '已导入 $count 个节点';
  }

  @override
  String get qrImportFailed => '导入失败';
}
