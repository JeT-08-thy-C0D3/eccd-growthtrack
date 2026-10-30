import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import * as functions from 'firebase-functions/v1';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { createHash } from 'node:crypto';
import nodemailer from 'nodemailer';

initializeApp();

/**
 * Gives every newly-created Firebase user the Supabase-required role claim.
 *
 * This is deliberately separate from the app role stored in Firestore. The
 * Firestore role remains admin/teacher/parent; this claim only maps the
 * Firebase identity to Supabase's authenticated Postgres role.
 */
export const setSupabaseAuthenticatedClaim = functions.auth.user().onCreate(async (user) => {
  const existingClaims = user.customClaims ?? {};

  if (existingClaims.role === 'authenticated') {
    return;
  }

  await getAuth().setCustomUserClaims(user.uid, {
    ...existingClaims,
    role: 'authenticated',
  });
});

const smtpUser = defineSecret('SMTP_USER');
const smtpPass = defineSecret('SMTP_PASS');
const customResetPage = 'https://eccd-growthtrack.web.app/reset-password';

// One-time replacement for the legacy admin profile whose Firestore document
// was created under a different UID than its Firebase Authentication account.
// The callable is locked to the intended, verified Gmail identity and becomes
// a no-op once the replacement profile exists.
const legacyAdminUid = 'A4OPp3bV7ffrtLXqLyqFlx2pS503';
const replacementAdminUid = 'sj8Fqo4wd3OnE0Z0Uhmv6bV3WQs2';
const replacementAdminEmail = 'johnexiquel.idian@gmail.com';

export const bootstrapReplacementAdmin = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    const callerEmail = String(request.auth?.token.email ?? '').toLowerCase();
    if (
      !request.auth ||
      request.auth.uid !== replacementAdminUid ||
      callerEmail !== replacementAdminEmail
    ) {
      throw new HttpsError('permission-denied', 'This migration is not available for this account.');
    }

    const firestore = getFirestore();
    const replacementRef = firestore.collection('users').doc(replacementAdminUid);
    const replacementProfile = await replacementRef.get();
    if (replacementProfile.exists) {
      return { migrated: false, reason: 'already-migrated' };
    }

    const legacyRef = firestore.collection('users').doc(legacyAdminUid);
    const legacyProfile = await legacyRef.get();
    const legacyData = legacyProfile.data();
    if (
      !legacyProfile.exists ||
      legacyData?.role !== 'admin' ||
      String(legacyData.email ?? '').toLowerCase() !== replacementAdminEmail
    ) {
      throw new HttpsError('failed-precondition', 'The legacy administrator profile could not be verified.');
    }

    // Credentials and device tokens must never be copied from another UID.
    const { password, uid, fcm_token, ...safeProfile } = legacyData;
    void password;
    void uid;
    void fcm_token;

    const now = new Date().toISOString();
    const batch = firestore.batch();
    batch.set(replacementRef, {
      ...safeProfile,
      uid: replacementAdminUid,
      email: replacementAdminEmail,
      role: 'admin',
      status: 'active',
      is_synced: true,
      migrated_from_uid: legacyAdminUid,
      updated_at: now,
    });
    // The profile move is atomic: the replacement exists before the legacy
    // profile disappears, so permissions do not have a gap.
    batch.delete(legacyRef);
    await batch.commit();

    const auth = getAuth();
    const user = await auth.getUser(replacementAdminUid);
    await auth.setCustomUserClaims(replacementAdminUid, {
      ...(user.customClaims ?? {}),
      role: 'authenticated',
    });

    return { migrated: true, uid: replacementAdminUid };
  },
);

/// Sends ECCD's own reset email. Firebase still creates the one-time code,
/// while the recipient sees the branded Verify It's Me page instead of the
/// locked Firebase template.
export const sendBrandedPasswordReset = onCall(
  {
    region: 'asia-southeast1',
    secrets: [smtpUser, smtpPass],
  },
  async (request) => {
    const email = String(request.data?.email ?? '').trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError('invalid-argument', 'Enter a valid email address.');
    }

    const rateLimitId = createHash('sha256').update(email).digest('hex');
    const rateLimitRef = getFirestore()
      .collection('_password_reset_rate_limits')
      .doc(rateLimitId);
    const now = Date.now();
    await getFirestore().runTransaction(async (transaction) => {
      const current = await transaction.get(rateLimitRef);
      const lastRequestedAt = Number(current.data()?.lastRequestedAt ?? 0);
      if (now - lastRequestedAt < 60000) {
        throw new HttpsError(
          'resource-exhausted',
          'Please wait 60 seconds before requesting another reset email.',
        );
      }
      transaction.set(rateLimitRef, { lastRequestedAt: now }, { merge: true });
    });

    try {
      await getAuth().getUserByEmail(email);
    } catch (_) {
      // Keep account existence private.
      return { sent: true };
    }

    const firebaseUrl = new URL(
      await getAuth().generatePasswordResetLink(email),
    );
    const brandedUrl = new URL(customResetPage);
    firebaseUrl.searchParams.forEach((value, key) => {
      brandedUrl.searchParams.set(key, value);
    });

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: { user: smtpUser.value(), pass: smtpPass.value() },
    });
    await transporter.sendMail({
      from: `ECCD GrowthTrack <${smtpUser.value()}>`,
      to: email,
      subject: 'Verify your password reset | ECCD GrowthTrack',
      text: `Verify it's you and create a new password: ${brandedUrl.toString()}`,
      html: `
        <main style="max-width:560px;margin:0 auto;padding:32px;font-family:Arial,sans-serif;color:#263238">
          <h1 style="color:#07537a">Verify it’s you</h1>
          <p>We received a request to reset your ECCD GrowthTrack password.</p>
          <p>Use the secure button below to verify your request and create a new password.</p>
          <p style="margin:28px 0"><a href="${brandedUrl.toString()}" style="display:inline-block;padding:14px 22px;background:#2f9d5d;color:#fff;text-decoration:none;border-radius:10px;font-weight:700">Verify it’s me</a></p>
          <p style="font-size:13px;color:#64747a">This link expires automatically. If you did not request this, you can safely ignore this email.</p>
        </main>
      `,
    });
    return { sent: true };
  },
);

/**
 * Changes a managed user's sign-in email and its matching Firestore profile.
 * Only an authenticated ECCD administrator can invoke this callable.
 */
export const adminUpdateUserEmail = onCall(
  { region: 'asia-southeast1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Please sign in as an administrator.');
    }

    const oldEmail = String(request.data?.oldEmail ?? '').trim().toLowerCase();
    const newEmail = String(request.data?.newEmail ?? '').trim().toLowerCase();
    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailPattern.test(oldEmail) || !emailPattern.test(newEmail)) {
      throw new HttpsError('invalid-argument', 'Both email addresses must be valid.');
    }

    const firestore = getFirestore();
    const callerProfile = await firestore.collection('users').doc(request.auth.uid).get();
    if (callerProfile.data()?.role !== 'admin') {
      throw new HttpsError('permission-denied', 'Only administrators can change account emails.');
    }

    const auth = getAuth();
    const target = await auth.getUserByEmail(oldEmail).catch(() => null);
    if (!target) {
      throw new HttpsError('not-found', 'The account to update was not found.');
    }

    const targetProfileRef = firestore.collection('users').doc(target.uid);
    const targetProfile = await targetProfileRef.get();
    if (targetProfile.data()?.role !== 'teacher') {
      throw new HttpsError('failed-precondition', 'This action is only available for teacher accounts.');
    }

    const existingNewEmail = await auth.getUserByEmail(newEmail).catch(() => null);
    if (existingNewEmail && existingNewEmail.uid !== target.uid) {
      throw new HttpsError('already-exists', 'That email address is already in use.');
    }

    if (oldEmail !== newEmail) {
      await auth.updateUser(target.uid, { email: newEmail, emailVerified: false });
    }
    await targetProfileRef.set(
      {
        email: newEmail,
        updated_at: new Date().toISOString(),
        is_synced: true,
      },
      { merge: true },
    );

    return { uid: target.uid, email: newEmail };
  },
);
