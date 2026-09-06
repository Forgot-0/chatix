abstract class Logger {
  static void debug(String message) {
    // ignore: avoid_print
    print('[DEBUG] $message');
  }

  static void info(String message) {
    // ignore: avoid_print
    print('[INFO] $message');
  }

  static void warning(String message) {
    // ignore: avoid_print
    print('[WARNING] $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    // ignore: avoid_print
    print('[ERROR] $message');
    if (error != null) {
      // ignore: avoid_print
      print('Error: $error');
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print('StackTrace: $stackTrace');
    }
  }
}
