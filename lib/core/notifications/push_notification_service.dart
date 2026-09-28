import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';

/// Registers this device for push (coastal weather advisories, PFZ
/// prediction updates -- see sealanka-be's fcm_service.py). Every device
/// subscribes to the same "all_users" topic; the backend sends to that
/// topic rather than tracking individual device tokens.
Future<void> initPushNotifications() async {
  await Firebase.initializeApp();

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  await messaging.subscribeToTopic('all_users');

  FirebaseMessaging.onMessage.listen((message) {
    Logger().i('Push received: ${message.notification?.title}');
  });
}
