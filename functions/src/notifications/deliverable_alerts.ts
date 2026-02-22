import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";

// Lazy initialization to avoid calling firestore() before initializeApp()
const getFirestore = () => admin.firestore();

const emailUser = process.env.EMAIL_USER;
const emailPass = process.env.EMAIL_PASSWORD;

const transporter = emailUser && emailPass ?
  nodemailer.createTransport({
    service: "gmail",
    auth: {user: emailUser, pass: emailPass},
  }) :
  null;

const DEFAULT_LEAD_DAYS = [14, 7];
const DEFAULT_TIMEZONE = "UTC";

type DeliverableDoc = FirebaseFirestore.DocumentData & {
  organizationId: string;
  name: string;
  dueDate: string;
  statusId: string;
  permitId?: string;
  requiredSiteIds?: string[];
  assigneeUserIds?: string[];
};

type UserDoc = FirebaseFirestore.DocumentData & {
  uid: string;
  email: string;
  isAdmin?: boolean;
  organizationId?: string;
  fcmToken?: string;
  timezone?: string;
};

type OrgNotificationSettings = {
  leadDays: number[];
  channels: {
    inApp: boolean;
    push: boolean;
    email: boolean;
  };
  timezone?: string;
};

function riskLabel(statusId: string, dueDate: string): string {
  const now = new Date();
  const due = new Date(dueDate);
  const daysUntil = Math.floor((due.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
  if (statusId === "overdue" || daysUntil < 0) return "Overdue";
  if (statusId === "at_risk") return "At Risk";
  if (daysUntil <= 7) return "Due in 7d";
  if (daysUntil <= 14) return "Due in 14d";
  return "Upcoming";
}

async function notifyUserInApp(
  userId: string,
  payload: Record<string, unknown>
): Promise<void> {
  await getFirestore()
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .add({
      ...payload,
      createdAt: new Date().toISOString(),
      read: false,
      type: "deliverable_due",
    });
}

async function notifyUserPush(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<void> {
  await admin.messaging().send({
    token,
    notification: {title, body},
    data,
    android: {
      priority: "high",
      notification: {clickAction: "FLUTTER_NOTIFICATION_CLICK"},
    },
    apns: {payload: {aps: {badge: 1, sound: "default"}}},
  });
}

async function notifyUserEmail(
  email: string,
  subject: string,
  body: string
): Promise<void> {
  if (!transporter) {
    console.log(`[deliverable-alert] Email disabled; would send to ${email}: ${subject}`);
    return;
  }
  await transporter.sendMail({
    from: emailUser,
    to: email,
    subject,
    text: body,
  });
}

async function fetchAdminRecipients(orgId: string): Promise<UserDoc[]> {
  const snapshot = await getFirestore()
    .collection("users")
    .where("organizationId", "==", orgId)
    .where("isAdmin", "==", true)
    .get();

  return snapshot.docs.map((doc) => ({
    ...doc.data(),
    uid: doc.id,
    email: doc.data()?.email || null,
  } as UserDoc));
}

async function fetchAssigneeRecipients(userIds: string[]): Promise<UserDoc[]> {
  if (!userIds || userIds.length === 0) return [];

  // Batch fetch all user documents
  const userRefs = userIds.map((id) =>
    getFirestore().collection("users").doc(id)
  );
  const userDocs = await getFirestore().getAll(...userRefs);

  // Filter existing docs and map to UserDoc
  return userDocs
    .filter((doc) => doc.exists)
    .map((doc) => ({
      ...doc.data(),
      uid: doc.id,
      email: doc.data()?.email || null,
    } as UserDoc));
}

async function fetchLeadDays(orgId: string): Promise<number[]> {
  try {
    const orgDoc = await getFirestore().collection("organizations").doc(orgId).get();
    const leadDays = orgDoc.data()?.notificationLeadDays as number[] | undefined;
    if (leadDays && Array.isArray(leadDays) && leadDays.length > 0) {
      return leadDays;
    }
  } catch (error) {
    console.warn(`[deliverable-alert] failed to fetch lead days for ${orgId}`, error);
  }
  return DEFAULT_LEAD_DAYS;
}

function formatDueDate(dueDate: string, timezone?: string): string {
  try {
    return new Date(dueDate).toLocaleString("en-US", {
      timeZone: timezone || DEFAULT_TIMEZONE,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch (_) {
    return dueDate.slice(0, 10);
  }
}

async function fetchOrgNotificationSettings(orgId: string): Promise<OrgNotificationSettings> {
  const leadDays = await fetchLeadDays(orgId);
  try {
    const orgDoc = await getFirestore().collection("organizations").doc(orgId).get();
    const channels = orgDoc.data()?.notificationChannels as
      {inApp?: boolean; push?: boolean; email?: boolean} | undefined;
    const timezone = orgDoc.data()?.timezone as string | undefined;
    return {
      leadDays,
      channels: {
        inApp: channels?.inApp ?? true,
        push: channels?.push ?? true,
        email: channels?.email ?? true,
      },
      timezone,
    };
  } catch (error) {
    console.warn(`[deliverable-alert] failed to fetch channels/timezone for ${orgId}`, error);
    return {
      leadDays,
      channels: {inApp: true, push: true, email: true},
      timezone: undefined,
    };
  }
}

// Scheduled notifier for deliverables approaching deadlines or at risk/overdue
export const deliverableDeadlineAlerts = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "UTC",
    retryCount: 3,
  },
  async () => {
    const now = new Date();
    // Fetch up to a generous window so org overrides are respected
    const maxLeadDays = 60;
    const warningDate = new Date(now.getTime() + 1000 * 60 * 60 * 24 * maxLeadDays);

    const deliverablesSnap = await getFirestore()
      .collection("deliverables")
      .where("statusId", "in", ["not_started", "in_progress", "at_risk", "pending_review", "overdue"])
      .where("dueDate", "<=", warningDate.toISOString())
      .get();

    if (deliverablesSnap.empty) {
      console.log("deliverableDeadlineAlerts: no upcoming deliverables");
      return;
    }

    for (const doc of deliverablesSnap.docs) {
      const data = doc.data() as DeliverableDoc;
      const risk = riskLabel(data.statusId, data.dueDate);
      const title = `Deliverable: ${data.name}`;
      const [admins, orgSettings] = await Promise.all([
        fetchAdminRecipients(data.organizationId),
        fetchOrgNotificationSettings(data.organizationId),
      ]);
      const assignees = await fetchAssigneeRecipients(data.assigneeUserIds ?? []);
      const recipients = [...admins, ...assignees];
      if (recipients.length === 0) {
        console.log(`[deliverable-alert] No recipients found for org ${data.organizationId}`);
        continue;
      }

      const daysUntilDue = Math.floor(
        (new Date(data.dueDate).getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
      );
      const shouldAlert =
        daysUntilDue < 0 || orgSettings.leadDays.some((d) => daysUntilDue <= d);
      if (!shouldAlert) {
        continue;
      }

      const alertKey = `${doc.id}_${data.organizationId}`;

      for (const recipient of recipients) {
        const dueLocal = formatDueDate(
          data.dueDate,
          recipient.timezone || orgSettings?.timezone,
        );
        const body = `${risk} • Due ${dueLocal}${data.permitId ? ` • Permit ${data.permitId}` : ""}`;

        const notifyData = {
          deliverableId: doc.id,
          organizationId: data.organizationId,
          permitId: data.permitId ?? "",
          statusId: data.statusId,
          dueDate: data.dueDate,
          risk,
        };

        // idempotency: track lastSentAt per deliverable/user per day
        const lastSentDoc = await getFirestore()
          .collection("users")
          .doc(recipient.uid)
          .collection("deliverable_alerts")
          .doc(alertKey)
          .get();
        const lastSentAt = lastSentDoc.exists ?
          new Date(lastSentDoc.data()?.lastSentAt) :
          undefined;
        if (lastSentAt) {
          const sameDay =
              lastSentAt.toDateString() === now.toDateString();
          if (sameDay) {
            continue;
          }
        }

        // In-app notification
        if (orgSettings.channels.inApp) {
          await notifyUserInApp(recipient.uid, {
            title,
            body,
            ...notifyData,
          });
        }

        // Push notification
        if (orgSettings.channels.push && recipient.fcmToken) {
          try {
            await notifyUserPush(recipient.fcmToken, title, body, {
              ...notifyData,
              deliverableId: doc.id,
              type: "deliverable_due",
            } as Record<string, string>);
          } catch (error) {
            console.error(`[deliverable-alert] push failed for ${recipient.email}`, error);
          }
        }

        // Email fallback
        if (orgSettings.channels.email) {
          try {
            await notifyUserEmail(recipient.email, title, body);
          } catch (error) {
            console.error(`[deliverable-alert] email failed for ${recipient.email}`, error);
          }
        }

        await getFirestore()
          .collection("users")
          .doc(recipient.uid)
          .collection("deliverable_alerts")
          .doc(alertKey)
          .set({lastSentAt: now.toISOString()}, {merge: true});
      }

      console.log(
        `[deliverable-alert] notified ${recipients.length} recipients for deliverable ${doc.id} (${data.name})`
      );
    }
  }
);
