import '../../../../core/database/database_helper.dart';
import '../../../../shared/models/user_model.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_datasource.dart';
import '../../../../core/network/connectivity_service.dart';
import 'audit_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final UserRemoteDataSource _remoteDataSource = UserRemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();
  final AuditRepository _auditRepo = AuditRepository();

  @override
  Future<void> createUser(UserModel user) async {
    String finalUid = user.uid;
    
    // 1. If online, create Firebase Auth account
    if (await _connectivity.isOnline) {
      try {
        finalUid = await _remoteDataSource.createAuthAccount(user.email, user.password);
      } catch (e) {
        print("Firebase Auth creation failed: $e");
        rethrow;
      }
    }

    final newUser = user.copyWith(uid: finalUid, isSynced: await _connectivity.isOnline);

    // 2. Save locally
    await _dbHelper.createUser(newUser);

    // 3. If online, save to Firestore
    if (await _connectivity.isOnline) {
      await _remoteDataSource.saveUserToFirestore(newUser);
    }
    
    // Log User Created
    await _auditRepo.logAction(
      action: 'User Created',
      targetRecord: '${newUser.name} (${newUser.email} • ${newUser.role.name.toUpperCase()})',
    );
  }

  @override
  Future<List<UserModel>> getUsers() async {
    return await _dbHelper.readAllUsers();
  }

  @override
  Stream<List<UserModel>> getUsersStream() {
    return _remoteDataSource.streamUsersFromFirestore();
  }

  @override
  Future<void> updateUser(UserModel user) async {
    final updatedUser = user.copyWith(isSynced: await _connectivity.isOnline);
    
    // 1. Update locally
    await _dbHelper.updateRecord('users', updatedUser.toMap(), 'id');

    // 2. If online, update Firestore
    if (await _connectivity.isOnline) {
      await _remoteDataSource.saveUserToFirestore(updatedUser);
    }
    
    // Log User Updated
    await _auditRepo.logAction(
      action: 'User Updated',
      targetRecord: '${updatedUser.name} (${updatedUser.email} • Status: ${updatedUser.status})',
    );
  }

  @override
  Future<void> deleteUser(int id, String uid) async {
    // 1. Delete locally
    await _dbHelper.delete('users', id);

    // 2. If online, delete from Firestore
    if (await _connectivity.isOnline) {
      await _remoteDataSource.deleteUserFromFirestore(uid);
    }
    
    // Log User Deleted
    await _auditRepo.logAction(
      action: 'User Deleted',
      targetRecord: 'UID: $uid',
    );
  }

  @override
  Future<void> toggleUserStatus(UserModel user) async {
    final newStatus = user.status == 'active' ? 'deactivated' : 'active';
    final updatedUser = user.copyWith(status: newStatus);
    await updateUser(updatedUser);
  }
}
