/**
 * Sebastian AI chat streaming Cloud Function
 * HTTP endpoint for streaming AI responses via SSE
 */

import {onRequest, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {SebastianChatRequest} from "../models/sebastian";
import {isFeatureEnabledForOrg, Tier} from "../feature_access";
import {sendMessageStream} from "./gemini-service";
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
import {setupSSEHeaders, sendSSEError, sendSSEComplete} from "./sse-utils";
import {getCorsOrigins} from "../cors";
import {getCustomPromptForOrg} from "./custom-prompt";

// Define Gemini API key secret
const geminiApiKey = defineSecret("GEMINI_API_KEY");

/**
 * Extract and verify Bearer token from Authorization header
 */
async function verifyAuthToken(authHeader: string | undefined): Promise<string> {
  if (!authHeader) {
    throw new HttpsError(
      "unauthenticated",
      "Missing Authorization header"
    );
  }

  const parts = authHeader.split("Bearer ");
  if (parts.length !== 2) {
    throw new HttpsError(
      "unauthenticated",
      "Invalid Authorization header format. Expected: Bearer <token>"
    );
  }

  const idToken = parts[1];

  try {
    // Verify Firebase ID token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    return decodedToken.uid;
  } catch (error) {
    console.error("Token verification failed:", {
      error: error instanceof Error ? {
        name: error.name,
        message: error.message,
      } : error,
      timestamp: new Date().toISOString(),
      // Intentionally not logging the token itself for security
    });
    throw new HttpsError(
      "unauthenticated",
      "Invalid or expired authentication token"
    );
  }
}

/**
 * Sebastian chat streaming HTTP endpoint
 * Streams AI responses via Server-Sent Events (SSE)
 */
export const sebastianChatStream = onRequest(
  {
    region: "us-central1",
    cors: getCorsOrigins(),
    secrets: [geminiApiKey],
  },
  async (req, res) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    // Only allow POST requests
    if (req.method !== "POST") {
      res.status(405).json({error: "Method not allowed. Use POST."});
      return;
    }

    // Setup SSE headers
    setupSSEHeaders(res);

    // Declare variables at function scope for error logging context
    let conversationId: string | undefined;
    let userId: string | undefined;
    let organizationId: string | undefined;
    let tier: Tier | undefined;
    let messageLength: number | undefined;
    let historyCount: number | undefined;

    try {
      // Get the API key from secret
      const apiKey = geminiApiKey.value();
      if (!apiKey) {
        sendSSEError(res, "GEMINI_API_KEY secret is not configured", "internal");
        return;
      }

      // Verify authentication
      userId = await verifyAuthToken(req.headers.authorization);

      // Parse request body
      const data = req.body as Partial<SebastianChatRequest>;

      // Validate and sanitize organization ID
      organizationId = validateOrganizationId(data.organizationId);

      // Verify user authorization
      await verifyUserOrganization(userId, organizationId);

      // Rate limiting check
      await checkRateLimit(organizationId);
      recordRateLimitRequest(organizationId);

      // Validate and sanitize user message
      const userMessage = sanitizeMessage(data.userMessage);
      messageLength = userMessage.length;

      // Validate conversation ID (for logging/tracking purposes)
      conversationId = validateConversationId(data.conversationId);

      // Validate conversation history
      const conversationHistory = validateConversationHistory(
        data.conversationHistory || []
      );
      historyCount = conversationHistory.length;

      // Extract context if provided
      const context = data.context as {
        organizationId: string;
        organizationName: string;
        tier: string;
        userId: string;
        userName: string;
        userRole?: string;
        currentScreen?: string;
        currentNodeId?: string;
        currentNodeType?: string;
        supportedOrganisms?: string[];
        metadata?: Record<string, unknown>;
      } | undefined;

      // Feature access check
      const featureAccess = await isFeatureEnabledForOrg(
        organizationId,
        "ai_copilot"
      );

      if (!featureAccess.enabled) {
        sendSSEError(
          res,
          "Sebastian AI is not enabled for this organization. Upgrade your plan to access AI features.",
          "permission-denied"
        );
        return;
      }

      // Budget reservation with optimistic locking
      tier = featureAccess.tier;
      if (!tier) {
        sendSSEError(res, "Unable to determine organization tier", "internal");
        return;
      }
      const reservation = await reserveBudget(organizationId, tier);
      let reservationFinalized = false;

      if (!reservation.success) {
        sendSSEError(
          res,
          reservation.errorMessage ||
            "Monthly AI budget exhausted. Upgrade your plan or wait until next month.",
          "resource-exhausted"
        );
        return;
      }

      try {
        // Fetch custom prompt if configured for this organization
        const customPrompt = await getCustomPromptForOrg(organizationId);

        // Call Gemini with streaming, context, and custom prompt
        const {tokenCount, cost} = await sendMessageStream(
          conversationHistory,
          userMessage,
          organizationId,
          apiKey,
          res,
          context, // Pass context for context-aware responses
          customPrompt // Pass custom prompt if configured
        );

        // Finalize usage - adjusts reserved cost to actual cost
        await finalizeUsage(
          organizationId,
          reservation.reservedCost,
          tokenCount,
          cost,
          reservation.reservationMonth
        );
        reservationFinalized = true;

        // Get updated usage
        const usage = await getCurrentUsage(organizationId);
        const budgetLimit = budgetForTier(tier);

        // Send completion event with metadata
        sendSSEComplete(res, {
          tokenCount,
          cost,
          timestamp: new Date().toISOString(),
          usageRemaining: {
            totalCost: usage.totalCost,
            budgetLimit,
            percentageUsed: (usage.totalCost / budgetLimit) * 100,
          },
        });
      } catch (streamError) {
        if (!reservationFinalized) {
          try {
            await releaseReservation(
              organizationId,
              reservation.reservedCost,
              reservation.reservationMonth
            );
          } catch (releaseError) {
            console.error("Failed to release budget reservation:", releaseError);
          }
        }
        throw streamError;
      }
    } catch (error) {
      // Log error with full context for debugging
      console.error("Error in sebastianChatStream:", {
        error: error instanceof Error ? {
          name: error.name,
          message: error.message,
          stack: error.stack,
        } : error,
        timestamp: new Date().toISOString(),
        request: {
          method: req.method,
          path: req.path,
        },
        context: {
          userId,
          organizationId,
          conversationId,
          tier,
          messageLength,
          historyCount,
        },
      });

      // Handle HttpsError from validation/auth
      if (error instanceof HttpsError) {
        sendSSEError(res, error.message, error.code);
        return;
      }

      // Handle unexpected errors
      const errorMessage = error instanceof Error ?
        error.message :
        "An unexpected error occurred while processing your request";

      sendSSEError(res, errorMessage, "internal");
    }
  }
);
