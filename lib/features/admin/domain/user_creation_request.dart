import '../../../../shared/models/user_model.dart';

/// Carries a plaintext password only for the one-time Firebase Auth creation
/// request. It must never be serialized or stored in a UserModel.
class UserCreationRequest {
  final UserModel profile;
  final String password;

  const UserCreationRequest({
    required this.profile,
    required this.password,
  });
}
