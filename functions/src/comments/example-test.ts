/**
 * Example test script for comment notifications
 *
 * This is not an automated test, but shows how to manually test
 * the comment notification function using Firebase emulators.
 *
 * Usage:
 * 1. Start Firebase emulators: `firebase emulators:start`
 * 2. Run this script: `ts-node functions/src/comments/example-test.ts`
 * 3. Check the function logs for notification attempts
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin for testing
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "demo-seafoundry",
  });
}

const db = admin.firestore();

async function setupTestData() {
  console.log("Setting up test data...");

  // Create test users (doc ID = UID, not email)
  const testUsers = [
    {
      uid: "uid-alice-001",
      email: "alice@seafoundry.app",
      name: "Alice Marine",
      fcmToken: "test-token-alice-123", // In production, this would be a real FCM token
    },
    {
      uid: "uid-bob-002",
      email: "bob@seafoundry.app",
      name: "Bob Coral",
      fcmToken: "test-token-bob-456",
    },
    {
      uid: "uid-charlie-003",
      email: "charlie@seafoundry.app",
      name: "Charlie Reef",
      // No FCM token - should be skipped gracefully
    },
  ];

  for (const user of testUsers) {
    await db.collection("users").doc(user.uid).set(user);
    console.log(`  Created user: ${user.uid} (${user.email})`);
  }

  console.log("Test data setup complete!");
}

async function testMentionNotification() {
  console.log("\n=== Testing Mention Notification ===");

  const testOrgId = "test-org-123";
  const commentRef = db
    .collection("organizations")
    .doc(testOrgId)
    .collection("comments")
    .doc();

  const comment = {
    authorUid: "uid-alice-001",
    authorName: "Alice Marine",
    content: "Hey @bob and @charlie, check out this coral specimen! It's amazing.",
    mentions: ["bob@seafoundry.app", "charlie@seafoundry.app"],
    targetType: "organism_record",
    targetId: "organism-789",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await commentRef.set(comment);
  console.log(`Created comment ${commentRef.id} with mentions`);
  console.log("Expected behavior:");
  console.log("  - Bob should receive notification (has FCM token)");
  console.log("  - Charlie should be skipped (no FCM token) with log message");
  console.log("  - Alice should not be notified (is the author)");
}

async function testReplyNotification() {
  console.log("\n=== Testing Reply Notification ===");

  const testOrgId = "test-org-123";
  const commentsCollection = db
    .collection("organizations")
    .doc(testOrgId)
    .collection("comments");

  // Create parent comment
  const parentCommentRef = commentsCollection.doc();
  const parentComment = {
    authorUid: "uid-bob-002",
    authorName: "Bob Coral",
    content: "This is an interesting finding about coral growth rates.",
    mentions: [],
    targetType: "organism_record",
    targetId: "organism-789",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await parentCommentRef.set(parentComment);
  console.log(`Created parent comment ${parentCommentRef.id}`);

  // Wait a moment for the function to process
  await new Promise((resolve) => setTimeout(resolve, 1000));

  // Create reply comment
  const replyCommentRef = commentsCollection.doc();
  const replyComment = {
    authorUid: "uid-alice-001",
    authorName: "Alice Marine",
    content: "I agree! The growth rate is exceptional.",
    mentions: [],
    parentCommentId: parentCommentRef.id,
    targetType: "organism_record",
    targetId: "organism-789",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await replyCommentRef.set(replyComment);
  console.log(`Created reply comment ${replyCommentRef.id}`);
  console.log("Expected behavior:");
  console.log("  - Bob should receive reply notification (has FCM token)");
  console.log("  - Alice should not be notified (is the reply author)");
}

async function testSelfReply() {
  console.log("\n=== Testing Self-Reply (Should Not Notify) ===");

  const testOrgId = "test-org-123";
  const commentsCollection = db
    .collection("organizations")
    .doc(testOrgId)
    .collection("comments");

  // Create parent comment
  const parentCommentRef = commentsCollection.doc();
  const parentComment = {
    authorUid: "uid-alice-001",
    authorName: "Alice Marine",
    content: "Initial observation about coral health.",
    mentions: [],
    targetType: "organism_record",
    targetId: "organism-789",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await parentCommentRef.set(parentComment);
  console.log(`Created parent comment ${parentCommentRef.id}`);

  // Wait a moment
  await new Promise((resolve) => setTimeout(resolve, 1000));

  // Reply to own comment
  const replyCommentRef = commentsCollection.doc();
  const replyComment = {
    authorUid: "uid-alice-001",
    authorName: "Alice Marine",
    content: "Update: coral is showing improvement!",
    mentions: [],
    parentCommentId: parentCommentRef.id,
    targetType: "organism_record",
    targetId: "organism-789",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await replyCommentRef.set(replyComment);
  console.log(`Created self-reply comment ${replyCommentRef.id}`);
  console.log("Expected behavior:");
  console.log("  - Alice should NOT receive notification (replied to own comment)");
}

async function cleanup() {
  console.log("\n=== Cleanup ===");
  console.log("Note: In emulator mode, data is automatically cleared on restart");
  console.log("For production testing, you'd want to delete test documents here");
}

// Main test runner
async function runTests() {
  try {
    console.log("Starting Comment Notification Tests");
    console.log("=====================================\n");

    await setupTestData();
    await testMentionNotification();

    // Wait for function to process
    await new Promise((resolve) => setTimeout(resolve, 2000));

    await testReplyNotification();

    // Wait for function to process
    await new Promise((resolve) => setTimeout(resolve, 2000));

    await testSelfReply();

    // Wait for function to process
    await new Promise((resolve) => setTimeout(resolve, 2000));

    await cleanup();

    console.log("\n=====================================");
    console.log("Tests complete! Check function logs for notification attempts.");
    console.log("\nTo view logs:");
    console.log("  firebase functions:log --only onCommentCreated");
  } catch (error) {
    console.error("Test failed:", error);
    throw error;
  }
}

// Only run if executed directly
if (require.main === module) {
  runTests()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

export {runTests, setupTestData, testMentionNotification, testReplyNotification};
