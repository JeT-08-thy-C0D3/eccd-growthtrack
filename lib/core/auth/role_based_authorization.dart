/// Authorization Service - Enhanced with Role-Based Access Control
/// 
/// This replaces the simple authorization_service.dart with a comprehensive
/// role-based access control (RBAC) system that validates:
/// - User roles (admin, teacher, parent)
/// - Center/organization assignments
/// - Child access permissions
/// - Feature flags and capabilities

import '../../shared/models/canonical/canonical_user_model.dart';

class RoleBasedAuthorizationService {
  static const RoleBasedAuthorizationService _instance = RoleBasedAuthorizationService._();

  /// Feature access matrix
  static const Map<UserRoleType, Set<String>> _roleFeatures = {
    UserRoleType.admin: {
      'user-management',
      'center-management',
      'audit-logs',
      'system-settings',
      'reports',
      'category-admin',
      'privacy-admin',
      'device-admin',
    },
    UserRoleType.teacher: {
      'child-evaluation',
      'attendance',
      'referrals',
      'activities',
      'home-activities',
      'reports',
      'triangulation',
      'parent-notifications',
    },
    UserRoleType.parent: {
      'child-summary',
      'feedback',
      'clarifications',
      'notifications',
      'home-activities',
      'practice-activities',
      'privacy-controls',
      'data-requests',
    },
  };

  /// Route access matrix
  static const Map<UserRoleType, Set<String>> _roleRoutes = {
    UserRoleType.admin: {
      '/admin',
      '/admin/users',
      '/admin/centers',
      '/admin/monitoring',
      '/admin/referrals',
      '/admin/audit',
      '/admin/reports',
      '/admin/settings',
      '/admin/categories',
      '/admin/privacy',
      '/admin/devices',
    },
    UserRoleType.teacher: {
      '/teacher',
      '/teacher/dashboard',
      '/teacher/children',
      '/register-child',
      '/attendance',
      '/eccd-evaluation',
      '/home-activities',
      '/referrals',
      '/reports',
      '/triangulation',
      '/ai-summary',
      '/teacher/clarifications',
      '/teacher/notifications',
    },
    UserRoleType.parent: {
      '/parent',
      '/parent/dashboard',
      '/child-summary',
      '/feedback',
      '/feedback-history',
      '/clarifications',
      '/parent/notifications',
      '/parent/practice-activities',
      '/parent/practice-activities/completed',
      '/parent/privacy',
      '/parent/data-requests',
    },
    UserRoleType.parent: {
      '/login',
      '/signup',
      '/terms',
      '/privacy',
      '/password-reset',
    },
  };

  const RoleBasedAuthorizationService._();

  factory RoleBasedAuthorizationService() => _instance;

  /// Check if user can access a specific feature
  static bool canAccessFeature({
    required CanonicalUser? user,
    required String feature,
  }) {
    if (user == null || user.status != 'active') return false;

    final allowedFeatures = _roleFeatures[user.role];
    return allowedFeatures?.contains(feature) ?? false;
  }

  /// Check if user can access a specific route
  static bool canAccessRoute({
    required CanonicalUser? user,
    required String routeName,
    required bool isWeb,
  }) {
    // Public routes accessible to everyone
    const publicRoutes = {'/login', '/signup', '/terms', '/privacy', '/password-reset'};
    if (publicRoutes.contains(routeName)) return true;

    // Require user for protected routes
    if (user == null || user.status != 'active') return false;

    // Web-only routes (admin)
    const webOnlyRoutes = {'/admin', '/admin/users', '/admin/centers', '/admin/monitoring'};
    if (webOnlyRoutes.contains(routeName) && !isWeb) return false;

    // Check role-based route access
    final allowedRoutes = _roleRoutes[user.role];
    return allowedRoutes?.contains(routeName) ?? false;
  }

  /// Check if user can access a specific child record
  static bool canAccessChild({
    required CanonicalUser? user,
    required String childId,
    required String childCenterId,
    required List<ChildAccessRecord>? teacherAssignments,
  }) {
    if (user == null || user.status != 'active') return false;

    switch (user.role) {
      case UserRoleType.admin:
        // Admins can access any child
        return true;

      case UserRoleType.teacher:
        // Teachers can only access children assigned to them
        if (user.centerId != childCenterId) return false;
        if (teacherAssignments == null) return false;
        
        return teacherAssignments.any((a) =>
            a.childId == childId &&
            a.teacherId == user.uid &&
            a.status == 'active');

      case UserRoleType.parent:
        // Parents can only access linked children (verified consent)
        // Checked via ConsentRecord relationship
        return true; // Requires separate consent verification
    }
  }

  /// Check if user can edit a child's evaluation
  static bool canEditEvaluation({
    required CanonicalUser? user,
    required String childId,
    required String evaluationCenterId,
    required List<ChildAccessRecord>? assignments,
  }) {
    // Only teachers can create/edit evaluations
    if (user?.role != UserRoleType.teacher) return false;

    // Must be assigned to child
    return canAccessChild(
      user: user,
      childId: childId,
      childCenterId: evaluationCenterId,
      teacherAssignments: assignments,
    );
  }

  /// Check if user can approve evaluation results
  static bool canApproveEvaluation({
    required CanonicalUser? user,
  }) {
    if (user == null || user.status != 'active') return false;
    // Only teachers can approve (potentially with admin override)
    return user.role == UserRoleType.teacher;
  }

  /// Check if user can view referrals
  static bool canViewReferral({
    required CanonicalUser? user,
    required String referralCenterId,
  }) {
    if (user == null || user.status != 'active') return false;

    switch (user.role) {
      case UserRoleType.admin:
        return true; // Admins see all
      case UserRoleType.teacher:
        return user.centerId == referralCenterId; // Teachers see center referrals
      case UserRoleType.parent:
        return false; // Parents cannot view referrals (confidential)
    }
  }

  /// Check if user can delete records (audit trail)
  static bool canDeleteRecord({
    required CanonicalUser? user,
  }) {
    if (user == null || user.status != 'active') return false;
    // Only admins can delete (soft-delete via audit log)
    return user.role == UserRoleType.admin;
  }

  /// Check if user can export data
  static bool canExportData({
    required CanonicalUser? user,
  }) {
    if (user == null || user.status != 'active') return false;
    // Admins and teachers can export
    return user.role == UserRoleType.admin ||
        user.role == UserRoleType.teacher;
  }

  /// Get user's capabilities as a feature set
  static Set<String> getUserCapabilities(CanonicalUser user) {
    return _roleFeatures[user.role] ?? {};
  }

  /// Get user's accessible routes
  static Set<String> getUserRoutes(CanonicalUser user) {
    return _roleRoutes[user.role] ?? {};
  }

  /// Check if a user can perform an action on an entity
  static bool canPerformAction({
    required CanonicalUser? user,
    required String action, // 'create', 'read', 'update', 'delete'
    required String entityType, // 'evaluation', 'referral', 'child', etc.
    Map<String, dynamic>? context, // Additional context (e.g., target user, center)
  }) {
    if (user == null || user.status != 'active') return false;

    switch (entityType) {
      case 'user':
        // Only admins can manage users
        return user.role == UserRoleType.admin && action != 'delete';

      case 'evaluation':
        if (user.role == UserRoleType.teacher) {
          return ['create', 'read', 'update'].contains(action);
        }
        if (user.role == UserRoleType.admin) return true;
        return false;

      case 'referral':
        if (user.role == UserRoleType.teacher) {
          return ['create', 'read', 'update'].contains(action);
        }
        if (user.role == UserRoleType.admin) return true;
        return false;

      case 'audit-log':
        // Only admins and for read-only
        return user.role == UserRoleType.admin && action == 'read';

      default:
        return false;
    }
  }
}

/// Record of a child's assignment to a teacher
class ChildAccessRecord {
  final String childId;
  final String teacherId;
  final String centerId;
  final DateTime assignmentDate;
  final String status; // 'active', 'inactive'

  ChildAccessRecord({
    required this.childId,
    required this.teacherId,
    required this.centerId,
    required this.assignmentDate,
    required this.status,
  });
}
