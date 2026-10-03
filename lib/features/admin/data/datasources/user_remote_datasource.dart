import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../shared/models/user_model.dart';

class UserRemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createAuthAccount(String email, String password) async {
    // Create a secondary app to avoid signing out the current admin
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );
    
    try {
      FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      UserCredential res = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      String uid = res.user!.uid;
      await secondaryApp.delete();
      return uid;
    } catch (e) {
      await secondaryApp.delete();
      rethrow;
    }
  }

  Future<void> saveUserToFirestore(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteUserFromFirestore(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  Future<List<UserModel>> fetchUsersFromFirestore({int limit = 50}) async {
    final query = await _firestore.collection('users').limit(limit).get();
    return query.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
  }

  Stream<List<UserModel>> streamUsersFromFirestore({int limit = 50}) {
    return _firestore.collection('users').limit(limit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    });
  }
}
