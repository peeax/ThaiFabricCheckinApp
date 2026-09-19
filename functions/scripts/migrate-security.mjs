import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const projectId = process.env.FIREBASE_PROJECT_ID ?? "thai-fabric-check-in-app";
initializeApp({ credential: applicationDefault(), projectId });

const writeMode = process.argv.includes("--write");
const db = getFirestore();
const users = await db.collection("users").get();
const admins = users.docs.filter((document) => document.get("isAdmin") === true);

console.log(
  JSON.stringify(
    {
      projectId,
      dryRun: !writeMode,
      users: users.size,
      leaderboardProfiles: users.size,
      adminClaims: admins.length,
    },
    null,
    2,
  ),
);

if (!writeMode) process.exit(0);

for (let offset = 0; offset < users.docs.length; offset += 400) {
  const batch = db.batch();
  for (const document of users.docs.slice(offset, offset + 400)) {
    const data = document.data();
    batch.set(
      db.collection("leaderboardProfiles").doc(document.id),
      {
        username: String(data.username ?? "ไม่ระบุชื่อ"),
        stampCount: Math.max(0, Number(data.stampCount ?? 0)),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  await batch.commit();
}

const auth = getAuth();
for (const document of admins) {
  const user = await auth.getUser(document.id);
  await auth.setCustomUserClaims(user.uid, {
    ...(user.customClaims ?? {}),
    admin: true,
  });
}

console.log("Security migration completed. Admin users must sign in again.");
