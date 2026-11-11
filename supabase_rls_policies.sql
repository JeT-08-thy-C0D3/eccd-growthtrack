-- Supabase Row-Level Security (RLS) Policies for ECCD GrowthTrack
--
-- These policies complement Firebase for applications that use both platforms.
-- Supabase provides PostgreSQL with built-in RLS for SQL-based access patterns.
--
-- Prerequisites:
-- 1. Enable RLS on all tables
-- 2. Create users and auth schema
-- 3. Create extension for jwt

-- ============================================================================
-- ENABLE RLS (Execute for each table)
-- ============================================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE children ENABLE ROW LEVEL SECURITY;
ALTER TABLE child_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE evaluation_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE evaluation_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE consent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Get current user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
  SELECT role FROM users WHERE uid = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER;

-- Get current user's center ID
CREATE OR REPLACE FUNCTION get_user_center()
RETURNS TEXT AS $$
  SELECT center_id FROM users WHERE uid = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER;

-- Check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT role = 'admin' FROM users WHERE uid = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER;

-- Check if user is teacher
CREATE OR REPLACE FUNCTION is_teacher()
RETURNS BOOLEAN AS $$
  SELECT role = 'teacher' FROM users WHERE uid = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER;

-- Check if user is parent
CREATE OR REPLACE FUNCTION is_parent()
RETURNS BOOLEAN AS $$
  SELECT role = 'parent' FROM users WHERE uid = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER;

-- Check if teacher is assigned to child
CREATE OR REPLACE FUNCTION is_assigned_to_child(child_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS(
    SELECT 1 FROM child_assignments
    WHERE teacher_id = auth.uid()
      AND child_id = $1
      AND status = 'active'
  )
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================================================
-- USERS TABLE POLICIES
-- ============================================================================

-- Users can read their own profile
CREATE POLICY users_read_own ON users
  FOR SELECT USING (uid = auth.uid());

-- Admins can read all users
CREATE POLICY users_read_admin ON users
  FOR SELECT USING (is_admin());

-- Users can update their own profile (except role/status)
CREATE POLICY users_update_own ON users
  FOR UPDATE USING (uid = auth.uid())
  WITH CHECK (
    uid = auth.uid() AND
    role = (SELECT role FROM users WHERE uid = auth.uid()) AND
    status = (SELECT status FROM users WHERE uid = auth.uid())
  );

-- Admins can update all user records
CREATE POLICY users_update_admin ON users
  FOR UPDATE USING (is_admin());

-- ============================================================================
-- CHILDREN TABLE POLICIES
-- ============================================================================

-- Teachers can read children at their center
CREATE POLICY children_read_teacher ON children
  FOR SELECT USING (
    is_teacher() AND center_id = get_user_center()
  );

-- Admins can read all children
CREATE POLICY children_read_admin ON children
  FOR SELECT USING (is_admin());

-- Parents can read their linked children (verified via consent)
CREATE POLICY children_read_parent ON children
  FOR SELECT USING (
    is_parent() AND EXISTS(
      SELECT 1 FROM consent_records
      WHERE child_id = children.id
        AND parent_id = auth.uid()
        AND is_given = true
        AND withdrawal_date IS NULL
    )
  );

-- Admins can insert children
CREATE POLICY children_create_admin ON children
  FOR INSERT WITH CHECK (is_admin());

-- Teachers and admins can update children
CREATE POLICY children_update ON children
  FOR UPDATE USING (is_admin() OR is_teacher());

-- ============================================================================
-- EVALUATION SESSIONS POLICIES
-- ============================================================================

-- Teachers can read evaluations for their center
CREATE POLICY eval_sessions_read_teacher ON evaluation_sessions
  FOR SELECT USING (
    is_teacher() AND center_id = get_user_center()
  );

-- Parents can read evaluations for their children
CREATE POLICY eval_sessions_read_parent ON evaluation_sessions
  FOR SELECT USING (
    is_parent() AND EXISTS(
      SELECT 1 FROM consent_records
      WHERE child_id = evaluation_sessions.child_id
        AND parent_id = auth.uid()
    )
  );

-- Admins can read all
CREATE POLICY eval_sessions_read_admin ON evaluation_sessions
  FOR SELECT USING (is_admin());

-- Teachers can create evaluations
CREATE POLICY eval_sessions_create_teacher ON evaluation_sessions
  FOR INSERT WITH CHECK (
    is_teacher() AND
    evaluator_id = auth.uid() AND
    center_id = get_user_center() AND
    is_assigned_to_child(child_id)
  );

-- Teachers can update own evaluations
CREATE POLICY eval_sessions_update_teacher ON evaluation_sessions
  FOR UPDATE USING (
    is_teacher() AND evaluator_id = auth.uid()
  );

-- Admins can approve evaluations
CREATE POLICY eval_sessions_update_admin ON evaluation_sessions
  FOR UPDATE USING (is_admin());

-- ============================================================================
-- REFERRALS POLICIES (CONFIDENTIAL)
-- ============================================================================

-- Only referring teacher and admins can read referrals
CREATE POLICY referrals_read ON referrals
  FOR SELECT USING (
    is_admin() OR
    (is_teacher() AND referrer_id = auth.uid())
  );

-- Teachers can create referrals
CREATE POLICY referrals_create ON referrals
  FOR INSERT WITH CHECK (
    is_teacher() AND
    referrer_id = auth.uid()
  );

-- Teachers can update own referrals
CREATE POLICY referrals_update ON referrals
  FOR UPDATE USING (
    is_teacher() AND referrer_id = auth.uid()
  );

-- ============================================================================
-- CONSENT RECORDS POLICIES (IMMUTABLE AUDIT TRAIL)
-- ============================================================================

-- Parents can read their own consent records
CREATE POLICY consent_read_parent ON consent_records
  FOR SELECT USING (parent_id = auth.uid());

-- Admins can read all
CREATE POLICY consent_read_admin ON consent_records
  FOR SELECT USING (is_admin());

-- Consent records created by backend only
CREATE POLICY consent_insert_disabled ON consent_records
  FOR INSERT WITH CHECK (false);

-- Consent records never updated (immutable)
CREATE POLICY consent_update_disabled ON consent_records
  FOR UPDATE WITH CHECK (false);

-- ============================================================================
-- ATTENDANCE EVENTS POLICIES
-- ============================================================================

-- Teachers can read attendance for their center
CREATE POLICY attendance_read_teacher ON attendance_events
  FOR SELECT USING (
    is_teacher() AND center_id = get_user_center()
  );

-- Admins can read all
CREATE POLICY attendance_read_admin ON attendance_events
  FOR SELECT USING (is_admin());

-- Teachers can create attendance events
CREATE POLICY attendance_create ON attendance_events
  FOR INSERT WITH CHECK (
    is_teacher() AND center_id = get_user_center()
  );

-- ============================================================================
-- AUDIT LOGS POLICIES (READ-ONLY, IMMUTABLE)
-- ============================================================================

-- Admins can read audit logs
CREATE POLICY audit_logs_read ON audit_logs
  FOR SELECT USING (is_admin());

-- Never allow insert/update/delete from client (backend only)
CREATE POLICY audit_logs_insert_disabled ON audit_logs
  FOR INSERT WITH CHECK (false);

CREATE POLICY audit_logs_update_disabled ON audit_logs
  FOR UPDATE WITH CHECK (false);

CREATE POLICY audit_logs_delete_disabled ON audit_logs
  FOR DELETE USING (false);

-- ============================================================================
-- NOTIFICATIONS POLICIES
-- ============================================================================

-- Users can read their own notifications
CREATE POLICY notifications_read ON notifications
  FOR SELECT USING (user_id = auth.uid());

-- Users can update their own notifications (mark as read)
CREATE POLICY notifications_update ON notifications
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Notifications created by backend only
CREATE POLICY notifications_insert_disabled ON notifications
  FOR INSERT WITH CHECK (false);

-- ============================================================================
-- DEPLOYMENT NOTES
-- ============================================================================
--
-- 1. Create Supabase project
-- 2. Enable RLS on all tables
-- 3. Apply these policies via SQL editor
-- 4. Test policies with different user roles
-- 5. Enable audit logging (Supabase dashboard)
-- 6. Monitor for policy violations
-- 7. Use pgBouncer for connection pooling
-- 8. Set up automated backups

-- ============================================================================
-- PRIVATE FILE STORAGE (required for activity proof uploads)
-- ============================================================================
-- Run this block once in the Supabase SQL Editor. The Flutter app uses one
-- private bucket with fixed path prefixes for child photos, activity proof,
-- referrals, and generated reports.

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'eccd-files',
  'eccd-files',
  false,
  41943040,
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/webp',
    'video/mp4',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Firebase UIDs are not UUIDs, so do not call auth.uid() in these policies.
-- Instead, require a verified Firebase JWT subject. Files remain private; the
-- app receives a short-lived signed URL only after Firestore has already
-- checked that the user can access the related record.
DROP POLICY IF EXISTS eccd_files_read_authenticated ON storage.objects;
DROP POLICY IF EXISTS eccd_files_insert_authenticated ON storage.objects;
DROP POLICY IF EXISTS eccd_files_update_authenticated ON storage.objects;
DROP POLICY IF EXISTS eccd_files_read_verified ON storage.objects;
DROP POLICY IF EXISTS eccd_files_insert_verified ON storage.objects;
DROP POLICY IF EXISTS eccd_files_update_verified ON storage.objects;
DROP POLICY IF EXISTS eccd_files_read_firebase ON storage.objects;
DROP POLICY IF EXISTS eccd_files_insert_firebase ON storage.objects;
DROP POLICY IF EXISTS eccd_files_update_firebase ON storage.objects;

CREATE POLICY eccd_files_read_firebase
ON storage.objects FOR SELECT TO public
USING (
  bucket_id = 'eccd-files' AND
  COALESCE(auth.jwt() ->> 'sub', '') <> ''
);

CREATE POLICY eccd_files_insert_firebase
ON storage.objects FOR INSERT TO public
WITH CHECK (
  bucket_id = 'eccd-files' AND
  COALESCE(auth.jwt() ->> 'sub', '') <> '' AND
  (storage.foldername(name))[1] IN (
    'child-profile-photos',
    'home-activity-evidence',
    'referral-attachments',
    'pdf-reports'
  )
);

CREATE POLICY eccd_files_update_firebase
ON storage.objects FOR UPDATE TO public
USING (
  bucket_id = 'eccd-files' AND
  COALESCE(auth.jwt() ->> 'sub', '') <> ''
)
WITH CHECK (
  bucket_id = 'eccd-files' AND
  COALESCE(auth.jwt() ->> 'sub', '') <> ''
);
