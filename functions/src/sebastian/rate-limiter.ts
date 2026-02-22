/**
 * Rate limiting for Sebastian AI
 * Prevents abuse by enforcing per-organization request limits
 */

import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";

/**
 * In-memory fallback rate limiter for when Firestore is unavailable.
 * This provides basic protection during infrastructure issues.
 */
interface InMemoryRateLimit {
  count: number;
  resetAt: number;
}

const inMemoryLimits = new Map<string, InMemoryRateLimit>();
const IN_MEMORY_WINDOW_MS = 60 * 1000; // 1 minute
const IN_MEMORY_MAX_REQUESTS = 15; // Slightly more permissive fallback

/**
 * Memory protection constants for in-memory rate limiter
 */
const MAX_ORG_ID_LENGTH = 100;
const MAX_MEMORY_ENTRIES = 10000;
const ORG_ID_PATTERN = /^[a-zA-Z0-9._-]+$/;

/**
 * Validates organizationId format to prevent memory attacks
 */
function isValidOrgId(orgId: string): boolean {
  return (
    typeof orgId === "string" &&
    orgId.length > 0 &&
    orgId.length <= MAX_ORG_ID_LENGTH &&
    ORG_ID_PATTERN.test(orgId)
  );
}

/**
 * Cleans up stale entries from in-memory rate limiter
 * Called when map approaches capacity or periodically
 */
function cleanupStaleEntries(): void {
  const now = Date.now();
  for (const [key, value] of inMemoryLimits.entries()) {
    if (value.resetAt < now) {
      inMemoryLimits.delete(key);
    }
  }
}

/**
 * Rate limit windows and thresholds
 */
const RATE_LIMITS = {
  perMinute: {
    window: 60 * 1000, // 1 minute in milliseconds
    maxRequests: 10,
  },
  perHour: {
    window: 60 * 60 * 1000, // 1 hour in milliseconds
    maxRequests: 100,
  },
};

/**
 * Rate limit tracking document structure
 */
interface RateLimitRecord {
  organizationId: string;
  minuteWindow: {
    startTime: number;
    requestCount: number;
  };
  hourWindow: {
    startTime: number;
    requestCount: number;
  };
  lastUpdated: number;
}

/**
 * Check if organization has exceeded rate limits
 * Returns true if request is allowed, throws HttpsError if rate limited
 */
export async function checkRateLimit(organizationId: string): Promise<boolean> {
  const now = Date.now();
  const rateLimitRef = admin
    .firestore()
    .collection("sebastian_rate_limits")
    .doc(organizationId);

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(rateLimitRef);
      const data = doc.exists ? (doc.data() as RateLimitRecord) : null;

      // Initialize or reset windows as needed
      const minuteWindowStart = data?.minuteWindow?.startTime || 0;
      const hourWindowStart = data?.hourWindow?.startTime || 0;

      const minuteWindowAge = now - minuteWindowStart;
      const hourWindowAge = now - hourWindowStart;

      // Check if windows need to be reset
      const resetMinuteWindow = minuteWindowAge >= RATE_LIMITS.perMinute.window;
      const resetHourWindow = hourWindowAge >= RATE_LIMITS.perHour.window;

      const currentMinuteCount = resetMinuteWindow ? 0 : (data?.minuteWindow?.requestCount || 0);
      const currentHourCount = resetHourWindow ? 0 : (data?.hourWindow?.requestCount || 0);

      // Check rate limits
      if (currentMinuteCount >= RATE_LIMITS.perMinute.maxRequests) {
        const resetIn = Math.ceil(
          (RATE_LIMITS.perMinute.window - minuteWindowAge) / 1000
        );
        throw new HttpsError(
          "resource-exhausted",
          `Rate limit exceeded: ${RATE_LIMITS.perMinute.maxRequests} requests per minute. Try again in ${resetIn} seconds.`
        );
      }

      if (currentHourCount >= RATE_LIMITS.perHour.maxRequests) {
        const resetIn = Math.ceil(
          (RATE_LIMITS.perHour.window - hourWindowAge) / 60000
        );
        throw new HttpsError(
          "resource-exhausted",
          `Rate limit exceeded: ${RATE_LIMITS.perHour.maxRequests} requests per hour. Try again in ${resetIn} minutes.`
        );
      }

      // Update rate limit counters
      const updatedRecord: RateLimitRecord = {
        organizationId,
        minuteWindow: {
          startTime: resetMinuteWindow ? now : minuteWindowStart,
          requestCount: currentMinuteCount + 1,
        },
        hourWindow: {
          startTime: resetHourWindow ? now : hourWindowStart,
          requestCount: currentHourCount + 1,
        },
        lastUpdated: now,
      };

      transaction.set(rateLimitRef, updatedRecord);

      return true;
    });

    return result;
  } catch (error) {
    // Re-throw HttpsError rate limit errors
    if (error instanceof HttpsError) {
      throw error;
    }

    // Firestore unavailable - use in-memory fallback rate limiting
    console.error("Firestore rate limit check failed, using in-memory fallback:", error);
    return checkInMemoryRateLimit(organizationId);
  }
}

/**
 * In-memory fallback rate limiter for when Firestore is unavailable.
 * Provides basic protection during infrastructure outages.
 * Includes protections against memory exhaustion attacks.
 */
function checkInMemoryRateLimit(organizationId: string): boolean {
  // Validate organizationId to prevent memory attacks with fake IDs
  if (!isValidOrgId(organizationId)) {
    console.warn(`Invalid organizationId format rejected: ${organizationId?.substring(0, 50)}`);
    throw new HttpsError(
      "invalid-argument",
      "Invalid organization identifier"
    );
  }

  const now = Date.now();
  const limit = inMemoryLimits.get(organizationId);

  // Check if within existing window and over limit
  if (limit && limit.resetAt > now) {
    if (limit.count >= IN_MEMORY_MAX_REQUESTS) {
      const resetIn = Math.ceil((limit.resetAt - now) / 1000);
      throw new HttpsError(
        "resource-exhausted",
        `Rate limit exceeded (fallback mode). Try again in ${resetIn} seconds.`
      );
    }
    // Increment counter
    limit.count++;
  } else {
    // Before adding new entry, check capacity and cleanup if needed
    if (inMemoryLimits.size >= MAX_MEMORY_ENTRIES) {
      cleanupStaleEntries();

      // If still at capacity after cleanup, reject new entries
      if (inMemoryLimits.size >= MAX_MEMORY_ENTRIES) {
        console.warn(`In-memory rate limiter at capacity (${MAX_MEMORY_ENTRIES}), rejecting new entry`);
        throw new HttpsError(
          "resource-exhausted",
          "Service temporarily unavailable. Please try again later."
        );
      }
    }

    // Start new window
    inMemoryLimits.set(organizationId, {
      count: 1,
      resetAt: now + IN_MEMORY_WINDOW_MS,
    });
  }

  // Cleanup old entries periodically (every ~100 requests)
  if (Math.random() < 0.01) {
    cleanupStaleEntries();
  }

  return true;
}

/**
 * Record a rate limit request (for metrics/monitoring)
 * Non-blocking, fire-and-forget
 */
export function recordRateLimitRequest(organizationId: string): void {
  const metricsRef = admin
    .firestore()
    .collection("sebastian_metrics")
    .doc(organizationId);

  // Fire-and-forget increment
  metricsRef
    .set(
      {
        organizationId,
        totalRequests: admin.firestore.FieldValue.increment(1),
        lastRequestAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    )
    .catch((error) => {
      console.error("Error recording rate limit metrics:", error);
      // Don't throw - this is non-critical
    });
}

/**
 * Reset rate limits for an organization (admin function)
 * Useful for testing or resolving customer issues
 */
export async function resetRateLimit(organizationId: string): Promise<void> {
  const rateLimitRef = admin
    .firestore()
    .collection("sebastian_rate_limits")
    .doc(organizationId);

  await rateLimitRef.delete();
}
