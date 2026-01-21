import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static const String trainingTopic = 'trainingNotice';

  static bool _initialized = false;
  static bool _listenersAttached = false;

  /// 初始化：
  /// - Android 13+ 申請通知權限
  /// - 訂閱 topic（讓 Functions 的 topic push 能收到）
  /// - 印出 token（方便你去 Firebase Console 測試推播）
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    // Android 13+ runtime permission (permission_handler)
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }

    // iOS permission via Firebase Messaging
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
    }

    // 訂閱 topic
    await FirebaseMessaging.instance.subscribeToTopic(trainingTopic);

    // 取 token 方便你測試
    final token = await FirebaseMessaging.instance.getToken();
    // ignore: avoid_print
    print('FCM token: $token');

    _attachDebugListenersOnce();
  }

  static void _attachDebugListenersOnce() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // ignore: avoid_print
      print(
        'FCM onMessage (foreground): '
        'title=${message.notification?.title}, '
        'body=${message.notification?.body}, '
        'data=${message.data}',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // ignore: avoid_print
      print(
        'FCM onMessageOpenedApp: '
        'title=${message.notification?.title}, '
        'body=${message.notification?.body}, '
        'data=${message.data}',
      );
    });
  }
}

