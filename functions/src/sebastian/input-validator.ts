/**
 * Input validation for Sebastian AI
 * Protects against prompt injection, excessive inputs, and malformed data
 */

import {HttpsError} from "firebase-functions/v2/https";
import {SebastianMessage} from "../models/sebastian";

/**
 * Custom error class for validation failures
 */
export class ValidationError extends HttpsError {
  constructor(message: string) {
    super("invalid-argument", message);
  }
}

/**
 * Maximum message length to prevent resource exhaustion
 */
const MAX_MESSAGE_LENGTH = 4000;

/**
 * Maximum conversation history to prevent context overflow
 */
const MAX_CONVERSATION_HISTORY = 50;

/**
 * Prompt injection patterns to detect
 */
const PROMPT_INJECTION_PATTERNS = [
  /ignore\s+(all\s+)?previous\s+instructions/i,
  /disregard\s+(all\s+)?previous\s+instructions/i,
  /forget\s+(all\s+)?previous\s+instructions/i,
  /you\s+are\s+now/i,
  /new\s+role/i,
  /system\s*:/i,
  /<\|im_start\|>/i,
  /<\|im_end\|>/i,
  /\[INST\]/i,
  /\[\/INST\]/i,
];

/**
 * Sanitize and validate user message
 * Checks for prompt injection attempts and length limits
 */
export function sanitizeMessage(message: unknown): string {
  if (!message || typeof message !== "string") {
    throw new ValidationError("userMessage is required and must be a string");
  }

  const trimmed = message.trim();

  if (trimmed.length === 0) {
    throw new ValidationError("Message cannot be empty");
  }

  if (trimmed.length > MAX_MESSAGE_LENGTH) {
    throw new ValidationError(
      `Message too long (max ${MAX_MESSAGE_LENGTH} characters)`
    );
  }

  // Check for prompt injection patterns
  for (const pattern of PROMPT_INJECTION_PATTERNS) {
    if (pattern.test(trimmed)) {
      throw new ValidationError(
        "Message contains suspicious patterns and cannot be processed"
      );
    }
  }

  return trimmed;
}

/**
 * Validate conversation history array
 * Ensures history is well-formed and within limits
 */
export function validateConversationHistory(
  history: unknown
): SebastianMessage[] {
  if (!Array.isArray(history)) {
    throw new ValidationError("conversationHistory must be an array");
  }

  if (history.length > MAX_CONVERSATION_HISTORY) {
    throw new ValidationError(
      `conversationHistory too large (max ${MAX_CONVERSATION_HISTORY} messages)`
    );
  }

  const sanitizedHistory: SebastianMessage[] = [];

  // Validate each message in history
  for (let i = 0; i < history.length; i++) {
    const msg = history[i];

    if (!msg || typeof msg !== "object") {
      throw new ValidationError(
        `Invalid message at index ${i}: must be an object`
      );
    }

    const message = msg as Record<string, unknown>;

    if (!message.role || typeof message.role !== "string") {
      throw new ValidationError(
        `Invalid message at index ${i}: role is required and must be a string`
      );
    }

    if (!["user", "assistant", "system"].includes(message.role)) {
      throw new ValidationError(
        `Invalid message at index ${i}: role must be 'user', 'assistant', or 'system'`
      );
    }

    if (typeof message.content !== "string") {
      throw new ValidationError(
        `Invalid message at index ${i}: content is required and must be a string`
      );
    }

    const trimmedContent = message.content.trim();
    if (trimmedContent.length === 0) {
      continue;
    }

    if (trimmedContent.length > MAX_MESSAGE_LENGTH) {
      throw new ValidationError(
        `Invalid message at index ${i}: content exceeds max length`
      );
    }

    // Validate optional id field
    if (message.id !== undefined) {
      if (typeof message.id !== "string" || message.id.trim() === "") {
        throw new ValidationError(
          `Invalid message at index ${i}: id must be a non-empty string`
        );
      }
    }

    // Validate optional createdAt field
    if (message.createdAt !== undefined) {
      if (
        typeof message.createdAt !== "string" ||
        isNaN(Date.parse(message.createdAt))
      ) {
        throw new ValidationError(
          `Invalid message at index ${i}: createdAt must be a valid ISO timestamp`
        );
      }
    }

    // Validate optional tokenCount field
    if (message.tokenCount !== undefined) {
      if (
        typeof message.tokenCount !== "number" ||
        message.tokenCount < 0 ||
        !Number.isInteger(message.tokenCount)
      ) {
        throw new ValidationError(
          `Invalid message at index ${i}: tokenCount must be a non-negative integer`
        );
      }
    }

    const sanitizedMessage = message as unknown as SebastianMessage;
    sanitizedHistory.push({
      ...sanitizedMessage,
      content: trimmedContent,
    });
  }

  return sanitizedHistory;
}

/**
 * Validate conversation ID format
 * Must be alphanumeric with optional hyphens/underscores
 */
export function validateConversationId(conversationId: unknown): string {
  if (typeof conversationId !== "string") {
    throw new ValidationError("conversationId must be a string");
  }

  const trimmed = conversationId.trim();

  if (trimmed.length === 0) {
    throw new ValidationError("conversationId cannot be empty");
  }

  if (trimmed.length > 100) {
    throw new ValidationError("conversationId too long (max 100 characters)");
  }

  // Allow alphanumeric, hyphens, and underscores only
  if (!/^[a-zA-Z0-9_-]+$/.test(trimmed)) {
    throw new ValidationError(
      "conversationId contains invalid characters (only alphanumeric, hyphens, and underscores allowed)"
    );
  }

  return trimmed;
}

/**
 * Validate organization ID format
 * Must be alphanumeric with optional hyphens/underscores
 */
export function validateOrganizationId(organizationId: unknown): string {
  if (typeof organizationId !== "string") {
    throw new ValidationError("organizationId must be a string");
  }

  const trimmed = organizationId.trim();

  if (trimmed.length === 0) {
    throw new ValidationError("organizationId cannot be empty");
  }

  if (trimmed.length > 100) {
    throw new ValidationError("organizationId too long (max 100 characters)");
  }

  // Allow alphanumeric, hyphens, and underscores only
  if (!/^[a-zA-Z0-9_-]+$/.test(trimmed)) {
    throw new ValidationError(
      "organizationId contains invalid characters (only alphanumeric, hyphens, and underscores allowed)"
    );
  }

  return trimmed;
}
