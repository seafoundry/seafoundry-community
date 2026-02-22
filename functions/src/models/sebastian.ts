/**
 * Sebastian AI model interfaces for Cloud Functions
 */

export type SebastianMessageRole = "user" | "assistant" | "system";

export interface SebastianMessage {
  id: string;
  conversationId: string;
  role: SebastianMessageRole;
  content: string;
  createdAt: string;
  groundingSources?: string[];
  tokenCount?: number;
  cost?: number;
}

export interface SebastianUsage {
  organizationId: string;
  yearMonth: string;
  totalTokens: number;
  totalCost: number;
  conversationCount: number;
  messageCount: number;
}

export interface SebastianContext {
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
}

export interface SebastianChatRequest {
  conversationId: string;
  userMessage: string;
  conversationHistory: SebastianMessage[];
  organizationId: string;
  context?: SebastianContext;
}

export interface SebastianChatResponse {
  messageId: string;
  content: string;
  tokenCount: number;
  cost: number;
  timestamp: string;
  usageRemaining: {
    totalCost: number;
    budgetLimit: number;
    percentageUsed: number;
  };
}
