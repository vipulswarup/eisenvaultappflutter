import 'package:talker_flutter/talker_flutter.dart';

final talker = Talker();

class EVLogger {
  static void debug(String message, [dynamic data]) {
    talker.debug('$message ${data ?? ''}');
  }

  static void info(String message, [dynamic data]) {
    talker.info('$message ${data ?? ''}');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    talker.error(message, error, stackTrace);
  }
}
