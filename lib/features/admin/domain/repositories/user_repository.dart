import '../../../../shared/models/user_model.dart';

abstract class UserRepository {
  Future<List<UserModel>> getUsers();
  Stream<List<UserModel>> getUsersStream();
  Future<void> createUser(UserModel user);
  Future<void> updateUser(UserModel user);
  Future<void> deleteUser(int id, String uid);
  Future<void> toggleUserStatus(UserModel user);
}
