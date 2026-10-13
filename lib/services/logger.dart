import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';

/// Thin wrapper over Sentry's structured logging API ([Sentry.logger]).
///
/// Emits log records that Sentry groups and indexes alongside crashes, and
/// mirrors them to the debug console in debug builds so local runs stay
/// observable without a network round-trip.
class AppLog {
  AppLog._();

  static void trace(String message, {Map<String, SentryAttribute>? attributes}) {
    Sentry.logger.trace(message, attributes: attributes);
    _console('TRACE', message);
  }

  static void debug(String message, {Map<String, SentryAttribute>? attributes}) {
    Sentry.logger.debug(message, attributes: attributes);
    _console('DEBUG', message);
  }

  static void info(String message, {Map<String, SentryAttribute>? attributes}) {
    Sentry.logger.info(message, attributes: attributes);
    _console('INFO', message);
  }

  static void warn(String message, {Map<String, SentryAttribute>? attributes}) {
    Sentry.logger.warn(message, attributes: attributes);
    _console('WARN', message);
  }

  static void error(
    String message, {
    Map<String, SentryAttribute>? attributes,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    Sentry.logger.error(message, attributes: attributes);
    if (exception != null) {
      Sentry.captureException(exception, stackTrace: stackTrace);
    }
    _console('ERROR', message);
  }

  static void fatal(
    String message, {
    Map<String, SentryAttribute>? attributes,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    Sentry.logger.fatal(message, attributes: attributes);
    if (exception != null) {
      Sentry.captureException(exception, stackTrace: stackTrace);
    }
    _console('FATAL', message);
  }

  static void _console(String level, String message) {
    if (kDebugMode) {
      debugPrint('[$level] $message');
    }
  }
}
