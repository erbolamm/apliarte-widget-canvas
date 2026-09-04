import 'dart:developer' as developer;

/// Logger centralizado para la aplicación. Cumple la regla de no usar print().
class AppLogger {
  AppLogger._();

  static void i(String message, [String tag = 'Canvas']) {
    developer.log(message, name: tag);
  }

  static void w(String message, [String tag = 'Canvas']) {
    developer.log('⚠️ $message', name: tag);
  }

  static void e(String message, [dynamic error, StackTrace? st, String tag = 'Canvas']) {
    developer.log('❌ $message', name: tag, error: error, stackTrace: st);
  }
}
