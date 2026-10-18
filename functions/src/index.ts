import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import * as functions from 'firebase-functions/v1';

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
