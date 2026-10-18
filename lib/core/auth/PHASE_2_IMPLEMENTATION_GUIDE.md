/// Phase 2 Implementation Guide: Security and Privacy Foundation
/// 
/// This document outlines the critical security improvements made in Phase 2.

# Phase 2: Security and Privacy Foundation

## Critical Security Fix ✅

### Password Removal from UserModel
- **ISSUE**: Old UserModel stored passwords in plaintext in SQLite
- **RISK**: High - Local database compromise exposes all passwords
- **SOLUTION**: Implement CanonicalUser model (Phase 1) with:
  - NO password field
  - Firebase UID only (credentials never stored locally)
  - Metadata for profile info only

### Migration Steps:
```dart
// OLD (INSECURE - DELETE)
class UserModel {
  final String password;  // ❌ NEVER store passwords locally
  // ...
}

// NEW (SECURE - USE)
class CanonicalUser {
  final String uid;  // Firebase Auth UID only
  final String name, email, role;
  // NO password field
}
```

## Authentication Services

### 1. FirebaseAuthService (`firebase_auth_service.dart`)
**Purpose**: Handle all authentication operations securely

**Key Methods:**
- `signUp(email, password, name)` - Register new user
  - Password validated in Firebase Auth only
  - Backend Cloud Function creates CanonicalUser in Firestore
  - Password NEVER stored locally

- `signIn(email, password)` - Login
  - Firebase validates credentials
  - Returns User object with uid
  - No password caching

- `sendPasswordResetEmail(email)` - Self-service password reset
  - Email link sent by Firebase
  - Reset happens outside app

- `signOut()` - Logout with cleanup
  - Clears FCM tokens
  - Signals SessionController to wipe cache

**Security Features:**
- Delegates ALL password validation to Firebase Auth
- Never caches passwords
- Handles auth exceptions gracefully
- Email verification support

### 2. SessionController (`session_controller.dart`)
**Purpose**: Manage user session timeout and enforce auto-logout

**Features:**
- 15-minute session timeout (configurable)
- Automatic logout on inactivity
- 2-minute warning before timeout
- Activity tracking (touch, tap, gestures)
- App lifecycle awareness (pause/resume)

**Usage:**
```dart
// In main.dart, wrap app with SessionTimeoutListener
SessionTimeoutListener(
  onSessionTimeout: () => showLogoutDialog(context),
  onTimeoutWarning: () => showWarningDialog(context),
  child: MyApp(),
)
```

### 3. RoleBasedAuthorizationService (`role_based_authorization.dart`)
**Purpose**: Enforce granular access control based on roles

**Role Matrix:**
```
ADMIN: User management, centers, audit logs, settings, reports, categories
TEACHER: Evaluations, attendance, referrals, reports, activities
PARENT: Child summary, feedback, clarifications, notifications
```

**Key Methods:**
- `canAccessFeature(user, feature)` - Feature-level access
- `canAccessRoute(user, route)` - Route-level access control
- `canAccessChild(user, childId)` - Child-level access (teacher→child assignment)
- `canEditEvaluation(user, childId)` - Evaluation permission
- `canViewReferral(user, centerId)` - Referral confidentiality
- `canPerformAction(user, action, entityType)` - CRUD-level access

**Integration Points:**
- Route guards in app.dart
- Before evaluation submission
- Before referral access
- Before data export

## Firestore Security Rules (`firestore.rules`)

### Rule Hierarchy:
1. **Utility Functions** - Shared checks
   - `isAuthenticated()`
   - `isAdmin()`, `isTeacher()`, `isParent()`
   - `getUserCenterId()`

2. **Collection-Level Rules**
   - **users**: No passwords; read own + admins
   - **children**: Role-based access (admin all, teacher→center, parent→linked)
   - **evaluation_sessions**: Teacher creates, all can read per role
   - **referrals**: Confidential (teacher who created + admin only)
   - **consent_records**: Immutable audit trail (GDPR critical)
   - **attendance_events**: Teacher records, admin reads
   - **audit_logs**: Admin read-only (immutable)
   - **notifications**: Own notifications only
   - **categories**: All read, admin write
   - **eccd_domains**: Reference data (all read)

3. **Verification Rules**
   ```
   - No password field in user documents
   - Referral access limited (confidentiality)
   - Audit logs immutable (write-once, never delete)
   - Role/status changes by admin only
   ```

## Privacy and Consent Models

### 1. PrivacyNotice (Versioned)
- Stores privacy policy with version tracking
- Lists data purposes (evaluation, reporting, etc.)
- Specifies legal basis (consent, legitimate interest)
- DPO contact information
- Deprecation dates for old versions

### 2. TermsOfUse (Versioned)
- Standard terms with version history
- Active/deprecated status

### 3. ParentChildRelationship
- Documents legal relationship (parent, guardian, custodian)
- Tracks relationship type and custody status
- Verification timestamp
- Primary contact indicator

### 4. DataAccessRequest (Right to Access)
- User request for data export
- Status workflow: pending → processing → completed
- Signed URL for file download (expires)
- Format options: CSV, JSON, PDF

### 5. DataCorrectionRequest (Right to Correct)
- Request to fix incorrect personal data
- Field-level corrections with evidence
- Approval workflow for sensitive fields
- Audit trail of changes

### 6. DataDeletionRequest (Right to be Forgotten)
- Request to delete personal data
- Reason and notes
- Admin approval workflow
- Disposal method tracking

### 7. RetentionDisposalRecord
- Audit trail of data deletion
- Retention period enforcement
- Disposal method (permanent delete, archive, anonymize)
- Count of records disposed

## Implementation Checklist

### Phase 2 Deliverables
- [x] Remove password from UserModel
- [x] Create CanonicalUser (Firebase-only credentials)
- [x] Implement FirebaseAuthService
- [x] Implement SessionController with timeout
- [x] Implement RoleBasedAuthorizationService
- [x] Create Firestore security rules
- [x] Create privacy/consent models
- [ ] Implement Cloud Functions for user creation
- [ ] Add route guards in app.dart
- [ ] Update login/signup UI to use new auth service
- [ ] Add consent flow UI
- [ ] Test all security rules (Firebase Emulator)
- [ ] Deploy rules to Firebase

### Phase 2 Approval Gate Requirements
Before Phase 3, verify:
- [ ] No password fields in any model
- [ ] All authentication uses Firebase only
- [ ] Session timeout working correctly
- [ ] Role-based access enforced
- [ ] Firestore rules tested and approved
- [ ] Consent records immutable
- [ ] Audit logging in place

## Backward Compatibility

During transition (Phase 2 → Phase 3):
1. OLD UserModel marked as @Deprecated
2. New code uses CanonicalUser
3. Login flow migrated to FirebaseAuthService
4. Old records can be read, but not created
5. By Phase 4, old models archived

## Testing Strategy

### Unit Tests:
- Role-based permission matrix
- Auth exception handling
- Session timeout logic

### Integration Tests:
- Login/logout flow with Firestore
- Role-based route access
- Consent record creation

### Firebase Emulator Tests:
- Firestore rule validation
- Collection-level access
- Subcollection permissions

### Security Tests:
- No passwords in Firestore
- No password in logs
- Role escalation prevention
- Unauthorized access blocked

## Deployment Order

1. Deploy Firestore rules (test first!)
2. Deploy privacy models to Firestore
3. Create admin user via Cloud Function
4. Update mobile app code
5. Update web app code
6. Gradual migration of existing users
7. Verify all roles work correctly
8. Archive old UserModel after confirmation

## References

- Firebase Auth Best Practices: https://firebase.google.com/docs/auth/best-practices
- Firestore Security Rules: https://firebase.google.com/docs/firestore/security/start
- GDPR Compliance: https://gdpr.eu/
- Session Management: https://owasp.org/www-community/attacks/Session_fixation
