/**
 * Sebastian AI Gemini service
 * Handles communication with Google Gemini API
 */

import {GoogleGenerativeAI, SchemaType, FunctionDeclaration} from "@google/generative-ai";
import {Response} from "express";
import {SebastianMessage} from "../models/sebastian";
import {executeFunctionCall} from "./function-handlers";
import {sendSSE, sendSSEError} from "./sse-utils";

const BASE_SYSTEM_PROMPT = `You are Sebastian, the AI assistant for SeaFoundry - a marine restoration platform.

You help restoration organizations manage their:
- Inventory (organism records, holdings, genets, cohorts, structures, sites, zones, subplots)
- Husbandry logs, environmental events, and monitoring
- Tasks and workflows
- Operations and compliance (missions, permits, deliverables, vessels, funders)

You have access to functions to query the organization's data and SeaFoundry documentation. Use these functions to provide accurate, data-driven answers when questions depend on live org data.

If the answer is not available in org data or help docs, use the web search function to gather current information and cite sources. Be clear about uncertainty and recommend consulting qualified marine biologists or veterinarians for treatment decisions.

Key concepts:
- **Organisms**: SeaFoundry supports coral, kelp, oyster, seagrass, mangrove, echinoid, crab, finfish, and sea cucumber.
- **Holdings**: Inventory of organisms at different life stages
- **Provenance**: Genetic tracking through genets and cohorts
- **Sites**: Physical locations where restoration work happens
- **Five-axis model**: Taxonomy, Provenance, Location/Permit, Life Stage, Measurement
- **Readiness**: Organism records include healthStatus, readyForPropagation, and readyForOutplant flags
- **Knowledge base**: Built-in help docs include coral biology, husbandry, and restoration practices (use searchHelp to surface them)

## Query Filter Behavior
Some query functions have mutually exclusive location filters. When multiple location filters are provided, only the highest-priority filter queries the database; others filter results afterward. Results are still correct, but use the most specific filter for best performance.

Priority chains:
- getOrganismHoldings/getHoldings/getCohorts: siteId > groupId > structureId > genetId/cohortId/provenanceId > speciesId > organismKind
- getGroups: siteId > parentId > groupTypeId
- getSubplots: zoneId > siteId

Always prioritize accuracy over speculation.`;

/**
 * Context information from the client app
 */
interface SebastianContext {
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

/**
 * Build system prompt with optional context
 */
function buildSystemPrompt(context?: SebastianContext, customPrompt?: string): string {
  let prompt = customPrompt || BASE_SYSTEM_PROMPT;

  if (context) {
    prompt += `\n\n## Current Context
- Organization: ${context.organizationName}
- Tier: ${context.tier}
- User: ${context.userName} (${context.userRole || "practitioner"})`;

    if (context.supportedOrganisms && context.supportedOrganisms.length > 0) {
      prompt += `\n- Supported organisms: ${context.supportedOrganisms.join(", ")}`;
    }

    if (context.currentScreen) {
      prompt += `\n- Current screen: ${context.currentScreen}`;
    }

    if (context.currentNodeType) {
      prompt += `\n- Viewing: ${context.currentNodeType}${context.currentNodeId ? ` (ID: ${context.currentNodeId})` : ""}`;
    }

    prompt += `\n\nUse this context to provide more relevant and specific answers. When the user asks about "this site" or "here", refer to the current context.`;
  }

  return prompt;
}

const FUNCTION_DECLARATIONS: FunctionDeclaration[] = [
  {
    name: "getOrganismHoldings",
    description: "Query organism holdings with readiness/health filters. Location filters are mutually exclusive (Priority: siteId > groupId > structureId > genetId > speciesId > organismKind). Only the highest-priority filter queries Firestore; others filter results post-query.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        organismKind: {
          type: SchemaType.STRING,
          description: "Filter by organism type (coral, kelp, oyster, seagrass, mangrove, echinoid, crab, finfish, seaCucumber)",
        },
        lifeStageId: {
          type: SchemaType.STRING,
          description: "Filter by life stage ID (e.g., juvenile, adult)",
        },
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by site ID",
        },
        groupId: {
          type: SchemaType.STRING,
          description: "Filter by group/structure ID",
        },
        structureId: {
          type: SchemaType.STRING,
          description: "Filter by structure ID",
        },
        genetId: {
          type: SchemaType.STRING,
          description: "Filter by genet ID",
        },
        speciesId: {
          type: SchemaType.STRING,
          description: "Filter by species ID",
        },
        readyForPropagation: {
          type: SchemaType.BOOLEAN,
          description: "Filter by ready for propagation flag",
        },
        readyForOutplant: {
          type: SchemaType.BOOLEAN,
          description: "Filter by ready for outplant flag",
        },
        healthStatus: {
          type: SchemaType.STRING,
          description: "Filter by health status id (healthy, stressed, diseased, recovering, etc.)",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of holdings to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getHoldings",
    description: "Query detailed holdings batches. Location filters are mutually exclusive (Priority: siteId > groupId > structureId > cohortId > provenanceId > organismKind). Only the highest-priority filter queries Firestore; others filter post-query.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        organismKind: {
          type: SchemaType.STRING,
          description: "Filter by organism type",
        },
        lifeStageId: {
          type: SchemaType.STRING,
          description: "Filter by life stage ID",
        },
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by site ID",
        },
        groupId: {
          type: SchemaType.STRING,
          description: "Filter by group/structure ID",
        },
        structureId: {
          type: SchemaType.STRING,
          description: "Filter by structure ID",
        },
        provenanceId: {
          type: SchemaType.STRING,
          description: "Filter by provenance ID",
        },
        cohortId: {
          type: SchemaType.STRING,
          description: "Filter by cohort ID",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of holdings to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getCohorts",
    description: "Query cohort records. Location filters are mutually exclusive (Priority: siteId > groupId > structureId > provenanceId > organismKind). Only the highest-priority filter queries Firestore; others filter post-query.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        organismKind: {
          type: SchemaType.STRING,
          description: "Filter by organism type",
        },
        lifeStageId: {
          type: SchemaType.STRING,
          description: "Filter by life stage ID",
        },
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by site ID",
        },
        groupId: {
          type: SchemaType.STRING,
          description: "Filter by group/structure ID",
        },
        structureId: {
          type: SchemaType.STRING,
          description: "Filter by structure ID",
        },
        provenanceId: {
          type: SchemaType.STRING,
          description: "Filter by provenance ID",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of cohorts to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getGenets",
    description: "Get genetic individuals (genets) tracked by the organization",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        organismKind: {
          type: SchemaType.STRING,
          description: "Filter by organism type",
        },
        searchAlias: {
          type: SchemaType.STRING,
          description: "Search by genet alias",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of genets to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getGroups",
    description: "Query groups/structures. Filters are mutually exclusive (Priority: siteId > parentId > groupTypeId). Only the highest-priority filter queries Firestore; others filter post-query.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by site ID",
        },
        parentId: {
          type: SchemaType.STRING,
          description: "Filter by parent group ID",
        },
        groupTypeId: {
          type: SchemaType.STRING,
          description: "Filter by group type ID",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of groups to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getZones",
    description: "Get zones for outplanting sites",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by site ID",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of zones to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getSubplots",
    description: "Query subplots. Filters are mutually exclusive (Priority: zoneId > siteId). Only the highest-priority filter queries Firestore; the other filters post-query.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by site ID",
        },
        zoneId: {
          type: SchemaType.STRING,
          description: "Filter by zone ID",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of subplots to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getSites",
    description: "Get sites/locations managed by the organization",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        siteType: {
          type: SchemaType.STRING,
          description: "Filter by site type ID",
        },
        includeArchived: {
          type: SchemaType.BOOLEAN,
          description: "Include archived sites (default false)",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of sites to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getTasks",
    description: "Get tasks for the organization",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        status: {
          type: SchemaType.STRING,
          description: "Filter by task status ID (not_started, in_progress, completed)",
        },
        assignedUserId: {
          type: SchemaType.STRING,
          description: "Filter by assigned user ID",
        },
        assignedRoleId: {
          type: SchemaType.STRING,
          description: "Filter by assigned role ID",
        },
        recordId: {
          type: SchemaType.STRING,
          description: "Filter by related record ID",
        },
        dueBefore: {
          type: SchemaType.STRING,
          description: "Filter tasks due before this ISO timestamp",
        },
        dueAfter: {
          type: SchemaType.STRING,
          description: "Filter tasks due after this ISO timestamp",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of tasks to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getEvents",
    description: "Get events by type, record, or date range",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        eventTypeId: {
          type: SchemaType.STRING,
          description: "Filter by a single event type ID",
        },
        eventTypeIds: {
          type: SchemaType.ARRAY,
          description: "Filter by multiple event type IDs",
          items: {type: SchemaType.STRING},
        },
        recordId: {
          type: SchemaType.STRING,
          description: "Filter by related record ID",
        },
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by site ID",
        },
        startDate: {
          type: SchemaType.STRING,
          description: "Filter events created after this ISO timestamp",
        },
        endDate: {
          type: SchemaType.STRING,
          description: "Filter events created before this ISO timestamp",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of events to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getHusbandryEvents",
    description: "Get husbandry-related events (cleaning, feeding, treatment, etc.)",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        eventTypeId: {
          type: SchemaType.STRING,
          description: "Filter by a single husbandry event type ID",
        },
        eventTypeIds: {
          type: SchemaType.ARRAY,
          description: "Filter by multiple husbandry event type IDs",
          items: {type: SchemaType.STRING},
        },
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by site ID",
        },
        recordId: {
          type: SchemaType.STRING,
          description: "Filter by related record ID",
        },
        startDate: {
          type: SchemaType.STRING,
          description: "Filter events created after this ISO timestamp",
        },
        endDate: {
          type: SchemaType.STRING,
          description: "Filter events created before this ISO timestamp",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of events to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getMonitoringEvents",
    description: "Get monitoring events for sites or records",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by site ID",
        },
        recordId: {
          type: SchemaType.STRING,
          description: "Filter by related record ID",
        },
        startDate: {
          type: SchemaType.STRING,
          description: "Filter events created after this ISO timestamp",
        },
        endDate: {
          type: SchemaType.STRING,
          description: "Filter events created before this ISO timestamp",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of monitoring events to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getMonitoringSchedules",
    description: "Get monitoring schedules and upcoming due dates",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by site ID",
        },
        overdueOnly: {
          type: SchemaType.BOOLEAN,
          description: "Only return overdue schedules",
        },
        dueBefore: {
          type: SchemaType.STRING,
          description: "Filter schedules due before this ISO timestamp",
        },
        dueAfter: {
          type: SchemaType.STRING,
          description: "Filter schedules due after this ISO timestamp",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of schedules to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getEnvironmentalEvents",
    description: "Get environmental events affecting sites",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        eventType: {
          type: SchemaType.STRING,
          description: "Filter by environmental event type (bleaching, disease, storm, etc.)",
        },
        severity: {
          type: SchemaType.STRING,
          description: "Filter by severity (low, medium, high, critical)",
        },
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by affected site ID",
        },
        activeOnly: {
          type: SchemaType.BOOLEAN,
          description: "Only return active events",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of environmental events to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getMissions",
    description: "Get missions and field operations",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        statusId: {
          type: SchemaType.STRING,
          description: "Filter by mission status ID",
        },
        startDate: {
          type: SchemaType.STRING,
          description: "Filter missions scheduled after this ISO timestamp",
        },
        endDate: {
          type: SchemaType.STRING,
          description: "Filter missions scheduled before this ISO timestamp",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of missions to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getDeliverables",
    description: "Get permit deliverables and compliance milestones",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        statusId: {
          type: SchemaType.STRING,
          description: "Filter by deliverable status ID",
        },
        permitId: {
          type: SchemaType.STRING,
          description: "Filter by permit ID",
        },
        funderId: {
          type: SchemaType.STRING,
          description: "Filter by funder ID",
        },
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by required site ID",
        },
        dueBefore: {
          type: SchemaType.STRING,
          description: "Filter deliverables due before this ISO timestamp",
        },
        dueAfter: {
          type: SchemaType.STRING,
          description: "Filter deliverables due after this ISO timestamp",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of deliverables to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getPermits",
    description: "Get permits and regulatory compliance records",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        siteId: {
          type: SchemaType.STRING,
          description: "Filter by site ID",
        },
        activeOnly: {
          type: SchemaType.BOOLEAN,
          description: "Only return active permits",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of permits to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getVessels",
    description: "Get vessels and equipment for field operations",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        statusId: {
          type: SchemaType.STRING,
          description: "Filter by vessel status ID",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of vessels to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getFunders",
    description: "Get funder organizations and contacts",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        activeOnly: {
          type: SchemaType.BOOLEAN,
          description: "Only return active funders",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of funders to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "searchHelp",
    description: "Search SeaFoundry documentation and help resources",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        query: {
          type: SchemaType.STRING,
          description: "Search query for help documentation",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of results to return (default 5)",
        },
      },
      required: ["query"],
    },
  } as FunctionDeclaration,
  {
    name: "searchWeb",
    description: "Search the public web for external information",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        query: {
          type: SchemaType.STRING,
          description: "Search query for web results",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of web results to return (default 5)",
        },
      },
      required: ["query"],
    },
  } as FunctionDeclaration,
  {
    name: "getLifeStages",
    description: "Get valid life stage values. Optionally filter by organism kind.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        organismKind: {
          type: SchemaType.STRING,
          description: "Filter life stages applicable to this organism type",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getGroupTypes",
    description: "Get valid group/structure type values (tank, raceway, tray, rack, tree, line, plot, zone).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        category: {
          type: SchemaType.STRING,
          description: "Filter by category (structure, substructure, superstructure)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getSpecies",
    description: "Query species from the global taxonomy database. Not organization-scoped.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        searchName: {
          type: SchemaType.STRING,
          description: "Search by common or scientific name",
        },
        organismKind: {
          type: SchemaType.STRING,
          description: "Filter by organism type",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of species to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getUsers",
    description: "Query users belonging to the current organization.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        role: {
          type: SchemaType.STRING,
          description: "Filter by user role",
        },
        searchName: {
          type: SchemaType.STRING,
          description: "Search by user name",
        },
        limit: {
          type: SchemaType.NUMBER,
          description: "Maximum number of users to return (default 50)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getHoldingsSummary",
    description: "Get aggregated summary of organism holdings including total counts, counts by organism kind, site, life stage, health status, and readiness flags. Use this for dashboard overviews and inventory statistics.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        siteId: {
          type: SchemaType.STRING,
          description: "Optional: Filter summary to a specific site",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getTaskCounts",
    description: "Get task counts grouped by status (not_started, in_progress, completed), plus overdue, due soon, and unassigned counts. Use this for task dashboard summaries.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        dueSoonDays: {
          type: SchemaType.NUMBER,
          description: "Days to consider as 'due soon' (default: 7)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "getSiteSummary",
    description: "Get per-site summary including holdings count, total quantity, and group count for each site. Use this for site comparison and capacity planning.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        siteType: {
          type: SchemaType.STRING,
          description: "Optional: Filter to sites of a specific type",
        },
        includeArchived: {
          type: SchemaType.BOOLEAN,
          description: "Include archived sites (default: false)",
        },
      },
    },
  } as FunctionDeclaration,
  {
    name: "submitFeedback",
    description: "Submit a bug report, feature request, or general feedback about SeaFoundry. Use when users report issues or provide feedback.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        feedbackType: {
          type: SchemaType.STRING,
          description: "Type: bug_report, feature_request, general_feedback, or question",
        },
        description: {
          type: SchemaType.STRING,
          description: "User description of the issue or feedback",
        },
        severity: {
          type: SchemaType.STRING,
          description: "For bugs: low, medium, high, or critical",
        },
        stepsToReproduce: {
          type: SchemaType.STRING,
          description: "Steps to reproduce if applicable",
        },
      },
      required: ["feedbackType", "description"],
    },
  } as FunctionDeclaration,
];

/**
 * Calculate cost based on token count
 * Pricing is an approximate blended estimate for flash models.
 */
export function calculateCost(tokens: number): number {
  const costPerMillionTokens = 0.1875;
  return (tokens / 1_000_000) * costPerMillionTokens;
}

function resolveGeminiModel(modelName?: string): string {
  return modelName || process.env.GEMINI_MODEL || "gemini-flash-latest";
}

/**
 * Send message to Gemini and handle function calls
 */
export async function sendMessage(
  conversationHistory: SebastianMessage[],
  userMessage: string,
  organizationId: string,
  apiKey: string,
  context?: SebastianContext,
  customPrompt?: string,
  modelName?: string
): Promise<{
  content: string;
  tokenCount: number;
  cost: number;
}> {
  const systemPrompt = buildSystemPrompt(context, customPrompt);
  const modelId = resolveGeminiModel(modelName);

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: modelId,
    systemInstruction: systemPrompt,
    tools: [{functionDeclarations: FUNCTION_DECLARATIONS}],
  });

  // Build conversation history
  const history = conversationHistory.map((msg) => ({
    role: msg.role === "assistant" ? "model" : "user",
    parts: [{text: msg.content}],
  }));

  const chat = model.startChat({history});

  // Send user message
  let result = await chat.sendMessage(userMessage);
  let response = result.response;

  // Handle function calls (may require multiple rounds)
  const maxIterations = 5;
  let iterations = 0;

  while (response.functionCalls() && iterations < maxIterations) {
    iterations++;

    const functionCalls = response.functionCalls() || [];
    const functionResponses = await Promise.all(
      functionCalls.map(async (call) => {
        try {
          const functionResult = await executeFunctionCall(
            call.name,
            call.args as Record<string, unknown>,
            organizationId,
            context
          );
          return {
            functionResponse: {
              name: call.name,
              response: {result: functionResult},
            },
          };
        } catch (error) {
          console.error(`Error executing function ${call.name}:`, error);
          return {
            functionResponse: {
              name: call.name,
              response: {error: error instanceof Error ? error.message : "Unknown error"},
            },
          };
        }
      })
    );

    // Send function results back to model
    result = await chat.sendMessage(functionResponses);
    response = result.response;
  }

  // Extract final text response
  const text = response.text();

  // Calculate token count (approximate)
  const usageMetadata = response.usageMetadata;
  const tokenCount = usageMetadata?.totalTokenCount || 0;
  const cost = calculateCost(tokenCount);

  return {
    content: text,
    tokenCount,
    cost,
  };
}

/**
 * Send message to Gemini with streaming and handle function calls
 * Streams content chunks via SSE as they arrive
 */
export async function sendMessageStream(
  conversationHistory: SebastianMessage[],
  userMessage: string,
  organizationId: string,
  apiKey: string,
  res: Response,
  context?: SebastianContext,
  customPrompt?: string,
  modelName?: string
): Promise<{
  tokenCount: number;
  cost: number;
}> {
  try {
    const systemPrompt = buildSystemPrompt(context, customPrompt);
    const modelId = resolveGeminiModel(modelName);

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: modelId,
      systemInstruction: systemPrompt,
      tools: [{functionDeclarations: FUNCTION_DECLARATIONS}],
    });

    // Build conversation history
    const history = conversationHistory.map((msg) => ({
      role: msg.role === "assistant" ? "model" : "user",
      parts: [{text: msg.content}],
    }));

    const chat = model.startChat({history});

    // Send user message with streaming
    let result = await chat.sendMessageStream(userMessage);
    let accumulatedText = "";

    // Stream content chunks
    for await (const chunk of result.stream) {
      const chunkText = chunk.text();
      if (chunkText) {
        accumulatedText += chunkText;
        sendSSE(res, {
          event: "content",
          data: JSON.stringify({
            chunk: chunkText,
            fullText: accumulatedText,
            text: chunkText,
            content: chunkText,
          }),
        });
      }
    }

    // Get final response (includes function calls if any)
    let response = await result.response;

    // Handle function calls (may require multiple rounds)
    const maxIterations = 5;
    let iterations = 0;

    while (response.functionCalls() && iterations < maxIterations) {
      iterations++;

      const functionCalls = response.functionCalls() || [];

      // Notify client about function calls
      const callSummaries = functionCalls.map((call) => ({
        name: call.name,
        args: call.args,
      }));
      sendSSE(res, {
        event: "function_call",
        data: JSON.stringify({
          name: callSummaries[0]?.name || "function",
          calls: callSummaries,
        }),
      });

      // Execute function calls
      const functionResponses = await Promise.all(
        functionCalls.map(async (call) => {
          try {
            const functionResult = await executeFunctionCall(
              call.name,
              call.args as Record<string, unknown>,
              organizationId,
              context
            );
            return {
              functionResponse: {
                name: call.name,
                response: {result: functionResult},
              },
            };
          } catch (error) {
            console.error(`Error executing function ${call.name}:`, error);
            return {
              functionResponse: {
                name: call.name,
                response: {error: error instanceof Error ? error.message : "Unknown error"},
              },
            };
          }
        })
      );

      // Send function results back to model with streaming
      result = await chat.sendMessageStream(functionResponses);
      accumulatedText = "";

      // Stream the response after function execution
      for await (const chunk of result.stream) {
        const chunkText = chunk.text();
        if (chunkText) {
          accumulatedText += chunkText;
          sendSSE(res, {
            event: "content",
            data: JSON.stringify({
              chunk: chunkText,
              fullText: accumulatedText,
            }),
          });
        }
      }

      response = await result.response;
    }

    // Calculate token count and cost
    const usageMetadata = response.usageMetadata;
    const tokenCount = usageMetadata?.totalTokenCount || 0;
    const cost = calculateCost(tokenCount);

    return {
      tokenCount,
      cost,
    };
  } catch (error) {
    console.error("Error in sendMessageStream:", error);
    const errorMessage = error instanceof Error ? error.message : "Unknown error occurred";
    sendSSEError(res, errorMessage, "gemini_error");
    throw error;
  }
}
