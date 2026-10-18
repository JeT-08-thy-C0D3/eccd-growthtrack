import '../../shared/models/user_model.dart';

class AuthorizationService {
  const AuthorizationService._();

  static const Set<String> _publicRoutes = {'/login', '/terms'};
  static const Set<String> _adminRoutes = {
    '/admin',
    '/admin/users',
    '/admin/monitoring',
    '/admin/referrals',
    '/admin/audit',
    '/admin/reports',
    '/admin/settings',
  };
  static const Set<String> _teacherRoutes = {
    '/teacher',
    '/register-child',
    '/child-registration',
    '/attendance',
    '/eccd-evaluation',
    '/home-activities',
    '/referrals',
    '/reports',
    '/triangulation',
    '/ai-summary',
    '/teacher/clarifications',
  };
  static const Set<String> _parentRoutes = {
    '/parent',
    '/feedback',
    '/feedback-history',
    '/clarifications',
    '/parent/notifications',
    '/parent/practice-activities',
    '/parent/practice-activities/completed',
  };

  static bool canAccessRoute({
    required UserModel? user,
    required String? routeName,
    required bool isWeb,
  }) {
    if (routeName == null || _publicRoutes.contains(routeName)) return true;
    if (user == null || user.status != 'active') return false;

    if (_adminRoutes.contains(routeName)) {
      return isWeb && user.role == UserRole.admin;
    }
    if (_teacherRoutes.contains(routeName)) {
      return !isWeb && user.role == UserRole.teacher;
    }
    if (_parentRoutes.contains(routeName)) {
      return !isWeb && user.role == UserRole.parent;
    }

    return false;
  }
}
