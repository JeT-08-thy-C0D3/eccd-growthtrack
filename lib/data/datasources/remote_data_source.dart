import 'package:cloud_firestore/cloud_firestore.dart';

class RemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadRecord(String collection, String docId, Map<String, dynamic> data) async {
    // Remove SQLite specific flags before uploading
    final uploadData = Map<String, dynamic>.from(data);
    uploadData.remove('is_synced');
    uploadData.remove('id'); // Remove local auto-increment ID if it's not the primary identifier

    await _firestore.collection(collection).doc(docId).set(uploadData, SetOptions(merge: true));
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchUpdates(String collection, String lastSyncDate) async {
    return (await _firestore
            .collection(collection)
            .where('updated_at', isGreaterThan: lastSyncDate)
            .get())
        .docs;
  }
}
