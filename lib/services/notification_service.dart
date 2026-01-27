import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static const String trainingTopic = 'trainingNotice';

  static bool _initialized = false;
  static bool _listenersAttached = false;
  static Future<void>? _initFuture;

  /// 初始化：
  /// - Android 13+ 申請通知權限
  /// - 訂閱 topic（讓 Functions 的 topic push 能收到）
  /// - 印出 token（方便你去 Firebase Console 測試推播）
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    // 避免多處同時呼叫造成重複初始化
    if (_initFuture != null) return _initFuture!;
    _initFuture = _ensureInitializedImpl();
    return _initFuture!;
  }

  static Future<void> _ensureInitializedImpl() async {
    try {
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

      // 先 attach listener（避免初始化過程中漏 log）
      _attachDebugListenersOnce();

      // 取 token（方便你測試）
      try {
        final token = await FirebaseMessaging.instance.getToken();
        // ignore: avoid_print
        print('FCM token: $token');
      } catch (e) {
        // ignore: avoid_print
        print('FCM getToken failed (ignored): $e');
      }

      // ✅ 訂閱 topic
      // iOS 若尚未取得 APNs token（尚未開 Push capability / APNs 設定未完成）
      // subscribeToTopic 可能拋出 [firebase_messaging/apns-token-not-set]。
      // 這不該影響登入/使用，因此改為忽略並延後重試一次。
      await _subscribeTopicBestEffort();

      _initialized = true;
    } finally {
      // 若初始化未完成（例如被中斷/丟錯），允許下次再嘗試
      if (!_initialized) _initFuture = null;
    }
  }

  static Future<void> _subscribeTopicBestEffort() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(trainingTopic);
      return;
    } catch (e) {
      // ignore: avoid_print
      print('FCM subscribeToTopic failed (ignored): $e');
    }

    // iOS 常見：APNs token 還沒 ready，稍等再重試一次（不阻塞 UI）
    if (Platform.isIOS) {
      Future<void>.delayed(const Duration(seconds: 3), () async {
        try {
          await FirebaseMessaging.instance.subscribeToTopic(trainingTopic);
          // ignore: avoid_print
          print('FCM subscribeToTopic retry success');
        } catch (e) {
          // ignore: avoid_print
          print('FCM subscribeToTopic retry failed (ignored): $e');
        }
      });
    }
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

