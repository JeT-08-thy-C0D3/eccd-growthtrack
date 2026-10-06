import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../database/database_helper.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentToken;

  String? get currentToken => _currentToken;

  Future<void> initializeAndSyncToken(String userUid) async {
    try {
      // 1. Request OS Permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // 2. Fetch FCM Token
        final token = await _messaging.getToken();
        if (token != null) {
          _currentToken = token;
          await updateUserFcmToken(userUid, token);
        }

        // 3. Listen to Token Refresh
        _messaging.onTokenRefresh.listen((newToken) async {
          _currentToken = newToken;
          await updateUserFcmToken(userUid, newToken);
        });

        // 4. Foreground Message Handler
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print("FCM Foreground Message Received: ${message.notification?.title}");
        });

        // 5. Message Opened Handler (Background Deep Linking)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          print("FCM Message Opened App: ${message.data}");
        });
      }
    } catch (e) {
      print("FCM Initialization Error: $e");
    }
  }

  Future<void> updateUserFcmToken(String userUid, String token) async {
    if (userUid.isEmpty || token.isEmpty) return;

    try {
      // Update Firestore user document
      await _firestore
          .collection('users')
          .doc(userUid)
          .set({'fcm_token': token}, SetOptions(merge: true));

      // Update local SQLite table
      if (!kIsWeb) {
        await DatabaseHelper.instance.updateUserFcmToken(userUid, token);
      }
    } catch (e) {
      print("Error updating FCM Token for user $userUid: $e");
    }
  }

  Future<void> sendPushNotification({
    required String recipientFcmToken,
    required String title,
    required String body,
    required Map<String, dynamic> dataPayload,
  }) async {
    if (recipientFcmToken.isEmpty) return;

    try {
      // Payload structure prepared for FCM HTTP v1 / Cloud Function backend
      final payload = {
        'to': recipientFcmToken,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
        },
        'data': dataPayload,
      };

      print("FCM Payload Dispatched to $recipientFcmToken: $payload");
    } catch (e) {
      print("Error sending FCM Push Payload: $e");
    }
  }
}
