import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FlowGate'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabNodes.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get tabNodes;

  /// No description provided for @tabRouting.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get tabRouting;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @currentNode.
  ///
  /// In en, this message translates to:
  /// **'Current Node'**
  String get currentNode;

  /// No description provided for @tapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select'**
  String get tapToSelect;

  /// No description provided for @latency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get latency;

  /// No description provided for @down.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get down;

  /// No description provided for @up.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get up;

  /// No description provided for @traffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get traffic;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @disconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting...'**
  String get disconnecting;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @tapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to Connect'**
  String get tapToConnect;

  /// No description provided for @connectToSeeTraffic.
  ///
  /// In en, this message translates to:
  /// **'Connect to see live traffic'**
  String get connectToSeeTraffic;

  /// No description provided for @profiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profiles;

  /// No description provided for @importNodes.
  ///
  /// In en, this message translates to:
  /// **'Import Nodes'**
  String get importNodes;

  /// No description provided for @importHint.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL (https://...)\nor vmess:// vless:// trojan:// ss:// link\nor base64 subscription content'**
  String get importHint;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteFromClipboard;

  /// No description provided for @fetchingSubscription.
  ///
  /// In en, this message translates to:
  /// **'Fetching subscription...'**
  String get fetchingSubscription;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @importedCount.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} node(s)'**
  String importedCount(int count);

  /// No description provided for @noValidNodes.
  ///
  /// In en, this message translates to:
  /// **'No valid nodes found'**
  String get noValidNodes;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @noNodesYet.
  ///
  /// In en, this message translates to:
  /// **'No nodes yet'**
  String get noNodesYet;

  /// No description provided for @manualNodes.
  ///
  /// In en, this message translates to:
  /// **'Manual Nodes'**
  String get manualNodes;

  /// No description provided for @refreshSubscription.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshSubscription;

  /// No description provided for @testSpeed.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get testSpeed;

  /// No description provided for @searchNodes.
  ///
  /// In en, this message translates to:
  /// **'Search node name or address'**
  String get searchNodes;

  /// No description provided for @noSearchResult.
  ///
  /// In en, this message translates to:
  /// **'No matching nodes found'**
  String get noSearchResult;

  /// No description provided for @testAllSpeeds.
  ///
  /// In en, this message translates to:
  /// **'Test All'**
  String get testAllSpeeds;

  /// No description provided for @testAllStarted.
  ///
  /// In en, this message translates to:
  /// **'Batch speed test started...'**
  String get testAllStarted;

  /// No description provided for @testSpeedFailed.
  ///
  /// In en, this message translates to:
  /// **'Test failed'**
  String get testSpeedFailed;

  /// No description provided for @subscriptionUrl.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL (https://...)'**
  String get subscriptionUrl;

  /// No description provided for @rawConfig.
  ///
  /// In en, this message translates to:
  /// **'Or paste node links / base64 content'**
  String get rawConfig;

  /// No description provided for @renameGroup.
  ///
  /// In en, this message translates to:
  /// **'Rename Group'**
  String get renameGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteSubscription.
  ///
  /// In en, this message translates to:
  /// **'Delete Subscription'**
  String get deleteSubscription;

  /// No description provided for @deleteSubscriptionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete subscription \"{name}\" and all its nodes?'**
  String deleteSubscriptionConfirm(String name);

  /// No description provided for @deleteNode.
  ///
  /// In en, this message translates to:
  /// **'Delete Node'**
  String get deleteNode;

  /// No description provided for @deleteNodeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete node \"{name}\"?'**
  String deleteNodeConfirm(String name);

  /// No description provided for @nodeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Node deleted'**
  String get nodeDeleted;

  /// No description provided for @refreshedNodes.
  ///
  /// In en, this message translates to:
  /// **'Refreshed {count} node(s)'**
  String refreshedNodes(int count);

  /// No description provided for @refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed'**
  String get refreshFailed;

  /// No description provided for @routing.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get routing;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @modeSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get modeSmart;

  /// No description provided for @modeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get modeGlobal;

  /// No description provided for @modeBlockCn.
  ///
  /// In en, this message translates to:
  /// **'Block CN'**
  String get modeBlockCn;

  /// No description provided for @modeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get modeCustom;

  /// No description provided for @modeSmartDesc.
  ///
  /// In en, this message translates to:
  /// **'CN direct, overseas proxy'**
  String get modeSmartDesc;

  /// No description provided for @modeGlobalDesc.
  ///
  /// In en, this message translates to:
  /// **'All traffic via proxy'**
  String get modeGlobalDesc;

  /// No description provided for @modeBlockCnDesc.
  ///
  /// In en, this message translates to:
  /// **'Block CN, proxy others'**
  String get modeBlockCnDesc;

  /// No description provided for @modeCustomDesc.
  ///
  /// In en, this message translates to:
  /// **'User-defined rules'**
  String get modeCustomDesc;

  /// No description provided for @serviceAdaptive.
  ///
  /// In en, this message translates to:
  /// **'Service Adaptive'**
  String get serviceAdaptive;

  /// No description provided for @probe.
  ///
  /// In en, this message translates to:
  /// **'Probe'**
  String get probe;

  /// No description provided for @probing.
  ///
  /// In en, this message translates to:
  /// **'Probing'**
  String get probing;

  /// No description provided for @probeHint.
  ///
  /// In en, this message translates to:
  /// **'Run a probe to detect\nservice availability'**
  String get probeHint;

  /// No description provided for @actionProxy.
  ///
  /// In en, this message translates to:
  /// **'PROXY'**
  String get actionProxy;

  /// No description provided for @actionDirect.
  ///
  /// In en, this message translates to:
  /// **'DIRECT'**
  String get actionDirect;

  /// No description provided for @actionBlock.
  ///
  /// In en, this message translates to:
  /// **'BLOCK'**
  String get actionBlock;

  /// No description provided for @actionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get actionUnavailable;

  /// No description provided for @rulePacks.
  ///
  /// In en, this message translates to:
  /// **'Rule Packs'**
  String get rulePacks;

  /// No description provided for @compiledRules.
  ///
  /// In en, this message translates to:
  /// **'Compiled Rules'**
  String get compiledRules;

  /// No description provided for @rulesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Switch mode or run probe to compile rules'**
  String get rulesEmptyHint;

  /// No description provided for @viewXrayJson.
  ///
  /// In en, this message translates to:
  /// **'View Xray routing JSON'**
  String get viewXrayJson;

  /// No description provided for @xrayRouting.
  ///
  /// In en, this message translates to:
  /// **'Xray routing'**
  String get xrayRouting;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @dns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get dns;

  /// No description provided for @remoteDns.
  ///
  /// In en, this message translates to:
  /// **'Remote DNS'**
  String get remoteDns;

  /// No description provided for @domesticDns.
  ///
  /// In en, this message translates to:
  /// **'Domestic DNS'**
  String get domesticDns;

  /// No description provided for @fakeDns.
  ///
  /// In en, this message translates to:
  /// **'FakeDNS'**
  String get fakeDns;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @speedTestUrl.
  ///
  /// In en, this message translates to:
  /// **'Speed Test URL'**
  String get speedTestUrl;

  /// No description provided for @autoUpdate.
  ///
  /// In en, this message translates to:
  /// **'Auto Update'**
  String get autoUpdate;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @logsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View & share app logs'**
  String get logsSubtitle;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source Code'**
  String get sourceCode;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noLogsYet.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get noLogsYet;

  /// No description provided for @entries.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String entries(int count);

  /// No description provided for @logsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied to clipboard'**
  String get logsCopied;

  /// No description provided for @noLogFile.
  ///
  /// In en, this message translates to:
  /// **'No log file available'**
  String get noLogFile;

  /// No description provided for @errNoNodeSelected.
  ///
  /// In en, this message translates to:
  /// **'Please select a node first'**
  String get errNoNodeSelected;

  /// No description provided for @errNodeConfigMissing.
  ///
  /// In en, this message translates to:
  /// **'Node config missing, please re-import'**
  String get errNodeConfigMissing;

  /// No description provided for @errConnectTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out, check node or network'**
  String get errConnectTimeout;

  /// No description provided for @qrScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to Import'**
  String get qrScanTitle;

  /// No description provided for @qrScanHint.
  ///
  /// In en, this message translates to:
  /// **'Align QR code within frame to scan'**
  String get qrScanHint;

  /// No description provided for @qrProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get qrProcessing;

  /// No description provided for @qrNoNodeDetected.
  ///
  /// In en, this message translates to:
  /// **'No valid node link detected'**
  String get qrNoNodeDetected;

  /// No description provided for @qrImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported: {name}'**
  String qrImportSuccess(String name);

  /// No description provided for @qrImportMultiple.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} nodes'**
  String qrImportMultiple(int count);

  /// No description provided for @qrImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get qrImportFailed;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
