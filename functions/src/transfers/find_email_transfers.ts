import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";

interface FindEmailTransfersRequest {
  // No parameters needed - uses caller's email from auth token
}

interface TransferSummary {
  id: string;
  genetName: string;
  fromOrganizationName: string;
  quantity: number;
  status: string;
  createdAt: string;
  manifestChecksum: string | null;
}

interface FindEmailTransfersResponse {
  transfers: TransferSummary[];
}

/**
 * Finds pending/shipped transfers addressed to the caller's email.
 *
 * Security:
 * - Caller must be authenticated
 * - Only returns transfers where toOrganizationEmail matches caller's email
 * - Filter for non-terminal status (pending, shipped) enforced server-side
 */
export const findEmailTransfers = onCall<FindEmailTransfersRequest>(
  {cors: true},
  async (request): Promise<FindEmailTransfersResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const callerEmail = request.auth.token.email?.toLowerCase();

    if (!callerEmail) {
      throw new HttpsError("failed-precondition", "No email on auth token");
    }

    const db = admin.firestore();

    // Query transfers addressed to caller's email that are not yet terminal
    // Include draft status as well since those can be claimed
    const snapshot = await db
      .collection("events")
      .where("toOrganizationEmail", "==", callerEmail)
      .where("status", "in", ["draft", "pending", "shipped"])
      .orderBy("createdAt", "desc")
      .get();

    const transfers: TransferSummary[] = snapshot.docs.map((doc) => {
      const data = doc.data();
      const manifest = data.manifest as Record<string, unknown> | undefined;
      const genet = manifest?.genet as Record<string, unknown> | undefined;
      const fromOrg = manifest?.fromOrganization as Record<string, unknown> | undefined;

      return {
        id: doc.id,
        genetName: (genet?.name as string) || (genet?.displayName as string) || "Unknown",
        fromOrganizationName: (fromOrg?.name as string) || "Unknown",
        quantity: (data.quantity as number) || 0,
        status: data.status as string,
        createdAt: data.createdAt as string,
        manifestChecksum: (data.manifestChecksum as string) || null,
      };
    });

    return {transfers};
  }
);
