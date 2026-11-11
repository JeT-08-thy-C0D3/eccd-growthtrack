import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadRecord(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool isCreate = false,
  }) async {
    // Remove SQLite specific flags before uploading
    final uploadData = Map<String, dynamic>.from(data);
    uploadData.remove('is_synced');
    uploadData.remove(
      'id',
    ); // Remove local auto-increment ID if it's not the primary identifier
    // Activities and submissions use the local integer ID as their Firestore
    // document ID. Keep that value in the document so a later download can
    // update the existing SQLite row instead of inserting a duplicate.
    if (collection == 'activities' || collection == 'activity_submissions') {
      final localId = int.tryParse(docId);
      if (localId != null) uploadData['id'] = localId;
    }
    // Referral security rules scope every document to its referring teacher.
    // Native records may be queued locally first, so attach the active
    // teacher's identity when the queued record reaches Firestore.
    if (collection == 'referrals') {
      final teacherUid = FirebaseAuth.instance.currentUser?.uid;
      if (teacherUid != null && teacherUid.isNotEmpty) {
        uploadData.putIfAbsent('referrerId', () => teacherUid);
      }
    }

    // New child and activity documents are intentionally unreadable until
    // their owner fields have been stored (see the Firestore rules). A
    // Firestore transaction performs a read before its write, so it fails with
    // a 403 `batchGet` even though the teacher is allowed to create the
    // document. A direct merge write is evaluated as a create by Firestore.
    if (collection == 'children' ||
        collection == 'activities' ||
        collection == 'activity_submissions' ||
        collection == 'attendance_events' ||
        collection == 'referrals' ||
        collection == 'evaluations' ||
        collection == 'parent_feedback' ||
        collection == 'triangulations' ||
        collection == 'development_summaries') {
      await _writeWithoutPreread(
        collection,
        docId,
        uploadData,
        isCreate: isCreate,
      );
      return;
    }

    await _writeWithServerTimestamps(collection, docId, uploadData);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchUpdates(
    String collection,
    String lastSyncDate,
  ) async {
    final lastSyncUtc = DateTime.tryParse(lastSyncDate)?.toUtc();
    if (lastSyncUtc == null) return [];

    return (await _firestore
            .collection(collection)
            .where(
              'server_updated_at',
              isGreaterThan: Timestamp.fromDate(lastSyncUtc),
            )
            .get())
        .docs;
  }

  Future<void> updateDocumentFileUrl(
    String collection,
    String docId,
    String fieldName,
    String fileUrl,
  ) async {
    await _writeWithServerTimestamps(collection, docId, {fieldName: fileUrl});
  }

  /// Reads the authoritative time assigned by Firestore after a successful
  /// write. This is used for parent-facing history instead of the phone clock.
  Future<DateTime?> fetchServerUpdatedAt(
    String collection,
    String docId,
  ) async {
    final snapshot = await _firestore
        .collection(collection)
        .doc(docId)
        .get(const GetOptions(source: Source.server));
    final value = snapshot.data()?['server_updated_at'];
    return value is Timestamp ? value.toDate().toUtc() : null;
  }

  /// The phone clock is not trusted for official record times. Firestore fills
  /// these fields with its own UTC server time once the write reaches Firebase.
  Future<void> _writeWithServerTimestamps(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final document = _firestore.collection(collection).doc(docId);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(document);
      final serverData = <String, dynamic>{
        ...data,
        'server_updated_at': FieldValue.serverTimestamp(),
        if (!existing.exists) 'server_created_at': FieldValue.serverTimestamp(),
      };
      transaction.set(document, serverData, SetOptions(merge: true));
    });
  }

  Future<void> _writeWithoutPreread(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool isCreate = false,
  }) async {
    await _firestore.collection(collection).doc(docId).set({
      ...data,
      'server_updated_at': FieldValue.serverTimestamp(),
      if (isCreate) 'server_created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
