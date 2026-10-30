import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../domain/clarification_model.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/utils/audit_logger.dart';
import '../../notification/data/notification_repository.dart';

abstract class ClarificationRepository {
  Future<int> sendRequest(ClarificationModel request);
  Future<List<ClarificationModel>> getRequestsByChild(String childId);
  Future<List<ClarificationModel>> getRequestsByParent(int parentId);
  Future<List<Map<String, dynamic>>> getAllRequestsWithChild();
  Future<int> respondToRequest(int id, String response, int teacherId);
}

class ClarificationRepositoryImpl implements ClarificationRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<int> sendRequest(ClarificationModel request) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final newRequest = request.copyWith(
      createdAt: request.createdAt.isEmpty ? now : request.createdAt,
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    int id = 0;
    if (kIsWeb) {
      final cloudData = newRequest.toMap()
        ..['parent_uid'] = FirebaseAuth.instance.currentUser?.uid
        ..['server_created_at'] = FieldValue.serverTimestamp()
        ..['server_updated_at'] = FieldValue.serverTimestamp();
      final docRef = await _firestore
          .collection('clarifications')
          .add(cloudData);
      id = docRef.id.hashCode.abs();
    } else {
      // SQLite keeps teacher_id as NOT NULL. A pending parent request has no
      // assigned teacher yet, so use the existing neutral sentinel value 0
      // locally; the cloud record can still keep teacher_id null.
      final localData = newRequest.toMap()
        ..['teacher_id'] = newRequest.teacherId ?? 0;
      id = await _local.saveRecord('clarifications', localData);

      if (await _connectivity.isOnline) {
        try {
          final cloudData = newRequest.toMap()
            ..['parent_uid'] = FirebaseAuth.instance.currentUser?.uid;
          await _remote.uploadRecord(
            'clarifications',
            id.toString(),
            cloudData,
          );
          final serverTime = await _remote.fetchServerUpdatedAt(
            'clarifications',
            id.toString(),
          );
          if (serverTime != null) {
            final officialTime = DateFormat('yyyy-MM-dd HH:mm:ss \'UTC\'')
                .format(serverTime);
            await (await _dbHelper.database).update(
              'clarifications',
              {'created_at': officialTime, 'updated_at': officialTime},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
          await _local.markAsSynced('clarifications', id);
        } catch (e) {
          print("Cloud Sync Failed: $e");
        }
      }
    }

    await AuditLogger.log(
      action: 'Clarification Request',
      module: 'Parent Module',
      description:
          'Parent ID ${request.parentId} submitted clarification (${request.category}) for child ID ${request.childId}.',
    );

    return id;
  }

  @override
  Future<List<ClarificationModel>> getRequestsByChild(String childId) async {
    if (kIsWeb) {
      final parentUid = FirebaseAuth.instance.currentUser?.uid;
      final snapshot = await _firestore
          .collection('clarifications')
          .where('child_id', isEqualTo: childId)
          .where('parent_uid', isEqualTo: parentUid)
          .get();
      return snapshot.docs
          .map((doc) => ClarificationModel.fromMap(doc.data()))
          .toList();
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clarifications',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ClarificationModel.fromMap(map)).toList();
  }

  @override
  Future<List<ClarificationModel>> getRequestsByParent(int parentId) async {
    if (kIsWeb) {
      final snapshot = await _firestore
          .collection('clarifications')
          .where('parent_id', isEqualTo: parentId)
          .get();
      return snapshot.docs
          .map((doc) => ClarificationModel.fromMap(doc.data()))
          .toList();
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clarifications',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ClarificationModel.fromMap(map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllRequestsWithChild() async {
    if (kIsWeb) {
      final queries = await Future.wait([
        _firestore.collection('clarifications').get(),
        _firestore
            .collection('children')
            .where(
              'teacher_uid',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
            .get(),
      ]);
      final clarificationsSnapshot = queries[0];
      final childrenSnapshot = queries[1];
      final childrenMap = {
        for (final doc in childrenSnapshot.docs)
          doc.data()['child_id']: doc.data(),
      };

      return clarificationsSnapshot.docs.map((doc) {
        final data = doc.data();
        final child = childrenMap[data['child_id']] ?? {};
        return {
          ...data,
          'doc_id': doc.id,
          'first_name': child['first_name'] ?? 'Child',
          'last_name': child['last_name'] ?? '',
        };
      }).toList();
    }

    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT cl.*, c.first_name, c.last_name
      FROM clarifications cl
      LEFT JOIN children c ON cl.child_id = c.child_id
      ORDER BY cl.created_at DESC
    ''');
  }

  @override
  Future<int> respondToRequest(int id, String response, int teacherId) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    if (kIsWeb) {
      final snapshot = await _firestore.collection('clarifications').get();
      for (final doc in snapshot.docs) {
        if (doc.data()['id'] == id || doc.id == id.toString()) {
          await doc.reference.update({
            'response': response,
            'teacher_id': teacherId,
            'status': 'Responded',
            'updated_at': now,
            'server_updated_at': FieldValue.serverTimestamp(),
          });
          break;
        }
      }
      return id;
    }

    final db = await _dbHelper.database;
    final result = await db.update(
      'clarifications',
      {
        'response': response,
        'teacher_id': teacherId,
        'status': 'Responded',
        'updated_at': now,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (await _connectivity.isOnline) {
      try {
        final maps = await db.query(
          'clarifications',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (maps.isNotEmpty) {
          await _remote.uploadRecord(
            'clarifications',
            id.toString(),
            maps.first,
          );
          await _local.markAsSynced('clarifications', id);
        }
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    await AuditLogger.log(
      action: 'Respond to Clarification',
      module: 'Teacher Module',
      description:
          'Teacher ID $teacherId responded to clarification request ID $id.',
    );

    try {
      String childId = '';
      String category = 'General Concern';
      if (kIsWeb) {
        final snapshot = await _firestore.collection('clarifications').get();
        for (final doc in snapshot.docs) {
          if (doc.data()['id'] == id || doc.id == id.toString()) {
            childId = doc.data()['child_id'] as String? ?? '';
            category = doc.data()['category'] as String? ?? 'General Concern';
            break;
          }
        }
      } else {
        final db = await _dbHelper.database;
        final maps = await db.query(
          'clarifications',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (maps.isNotEmpty) {
          childId = maps.first['child_id'] as String? ?? '';
          category = maps.first['category'] as String? ?? 'General Concern';
        }
      }

      if (childId.isNotEmpty) {
        await NotificationRepositoryImpl().sendNotification(
          childId: childId,
          type: 'clarification_response',
          title: 'Teacher Responded to Clarification',
          body: 'Teacher responded to your question regarding "$category".',
          referenceId: id.toString(),
        );
      }
    } catch (e) {
      print("Notification Error: $e");
    }

    return result;
  }
}
