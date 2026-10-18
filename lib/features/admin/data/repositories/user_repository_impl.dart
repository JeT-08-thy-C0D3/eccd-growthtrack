import '../../../../core/database/database_helper.dart';
import '../../../../shared/models/user_model.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_datasource.dart';
import '../../../../core/network/connectivity_service.dart';
import 'audit_repository.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class UserRepositoryImpl implements UserRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final UserRemoteDataSource _remoteDataSource = UserRemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();
  final AuditRepository _auditRepo = AuditRepository();

  @override
  Future<void> createUser(UserModel user) async {
    if (user.isProtectedAdmin) {
      throw StateError('The system ADMIN account is protected.');
    }
    if (await emailExists(user.email)) {
      throw StateError('An account with this email address already exists.');
    }
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
    if (kIsWeb) {
      return _remoteDataSource.fetchUsersFromFirestore();
    }
    return await _dbHelper.readAllUsers();
  }

  @override
  Future<bool> emailExists(String email, {String? excludingUid}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final users = await getUsers();
    return users.any((user) =>
        user.email.trim().toLowerCase() == normalizedEmail &&
        (excludingUid == null || user.uid != excludingUid));
  }

  @override
  Stream<List<UserModel>> getUsersStream() {
    return _remoteDataSource.streamUsersFromFirestore();
  }

  @override
  Future<void> updateUser(UserModel user) async {
    final existingUser = await _findUserByUid(user.uid);
    if (user.isProtectedAdmin || existingUser?.isProtectedAdmin == true) {
      throw StateError('The system ADMIN account is protected.');
    }
    if (await emailExists(user.email, excludingUid: user.uid)) {
      throw StateError('An account with this email address already exists.');
    }
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
    final user = await _findUserByUid(uid);
    if (user?.isProtectedAdmin == true) {
      throw StateError('The system ADMIN account cannot be deleted.');
    }
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
    if (user.isProtectedAdmin) {
      throw StateError('The system ADMIN account cannot be deactivated.');
    }
    final newStatus = user.status == 'active' ? 'deactivated' : 'active';
    final updatedUser = user.copyWith(status: newStatus);
    await updateUser(updatedUser);
  }

  Future<UserModel?> _findUserByUid(String uid) async {
    for (final item in await getUsers()) {
      if (item.uid == uid) return item;
    }
    return null;
  }
}
