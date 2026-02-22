/**
 * Sebastian AI budget management
 *
 * Uses optimistic locking with Firestore transactions to prevent
 * race conditions where concurrent requests could exceed monthly budgets.
 */

import * as admin from "firebase-admin";
import {Tier} from "../feature_access";
import {SebastianUsage} from "../models/sebastian";

const USAGE_COLLECTION = "sebastian_usage";

/**
 * Estimated cost per AI request for budget reservation.
 * This is a conservative estimate used for optimistic locking.
 * Actual costs are typically lower and get adjusted after the call.
 */
const ESTIMATED_REQUEST_COST = 0.01; // $0.01 per request estimate

/**
 * Get budget limit for organization tier
 * Community: $1/month, Pro: $10/month, Scale: $50/month
 */
export function budgetForTier(tier: Tier): number {
  switch (tier) {
  case "community":
    return 1.0;
  case "pro":
    return 10.0;
  case "scale":
    return 50.0;
  default:
    return 1.0;
  }
}

/**
 * Get current month in YYYY-MM format
 */
export function getCurrentMonth(): string {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

/**
 * Get current usage for organization
 */
export async function getCurrentUsage(
  organizationId: string
): Promise<SebastianUsage> {
  const yearMonth = getCurrentMonth();
  const docId = `${organizationId}_${yearMonth}`;

  const doc = await admin
    .firestore()
    .collection(USAGE_COLLECTION)
    .doc(docId)
    .get();

  if (!doc.exists || !doc.data()) {
    return {
      organizationId,
      yearMonth,
      totalTokens: 0,
      totalCost: 0,
      conversationCount: 0,
      messageCount: 0,
    };
  }

  const data = doc.data();
  if (!data) {
    // This case should be caught by !doc.data() earlier, but for safety
    return {
      organizationId,
      yearMonth,
      totalTokens: 0,
      totalCost: 0,
      conversationCount: 0,
      messageCount: 0,
    };
  }
  return {
    organizationId: data.organizationId || organizationId,
    yearMonth: data.yearMonth || yearMonth,
    totalTokens: data.totalTokens || 0,
    totalCost: data.totalCost || 0,
    conversationCount: data.conversationCount || 0,
    messageCount: data.messageCount || 0,
  };
}

/**
 * Check if organization can make request within budget
 */
export async function canMakeRequest(
  organizationId: string,
  tier: Tier
): Promise<boolean> {
  const usage = await getCurrentUsage(organizationId);
  const budget = budgetForTier(tier);
  return usage.totalCost < budget;
}

/**
 * Record usage for organization (atomic increment)
 * @deprecated Use reserveBudget/finalizeUsage for race-condition-safe budget enforcement
 */
export async function recordUsage(
  organizationId: string,
  tokenCount: number,
  cost: number
): Promise<void> {
  const yearMonth = getCurrentMonth();
  const docId = `${organizationId}_${yearMonth}`;

  await admin
    .firestore()
    .collection(USAGE_COLLECTION)
    .doc(docId)
    .set(
      {
        organizationId,
        yearMonth,
        totalTokens: admin.firestore.FieldValue.increment(tokenCount),
        totalCost: admin.firestore.FieldValue.increment(cost),
        messageCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
}

/**
 * Result of a budget reservation attempt
 */
export interface BudgetReservation {
  /** Whether the reservation was successful */
  success: boolean;
  /** The estimated cost that was reserved */
  reservedCost: number;
  /** Current total cost after reservation */
  currentTotalCost: number;
  /** Budget limit for the tier */
  budgetLimit: number;
  /** Error message if reservation failed */
  errorMessage?: string;
  /**
   * The month (YYYY-MM format) when the reservation was made.
   * Pass this to finalizeUsage() or releaseReservation() to ensure
   * the finalization writes to the same document as the reservation,
   * even if the month changes between reservation and finalization.
   */
  reservationMonth?: string;
}

/**
 * Atomically reserve budget for an AI request using Firestore transaction.
 *
 * This function performs an optimistic lock by:
 * 1. Reading current usage within a transaction
 * 2. Checking if estimated request cost would exceed budget
 * 3. Reserving the estimated cost atomically if within budget
 *
 * This prevents race conditions where concurrent requests could
 * both pass budget checks and exceed the monthly limit.
 *
 * ## Month Boundary Edge Case
 *
 * If a reservation is made at 23:59:59 UTC on the last day of a month and
 * finalized at 00:00:01 UTC the next day, `finalizeUsage()` would normally
 * write to a different document (the new month's docId) than where the
 * reservation was made. This would result in:
 * - The old month having an unfinalized pending cost
 * - The new month having incorrect adjustments
 *
 * To prevent this, the returned `BudgetReservation.reservationMonth` should
 * be passed to `finalizeUsage()` or `releaseReservation()` to ensure the
 * finalization targets the same document as the reservation.
 *
 * @param organizationId - The organization making the request
 * @param tier - The organization's subscription tier
 * @param estimatedCost - Optional custom estimated cost (defaults to ESTIMATED_REQUEST_COST)
 * @returns BudgetReservation result with success status, reserved amount, and reservationMonth
 */
export async function reserveBudget(
  organizationId: string,
  tier: Tier,
  estimatedCost: number = ESTIMATED_REQUEST_COST
): Promise<BudgetReservation> {
  const yearMonth = getCurrentMonth();
  const docId = `${organizationId}_${yearMonth}`;
  const budgetLimit = budgetForTier(tier);

  const db = admin.firestore();
  const docRef = db.collection(USAGE_COLLECTION).doc(docId);

  try {
    const result = await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(docRef);

      let currentTotalCost = 0;
      let currentTotalTokens = 0;
      let currentMessageCount = 0;
      let currentConversationCount = 0;

      if (doc.exists) {
        const data = doc.data();
        currentTotalCost = data?.totalCost || 0;
        currentTotalTokens = data?.totalTokens || 0;
        currentMessageCount = data?.messageCount || 0;
        currentConversationCount = data?.conversationCount || 0;
      }

      // Check if adding estimated cost would exceed budget
      const projectedCost = currentTotalCost + estimatedCost;
      if (projectedCost > budgetLimit) {
        // Budget would be exceeded - don't reserve
        return {
          success: false,
          reservedCost: 0,
          currentTotalCost,
          budgetLimit,
          reservationMonth: yearMonth,
          errorMessage: "Monthly AI budget exhausted. " +
            "Upgrade your plan or wait until next month.",
        };
      }

      // Reserve the estimated cost by incrementing totalCost atomically
      // Using FieldValue.increment() ensures concurrent transactions properly
      // conflict and retry, preventing lost updates from race conditions.
      // Also increment a pendingCost field to track in-flight reservations
      transaction.set(
        docRef,
        {
          organizationId,
          yearMonth,
          totalTokens: currentTotalTokens,
          totalCost: admin.firestore.FieldValue.increment(estimatedCost),
          messageCount: currentMessageCount,
          conversationCount: currentConversationCount,
          pendingCost: admin.firestore.FieldValue.increment(estimatedCost),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );

      return {
        success: true,
        reservedCost: estimatedCost,
        currentTotalCost: projectedCost,
        budgetLimit,
        reservationMonth: yearMonth,
      };
    });

    return result;
  } catch (error) {
    console.error("Error reserving budget:", error);
    return {
      success: false,
      reservedCost: 0,
      currentTotalCost: 0,
      budgetLimit,
      reservationMonth: yearMonth,
      errorMessage: "Failed to reserve budget. Please try again.",
    };
  }
}

/**
 * Finalize usage after AI request completes.
 *
 * This adjusts the reserved budget to reflect actual usage:
 * - If actual cost < reserved: refunds the difference
 * - If actual cost > reserved: charges the difference
 * - Updates token count and message count
 *
 * ## Month Boundary Edge Case
 *
 * If a reservation was made near the end of a month (e.g., 23:59:59 UTC)
 * and finalization happens after midnight (e.g., 00:00:01 UTC the next day),
 * this function would write to a different document than where the reservation
 * was made unless `reservationMonth` is provided.
 *
 * **Always pass `BudgetReservation.reservationMonth` from `reserveBudget()`**
 * to ensure the finalization targets the correct document.
 *
 * @param organizationId - The organization that made the request
 * @param reservedCost - The cost that was reserved via reserveBudget()
 * @param actualTokenCount - The actual token count from the AI response
 * @param actualCost - The actual cost from the AI response
 * @param reservationMonth - The month (YYYY-MM) from BudgetReservation.reservationMonth.
 *                           If not provided, uses current month (may cause issues at month boundaries).
 */
export async function finalizeUsage(
  organizationId: string,
  reservedCost: number,
  actualTokenCount: number,
  actualCost: number,
  reservationMonth?: string
): Promise<void> {
  const yearMonth = reservationMonth ?? getCurrentMonth();
  const docId = `${organizationId}_${yearMonth}`;

  // Calculate the adjustment needed
  // Positive = we need to charge more, Negative = we need to refund
  const costAdjustment = actualCost - reservedCost;

  await admin
    .firestore()
    .collection(USAGE_COLLECTION)
    .doc(docId)
    .set(
      {
        organizationId,
        yearMonth,
        totalTokens: admin.firestore.FieldValue.increment(actualTokenCount),
        totalCost: admin.firestore.FieldValue.increment(costAdjustment),
        messageCount: admin.firestore.FieldValue.increment(1),
        // Decrease pending cost by the reserved amount (it's now finalized)
        pendingCost: admin.firestore.FieldValue.increment(-reservedCost),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
}

/**
 * Release a budget reservation without recording any usage.
 *
 * Use this when an AI request fails after budget was reserved,
 * to return the reserved amount back to the budget.
 *
 * ## Month Boundary Edge Case
 *
 * If a reservation was made near the end of a month (e.g., 23:59:59 UTC)
 * and release happens after midnight (e.g., 00:00:01 UTC the next day),
 * this function would write to a different document than where the reservation
 * was made unless `reservationMonth` is provided.
 *
 * **Always pass `BudgetReservation.reservationMonth` from `reserveBudget()`**
 * to ensure the release targets the correct document.
 *
 * @param organizationId - The organization that made the reservation
 * @param reservedCost - The cost that was reserved via reserveBudget()
 * @param reservationMonth - The month (YYYY-MM) from BudgetReservation.reservationMonth.
 *                           If not provided, uses current month (may cause issues at month boundaries).
 */
export async function releaseReservation(
  organizationId: string,
  reservedCost: number,
  reservationMonth?: string
): Promise<void> {
  const yearMonth = reservationMonth ?? getCurrentMonth();
  const docId = `${organizationId}_${yearMonth}`;

  await admin
    .firestore()
    .collection(USAGE_COLLECTION)
    .doc(docId)
    .set(
      {
        organizationId,
        yearMonth,
        // Refund the reserved cost
        totalCost: admin.firestore.FieldValue.increment(-reservedCost),
        // Decrease pending cost
        pendingCost: admin.firestore.FieldValue.increment(-reservedCost),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
}
