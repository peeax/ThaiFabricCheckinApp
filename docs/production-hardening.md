# Production hardening deployment

The security migration is intentionally deployed in stages. Deploying the new
Firestore rules before the callable functions would disable check-in for the
currently released client.

## One-time console setup

1. Enable billing for `thai-fabric-check-in-app`.
2. Create a server-restricted Google Geocoding API key.
3. Rotate the exposed TAT API key. Do not reuse the key from Git history.
4. Register Android and iOS apps in Firebase App Check.
5. Use Play Integrity for Android and App Attest with DeviceCheck fallback for
   Apple platforms.
6. Register the debug App Check token printed by a debug build before testing.

## Store backend secrets

Run these commands from the repository root and enter the newly issued values
only when Firebase prompts for them:

```powershell
firebase functions:secrets:set GOOGLE_GEOCODING_API_KEY
firebase functions:secrets:set TAT_API_KEY
```

Never place either value in `.env`, source control, CI logs, or Flutter assets.

## Deployment order

```powershell
npm --prefix functions ci
npm --prefix functions run build
firebase deploy --only functions
firebase deploy --only firestore:indexes
firebase deploy --only firestore:rules
```

After deploying the functions, test check-in and attractions with a debug App
Check token before deploying the restrictive rules. The security migration
script is idempotent and can be checked again with:

```powershell
$env:FIREBASE_PROJECT_ID="thai-fabric-check-in-app"
npm --prefix functions run migrate-security
```

## Verification

1. A normal user cannot read another `/users/{uid}` document.
2. A normal user can read `/leaderboardProfiles` but cannot change a score.
3. Direct writes to `/users/{uid}/checkins` are denied.
4. `checkInProvince` rejects missing Auth, missing App Check, mocked locations,
   inaccurate coordinates, duplicate provinces, and mismatched provinces.
5. Admin screens work after a forced token refresh.
6. `fetchAttractions` returns cached data without exposing the TAT key.

## Key history

`.env` is no longer tracked, but old commits still contain the retired keys.
After all collaborators have synchronized, purge `.env` from Git history with
`git filter-repo` and force-push during a coordinated maintenance window.
