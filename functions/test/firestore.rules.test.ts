import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import { afterAll, afterEach, beforeAll, describe, it } from "vitest";

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-aewmai",
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

afterEach(async () => testEnv.clearFirestore());
afterAll(async () => testEnv.cleanup());

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users/alice"), {
      username: "Alice",
      birthday: new Date("2000-01-01"),
      stampCount: 1,
      isAdmin: false,
      createdAt: new Date(),
    });
    await setDoc(doc(db, "users/bob"), {
      username: "Bob",
      birthday: new Date("2001-01-01"),
      stampCount: 2,
      isAdmin: false,
      createdAt: new Date(),
    });
    await setDoc(doc(db, "leaderboardProfiles/bob"), {
      username: "Bob",
      stampCount: 2,
      updatedAt: new Date(),
    });
    await setDoc(doc(db, "eventSources/tat-monthly-calendar"), {
      name: "TAT monthly calendar",
      enabled: true,
      updatedAt: new Date(),
    });
    await setDoc(doc(db, "importRuns/run-1"), {
      status: "success",
      startedAt: new Date(),
    });
  });
}

describe("private profiles", () => {
  it("allows owners but denies other users", async () => {
    await seed();
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(getDoc(doc(alice, "users/alice")));
    await assertFails(getDoc(doc(alice, "users/bob")));
  });

  it("denies score and role escalation", async () => {
    await seed();
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(updateDoc(doc(alice, "users/alice"), { stampCount: 999 }));
    await assertFails(updateDoc(doc(alice, "users/alice"), { isAdmin: true }));
  });

  it("allows safe profile fields", async () => {
    await seed();
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(alice, "users/alice"), {
        username: "Alice Updated",
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

describe("server-owned data", () => {
  it("denies direct check-in writes", async () => {
    await seed();
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(alice, "users/alice/checkins/เชียงใหม่"), {
        at: serverTimestamp(),
      }),
    );
  });

  it("exposes only leaderboard documents", async () => {
    await seed();
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(getDoc(doc(alice, "leaderboardProfiles/bob")));
    await assertFails(
      updateDoc(doc(alice, "leaderboardProfiles/bob"), { stampCount: 999 }),
    );
  });
});

describe("admin claims", () => {
  it("allows claimed admins to manage events", async () => {
    const admin = testEnv
      .authenticatedContext("admin-user", { admin: true })
      .firestore();
    await assertSucceeds(
      setDoc(doc(admin, "events/event-1"), {
        title: "งานทดสอบระบบ",
        status: "draft",
      }),
    );
  });

  it("denies ordinary users", async () => {
    const user = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(user, "events/event-1"), {
        title: "งานทดสอบระบบ",
        status: "draft",
      }),
    );
  });

  it("allows admins to monitor imports and toggle only source availability", async () => {
    await seed();
    const admin = testEnv
      .authenticatedContext("admin-user", { admin: true })
      .firestore();
    await assertSucceeds(getDoc(doc(admin, "importRuns/run-1")));
    await assertSucceeds(getDoc(doc(admin, "eventSources/tat-monthly-calendar")));
    await assertSucceeds(
      updateDoc(doc(admin, "eventSources/tat-monthly-calendar"), {
        enabled: false,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(admin, "eventSources/tat-monthly-calendar"), {
        consecutiveFailures: 0,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it("denies importer operations to ordinary users", async () => {
    await seed();
    const user = testEnv.authenticatedContext("alice").firestore();
    await assertFails(getDoc(doc(user, "importRuns/run-1")));
    await assertFails(getDoc(doc(user, "eventSources/tat-monthly-calendar")));
  });
});
