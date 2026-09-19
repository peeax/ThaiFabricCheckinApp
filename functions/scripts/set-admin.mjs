import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

initializeApp({ credential: applicationDefault() });

const uid = process.env.ADMIN_UID;
const email = process.env.ADMIN_EMAIL;
if (!uid && !email) {
  throw new Error("Set ADMIN_UID or ADMIN_EMAIL before running this script");
}

const auth = getAuth();
const user = uid ? await auth.getUser(uid) : await auth.getUserByEmail(email);
await auth.setCustomUserClaims(user.uid, {
  ...(user.customClaims ?? {}),
  admin: true,
});
console.log(`Admin claim granted to ${user.uid}. The user must sign in again.`);
