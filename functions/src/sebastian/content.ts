/**
 * Sebastian AI content generation functions
 */

import * as admin from "firebase-admin";
import {randomBytes} from "crypto";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret} from "firebase-functions/params";
import {isFeatureEnabledForOrg} from "../feature_access";
import {
  reserveBudget,
  finalizeUsage,
  releaseReservation,
  getCurrentUsage,
  budgetForTier,
} from "./budget";
import {getCustomPromptForOrg} from "./custom-prompt";
import {sendMessage} from "./gemini-service";
import {checkRateLimit, recordRateLimitRequest} from "./rate-limiter";
import {verifyUserOrganization} from "./auth-validator";
import {validateOrganizationId} from "./input-validator";

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const FIRESTORE_REGION = "us-central1";

interface SebastianGenerateContentRequest {
  organizationId: string;
  prompt: string;
  context?: Record<string, unknown>;
}

async function writeGeneratedContent({
  organizationId,
  content,
  prompt,
  createdById,
  source,
}: {
  organizationId: string;
  content: string;
  prompt: string;
  createdById: string;
  source: "manual" | "weekly";
}) {
  const db = admin.firestore();
  const docId = `sebastian_${Date.now()}_${randomBytes(4).toString("hex")}`;
  await db
    .collection("organizations")
    .doc(organizationId)
    .collection("sebastian_generated_content")
    .doc(docId)
    .set({
      id: docId,
      organizationId,
      prompt,
      content,
      source,
      createdById,
      createdAt: new Date().toISOString(),
    });
}

export const sebastianGenerateContent = onCall(
  {
    region: FIRESTORE_REGION,
    cors: true,
    secrets: [geminiApiKey],
  },
  async (request) => {
    const apiKey = geminiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        "internal",
        "GEMINI_API_KEY secret is not configured. Contact administrator.",
      );
    }

    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to generate content.",
      );
    }

    const userId = request.auth.uid;
    const data = request.data as Partial<SebastianGenerateContentRequest>;
    const organizationId = validateOrganizationId(data.organizationId);
    const prompt = (data.prompt ?? "").toString().trim();

    if (!prompt) {
      throw new HttpsError("invalid-argument", "Prompt is required.");
    }

    await verifyUserOrganization(userId, organizationId);

    await checkRateLimit(organizationId);
    recordRateLimitRequest(organizationId);

    const featureAccess = await isFeatureEnabledForOrg(
      organizationId,
      "ai_copilot",
    );

    if (!featureAccess.enabled) {
      throw new HttpsError(
        "permission-denied",
        "Sebastian AI is not enabled for this organization.",
      );
    }

    const reservation = await reserveBudget(organizationId, featureAccess.tier);
    if (!reservation.success) {
      throw new HttpsError(
        "resource-exhausted",
        reservation.errorMessage ||
          "Monthly AI budget exhausted. Upgrade your plan or wait until next month.",
      );
    }

    try {
      const customPrompt = await getCustomPromptForOrg(organizationId);
      const {content, tokenCount, cost} = await sendMessage(
        [],
        prompt,
        organizationId,
        apiKey,
        undefined,
        customPrompt,
      );

      await finalizeUsage(
        organizationId,
        reservation.reservedCost,
        tokenCount,
        cost,
        reservation.reservationMonth,
      );

      await writeGeneratedContent({
        organizationId,
        content,
        prompt,
        createdById: userId,
        source: "manual",
      });

      const usage = await getCurrentUsage(organizationId);
      const budgetLimit = budgetForTier(featureAccess.tier);

      return {
        content,
        tokenCount,
        cost,
        timestamp: new Date().toISOString(),
        usageRemaining: {
          totalCost: usage.totalCost,
          budgetLimit,
          percentageUsed: (usage.totalCost / budgetLimit) * 100,
        },
      };
    } catch (error) {
      try {
        await releaseReservation(
          organizationId,
          reservation.reservedCost,
          reservation.reservationMonth,
        );
      } catch (releaseError) {
        console.error("Failed to release budget reservation:", releaseError);
      }
      console.error("Error in sebastianGenerateContent:", error);
      throw error instanceof HttpsError
        ? error
        : new HttpsError("internal", "Failed to generate content.");
    }
  },
);

export const sebastianWeeklyContentGeneration = onSchedule(
  {
    schedule: "0 5 * * 1",
    region: FIRESTORE_REGION,
    secrets: [geminiApiKey],
  },
  async () => {
    const apiKey = geminiApiKey.value();
    if (!apiKey) {
      console.error("GEMINI_API_KEY secret is not configured.");
      return;
    }

    const db = admin.firestore();
    const orgsSnap = await db.collection("organizations").get();

    for (const orgDoc of orgsSnap.docs) {
      const orgData = orgDoc.data();
      const organizationId = orgDoc.id;
      const orgName = orgData.name?.toString() ?? "your organization";
      const sebastianConfig = orgData.sebastianConfig as {
        weeklyContentEnabled?: boolean;
      } | undefined;

      if (!sebastianConfig?.weeklyContentEnabled) {
        continue;
      }

      const featureAccess = await isFeatureEnabledForOrg(
        organizationId,
        "ai_copilot",
      );
      if (!featureAccess.enabled) {
        continue;
      }

      const reservation = await reserveBudget(organizationId, featureAccess.tier);
      if (!reservation.success) {
        console.warn(
          `Weekly content skipped for ${organizationId}: ${reservation.errorMessage}`,
        );
        continue;
      }

      try {
        const customPrompt = await getCustomPromptForOrg(organizationId);
        const prompt =
          `Create a weekly restoration update for ${orgName}. ` +
          "Include 3 highlights, 3 recommendations, and a short call-to-action. " +
          "Keep it under 200 words and use a friendly, professional tone.";

        const {content, tokenCount, cost} = await sendMessage(
          [],
          prompt,
          organizationId,
          apiKey,
          undefined,
          customPrompt,
        );

        await finalizeUsage(
          organizationId,
          reservation.reservedCost,
          tokenCount,
          cost,
          reservation.reservationMonth,
        );

        await writeGeneratedContent({
          organizationId,
          content,
          prompt,
          createdById: "system",
          source: "weekly",
        });
      } catch (error) {
        try {
          await releaseReservation(
            organizationId,
            reservation.reservedCost,
            reservation.reservationMonth,
          );
        } catch (releaseError) {
          console.error("Failed to release reservation:", releaseError);
        }
        console.error(
          `Weekly content generation failed for ${organizationId}:`,
          error,
        );
      }
    }
  },
);
