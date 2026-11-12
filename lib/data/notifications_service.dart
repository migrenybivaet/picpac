part of '../main.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);
    
    await _plugin.initialize(settings);

    // Запрос разрешения на уведомления для Android 13+
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static Future<void> show(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'picpac_channel', 
      'PicPac Уведомления',
      importance: Importance.max, 
      priority: Priority.high,
      color: Color(0xffe56b6b),
    );
    
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _plugin.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }
}