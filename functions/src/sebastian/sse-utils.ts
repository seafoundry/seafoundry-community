/**
 * SSE utilities for streaming responses
 */
import {Response} from "express";

export interface SSEMessage {
  event?: string;
  data: string;
  id?: string;
}

/**
 * Format data as SSE message
 */
export function formatSSE(message: SSEMessage): string {
  let formatted = "";
  if (message.event) {
    formatted += `event: ${message.event}\n`;
  }
  if (message.id) {
    formatted += `id: ${message.id}\n`;
  }
  formatted += `data: ${message.data}\n\n`;
  return formatted;
}

/**
 * Setup response headers for SSE
 */
export function setupSSEHeaders(res: Response): void {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");
}

/**
 * Send SSE message
 */
export function sendSSE(res: Response, message: SSEMessage): void {
  res.write(formatSSE(message));
}

/**
 * Send error and close stream
 */
export function sendSSEError(res: Response, error: string, code: string): void {
  sendSSE(res, {
    event: "error",
    data: JSON.stringify({error, code}),
  });
  res.end();
}

/**
 * Send completion and close stream
 */
export function sendSSEComplete(res: Response, metadata?: Record<string, unknown>): void {
  sendSSE(res, {
    event: "done",
    data: JSON.stringify(metadata || {}),
  });
  res.end();
}
