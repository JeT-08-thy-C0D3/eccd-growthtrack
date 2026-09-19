import '../../../../core/database/database_helper.dart';
import '../../../../shared/models/user_model.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_datasource.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/utils/audit_logger.dart';

class UserRepositoryImpl implements UserRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final UserRemoteDataSource _remoteDataSource = UserRemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  Future<void> createUser(UserModel user) async {
    String finalUid = user.uid;
    
    // 1. If online, create Firebase Auth account
    if (await _connectivity.isOnline) {
      try {
        finalUid = await _remoteDataSource.createAuthAccount(user.email, user.password);
      } catch (e) {
        // If account creation fails, we might still want to proceed locally if it's a prototype,
        // but typically we should fail if the auth account is required.
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
    
    // Log creation
    await AuditLogger.log(
      action: 'Create User',
      module: 'User Management',
      description: 'Created account for ${newUser.name} (${newUser.role.name}).',
    );
  }

  @override
  Future<List<UserModel>> getUsers() async {
    // Always return from local first for speed
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
    
    // Log update
    await AuditLogger.log(
      action: 'Update User',
      module: 'User Management',
      description: 'Updated account details for ${updatedUser.name}.',
    );
  }

  @override
  Future<void> deleteUser(int id, String uid) async {
    // 1. Delete locally
    await _dbHelper.delete('users', id);

    // 2. If online, delete from Firestore
    if (await _connectivity.isOnline) {
      await _remoteDataSource.deleteUserFromFirestore(uid);
      // Note: Deleting from Firebase Auth requires Admin SDK or custom logic
    }
    
    // Log deletion
    await AuditLogger.log(
      action: 'Delete User',
      module: 'User Management',
      description: 'Deleted user account with UID: $uid.',
    );
  }

  @override
  Future<void> toggleUserStatus(UserModel user) async {
    final newStatus = user.status == 'active' ? 'deactivated' : 'active';
    final updatedUser = user.copyWith(status: newStatus);
    await updateUser(updatedUser);
  }
}
