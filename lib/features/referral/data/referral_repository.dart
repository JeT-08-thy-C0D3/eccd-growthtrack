import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/audit_logger.dart';
import '../../admin/data/repositories/audit_repository.dart';
import '../domain/referral_model.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../data/repositories/file_upload_repository.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/network/connectivity_service.dart';
import '../../notification/data/notification_repository.dart';

abstract class ReferralRepository {
  Future<int> addReferral(ReferralModel referral);
  Future<List<ReferralModel>> getReferralsByChild(String childId);
  Future<List<Map<String, dynamic>>> getAllReferrals();
  Future<int> updateReferral(ReferralModel referral);
  Future<int> deleteReferral(int id);
  Future<String?> uploadReferralAttachment(String referralId, String filePath);
}

class ReferralRepositoryImpl implements ReferralRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FileUploadRepository _fileUploadRepo = FileUploadRepository();

  @override
  Future<int> addReferral(ReferralModel referral) async {
    _ensureAppropriateContent(referral);
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final newReferral = referral.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    // Web has no SQLite auto-increment table.  Referral rules require the
    // creator's UID, so save a teacher-owned document directly instead of
    // producing local ID 0 records that cannot be listed by the teacher.
    if (kIsWeb) {
      final teacherUid = FirebaseAuth.instance.currentUser?.uid;
      if (teacherUid == null || teacherUid.isEmpty) {
        throw StateError(
          'Your teacher session has expired. Please sign in again.',
        );
      }
      final id = DateTime.now().microsecondsSinceEpoch.remainder(2147483647);
      await _firestore.collection('referrals').doc(id.toString()).set({
        ...newReferral.toMap(),
        'id': id,
        'is_synced': 1,
        'referrerId': teacherUid,
        'server_created_at': FieldValue.serverTimestamp(),
        'server_updated_at': FieldValue.serverTimestamp(),
      });
      await AuditLogger.log(
        action: 'Create Referral',
        module: 'Referral',
        description: 'Created referral for concern: ${referral.concern}.',
      );
      return id;
    }

    // 1. Save Locally
    final id = await _local.saveRecord('referrals', newReferral.toMap());

    // 2. Sync to Cloud if online
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord(
          'referrals',
          id.toString(),
          newReferral.toMap(),
        );
        await _local.markAsSynced('referrals', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    // 3. Log Action
    await AuditLogger.log(
      action: 'Create Referral',
      module: 'Referral',
      description: 'Created referral for concern: ${referral.concern}.',
    );

    return id;
  }

  @override
  Future<List<ReferralModel>> getReferralsByChild(String childId) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.getReferralsByChild(
      childId,
    );
    return maps.map((map) => ReferralModel.fromMap(map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllReferrals() async {
    if (kIsWeb) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return [];
      final profile = await _firestore.collection('users').doc(uid).get();
      final isAdmin = profile.data()?['role'] == 'admin';
      final queries = await Future.wait([
        isAdmin
            ? _firestore.collection('referrals').get()
            : _firestore
                  .collection('referrals')
                  .where('referrerId', isEqualTo: uid)
                  .get(),
        isAdmin
            ? _firestore.collection('children').get()
            : _firestore
                  .collection('children')
                  .where('teacher_uid', isEqualTo: uid)
                  .get(),
      ]);
      final referrals = queries[0];
      final children = queries[1];
      final childrenById = {
        for (final child in children.docs)
          child.data()['child_id']: child.data(),
      };

      return referrals.docs.map((doc) {
        final data = doc.data();
        final child = childrenById[data['child_id']] ?? {};
        return {
          ...data,
          'id': data['id'] ?? int.tryParse(doc.id),
          'first_name': child['first_name'] ?? '',
          'last_name': child['last_name'] ?? '',
        };
      }).toList();
    }

    return await _dbHelper.getAllReferrals();
  }

  @override
  Future<int> updateReferral(ReferralModel referral) async {
    _ensureAppropriateContent(referral);
    if (kIsWeb) {
      if (referral.id == null) return 0;
      await _firestore
          .collection('referrals')
          .doc(referral.id.toString())
          .set(referral.toMap(), SetOptions(merge: true));
      return referral.id!;
    }

    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final updatedReferral = referral.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    // 1. Update Locally
    final result = await _local.saveRecord(
      'referrals',
      updatedReferral.toMap(),
    );

    // 2. Sync to Cloud if online
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord(
          'referrals',
          updatedReferral.id.toString(),
          updatedReferral.toMap(),
        );
        await _local.markAsSynced('referrals', updatedReferral.id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    // 3. Log Action
    await AuditRepository().logAction(
      action: 'Referral Updated',
      targetRecord:
          'Referral ID: ${referral.id} • Child ID: ${referral.childId} • Status: ${referral.status}',
    );

    // Send Parent Notification
    await NotificationRepositoryImpl().sendNotification(
      childId: referral.childId,
      type: 'referral',
      title: 'Referral Status Updated',
      body:
          'Referral case for concern "${referral.concern}" updated to status "${referral.status}".',
      referenceId: referral.id?.toString(),
    );

    return result;
  }

  @override
  Future<int> deleteReferral(int id) async {
    final result = await _dbHelper.delete('referrals', id);
    // Note: Remote delete usually handled by SyncService or direct call
    return result;
  }

  @override
  Future<String?> uploadReferralAttachment(
    String referralId,
    String filePath,
  ) async {
    return await _fileUploadRepo.uploadFile(
      bucket: SupabaseConfig.referralAttachments,
      entityId: referralId,
      category: SupabaseConfig.referralCategory,
      filePath: filePath,
      docCollection: 'referrals',
      urlFieldName: 'attachment_url',
    );
  }

  void _ensureAppropriateContent(ReferralModel referral) {
    final descriptionError = Validators.validateAppropriateText(
      referral.description,
      'Referral description',
      required: true,
    );
    final notesError = Validators.validateAppropriateText(
      referral.followUpNotes,
      'Follow-up notes',
    );
    final guidanceError = Validators.validateAppropriateText(
      referral.adminGuidance,
      'Admin guidance',
    );
    if (descriptionError != null) throw StateError(descriptionError);
    if (notesError != null) throw StateError(notesError);
    if (guidanceError != null) throw StateError(guidanceError);
  }
}
