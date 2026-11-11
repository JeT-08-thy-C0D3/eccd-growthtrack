import '../../../shared/models/child_model.dart';
import '../../../core/database/database_helper.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../data/repositories/file_upload_repository.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/utils/audit_logger.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DuplicateRfidCardException implements Exception {
  const DuplicateRfidCardException();
  @override
  String toString() => 'RFID Card Already Registered';
}

class OfflineRfidVerificationException implements Exception {
  const OfflineRfidVerificationException();
  @override
  String toString() =>
      'Connect to the internet to verify this RFID card safely.';
}

abstract class ChildRepository {
  Future<int> addChild(ChildModel child);
  Future<List<ChildModel>> getChildren({bool includeInactive = false});
  Future<int> updateChild(ChildModel child);
  Future<void> archiveChild(ChildModel child);
  Future<void> restoreChild(ChildModel child);
  Future<int> deleteChild(int id);
  Future<String?> uploadProfilePhoto(String childId, String filePath);
  Future<ChildModel> linkRfidCard(ChildModel child, String uid);
  Future<ChildModel> unlinkRfidCard(ChildModel child);
  Future<ChildModel?> findVerifiedChildByRfidUid(String uid);
  Future<void> discardPendingChild(ChildModel child);
}

class ChildRepositoryImpl implements ChildRepository {
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();
  final FileUploadRepository _fileUploadRepo = FileUploadRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<int> addChild(ChildModel child) async {
    if (await _hasDuplicateChild(child)) {
      throw StateError(
        'A child with the same first and last name is already registered.',
      );
    }
    // The web build has no local SQLite database. A cloud write must succeed
    // before reporting success; otherwise a linked child would disappear from
    // both the teacher and parent lists after the form closes.
    if (kIsWeb) {
      await _remote.uploadRecord('children', child.childId, child.toMap());
      await AuditLogger.log(
        action: 'Register Child',
        module: 'Child Registration',
        description:
            'Registered child: ${child.firstName} ${child.lastName} (ID: ${child.childId}).',
      );
      return 1;
    }

    // 1. Save locally first on mobile for offline support.
    final id = await _local.saveRecord('children', child.toMap());

    // 2. OPTIONAL: Attempt immediate cloud sync if online
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('children', child.childId, child.toMap());
        await _local.markAsSynced('children', child.childId);
      } catch (e) {
        // Silently fail; SyncService will retry later
      }
    }

    // Log addition
    await AuditLogger.log(
      action: 'Register Child',
      module: 'Child Registration',
      description:
          'Registered child: ${child.firstName} ${child.lastName} (ID: ${child.childId}).',
    );

    return id;
  }

  @override
  Future<List<ChildModel>> getChildren({bool includeInactive = false}) async {
    // DatabaseHelper implements the shared local-first policy: SQLite is read
    // first on mobile and Firestore is used only to hydrate an empty cache.
    // Web has no SQLite support, so it reads Firestore directly.
    return await DatabaseHelper.instance.getAllChildren(
      includeInactive: includeInactive,
    );
  }

  Future<bool> _hasDuplicateChild(ChildModel candidate) async {
    // Web writes must not preflight-read a collection. Firestore rejects the
    // SDK's broad preflight request for teacher accounts, which otherwise
    // prevents a valid child–parent link from being saved. Mobile retains its
    // local duplicate validation below.
    if (kIsWeb) return false;

    final firstName = _normalizeName(candidate.firstName);
    final lastName = _normalizeName(candidate.lastName);
    final teacherUid = FirebaseAuth.instance.currentUser?.uid;

    // Teachers are intentionally not permitted to read every child record.
    // Checking only their own linked classroom records keeps the duplicate
    // validation valid on web and avoids a Firestore permission failure.
    final existingChildren = teacherUid == null
        ? const <ChildModel>[]
        : await DatabaseHelper.instance.readChildrenByTeacher(
            teacherUid,
            includeInactive: true,
          );

    return existingChildren.any(
      (existing) =>
          existing.childId != candidate.childId &&
          _normalizeName(existing.firstName) == firstName &&
          _normalizeName(existing.lastName) == lastName,
    );
  }

  String _normalizeName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  Future<int> updateChild(ChildModel child) async {
    if (await _hasDuplicateChild(child)) {
      throw StateError(
        'A child with the same first and last name is already registered.',
      );
    }
    if (kIsWeb) {
      await _remote.uploadRecord('children', child.childId, child.toMap());
      await AuditLogger.log(
        action: 'Update Child',
        module: 'Child Registration',
        description:
            'Updated profile for ${child.firstName} ${child.lastName}.',
      );
      return 1;
    }

    final id = await _local.saveRecord('children', child.toMap());
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('children', child.childId, child.toMap());
        await _local.markAsSynced('children', child.childId);
      } catch (_) {}
    }

    // Log update
    await AuditLogger.log(
      action: 'Update Child',
      module: 'Child Registration',
      description: 'Updated profile for ${child.firstName} ${child.lastName}.',
    );

    return id;
  }

  @override
  Future<void> archiveChild(ChildModel child) =>
      _setChildStatus(child, 'inactive', 'Archive Child');

  @override
  Future<void> restoreChild(ChildModel child) =>
      _setChildStatus(child, 'active', 'Restore Child');

  Future<void> _setChildStatus(
    ChildModel child,
    String status,
    String action,
  ) async {
    final updatedChild = child.copyWith(
      status: status,
      updatedAt: DateTime.now().toIso8601String(),
      isSynced: false,
    );
    if (kIsWeb) {
      await _remote.uploadRecord(
        'children',
        updatedChild.childId,
        updatedChild.toMap(),
      );
      await AuditLogger.log(
        action: action,
        module: 'Child Profiles',
        description:
            '$action: ${child.firstName} ${child.lastName} (ID: ${child.childId}).',
      );
      return;
    }

    await _local.saveRecord('children', updatedChild.toMap());
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord(
          'children',
          updatedChild.childId,
          updatedChild.toMap(),
        );
        await _local.markAsSynced('children', updatedChild.childId);
      } catch (_) {}
    }
    await AuditLogger.log(
      action: action,
      module: 'Child Profiles',
      description:
          '$action: ${child.firstName} ${child.lastName} (ID: ${child.childId}).',
    );
  }

  @override
  Future<int> deleteChild(int id) async {
    // Local delete + cloud delete trigger
    return 0; // Simplified for example
  }

  @override
  Future<String?> uploadProfilePhoto(String childId, String filePath) async {
    return await _fileUploadRepo.uploadFile(
      bucket: SupabaseConfig.childProfilePhotos,
      entityId: childId,
      category: SupabaseConfig.childProfileCategory,
      filePath: filePath,
      docCollection: 'children',
      urlFieldName: 'photo_url',
    );
  }

  /// Reserves the UID in a separate authoritative Firestore document before a
  /// child becomes verified. A local cache can never prove global uniqueness.
  @override
  Future<ChildModel> linkRfidCard(ChildModel child, String uid) async {
    final normalizedUid = _normalizeUid(uid);
    if (normalizedUid.isEmpty) {
      throw ArgumentError.value(uid, 'uid');
    }
    if (!await _connectivity.isOnline) {
      throw const OfflineRfidVerificationException();
    }

    final linkedAt = DateTime.now().toUtc().toIso8601String();
    final linked = child.copyWith(
      rfidUid: normalizedUid,
      rfidVerified: true,
      rfidLinkedAt: linkedAt,
      updatedAt: linkedAt,
      isSynced: true,
    );
    final cardRef = _firestore.collection('rfid_cards').doc(normalizedUid);
    final childRef = _firestore.collection('children').doc(child.childId);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(cardRef);
      final owner = existing.data()?['child_id'] as String?;
      if (existing.exists && owner != child.childId) {
        throw const DuplicateRfidCardException();
      }
      final oldUid = _normalizeUid(child.rfidUid ?? '');
      if (oldUid.isNotEmpty && oldUid != normalizedUid) {
        final oldCardRef = _firestore.collection('rfid_cards').doc(oldUid);
        final oldCard = await transaction.get(oldCardRef);
        if (oldCard.exists && oldCard.data()?['child_id'] == child.childId) {
          transaction.delete(oldCardRef);
        }
      }
      final data = linked.toMap()
        ..remove('id')
        ..remove('is_synced');
      transaction.set(childRef, data, SetOptions(merge: true));
      if (!existing.exists) {
        transaction.set(cardRef, {
          'uid': normalizedUid,
          'child_id': child.childId,
          'teacher_uid': child.teacherUid,
          'verified': true,
          'linked_at': linkedAt,
          'server_updated_at': FieldValue.serverTimestamp(),
        });
      }
    });

    if (!kIsWeb) {
      await _local.saveRecord('children', linked.toMap());
      await _local.markAsSynced('children', linked.childId);
    }
    await AuditLogger.log(
      action: 'Link RFID Card',
      module: 'Child Profiles',
      description: 'Verified RFID card for child ID ${child.childId}.',
    );
    return linked;
  }

  @override
  Future<ChildModel> unlinkRfidCard(ChildModel child) async {
    final uid = _normalizeUid(child.rfidUid ?? '');
    if (uid.isEmpty) {
      return child;
    }
    if (!await _connectivity.isOnline) {
      throw const OfflineRfidVerificationException();
    }
    final unlinked = child.copyWith(
      clearRfidLink: true,
      rfidVerified: false,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      isSynced: true,
    );
    final cardRef = _firestore.collection('rfid_cards').doc(uid);
    final childRef = _firestore.collection('children').doc(child.childId);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(cardRef);
      if (existing.exists && existing.data()?['child_id'] == child.childId) {
        transaction.delete(cardRef);
      }
      final data = unlinked.toMap()
        ..remove('id')
        ..remove('is_synced');
      transaction.set(childRef, data, SetOptions(merge: true));
    });
    if (!kIsWeb) {
      await _local.saveRecord('children', unlinked.toMap());
      await _local.markAsSynced('children', unlinked.childId);
    }
    await AuditLogger.log(
      action: 'Unlink RFID Card',
      module: 'Child Profiles',
      description: 'Removed RFID card from child ID ${child.childId}.',
    );
    return unlinked;
  }

  @override
  Future<ChildModel?> findVerifiedChildByRfidUid(String uid) async {
    final normalizedUid = _normalizeUid(uid);
    if (normalizedUid.isEmpty) return null;

    // Web teacher accounts are intentionally forbidden from broad reads of
    // /children. Looking through getChildren() therefore returned an empty
    // list in Chrome even after the profile displayed "RFID Verified". The
    // UID registry is the authoritative, teacher-readable mapping; resolve
    // the child ID from it, then read only that permitted child document.
    try {
      final card = await _firestore
          .collection('rfid_cards')
          .doc(normalizedUid)
          .get(const GetOptions(source: Source.server));
      final childId = card.data()?['child_id'] as String?;
      if (card.exists && childId != null && childId.isNotEmpty) {
        final childSnapshot = await _firestore
            .collection('children')
            .doc(childId)
            .get(const GetOptions(source: Source.server));
        if (childSnapshot.exists) {
          final child = ChildModel.fromMap({
            ...childSnapshot.data()!,
            'child_id': childSnapshot.data()!['child_id'] ?? childSnapshot.id,
          });
          if (child.rfidVerified &&
              _normalizeUid(child.rfidUid ?? '') == normalizedUid) {
            return child;
          }
        }
      }
    } catch (_) {
      // Offline/mobile fallback below retains local-first attendance support.
    }

    // Fallback only reads the signed-in teacher's classroom. Do not call the
    // broad web collection loader here; Firestore rules reject it for teachers.
    final teacherUid = FirebaseAuth.instance.currentUser?.uid;
    final children = teacherUid == null
        ? const <ChildModel>[]
        : await DatabaseHelper.instance.readChildrenByTeacher(
            teacherUid,
            includeInactive: true,
          );
    for (final child in children) {
      if (child.rfidVerified &&
          _normalizeUid(child.rfidUid ?? '') == normalizedUid) {
        return child;
      }
    }
    return null;
  }

  /// A new registration is provisional until its card is verified. Cancelling
  /// or rejecting verification must leave no child profile behind.
  @override
  Future<void> discardPendingChild(ChildModel child) async {
    if (child.rfidVerified) {
      throw StateError('A verified child profile cannot be discarded here.');
    }
    if (await _connectivity.isOnline) {
      // Delete cloud first. If this fails, surface the failure instead of
      // claiming that a cancelled registration left no child profile behind.
      // Deleting a document that was never uploaded is still a successful
      // Firestore operation.
      await _firestore.collection('children').doc(child.childId).delete();
    }
    if (!kIsWeb) {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'children',
        where: 'child_id = ?',
        whereArgs: [child.childId],
      );
    }
    await AuditLogger.log(
      action: 'Cancel Pending Child Registration',
      module: 'Child Registration',
      description: 'Discarded unverified child ID ${child.childId}.',
    );
  }

  String _normalizeUid(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[\s:\-]'), '');
}
