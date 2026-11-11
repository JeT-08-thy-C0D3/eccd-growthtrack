import '../../../../shared/models/user_model.dart';

abstract class UserRepository {
  Future<List<UserModel>> getUsers();
  Future<bool> emailExists(String email, {String? excludingUid});
  Stream<List<UserModel>> getUsersStream();
  Future<UserModel> createUser(UserModel user);
  Future<void> updateUser(UserModel user);
  Future<void> deleteUser(int id, String uid);
  Future<void> toggleUserStatus(UserModel user);
}
