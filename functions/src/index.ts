/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import * as admin from "firebase-admin";
import {onDocumentCreated, onDocumentDeleted} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret} from "firebase-functions/params";
import {Resend} from "resend";

// Transfer functions
export * from "./transfers";

// Initialize Firebase Admin
admin.initializeApp();

// Firestore triggers must live in the same region as the Firestore database.
const FIRESTORE_REGION = "us-east1";

// Resend API key stored in Firebase Secret Manager.
const resendApiKey = defineSecret("RESEND_API_KEY");

/**
 * Get the app domain based on the Firebase project environment
 */
function getAppDomain(): string {
  // Check for explicit APP_DOMAIN override first (highest priority)
  if (process.env.APP_DOMAIN) {
    return process.env.APP_DOMAIN;
  }

  // Detect if running in Firebase emulator
  // The emulator sets FUNCTIONS_EMULATOR=true
  const isEmulator = process.env.FUNCTIONS_EMULATOR === "true" ||
    process.env.FIRESTORE_EMULATOR_HOST != null;

  if (isEmulator) {
    // Use localhost for emulator - assumes Flutter web runs on port 5000
    // You can override this by setting APP_DOMAIN env var
    const port = process.env.FLUTTER_WEB_PORT || "5000";
    console.log(`[getAppDomain] Running in emulator, using localhost:${port}`);
    return `http://localhost:${port}`;
  }

  const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";

  const domainMap: Record<string, string> = {
    "seafoundry-app": "https://provenance.seafoundry.com",
    "seafoundryapp": "https://provenance.seafoundry.com",
    "seafoundry-staging": "https://seafoundry-staging.web.app",
    "seafoundry-dev": "https://seafoundry-dev.web.app",
  };

  return domainMap[projectId] || "https://provenance.seafoundry.com";
}

// Email configuration using Resend
const EMAIL_FROM = "SeaFoundry <invites@email.seafoundry.com>";
const FEEDBACK_EMAIL_TO = "dev@seafoundry.com";

const ALLOWED_FEEDBACK_TYPES = [
  "bug_report",
  "feature_request",
  "general_feedback",
  "question",
];

const ALLOWED_SEVERITY_LEVELS = ["low", "medium", "high", "critical"];

// Lazy-initialized Resend client (secrets only available at runtime)
let resendClient: Resend | null = null;

function getResendClient(apiKey: string): Resend {
  if (!apiKey) {
    throw new Error("RESEND_API_KEY secret is not configured");
  }
  if (!resendClient) {
    resendClient = new Resend(apiKey);
  }
  return resendClient;
}

/**
 * Build the HTML email template for invitation emails
 */
function buildInvitationEmailHtml(
  inviterName: string,
  orgName: string,
  invitationLink: string,
  expiresAt: string
): string {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <div style="background-color: #f8f9fa; padding: 20px; text-align: center;">
        <h1 style="color: #2c3e50; margin: 0;">SeaFoundry Invitation</h1>
      </div>

      <div style="padding: 30px; background-color: white;">
        <h2 style="color: #2c3e50;">You're Invited!</h2>

        <p style="font-size: 16px; line-height: 1.6; color: #34495e;">
          Hi there!
        </p>

        <p style="font-size: 16px; line-height: 1.6; color: #34495e;">
          <strong>${inviterName}</strong> has invited you to join
          <strong>${orgName}</strong> on SeaFoundry.
        </p>

        <p style="font-size: 16px; line-height: 1.6; color: #34495e;">
          SeaFoundry is a platform for coral restoration and research organizations
          to manage their sites, track coral growth, and collaborate with other researchers.
        </p>

        <div style="text-align: center; margin: 40px 0;">
          <a href="${invitationLink}"
             style="background-color: #3498db; color: white; padding: 15px 30px;
                    text-decoration: none; border-radius: 5px; font-size: 16px;
                    font-weight: bold; display: inline-block;">
            Accept Invitation
          </a>
        </div>

        <p style="font-size: 14px; color: #7f8c8d; text-align: center;">
          This invitation expires on ${new Date(expiresAt).toLocaleDateString()}
        </p>

        <p style="font-size: 14px; color: #7f8c8d; text-align: center;">
          If the button doesn't work, copy and paste this link into your browser:<br>
          <a href="${invitationLink}" style="color: #3498db;">${invitationLink}</a>
        </p>
      </div>

      <div style="background-color: #ecf0f1; padding: 20px; text-align: center;">
        <p style="margin: 0; color: #7f8c8d; font-size: 12px;">
          © 2024 SeaFoundry. All rights reserved.
        </p>
      </div>
    </div>
  `;
}

function buildFeedbackEmailHtml(params: {
  ticketId: string;
  feedbackType: string;
  description: string;
  severity?: string | null;
  stepsToReproduce?: string | null;
  userName?: string | null;
  userEmail?: string | null;
  organizationName?: string | null;
  organizationId?: string | null;
  organizationTier?: string | null;
  platform?: string | null;
  currentScreen?: string | null;
  currentNodeType?: string | null;
  createdAt: string;
}): string {
  const {
    ticketId,
    feedbackType,
    description,
    severity,
    stepsToReproduce,
    userName,
    userEmail,
    organizationName,
    organizationId,
    organizationTier,
    platform,
    currentScreen,
    currentNodeType,
    createdAt,
  } = params;

  const typeLabel = feedbackType.replace(/_/g, " ");
  const safeValue = (value?: string | null) =>
    value && value.trim().length > 0 ? value : "-";

  return `
    <div style="font-family: Arial, sans-serif; max-width: 640px; margin: 0 auto;">
      <h2 style="color: #2c3e50;">SeaFoundry Feedback (${typeLabel})</h2>
      <p><strong>Ticket ID:</strong> ${ticketId}</p>
      <p><strong>Submitted:</strong> ${createdAt}</p>
      <hr />
      <h3 style="color: #2c3e50;">Details</h3>
      <p><strong>Type:</strong> ${typeLabel}</p>
      <p><strong>Severity:</strong> ${safeValue(severity)}</p>
      <p><strong>Description:</strong></p>
      <pre style="white-space: pre-wrap; background: #f6f8fa; padding: 12px; border-radius: 6px;">${description}</pre>
      <p><strong>Steps to reproduce:</strong></p>
      <pre style="white-space: pre-wrap; background: #f6f8fa; padding: 12px; border-radius: 6px;">${safeValue(stepsToReproduce)}</pre>
      <hr />
      <h3 style="color: #2c3e50;">Context</h3>
      <p><strong>User:</strong> ${safeValue(userName)} (${safeValue(userEmail)})</p>
      <p><strong>Organization:</strong> ${safeValue(organizationName)} (${safeValue(organizationId)})</p>
      <p><strong>Tier:</strong> ${safeValue(organizationTier)}</p>
      <p><strong>Platform:</strong> ${safeValue(platform)}</p>
      <p><strong>Screen:</strong> ${safeValue(currentScreen)}</p>
      <p><strong>Node:</strong> ${safeValue(currentNodeType)}</p>
    </div>
  `;
}

function normalizeString(value: unknown, maxLength = 5000): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.length > maxLength ? trimmed.substring(0, maxLength) : trimmed;
}

/**
 * Send email with retry logic (exponential backoff)
 */
async function sendEmailWithRetry(
  to: string,
  subject: string,
  html: string,
  apiKey: string,
  maxRetries = 3
): Promise<void> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const {error} = await getResendClient(apiKey).emails.send({
        from: EMAIL_FROM,
        to,
        subject,
        html,
      });

      if (error) {
        throw new Error(error.message);
      }
      return;
    } catch (error) {
      lastError = error as Error;
      const delay = Math.pow(2, attempt) * 1000;
      console.warn(`Email send attempt ${attempt + 1} failed, retrying in ${delay}ms...`, {
        error: lastError.message,
        stack: lastError.stack,
        recipient: to,
        attempt: attempt + 1,
        nextDelay: delay,
      });

      if (attempt < maxRetries - 1) {
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }

  throw lastError || new Error("Email sending failed after retries");
}

async function requireOrgAdmin(userId: string, organizationId: string) {
  const db = admin.firestore();
  const memberRef = db
    .collection("organizations")
    .doc(organizationId)
    .collection("members")
    .doc(userId);
  const memberSnap = await memberRef.get();

  if (memberSnap.exists) {
    const data = memberSnap.data() || {};
    const role = (data.role ?? "").toString();
    const status = (data.status ?? "active").toString();
    if (status === "suspended") {
      throw new HttpsError(
        "permission-denied",
        "Membership is suspended"
      );
    }
    if (role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Admin access is required"
      );
    }
    return;
  }

  const userSnap = await db.collection("users").doc(userId).get();
  if (!userSnap.exists) {
    throw new HttpsError("permission-denied", "User not found");
  }

  const userData = userSnap.data() || {};
  if (userData.organizationId !== organizationId) {
    throw new HttpsError(
      "permission-denied",
      "User does not belong to this organization"
    );
  }

  const role = (userData.role ?? "").toString();
  const isAdmin = userData.isAdmin === true;
  if (role !== "admin" && !isAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Admin access is required"
    );
  }
}

function normalizeReturnUrl(raw: unknown): string {
  if (typeof raw === "string" && raw.trim().length > 0) {
    try {
      const parsed = new URL(raw);
      if (parsed.protocol === "https:" || parsed.protocol === "http:") {
        return parsed.toString();
      }
    } catch (error) {
      console.warn("Invalid return URL provided:", error);
    }
  }

  return getAppDomain();
}

// Interface for invitation data
interface InvitationData {
  id: string;
  email: string;
  organizationId: string;
  invitedById: string;
  status: string;
  expiresAt: string;
  createdAt: string;
  originDomain?: string; // The domain where the invitation was created (e.g., http://localhost:5000)
}

// Interface for organization data
interface OrganizationData {
  id: string;
  name: string;
  domain: string;
}

// Interface for user data
interface UserData {
  id: string;
  name: string;
  email: string;
}

/**
 * Cloud Function to send invitation emails
 * Triggered when a new invitation is created in Firestore
 */
export const sendInvitationEmail = onDocumentCreated(
  {
    document: "invitations/{invitationId}",
    region: FIRESTORE_REGION,
    secrets: [resendApiKey],
  },
  async (event) => {
    const docData = event.data?.data();
    if (!docData) {
      console.error("Document data is missing");
      return;
    }

    // Validate invitation data structure
    const invitationData = docData as InvitationData;
    if (!invitationData.id || !invitationData.email || !invitationData.organizationId) {
      console.error("Invalid invitation data structure");
      return;
    }

    const apiKey = resendApiKey.value();
    if (!apiKey) {
      console.error("RESEND_API_KEY secret is not configured");
      await event.data?.ref.update({
        emailSent: false,
        emailError: "RESEND_API_KEY secret is not configured",
      });
      return;
    }

    try {
      // Get organization details
      const organizationDoc = await admin.firestore()
        .collection("organizations")
        .doc(invitationData.organizationId)
        .get();

      if (!organizationDoc.exists) {
        console.error("Organization not found:", invitationData.organizationId);
        return;
      }

      const orgData = organizationDoc.data();
      if (!orgData) {
        console.error("Organization data is missing");
        return;
      }
      const organization = orgData as OrganizationData;

      // Get inviter details
      const inviterDoc = await admin.firestore()
        .collection("users")
        .doc(invitationData.invitedById)
        .get();

      if (!inviterDoc.exists) {
        console.error("Inviter not found:", invitationData.invitedById);
        return;
      }

      const inviterData = inviterDoc.data();
      if (!inviterData) {
        console.error("Inviter data is missing");
        return;
      }
      const inviter = inviterData as UserData;

      // Create invitation link - use originDomain from invitation if available (for localhost testing)
      // Otherwise fall back to environment-aware domain
      const domain = invitationData.originDomain || getAppDomain();
      const invitationLink = `${domain}/invite/${invitationData.id}`;
      console.log(`[sendInvitationEmail] Using domain: ${domain} (originDomain: ${invitationData.originDomain || "not set"})`);

      // Build email content using shared template
      const emailContent = buildInvitationEmailHtml(
        inviter.name,
        organization.name,
        invitationLink,
        invitationData.expiresAt
      );

      // Send email
      await sendEmailWithRetry(
        invitationData.email,
        `You're invited to join ${organization.name} on SeaFoundry`,
        emailContent,
        apiKey
      );

      console.log("Invitation email sent successfully to:", invitationData.email);

      // Update invitation status to indicate email was sent
      await event.data?.ref.update({
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error("Error sending invitation email:", error);

      // Update invitation status to indicate email failed
      await event.data?.ref.update({
        emailSent: false,
        emailError: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

/**
 * Cloud Function to resend invitation emails
 * Can be called manually or triggered by a scheduled function
 */
export const resendInvitationEmail = onCall(
  {
    secrets: [resendApiKey],
  },
  async (request) => {
    // Check if user is authenticated
    if (!request.auth) {
      throw new Error("User must be authenticated");
    }

    // Validate request data
    if (!request.data || typeof request.data !== "object") {
      throw new Error("Invalid request data");
    }

    const {invitationId} = request.data as { invitationId: string };

    if (!invitationId || typeof invitationId !== "string") {
      throw new Error("Invitation ID is required and must be a string");
    }

    const apiKey = resendApiKey.value();
    if (!apiKey) {
      throw new Error("RESEND_API_KEY secret is not configured");
    }

    try {
      // Get invitation data
      const invitationDoc = await admin.firestore()
        .collection("invitations")
        .doc(invitationId)
        .get();

      if (!invitationDoc.exists) {
        throw new Error("Invitation not found");
      }

      const invData = invitationDoc.data();
      if (!invData) {
        throw new Error("Invitation data is missing");
      }
      const invitationData = invData as InvitationData;

      // Check if invitation is still pending
      if (invitationData.status !== "pending") {
        throw new Error("Invitation is not pending");
      }

      // Check if invitation has expired
      if (new Date(invitationData.expiresAt) < new Date()) {
        throw new Error("Invitation has expired");
      }

      // Get organization details
      const organizationDoc = await admin.firestore()
        .collection("organizations")
        .doc(invitationData.organizationId)
        .get();

      if (!organizationDoc.exists) {
        throw new Error("Organization not found");
      }

      const orgData = organizationDoc.data();
      if (!orgData) {
        throw new Error("Organization data is missing");
      }
      const organization = orgData as OrganizationData;

      // Get inviter details
      const inviterDoc = await admin.firestore()
        .collection("users")
        .doc(invitationData.invitedById)
        .get();

      if (!inviterDoc.exists) {
        throw new Error("Inviter not found");
      }

      const inviter = inviterDoc.data() as UserData;

      // Create invitation link - use originDomain from invitation if available (for localhost testing)
      const domain = invitationData.originDomain || getAppDomain();
      const invitationLink = `${domain}/invite/${invitationData.id}`;
      console.log(`[resendInvitationEmail] Using domain: ${domain} (originDomain: ${invitationData.originDomain || "not set"})`);

      // Build email content using shared template
      const emailContent = buildInvitationEmailHtml(
        inviter.name,
        organization.name,
        invitationLink,
        invitationData.expiresAt
      );

      // Send email
      await sendEmailWithRetry(
        invitationData.email,
        `You're invited to join ${organization.name} on SeaFoundry`,
        emailContent,
        apiKey
      );

      // Update invitation status
      await invitationDoc.ref.update({
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        resentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {success: true, message: "Invitation email resent successfully"};
    } catch (error) {
      console.error("Error resending invitation email:", error);
      throw new Error("Failed to resend invitation email");
    }
  }
);

/**
 * Cloud Function to submit feedback from the app and email the dev team.
 */
export const submitFeedbackReport = onCall(
  {
    secrets: [resendApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    if (!request.data || typeof request.data !== "object") {
      throw new HttpsError("invalid-argument", "Invalid request data");
    }

    const data = request.data as Record<string, unknown>;
    const feedbackType = normalizeString(data["feedbackType"]);
    if (!feedbackType || !ALLOWED_FEEDBACK_TYPES.includes(feedbackType)) {
      throw new HttpsError(
        "invalid-argument",
        `Invalid feedback type. Allowed values: ${ALLOWED_FEEDBACK_TYPES.join(", ")}`
      );
    }

    const description = normalizeString(data["description"], 5000);
    if (!description || description.length < 10) {
      throw new HttpsError(
        "invalid-argument",
        "Description must be at least 10 characters"
      );
    }

    const rawSeverity = normalizeString(data["severity"]);
    let severity: string | null = null;
    if (feedbackType === "bug_report" && rawSeverity) {
      if (!ALLOWED_SEVERITY_LEVELS.includes(rawSeverity)) {
        throw new HttpsError(
          "invalid-argument",
          `Invalid severity. Allowed values: ${ALLOWED_SEVERITY_LEVELS.join(", ")}`
        );
      }
      severity = rawSeverity;
    }

    const stepsToReproduce = normalizeString(data["stepsToReproduce"], 2000);

    const user = (data["user"] as Record<string, unknown>) ?? {};
    const organization = (data["organization"] as Record<string, unknown>) ?? {};
    const context = (data["context"] as Record<string, unknown>) ?? {};

    const ticketId = `SF-${Date.now().toString(36).toUpperCase()}-${
      Math.random().toString(36).substring(2, 6).toUpperCase()
    }`;

    const createdAt = new Date().toISOString();

    const feedbackDoc = {
      ticketId,
      feedbackType,
      description,
      severity: feedbackType === "bug_report" ? severity : null,
      stepsToReproduce: stepsToReproduce || null,
      context: {
        organizationId: normalizeString(organization["id"]) || null,
        organizationName: normalizeString(organization["name"]) || null,
        tier: normalizeString(organization["tier"]) || null,
        userId: normalizeString(user["id"]) || null,
        userName: normalizeString(user["name"]) || null,
        userEmail: normalizeString(user["email"]) || null,
        currentScreen: normalizeString(context["currentScreen"]) || null,
        currentNodeType: normalizeString(context["currentNodeType"]) || null,
        platform: normalizeString(context["platform"]) || null,
      },
      status: "open",
      createdAt,
      source: normalizeString(data["source"]) || "feedback_dialog",
    };

    await admin.firestore().collection("feedback").doc(ticketId).set(feedbackDoc);

    let emailSent = false;
    const apiKey = resendApiKey.value();
    if (apiKey) {
      const html = buildFeedbackEmailHtml({
        ticketId,
        feedbackType,
        description,
        severity,
        stepsToReproduce,
        userName: normalizeString(user["name"]),
        userEmail: normalizeString(user["email"]),
        organizationName: normalizeString(organization["name"]),
        organizationId: normalizeString(organization["id"]),
        organizationTier: normalizeString(organization["tier"]),
        platform: normalizeString(context["platform"]),
        currentScreen: normalizeString(context["currentScreen"]),
        currentNodeType: normalizeString(context["currentNodeType"]),
        createdAt,
      });
      const subject = `[${ticketId}] ${feedbackType.replace(/_/g, " ")} feedback`;
      await sendEmailWithRetry(
        FEEDBACK_EMAIL_TO,
        subject,
        html,
        apiKey
      );
      emailSent = true;
    } else {
      console.warn(
        "[submitFeedbackReport] RESEND_API_KEY not configured; skipping email"
      );
    }

    return {
      success: true,
      ticketId,
      message: "Thanks for the feedback!",
      emailSent,
    };
  }
);

async function countOrganizationMembers(orgId: string): Promise<number> {
  const membersSnap = await admin.firestore()
    .collection("organizations")
    .doc(orgId)
    .collection("members")
    .get();
  return membersSnap.size;
}

async function updateOrganizationMemberCount(orgId: string, delta: number) {
  const orgRef = admin.firestore().collection("organizations").doc(orgId);
  await admin.firestore().runTransaction(async (transaction) => {
    const orgSnap = await transaction.get(orgRef);
    if (!orgSnap.exists) {
      return;
    }

    const orgData = orgSnap.data() || {};
    const currentCount = orgData.memberCount;
    if (typeof currentCount !== "number") {
      return;
    }

    const nextCount = Math.max(0, currentCount + delta);
    transaction.set(orgRef, {memberCount: nextCount}, {merge: true});
  });

  const orgSnap = await orgRef.get();
  if (!orgSnap.exists) {
    return;
  }

  const orgData = orgSnap.data() || {};
  if (typeof orgData.memberCount === "number") {
    return;
  }

  const actualCount = await countOrganizationMembers(orgId);
  await orgRef.set({memberCount: actualCount}, {merge: true});
}

export const onOrganizationMemberCreated = onDocumentCreated(
  {
    document: "organizations/{orgId}/members/{memberId}",
    region: FIRESTORE_REGION,
  },
  async (event) => {
    const orgId = event.params.orgId;
    if (!orgId) return;
    await updateOrganizationMemberCount(orgId, 1);
  }
);

export const onOrganizationMemberDeleted = onDocumentDeleted(
  {
    document: "organizations/{orgId}/members/{memberId}",
    region: FIRESTORE_REGION,
  },
  async (event) => {
    const orgId = event.params.orgId;
    if (!orgId) return;
    await updateOrganizationMemberCount(orgId, -1);
  }
);

/**
 * Scheduled function to clean up expired invitations
 * Runs daily at 2 AM
 */
export const cleanupExpiredInvitations = onSchedule(
  "0 2 * * *",
  async () => {
    try {
      const now = new Date();

      // Get all expired invitations
      const expiredInvitations = await admin.firestore()
        .collection("invitations")
        .where("status", "==", "pending")
        .where("expiresAt", "<", now.toISOString())
        .get();

      // Update status to expired
      const batch = admin.firestore().batch();
      expiredInvitations.docs.forEach((doc) => {
        batch.update(doc.ref, {
          status: "expired",
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();

      console.log(`Updated ${expiredInvitations.size} expired invitations`);
    } catch (error) {
      console.error("Error cleaning up expired invitations:", error);
    }
  }
);

/**
 * Scheduled function to reconcile organization member counts.
 * Runs daily at 4 AM UTC.
 */
export const reconcileOrganizationMemberCounts = onSchedule(
  "0 4 * * *",
  async () => {
    const db = admin.firestore();
    const orgsSnap = await db.collection("organizations").get();
    let batch = db.batch();
    let batchCount = 0;

    for (const orgDoc of orgsSnap.docs) {
      const membersSnap = await orgDoc.ref.collection("members").get();
      batch.set(orgDoc.ref, {memberCount: membersSnap.size}, {merge: true});
      batchCount += 1;

      if (batchCount >= 450) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }
  }
);

