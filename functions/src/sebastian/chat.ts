/**
 * Sebastian AI chat Cloud Function
 * Main callable function for Sebastian AI chatbot
 */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {randomBytes} from "crypto";
import {SebastianChatRequest, SebastianChatResponse} from "../models/sebastian";
import {isFeatureEnabledForOrg} from "../feature_access";
import {sendMessage} from "./gemini-service";
import {getCustomPromptForOrg} from "./custom-prompt";
import {
  reserveBudget,
  finalizeUsage,
  releaseReservation,
  getCurrentUsage,
  budgetForTier,
} from "./budget";
import {
  sanitizeMessage,
  validateConversationHistory,
  validateConversationId,
  validateOrganizationId,
} from "./input-validator";
import {checkRateLimit, recordRateLimitRequest} from "./rate-limiter";
import {verifyUserOrganization} from "./auth-validator";

// Define Gemini API key secret
const geminiApiKey = defineSecret("GEMINI_API_KEY");

/**
 * Sebastian chat callable function
 * Handles user messages and returns AI responses
 */
export const sebastianChat = onCall(
  {
    region: "us-central1",
    cors: true,
    secrets: [geminiApiKey],
  },
  async (request) => {
    // Get the API key from secret
    const apiKey = geminiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        "internal",
        "GEMINI_API_KEY secret is not configured. Contact administrator."
      );
    }
    // Authentication check
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to use Sebastian AI"
      );
    }

    const userId = request.auth.uid;

    // Request validation
    const data = request.data as Partial<SebastianChatRequest>;

    // Validate and sanitize organization ID
    const organizationId = validateOrganizationId(data.organizationId);

    // Verify user authorization - user must belong to the organization
    await verifyUserOrganization(userId, organizationId);

    // Rate limiting check
    await checkRateLimit(organizationId);
    recordRateLimitRequest(organizationId);

    // Validate and sanitize user message
    const userMessage = sanitizeMessage(data.userMessage);

    // Validate conversation ID
    const conversationId = validateConversationId(data.conversationId);

    // Validate conversation history
    const conversationHistory = validateConversationHistory(
      data.conversationHistory || []
    );

    // Feature access check - use ai_copilot (defined in tier_features.yaml)
    const featureAccess = await isFeatureEnabledForOrg(
      organizationId,
      "ai_copilot"
    );

    if (!featureAccess.enabled) {
      throw new HttpsError(
        "permission-denied",
        "Sebastian AI is not enabled for this organization. Upgrade your plan to access AI features."
      );
    }

    // Budget reservation with optimistic locking
    // This atomically reserves estimated budget BEFORE the AI call
    // to prevent race conditions where concurrent requests exceed limits
    const tier = featureAccess.tier;
    const reservation = await reserveBudget(organizationId, tier);

    if (!reservation.success) {
      throw new HttpsError(
        "resource-exhausted",
        reservation.errorMessage ||
          "Monthly AI budget exhausted. Upgrade your plan or wait until next month."
      );
    }

    try {
      // Fetch custom prompt if configured for this organization
      const customPrompt = await getCustomPromptForOrg(organizationId);

      // Call Gemini via gemini-service with custom prompt
      const {content, tokenCount, cost} = await sendMessage(
        conversationHistory,
        userMessage,
        organizationId,
        apiKey,
        undefined, // context - not passed in non-streaming call
        customPrompt // custom prompt if configured
      );

      // Finalize usage - adjusts reserved cost to actual cost
      // Pass reservationMonth to handle month boundary edge case
      await finalizeUsage(
        organizationId,
        reservation.reservedCost,
        tokenCount,
        cost,
        reservation.reservationMonth
      );

      // Get updated usage
      const usage = await getCurrentUsage(organizationId);
      const budgetLimit = budgetForTier(tier);

      // Generate response message ID using cryptographically secure random bytes
      const messageId = `msg_${Date.now()}_${randomBytes(6).toString("hex")}`;

      const response: SebastianChatResponse = {
        messageId,
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

      return response;
    } catch (error) {
      // Release the budget reservation since the AI call failed
      // This returns the reserved amount back to the organization's budget
      // Pass reservationMonth to handle month boundary edge case
      try {
        await releaseReservation(
          organizationId,
          reservation.reservedCost,
          reservation.reservationMonth
        );
      } catch (releaseError) {
        // Log but don't fail on release error - the main error is more important
        console.error("Failed to release budget reservation:", releaseError);
      }

      // Log error with context
      console.error("Error in sebastianChat:", {
        error,
        userId,
        organizationId,
        conversationId,
      });

      // Re-throw HttpsError (includes validation and rate limit errors)
      if (error instanceof HttpsError) {
        throw error;
      }

      // Handle unexpected errors
      const errorMessage = error instanceof Error ?
        error.message :
        "An unexpected error occurred while processing your request";

      throw new HttpsError(
        "internal",
        errorMessage
      );
    }
  }
);
