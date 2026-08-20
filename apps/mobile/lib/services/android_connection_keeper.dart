import 'dart:io';

import 'package:flutter/services.dart';

import 'log_service.dart';

/// Keeps the Flutter process schedulable while Android turns the screen off.
/// The native side runs only while the app is backgrounded with a live remote
/// transport and owns the required foreground notification + partial wake lock.
class AndroidConnectionKeeper {
  static const _channel = MethodChannel('com.duxweb.codux/connection_keeper');

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('start');
      CoduxLog.info('[codux-flutter-lifecycle] background keeper started');
    } on PlatformException catch (error) {
      CoduxLog.warn(
        '[codux-flutter-lifecycle] background keeper start failed code=${error.code}',
      );
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException catch (error) {
      CoduxLog.warn(
        '[codux-flutter-lifecycle] background keeper stop failed code=${error.code}',
      );
    }
  }

  static Future<void> prepareNotifications() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('prepareNotifications');
    } on PlatformException catch (error) {
      CoduxLog.warn(
        '[codux-flutter-notification] prepare failed code=${error.code}',
      );
    }
  }

  static Future<void> notifyIntervention({
    required String terminalId,
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('notifyIntervention', {
        'id': 3000 + (terminalId.hashCode & 0x3fffffff),
        'title': title,
        'body': body,
      });
    } on PlatformException catch (error) {
      CoduxLog.warn(
        '[codux-flutter-notification] show failed code=${error.code}',
      );
    }
  }

  static Future<void> cancelIntervention(String terminalId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('cancelIntervention', {
        'id': 3000 + (terminalId.hashCode & 0x3fffffff),
      });
    } on PlatformException catch (error) {
      CoduxLog.warn(
        '[codux-flutter-notification] cancel failed code=${error.code}',
      );
    }
  }
}
