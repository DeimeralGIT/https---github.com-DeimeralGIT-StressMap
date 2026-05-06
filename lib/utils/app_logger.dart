import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void info(String scope, String message) {
    _write('INFO', scope, message);
  }

  static void warning(String scope, String message) {
    _write('WARN', scope, message);
  }

  static void error(String scope, String message, [Object? error]) {
    final suffix = error == null ? '' : ' | error=$error';
    _write('ERROR', scope, '$message$suffix');
  }

  static void _write(String level, String scope, String message) {
    if (!kDebugMode) return;
    debugPrint('[$level][$scope] $message');
  }
}