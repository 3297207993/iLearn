import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 全局日志实例，统一收口所有日志输出。
///
/// 业务代码请直接使用 `log.i(...)` / `log.w(...)` / `log.e(...)`，
/// 而不是各自散落的 `print` / `debugPrint`，便于按级别与模块统一控制。
///
/// Release 构建下自动静默（仅保留 warning 以上），Debug 下输出完整信息。
final Logger log = Logger(
  level: kReleaseMode ? Level.warning : Level.debug,
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
);
