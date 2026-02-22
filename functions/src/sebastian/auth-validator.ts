/**
 * Authorization validation for Sebastian AI
 * Ensures users can only access data from their own organization
 */

import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";

/**
 * Verify that a user belongs to the specified organization.
 * Throws HttpsError if authorization fails.
 *
 * Check order:
 * 1. Membership subcollection: organizations/{orgId}/members/{userId}
 * 2. Fallback: users/{userId} doc with matching organizationId
 */
export async function verifyUserOrganization(
  userId: string,
  organizationId: string
): Promise<void> {
  if (!userId || typeof userId !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "userId is required and must be a string"
    );
  }

  if (!organizationId || typeof organizationId !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "organizationId is required and must be a string"
    );
  }

  try {
    const db = admin.firestore();

    // 1. Check membership subcollection first (primary path)
    const memberSnap = await db
      .collection("organizations")
      .doc(organizationId)
      .collection("members")
      .doc(userId)
      .get();

    if (memberSnap.exists) {
      const data = memberSnap.data() || {};
      const status = (data.status ?? "active").toString();
      if (status === "suspended") {
        throw new HttpsError(
          "permission-denied",
          "Membership is suspended"
        );
      }
      // Member exists and is not suspended — authorized
      console.log(
        `Authorization successful (member): User ${userId} verified for organization ${organizationId}`
      );
      return;
    }

    // 2. Fallback: UID-keyed user doc with matching organizationId
    const userSnap = await db
      .collection("users")
      .doc(userId)
      .get();

    if (!userSnap.exists) {
      throw new HttpsError(
        "permission-denied",
        "User not found or access denied"
      );
    }

    const userData = userSnap.data() || {};
    if (userData.organizationId !== organizationId) {
      console.warn(
        `Authorization failed: User ${userId} attempted to access organization ${organizationId} but belongs to ${userData.organizationId}`
      );
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to access this organization's data"
      );
    }

    // Authorization successful via user doc
    console.log(
      `Authorization successful (user doc): User ${userId} verified for organization ${organizationId}`
    );
  } catch (error) {
    // Re-throw HttpsError
    if (error instanceof HttpsError) {
      throw error;
    }

    // Log unexpected errors
    console.error("Error verifying user organization:", error);

    // Fail closed - deny access on unexpected errors
    throw new HttpsError(
      "internal",
      "Unable to verify user authorization. Please try again."
    );
  }
}

/**
 * Verify organization exists and is active
 * Throws HttpsError if organization is invalid or inactive
 */
export async function verifyOrganizationExists(
  organizationId: string
): Promise<void> {
  try {
    const orgDoc = await admin
      .firestore()
      .collection("organizations")
      .doc(organizationId)
      .get();

    if (!orgDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Organization not found"
      );
    }

    const orgData = orgDoc.data();

    // Check if organization is active (if status field exists)
    if (orgData?.status && orgData.status !== "active") {
      throw new HttpsError(
        "permission-denied",
        "Organization is not active"
      );
    }
  } catch (error) {
    // Re-throw HttpsError
    if (error instanceof HttpsError) {
      throw error;
    }

    // Log unexpected errors
    console.error("Error verifying organization:", error);

    throw new HttpsError(
      "internal",
      "Unable to verify organization. Please try again."
    );
  }
}
