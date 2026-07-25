import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 日志级别
enum LogLevel { debug, info, warn, error }

extension LogLevelExt on LogLevel {
  String get label => switch (this) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warn => 'WARN',
        LogLevel.error => 'ERROR',
      };
}

/// 单条日志
class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final String? error;

  LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
  });

  String get formatted {
    final t = time.toIso8601String();
    final base = '$t [${level.label}] [$tag] $message';
    return error == null ? base : '$base\n  error: $error';
  }
}

/// 应用层日志服务 (单例)
/// - 内存环形缓冲（最近 1000 条）供 UI 实时查看
/// - 写入日志文件供导出分享
/// - 流式推送给 UI
class LogService {
  LogService._();
  static final LogService instance = LogService._();

  static const _maxBuffer = 1000;
  static const _fileName = 'flowgate.log';

  final List<LogEntry> _buffer = [];
  final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();
  File? _logFile;

  /// 日志流（UI 订阅）
  Stream<LogEntry> get stream => _controller.stream;

  /// 初始化日志文件
  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/$_fileName');
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
    } catch (e) {
      // 文件初始化失败不阻断，仅内存日志
      _buffer.add(LogEntry(
        time: DateTime.now(),
        level: LogLevel.warn,
        tag: 'LogService',
        message: 'Log file init failed, memory-only',
        error: e.toString(),
      ));
    }
  }

  /// 记录日志
  void log(LogLevel level, String tag, String message, [Object? err]) {
    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: err?.toString(),
    );

    _buffer.add(entry);
    if (_buffer.length > _maxBuffer) {
      _buffer.removeAt(0);
    }

    if (!_controller.isClosed) {
      _controller.add(entry);
    }

    // 异步写文件（不阻塞）
    _writeToFile(entry);
  }

  void debug(String tag, String msg) => log(LogLevel.debug, tag, msg);
  void info(String tag, String msg) => log(LogLevel.info, tag, msg);
  void warn(String tag, String msg, [Object? err]) =>
      log(LogLevel.warn, tag, msg, err);
  void error(String tag, String msg, [Object? err]) =>
      log(LogLevel.error, tag, msg, err);

  Future<void> _writeToFile(LogEntry entry) async {
    try {
      await _logFile?.writeAsString('${entry.formatted}\n',
          mode: FileMode.append, flush: false);
    } catch (_) {
      // 忽略文件写入失败
    }
  }

  /// 当前缓冲快照
  List<LogEntry> snapshot() => List.unmodifiable(_buffer);

  /// 导出日志文件（用于分享）
  Future<File?> exportFile() async {
    if (_logFile == null || !await _logFile!.exists()) return null;
    return _logFile;
  }

  /// 清空缓冲与文件
  Future<void> clear() async {
    _buffer.clear();
    try {
      await _logFile?.writeAsString('', flush: true);
    } catch (_) {}
  }
}
