import 'package:flutter/foundation.dart';
import '../../shared/models/user_model.dart';

class SessionController extends ChangeNotifier {
  SessionController._();

  static final SessionController instance = SessionController._();

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  void setUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  void clear() {
    if (_currentUser == null) return;
    _currentUser = null;
    notifyListeners();
  }
}
