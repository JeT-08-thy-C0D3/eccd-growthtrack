import 'package:cloud_firestore/cloud_firestore.dart';

class RemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadRecord(String collection, String docId, Map<String, dynamic> data) async {
    // Remove SQLite specific flags before uploading
    final uploadData = Map<String, dynamic>.from(data);
    uploadData.remove('is_synced');
    uploadData.remove('id'); // Remove local auto-increment ID if it's not the primary identifier
    // Activities and submissions use the local integer ID as their Firestore
    // document ID. Keep that value in the document so a later download can
    // update the existing SQLite row instead of inserting a duplicate.
    if (collection == 'activities' || collection == 'activity_submissions') {
      final localId = int.tryParse(docId);
      if (localId != null) uploadData['id'] = localId;
    }

    await _firestore.collection(collection).doc(docId).set(uploadData, SetOptions(merge: true));
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchUpdates(String collection, String lastSyncDate) async {
    return (await _firestore
            .collection(collection)
            .where('updated_at', isGreaterThan: lastSyncDate)
            .get())
        .docs;
  }

  Future<void> updateDocumentFileUrl(String collection, String docId, String fieldName, String fileUrl) async {
    await _firestore.collection(collection).doc(docId).set({
      fieldName: fileUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
