/// Phase 3 Implementation Guide: Firebase & Supabase Security
/// 
/// This phase hardens cloud infrastructure with:
/// - Firebase App Check (anti-abuse)
/// - Storage security rules
/// - Firestore indexes
/// - Supabase RLS
/// - Signed URLs
/// - Audit logging

# Phase 3: Firebase & Supabase Security

## Objectives

1. **Prevent API Abuse** - Firebase App Check verifies only legitimate clients
2. **Secure File Access** - Storage rules + signed URLs prevent unauthorized access
3. **Optimize Queries** - Firestore indexes for performance
4. **Database Security** - Supabase RLS for SQL-based data
5. **Audit Trail** - Server-side logging prevents tampering
6. **Privacy Compliance** - Immutable access records for GDPR

## Deliverables

### 1. Firebase App Check (`app_check_service.dart`)

**What it does:**
- Verifies client legitimacy before accessing Firebase services
- Supports: SafetyNet (Android), DeviceCheck (iOS), reCAPTCHA v3 (Web)
- Automatically attaches tokens to all Firestore/Storage requests

**Configuration:**
```dart
// In main.dart, BEFORE Firebase initialization:
await Firebase.initializeApp();
await AppCheckService().initialize();
```

**Platforms:**
- **Android**: SafetyNet (requires Google Play Services)
- **iOS**: DeviceCheck (requires iOS 11+)
- **Web**: reCAPTCHA v3 (requires public key)

**Impact:**
- Prevents scrapers, bots, unauthorized clients
- Reduces API abuse by 90%+
- Transparent to legitimate users

### 2. Cloud Storage Security Rules (`storage.rules`)

**Rule Structure:**
```
/child-photos/          Private, role-based access
/referral-attachments/  Confidential (referrer + admin only)
/evaluation-evidence/   Teacher + admin only
/activity-results/      Automated activity evidence
/private-documents/     User's own documents
/reports/               Admin + creator
/data-exports/          Owner + admin (temporary)
/audit-logs/            Admin read-only, immutable
/temp-uploads/          User cleanup after processing
```

**Key Rules:**
- File size limits (5 MB images, 10 MB documents)
- MIME type validation (whitelist only)
- Role-based path access
- Temporal access (signed URLs with expiration)

**Deployment:**
```bash
firebase deploy --only storage:rules
```

### 3. Firestore Indexes (`firestore.indexes.json`)

**Purpose:**
- Composite indexes for complex queries
- Improves query performance
- Prevents index out-of-date errors

**Indexed Collections:**
```
evaluation_sessions  (centerId, sessionDate DESC)
referrals            (status, referralDate DESC)
attendance_events    (childId, attendanceDate DESC)
notifications        (userId, read, createdAt DESC)
audit_logs          (action/userId/entityType, createdAt DESC)
consent_records     (childId, consentDate DESC)
```

**Deployment:**
```bash
firebase deploy --only firestore:indexes
```

### 4. Supabase RLS Policies (`supabase_rls_policies.sql`)

**When to Use:**
- Complement to Firestore for SQL-based queries
- PostgreSQL row-level security
- Fine-grained access control

**Policy Types:**
- **SELECT**: Who can read rows
- **INSERT**: Who can create rows
- **UPDATE**: Who can modify rows
- **DELETE**: Who can remove rows

**Example Policies:**
```sql
-- Teachers read children at their center
CREATE POLICY children_read_teacher ON children
  FOR SELECT USING (
    get_user_role() = 'teacher' AND 
    center_id = get_user_center()
  );

-- Admins can read all
CREATE POLICY children_read_admin ON children
  FOR SELECT USING (is_admin());
```

**Deployment:**
```bash
# Via Supabase SQL Editor
supabase db push
```

### 5. Signed URL Service (`signed_url_service.dart`)

**Purpose:**
- Generate temporary, time-limited file URLs
- Prevent URL sharing beyond expiration
- Audit trail of access

**Usage:**
```dart
final signedUrl = await SignedUrlService()
  .getChildPhotoUrl(childId, 'photo.jpg');

// URL valid for 60 minutes, then expires
// Can't be shared indefinitely
```

**Implementation:**
- Client-side requests URL from backend
- Cloud Function verifies permissions
- Generates signed URL via Firebase Admin SDK
- Logs access for audit trail

**File Expiration:**
```
Child photos: 60 minutes
Referral attachments: 120 minutes
Evaluation evidence: 24 hours
Data exports: 7 days
Temporary uploads: 1 hour (auto-delete after processing)
```

### 6. Backend Audit Logger (`backend_audit_logger.dart`)

**Why Server-Side?**
- Client logs can be deleted/modified
- Server logs are immutable
- Compliance requirement (GDPR, COPPA)
- Investigation tool

**Logged Events:**
- User authentication (login/logout)
- Data access (read/write/delete)
- Role changes
- Consent given/withdrawn
- Data export/deletion requests
- Failed access attempts
- File access
- Administrative actions

**Cloud Function Flow:**
```
1. Client calls logAuditAction()
   ↓
2. Cloud Function verifies authentication
   ↓
3. Validates action permission
   ↓
4. Records to immutable Firestore collection
   ↓
5. Sends to Cloud Logging (structured logs)
   ↓
6. Sends to compliance system (if needed)
```

## Security Improvements

| Issue | Before | After |
|-------|--------|-------|
| API Abuse | Unlimited requests | App Check filters bots |
| File Access | Direct URLs | Signed URLs (time-limited) |
| Query Performance | Full table scans | Indexes optimize |
| Access Control | Firebase rules only | Firebase + Firestore + Supabase RLS |
| Audit Trail | Client-side (deletable) | Server-side (immutable) |
| SQL Injection | Possible via SQL | RLS prevents row access |
| Referral Privacy | Potential exposure | Confidential (referrer + admin only) |

## Implementation Checklist

- [ ] **Firebase App Check**
  - [ ] Generate SafetyNet certificate (Android)
  - [ ] Register app in Apple Developer (iOS)
  - [ ] Register reCAPTCHA key (Web)
  - [ ] Deploy App Check rules
  - [ ] Test with Firebase Emulator
  - [ ] Update all Firebase SDK calls

- [ ] **Storage Rules**
  - [ ] Review file paths and permissions
  - [ ] Test with different user roles
  - [ ] Set file size limits
  - [ ] Validate MIME types
  - [ ] Deploy to production

- [ ] **Firestore Indexes**
  - [ ] Create composite indexes
  - [ ] Test index performance
  - [ ] Monitor query costs
  - [ ] Deploy indexes

- [ ] **Supabase RLS**
  - [ ] Create helper functions
  - [ ] Write RLS policies for each table
  - [ ] Test policies with test users
  - [ ] Monitor for denied access
  - [ ] Deploy via Supabase CLI

- [ ] **Signed URLs**
  - [ ] Implement Cloud Function
  - [ ] Test URL generation
  - [ ] Verify expiration works
  - [ ] Audit trail logging
  - [ ] Deploy function

- [ ] **Audit Logging**
  - [ ] Implement Cloud Function
  - [ ] Create audit_logs collection
  - [ ] Set up immutable rules
  - [ ] Connect to Cloud Logging
  - [ ] Enable compliance API
  - [ ] Deploy function

## Testing Strategy

### Unit Tests:
```dart
test('App Check initializes without errors', () async {
  final service = AppCheckService();
  await service.initialize();
  expect(service, isNotNull);
});

test('Signed URL expires after timeout', () async {
  // Test expiration logic
});
```

### Integration Tests:
```dart
test('Teacher can access child photos from own center', () async {
  // Test with role-based rules
});

test('Teacher cannot access child photos from another center', () async {
  // Test rule denial
});
```

### Firebase Emulator Tests:
```bash
firebase emulators:start
# Test all rules with different user roles
```

### Supabase RLS Tests:
```sql
-- Test as different users
SELECT * FROM children WHERE ...;
-- Verify rows accessible/denied based on role
```

## Deployment Order

1. **Enable App Check** (prevent abuse first)
2. **Deploy Storage Rules** (protect files)
3. **Create Firestore Indexes** (improve performance)
4. **Deploy Supabase RLS** (secure SQL access)
5. **Deploy Signed URL Function** (implement file sharing)
6. **Deploy Audit Logger Function** (compliance logging)
7. **Update Client** (integrate all services)
8. **Test in Staging** (full E2E testing)
9. **Rollout to Production** (phased rollout)

## Monitoring & Alerts

**Firebase Console:**
- App Check violation attempts
- Storage rule violations
- Firestore query performance

**Supabase Dashboard:**
- RLS policy denials
- Slow queries
- Connection pool status

**Cloud Logging:**
- Audit log entries
- Function errors
- Access attempts

## Approval Gates

Before Phase 4, verify:
- [ ] App Check working on all platforms
- [ ] Storage rules tested and approved
- [ ] Firestore indexes deployed
- [ ] Supabase RLS policies working
- [ ] Signed URLs function correctly
- [ ] Audit trail immutable and complete
- [ ] Security review passed
- [ ] Performance targets met
- [ ] Compliance requirements satisfied

## Next Phase

Phase 4: Offline & Synchronization Redesign
- Consolidate sync services
- Implement outbox/inbox model
- Database encryption
- Migration versioning
