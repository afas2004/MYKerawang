import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // 1. Initialize the System
  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Uses your app icon

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings);
    
    // Create the "Channel" (Required for Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // 2. Ask for Permission (The Popup you wanted)
  static Future<void> requestPermission() async {
    await Permission.notification.request();
  }

  // 3. Trigger the Popup
  static Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // Show the actual system notification
    await _notifications.show(
      DateTime.now().millisecond, // Unique ID
      title,
      body,
      details,
    );
  }
}