import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";

interface RelinkTransferRequest {
  transferEventId: string;
  organizationId: string;
}

interface RelinkTransferResponse {
  success: boolean;
  message: string;
}

/**
 * Links an email-addressed transfer to an organization.
 *
 * Security:
 * - Caller must be authenticated
 * - Caller's email must match transfer.toOrganizationEmail
 * - Transfer must NOT already have toOrganizationId set (prevents overwrites)
 * - Transfer must be in draft, pending, or shipped status
 * - Caller must be a member of the target organization
 * - Target organization must exist
 */
export const relinkEmailTransfer = onCall<RelinkTransferRequest>(
  {cors: true},
  async (request): Promise<RelinkTransferResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const {transferEventId, organizationId} = request.data;
    const callerEmail = request.auth.token.email?.toLowerCase();

    if (!callerEmail) {
      throw new HttpsError("failed-precondition", "No email on auth token");
    }

    if (!transferEventId || !organizationId) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    const db = admin.firestore();

    return await db.runTransaction(async (transaction) => {
      // 1. Fetch transfer event
      const transferRef = db.collection("events").doc(transferEventId);
      const transferDoc = await transaction.get(transferRef);

      if (!transferDoc.exists) {
        throw new HttpsError("not-found", "Transfer not found");
      }

      const transfer = transferDoc.data()!;

      // 2. Validate email match
      const targetEmail = (transfer.toOrganizationEmail as string | undefined)
        ?.toLowerCase();
      if (targetEmail !== callerEmail) {
        throw new HttpsError(
          "permission-denied",
          "Your email does not match this transfer's recipient"
        );
      }

      // 3. Prevent overwriting direct transfers
      if (transfer.toOrganizationId) {
        throw new HttpsError(
          "failed-precondition",
          "This transfer was sent directly to an organization and cannot be claimed via email"
        );
      }

      // 4. Validate transfer status - allow draft, pending, or shipped
      const status = transfer.status as string;
      const linkableStatuses = ["draft", "pending", "shipped"];
      if (!linkableStatuses.includes(status)) {
        throw new HttpsError(
          "failed-precondition",
          `Transfer is in "${status}" status and cannot be linked. ` +
          `Only transfers in draft, pending, or shipped status can be claimed.`
        );
      }

      // 5. Validate caller is member of target org
      const memberRef = db
        .collection("organizations")
        .doc(organizationId)
        .collection("members")
        .doc(request.auth!.uid);
      const memberDoc = await transaction.get(memberRef);

      if (!memberDoc.exists) {
        throw new HttpsError(
          "permission-denied",
          "You are not a member of this organization"
        );
      }

      // 6. Fetch target organization and verify it exists
      const orgRef = db.collection("organizations").doc(organizationId);
      const orgDoc = await transaction.get(orgRef);

      if (!orgDoc.exists) {
        throw new HttpsError(
          "not-found",
          "Target organization not found"
        );
      }

      const orgData = orgDoc.data()!;
      const orgName = orgData.name as string | undefined;

      // 7. Update transfer with organization ID
      const now = new Date().toISOString();
      transaction.update(transferRef, {
        toOrganizationId: organizationId,
        toOrganizationName: orgName,
        updatedAt: now,
        updatedById: request.auth!.uid,
      });

      // 8. Create notification for recipient organization
      const notificationRef = db
        .collection("organizations")
        .doc(organizationId)
        .collection("notifications")
        .doc();

      transaction.set(notificationRef, {
        id: notificationRef.id,
        type: "transfer_received",
        transferEventId: transferEventId,
        fromOrganizationId: transfer.fromOrganizationId,
        genetName: transfer.manifest?.genet?.name || "Unknown",
        quantity: transfer.quantity,
        status: "unread",
        createdAt: now,
      });

      return {
        success: true,
        message: "Transfer linked to organization successfully",
      };
    });
  }
);
