import { initializeApp } from 'firebase-admin/app';
import { getAuth, UserRecord } from 'firebase-admin/auth';

initializeApp();

const applyChanges = process.argv.includes('--apply');

async function backfill(): Promise<void> {
  let pageToken: string | undefined;
  let scanned = 0;
  let changed = 0;

  do {
    const page = await getAuth().listUsers(1000, pageToken);
    for (const user of page.users) {
      scanned += 1;
      const claims = { ...(user.customClaims ?? {}) };

      if (claims.role === 'authenticated') {
        continue;
      }

      changed += 1;
      console.log(`${applyChanges ? 'Updating' : 'Would update'} ${describe(user)}`);

      if (applyChanges) {
        await getAuth().setCustomUserClaims(user.uid, {
          ...claims,
          role: 'authenticated',
        });
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);

  console.log(`${applyChanges ? 'Applied' : 'Planned'} ${changed} changes across ${scanned} users.`);
  if (!applyChanges) {
    console.log('Dry run only. Re-run with --apply after reviewing the list.');
  }
}

function describe(user: UserRecord): string {
  return `${user.uid}${user.email ? ` (${user.email})` : ''}`;
}

backfill().catch((error: unknown) => {
  console.error('Claim backfill failed:', error);
  process.exitCode = 1;
});
