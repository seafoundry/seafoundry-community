import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

/**
 * Cloud Function triggered when a new comment is created.
 * Sends push notifications to mentioned users.
 *
 * Comment schema:
 * - authorUid: string (Firebase Auth UID of the comment author)
 * - authorName: string (display name)
 * - content: string (comment text)
 * - mentions: string[] (array of user emails)
 * - parentCommentId?: string (if this is a reply)
 * - targetType: string (e.g., "organism_record", "site", "event")
 * - targetId: string (ID of the entity being commented on)
 */
export const notifyCommentMentions = onDocumentCreated(
  "organizations/{orgId}/comments/{commentId}",
  async (event) => {
    const {orgId, commentId} = event.params;
    const comment = event.data?.data();

    if (!comment) {
      console.error(`Comment ${commentId} has no data`);
      return;
    }

    const authorUid: string = comment.authorUid || "";
    const authorName: string = comment.authorName || "Someone";
    const contentPreview = (comment.content || "").substring(0, 100);
    const mentions: string[] = comment.mentions || [];
    const parentCommentId: string | undefined = comment.parentCommentId;

    // Handle mentions notifications
    if (mentions.length > 0) {
      await sendMentionNotifications(
        mentions,
        authorUid,
        authorName,
        contentPreview,
        orgId,
        commentId,
        comment
      );
    }

    // Handle reply notifications (notify parent comment author)
    if (parentCommentId) {
      await sendReplyNotification(
        parentCommentId,
        authorUid,
        authorName,
        contentPreview,
        orgId,
        commentId,
        comment
      );
    }

    console.log(
      `Processed comment ${commentId}: ${mentions.length} mentions, ` +
      `${parentCommentId ? "1 reply" : "0 replies"}`
    );
  }
);

/**
 * Send notifications to users mentioned in a comment.
 * @param authorUid - Firebase Auth UID of the comment author.
 */
async function sendMentionNotifications(
  mentions: string[],
  authorUid: string,
  authorName: string,
  contentPreview: string,
  orgId: string,
  commentId: string,
  comment: FirebaseFirestore.DocumentData
): Promise<void> {
  // Look up the author's actual email from their user document so we can
  // filter them out of the mentions list (which contains real emails).
  let resolvedAuthorEmail: string | null = null;
  if (authorUid) {
    const authorDoc = await admin.firestore()
      .collection("users")
      .doc(authorUid)
      .get();
    if (authorDoc.exists) {
      resolvedAuthorEmail = authorDoc.data()?.email || null;
    } else {
      console.log(
        `Author user doc not found for UID ${authorUid}, ` +
        "cannot filter self-mentions"
      );
    }
  }

  // Filter out the author from mentions using their real email
  const recipientEmails = resolvedAuthorEmail
    ? mentions.filter((email) => email !== resolvedAuthorEmail)
    : mentions;

  if (recipientEmails.length === 0) {
    console.log("No recipients after filtering out author");
    return;
  }

  // Look up users by email field (not doc ID)
  const userDocs: admin.firestore.DocumentSnapshot[] = [];
  for (const email of recipientEmails) {
    const snap = await admin.firestore().collection("users")
      .where("email", "==", email).limit(1).get();
    if (!snap.empty) userDocs.push(snap.docs[0]);
  }

  // Build a map of email -> userData for quick lookup
  const userDataMap = new Map<string, FirebaseFirestore.DocumentData>();
  userDocs.forEach((doc) => {
    const data = doc.data();
    if (data?.email) {
      userDataMap.set(data.email, data);
    }
  });

  // Send notifications in parallel
  const notificationPromises = recipientEmails.map(async (userEmail: string) => {
    const userData = userDataMap.get(userEmail);

    if (!userData) {
      console.log(`User ${userEmail} not found, skipping`);
      return;
    }

    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log(`User ${userEmail} has no FCM token, skipping`);
      return;
    }

    try {
      // Send push notification
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: `${authorName} mentioned you`,
          body: contentPreview,
        },
        data: {
          type: "comment_mention",
          organizationId: orgId,
          targetType: comment.targetType || "",
          targetId: comment.targetId || "",
          commentId: commentId,
        },
        android: {
          priority: "high",
          notification: {
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: "default",
            },
          },
        },
      });

      console.log(
        `Sent mention notification to ${userEmail} for comment ${commentId}`
      );
    } catch (error) {
      console.error(
        `Error sending mention notification to ${userEmail}:`,
        error
      );
    }
  });

  await Promise.all(notificationPromises);
}

/**
 * Send notification to the parent comment author when someone replies.
 * @param authorUid - Firebase Auth UID of the reply author.
 */
async function sendReplyNotification(
  parentCommentId: string,
  authorUid: string,
  authorName: string,
  contentPreview: string,
  orgId: string,
  commentId: string,
  comment: FirebaseFirestore.DocumentData
): Promise<void> {
  try {
    // Get parent comment to find its author
    const parentCommentDoc = await admin.firestore()
      .collection("organizations")
      .doc(orgId)
      .collection("comments")
      .doc(parentCommentId)
      .get();

    if (!parentCommentDoc.exists) {
      console.log(`Parent comment ${parentCommentId} not found, skipping reply notification`);
      return;
    }

    const parentComment = parentCommentDoc.data();
    const parentAuthorUid: string = parentComment?.authorUid || "";

    // Don't notify if replying to yourself
    if (parentAuthorUid === authorUid) {
      console.log("Skipping reply notification (author replied to themselves)");
      return;
    }

    // Get parent author's user document using their UID
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(parentAuthorUid)
      .get();

    if (!userDoc.exists) {
      console.log(`Parent author ${parentAuthorUid} not found, skipping`);
      return;
    }

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      console.log(`Parent author ${parentAuthorUid} has no FCM token, skipping`);
      return;
    }

    // Send push notification
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: `${authorName} replied to your comment`,
        body: contentPreview,
      },
      data: {
        type: "comment_reply",
        organizationId: orgId,
        targetType: comment.targetType || "",
        targetId: comment.targetId || "",
        commentId: commentId,
        parentCommentId: parentCommentId,
      },
      android: {
        priority: "high",
        notification: {
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: "default",
          },
        },
      },
    });

    console.log(
      `Sent reply notification to ${parentAuthorUid} for comment ${commentId}`
    );
  } catch (error) {
    console.error(
      `Error sending reply notification for parent ${parentCommentId}:`,
      error
    );
  }
}
