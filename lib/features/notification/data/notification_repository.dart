import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../core/services/fcm_service.dart';
import '../domain/notification_model.dart';

abstract class NotificationRepository {
  Future<void> sendNotification({
    required String childId,
    required String type,
    required String title,
    required String body,
    String? referenceId,
  });

  Stream<List<NotificationModel>> getParentNotificationsStream(String parentUid);
  Stream<int> getUnreadCountStream(String parentUid);
  Future<void> markAsRead(NotificationModel notification);
  Future<void> markAllAsRead(String parentUid);
}

class NotificationRepositoryImpl implements NotificationRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> sendNotification({
    required String childId,
    required String type,
    required String title,
    required String body,
    String? referenceId,
  }) async {
    try {
      String recipientUid = '';
      String childName = '';

      // 1. Resolve Child & Parent UID
      if (kIsWeb) {
        final childDocs = await _firestore
            .collection('children')
            .where('child_id', isEqualTo: childId)
            .get();
        if (childDocs.docs.isNotEmpty) {
          final childData = childDocs.docs.first.data();
          childName = "${childData['first_name'] ?? ''} ${childData['last_name'] ?? ''}".trim();
          final parentName = childData['parent_name'] as String? ?? '';

          if (parentName.isNotEmpty) {
            final parentDocs = await _firestore
                .collection('users')
                .where('name', isEqualTo: parentName)
                .get();
            if (parentDocs.docs.isNotEmpty) {
              recipientUid = parentDocs.docs.first.data()['uid'] as String? ?? '';
            }
          }
        }
      } else {
        final children = await _dbHelper.getAllChildren();
        final childMatch = children.where((c) => c.childId == childId);
        if (childMatch.isNotEmpty) {
          final c = childMatch.first;
          childName = "${c.firstName} ${c.lastName}".trim();
          final users = await _dbHelper.readAllUsers();
          final parentMatch = users.where((u) => u.name.toLowerCase() == c.parentName.toLowerCase());
          if (parentMatch.isNotEmpty) {
            recipientUid = parentMatch.first.uid;
          }
        }
      }

      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final isOnline = await _connectivity.isOnline;

      final notification = NotificationModel(
        recipientUid: recipientUid,
        childId: childId,
        childName: childName.isNotEmpty ? childName : 'Your Child',
        type: type,
        title: title,
        body: body,
        referenceId: referenceId,
        isRead: false,
        createdAt: now,
        isSynced: isOnline,
      );

      // 2. Save to Firestore
      final docRef = await _firestore.collection('notifications').add(notification.toMap());
      
      // 3. Save to Local SQLite
      if (!kIsWeb) {
        final localMap = notification.copyWith(docId: docRef.id, isSynced: true).toMap();
        await _dbHelper.insertNotification(localMap);
      }

      // 4. Fetch Parent FCM Token & Dispatch Push Payload
      if (recipientUid.isNotEmpty) {
        String parentFcmToken = '';
        if (kIsWeb) {
          final userDoc = await _firestore.collection('users').doc(recipientUid).get();
          if (userDoc.exists) {
            parentFcmToken = userDoc.data()?['fcm_token'] as String? ?? '';
          }
        } else {
          final users = await _dbHelper.readAllUsers();
          final userMatch = users.where((u) => u.uid == recipientUid);
          if (userMatch.isNotEmpty) {
            parentFcmToken = userMatch.first.fcmToken ?? '';
          }
        }

        if (parentFcmToken.isNotEmpty) {
          await FcmService().sendPushNotification(
            recipientFcmToken: parentFcmToken,
            title: title,
            body: body,
            dataPayload: {
              'type': type,
              'child_id': childId,
              'reference_id': referenceId ?? '',
            },
          );
        }
      }
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  @override
  Stream<List<NotificationModel>> getParentNotificationsStream(String parentUid) {
    if (parentUid.isEmpty) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .where('recipient_uid', isEqualTo: parentUid)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return NotificationModel.fromMap({
          ...data,
          'doc_id': doc.id,
        });
      }).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  @override
  Stream<int> getUnreadCountStream(String parentUid) {
    if (parentUid.isEmpty) return Stream.value(0);

    return getParentNotificationsStream(parentUid).map((list) {
      return list.where((n) => !n.isRead).length;
    });
  }

  @override
  Future<void> markAsRead(NotificationModel notification) async {
    try {
      if (notification.docId != null && notification.docId!.isNotEmpty) {
        await _firestore.collection('notifications').doc(notification.docId!).update({'is_read': true});
      }
      if (notification.id != null) {
        await _dbHelper.markNotificationAsRead(notification.id!);
      }
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  @override
  Future<void> markAllAsRead(String parentUid) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('recipient_uid', isEqualTo: parentUid)
          .where('is_read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'is_read': true});
      }
      await batch.commit();

      if (!kIsWeb) {
        await _dbHelper.markAllNotificationsAsRead(parentUid);
      }
    } catch (e) {
      print("Error marking all notifications as read: $e");
    }
  }
}
