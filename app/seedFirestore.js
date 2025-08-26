const admin = require("firebase-admin");
const fs = require("fs");

// Load your Firebase service account key
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function seedData() {
  // Create users
  const users = [
    {
      id: "userID1",
      email: "user1@example.com",
      role: "coach",
      name: "User One",
      createdAt: admin.firestore.Timestamp.now(),
      groupId: "groupID1"
    },
    {
      id: "userID2",
      email: "user2@example.com",
      role: "athlete",
      name: "User Two",
      createdAt: admin.firestore.Timestamp.now(),
      groupId: "groupID1"
    },
    {
      id: "userID3",
      email: "user3@example.com",
      role: "athlete",
      name: "User Three",
      createdAt: admin.firestore.Timestamp.now(),
      groupId: "groupID1"
    }
  ];

  for (const user of users) {
    await db.collection("users").doc(user.id).set(user);

    if (user.role === "athlete") {
      const statsRef = db.collection("users").doc(user.id).collection("stats");
      await statsRef.add({
        hr: 75 + Math.floor(Math.random() * 10),
        temperature: 36 + Math.random(),
        time: admin.firestore.Timestamp.now()
      });

      await statsRef.add({
        hr: 80 + Math.floor(Math.random() * 5),
        temperature: 36.5 + Math.random(),
        time: admin.firestore.Timestamp.now()
      });
    }
  }

  // Create a group
  await db.collection("groups").doc("groupID1").set({
    coachId: "userID1",
    athletes: ["userID2", "userID3"],
    createdAt: admin.firestore.Timestamp.now()
  });

  // Create tips
  const tips = [
    {
      title: "Stay hydrated",
      description: "Drink at least 2L of water per day"
    },
    {
      title: "Warm up",
      description: "Always stretch before workouts"
    }
  ];

  for (const [i, tip] of tips.entries()) {
    await db.collection("tips").doc(`tipID${i + 1}`).set(tip);
  }

  // Add performance feedback
  await db.collection("performance_feedback").add({
    athleteId: "userID2",
    feedback: "Great performance today!",
    timestamp: admin.firestore.Timestamp.now()
  });

  console.log("✅ Firestore seeded successfully.");
}

seedData().catch(console.error);
