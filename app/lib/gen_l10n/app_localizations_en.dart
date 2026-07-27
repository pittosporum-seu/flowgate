import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FlowGate';

  @override
  String get tabHome => 'Home';

  @override
  String get tabNodes => 'Nodes';

  @override
  String get tabRouting => 'Routing';

  @override
  String get tabSettings => 'Settings';

  @override
  String get currentNode => 'Current Node';

  @override
  String get tapToSelect => 'Tap to select';

  @override
  String get latency => 'Latency';

  @override
  String get down => 'Down';

  @override
  String get up => 'Up';

  @override
  String get traffic => 'Traffic';

  @override
  String get connected => 'Connected';

  @override
  String get connecting => 'Connecting...';

  @override
  String get disconnecting => 'Disconnecting...';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get error => 'Error';

  @override
  String get tapToConnect => 'Tap to Connect';

  @override
  String get connectToSeeTraffic => 'Connect to see live traffic';

  @override
  String get profiles => 'Profiles';

  @override
  String get importNodes => 'Import Nodes';

  @override
  String get importHint => 'Subscription URL (https://...)\nor vmess:// vless:// trojan:// ss:// link\nor base64 subscription content';

  @override
  String get pasteFromClipboard => 'Paste from clipboard';

  @override
  String get fetchingSubscription => 'Fetching subscription...';

  @override
  String get cancel => 'Cancel';

  @override
  String get import => 'Import';

  @override
  String importedCount(int count) {
    return 'Imported $count node(s)';
  }

  @override
  String get noValidNodes => 'No valid nodes found';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get noNodesYet => 'No nodes yet';

  @override
  String get manualNodes => 'Manual Nodes';

  @override
  String get refreshSubscription => 'Refresh';

  @override
  String get testSpeed => 'Test';

  @override
  String get searchNodes => 'Search node name or address';

  @override
  String get noSearchResult => 'No matching nodes found';

  @override
  String get testAllSpeeds => 'Test All';

  @override
  String get testAllStarted => 'Batch speed test started...';

  @override
  String get testSpeedFailed => 'Test failed';

  @override
  String get subscriptionUrl => 'Subscription URL (https://...)';

  @override
  String get rawConfig => 'Or paste node links / base64 content';

  @override
  String get renameGroup => 'Rename Group';

  @override
  String get groupName => 'Group name';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get deleteSubscription => 'Delete Subscription';

  @override
  String deleteSubscriptionConfirm(String name) {
    return 'Delete subscription \"$name\" and all its nodes?';
  }

  @override
  String get deleteNode => 'Delete Node';

  @override
  String get editNode => 'Edit Node';

  @override
  String deleteNodeConfirm(String name) {
    return 'Delete node \"$name\"?';
  }

  @override
  String get nodeDeleted => 'Node deleted';

  @override
  String refreshedNodes(int count) {
    return 'Refreshed $count node(s)';
  }

  @override
  String get refreshFailed => 'Refresh failed';

  @override
  String get routing => 'Routing';

  @override
  String get mode => 'Mode';

  @override
  String get modeSmart => 'Smart';

  @override
  String get modeGlobal => 'Global';

  @override
  String get modeBlockCn => 'Block CN';

  @override
  String get modeCustom => 'Custom';

  @override
  String get modeSmartDesc => 'CN direct, overseas proxy';

  @override
  String get modeGlobalDesc => 'All traffic via proxy';

  @override
  String get modeBlockCnDesc => 'Block CN, proxy others';

  @override
  String get modeCustomDesc => 'User-defined rules';

  @override
  String get serviceAdaptive => 'Service Adaptive';

  @override
  String get probe => 'Probe';

  @override
  String get probing => 'Probing';

  @override
  String get probeHint => 'Run a probe to detect\nservice availability';

  @override
  String get actionProxy => 'PROXY';

  @override
  String get actionDirect => 'DIRECT';

  @override
  String get actionBlock => 'BLOCK';

  @override
  String get actionUnavailable => 'N/A';

  @override
  String get rulePacks => 'Rule Packs';

  @override
  String get compiledRules => 'Compiled Rules';

  @override
  String get rulesEmptyHint => 'Switch mode or run probe to compile rules';

  @override
  String get viewXrayJson => 'View Xray routing JSON';

  @override
  String get xrayRouting => 'Xray routing';

  @override
  String get close => 'Close';

  @override
  String get settings => 'Settings';

  @override
  String get general => 'General';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get notifications => 'Notifications';

  @override
  String get dns => 'DNS';

  @override
  String get remoteDns => 'Remote DNS';

  @override
  String get domesticDns => 'Domestic DNS';

  @override
  String get fakeDns => 'FakeDNS';

  @override
  String get advanced => 'Advanced';

  @override
  String get speedTestUrl => 'Speed Test URL';

  @override
  String get autoUpdate => 'Auto Update';

  @override
  String get debug => 'Debug';

  @override
  String get logs => 'Logs';

  @override
  String get logsSubtitle => 'View & share app logs';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get sourceCode => 'Source Code';

  @override
  String get followSystem => 'Follow system';

  @override
  String get chinese => 'Chinese';

  @override
  String get english => 'English';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get clear => 'Clear';

  @override
  String get all => 'All';

  @override
  String get noLogsYet => 'No logs yet';

  @override
  String entries(int count) {
    return '$count entries';
  }

  @override
  String get logsCopied => 'Logs copied to clipboard';

  @override
  String get noLogFile => 'No log file available';

  @override
  String get errNoNodeSelected => 'Please select a node first';

  @override
  String get errNodeConfigMissing => 'Node config missing, please re-import';

  @override
  String get errConnectTimeout => 'Connection timed out, check node or network';

  @override
  String get qrScanTitle => 'Scan to Import';

  @override
  String get qrScanHint => 'Align QR code within frame to scan';

  @override
  String get qrProcessing => 'Processing...';

  @override
  String get qrNoNodeDetected => 'No valid node link detected';

  @override
  String qrImportSuccess(String name) {
    return 'Imported: $name';
  }

  @override
  String qrImportMultiple(int count) {
    return 'Imported $count nodes';
  }

  @override
  String get qrImportFailed => 'Import failed';
}
