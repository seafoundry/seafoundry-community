/**
 * Sebastian AI function call handlers
 * Handles function calls from Gemini to query SeaFoundry data
 */

import * as admin from "firebase-admin";
import {Query} from "firebase-admin/firestore";

interface FunctionArgs {
  [key: string]: unknown;
}

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

// Maximum query limit to prevent resource exhaustion
const MAX_QUERY_LIMIT = 100;
const MAX_WEB_RESULTS = 5;

// Hardcoded life stages
const LIFE_STAGES = [
  {id: "life_stage_unknown", displayName: "Unknown"},
  {id: "life_stage_gamete", displayName: "Gamete"},
  {id: "life_stage_embryo", displayName: "Embryo"},
  {id: "life_stage_larva", displayName: "Larva"},
  {id: "life_stage_juvenile", displayName: "Juvenile"},
  {id: "life_stage_adult", displayName: "Adult"},
  {id: "life_stage_broodstock", displayName: "Broodstock"},
  {id: "life_stage_fragment", displayName: "Fragment"},
  {id: "life_stage_colony", displayName: "Colony"},
  {id: "life_stage_recruit", displayName: "Recruit"},
];

// Hardcoded group types
const GROUP_TYPES = [
  {id: "group_type_tank", name: "Tank", category: "structure"},
  {id: "group_type_raceway", name: "Raceway", category: "structure"},
  {id: "group_type_tray", name: "Tray", category: "substructure"},
  {id: "group_type_rack", name: "Rack", category: "structure"},
  {id: "group_type_tree", name: "Tree", category: "structure"},
  {id: "group_type_line", name: "Line", category: "structure"},
  {id: "group_type_plot", name: "Plot", category: "structure"},
  {id: "group_type_zone", name: "Zone", category: "superstructure"},
];


// Allowed organism kinds (must match OrganismKind enum in app)
const ALLOWED_ORGANISM_KINDS = [
  "coral",
  "kelp",
  "oyster",
  "seagrass",
  "mangrove",
  "echinoid",
  "crab",
  "finfish",
  "seaCucumber",
  "genericMarine",
];

const ORGANISM_KIND_ALIASES: Record<string, string> = {
  "sea cucumber": "seaCucumber",
  "sea_cucumber": "seaCucumber",
  "sea-cucumber": "seaCucumber",
  seacucumber: "seaCucumber",
  seaCucumber: "seaCucumber",
  urchin: "echinoid",
  "sea urchin": "echinoid",
  echinoderm: "echinoid",
  "sea grass": "seagrass",
  seagrass: "seagrass",
  "fin fish": "finfish",
  fish: "finfish",
  "generic marine": "genericMarine",
  generic_marine: "genericMarine",
  genericmarine: "genericMarine",
};

// Allowed task statuses
const ALLOWED_TASK_STATUSES = [
  "not_started",
  "in_progress",
  "completed",
  "pending",
  "cancelled",
];

// Allowed feedback types
const ALLOWED_FEEDBACK_TYPES = [
  "bug_report",
  "feature_request",
  "general_feedback",
  "question",
];

// Allowed severity levels for bug reports
const ALLOWED_SEVERITY_LEVELS = ["low", "medium", "high", "critical"];

const TASK_STATUS_ALIASES: Record<string, string> = {
  pending: "not_started",
  "not started": "not_started",
  "not-started": "not_started",
  todo: "not_started",
  "in progress": "in_progress",
  "in-progress": "in_progress",
  done: "completed",
};

const HUSBANDRY_EVENT_TYPE_IDS = [
  "event_cleaning",
  "event_feeding",
  "event_treatment",
  "event_environmental_adjustment",
  "event_structure_maintenance",
  "event_water_quality_test",
  "event_acquire_orthomosaic",
  "event_site_prep",
  "event_ecological_survey",
  "event_log_water_conditions",
  "event_husbandry_log",
];

/**
 * Safely get limit from args with max cap
 */
function getSafeLimit(args: FunctionArgs, defaultLimit = 50): number {
  const requestedLimit = typeof args["limit"] === "number" ? args["limit"] : defaultLimit;
  // Ensure limit is positive integer within bounds
  const safeLimit = Math.min(Math.max(1, Math.floor(requestedLimit)), MAX_QUERY_LIMIT);
  return safeLimit;
}

function normalizeString(value: unknown, maxLength = 200): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return undefined;
  }
  return trimmed.length > maxLength ? trimmed.substring(0, maxLength) : trimmed;
}

function normalizeBoolean(value: unknown, defaultValue = false): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (normalized === "true") return true;
    if (normalized === "false") return false;
  }
  return defaultValue;
}

function parseOptionalBoolean(value: unknown): boolean | undefined {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (normalized === "true") return true;
    if (normalized === "false") return false;
  }
  return undefined;
}

function parseDateInput(value: unknown, fieldName: string): string | undefined {
  const raw = normalizeString(value, 64);
  if (!raw) {
    return undefined;
  }
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`${fieldName} must be a valid ISO timestamp`);
  }
  return parsed.toISOString();
}

function sanitizeStringArray(value: unknown, maxItems = 20): string[] | undefined {
  if (!Array.isArray(value)) {
    return undefined;
  }
  const items = value
    .filter((entry): entry is string => typeof entry === "string")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0)
    .slice(0, maxItems);
  return items.length > 0 ? items : undefined;
}

function extractMetadata(data: Record<string, unknown>): Record<string, unknown> | undefined {
  const metadata = data["metadata"];
  if (metadata && typeof metadata === "object") {
    return metadata as Record<string, unknown>;
  }
  const createdEvent = data["createdEvent"];
  if (createdEvent && typeof createdEvent === "object") {
    const createdMetadata = (createdEvent as Record<string, unknown>)["metadata"];
    if (createdMetadata && typeof createdMetadata === "object") {
      return createdMetadata as Record<string, unknown>;
    }
  }
  return undefined;
}

function extractLifeStageId(data: Record<string, unknown>): string | undefined {
  const lifeStage = data["lifeStage"];
  if (typeof lifeStage === "string") {
    return lifeStage;
  }
  if (lifeStage && typeof lifeStage === "object") {
    const stage = (lifeStage as Record<string, unknown>)["id"] ??
      (lifeStage as Record<string, unknown>)["stage"];
    if (typeof stage === "string") {
      return stage;
    }
    if (stage && typeof stage === "object") {
      const nested = (stage as Record<string, unknown>)["id"];
      if (typeof nested === "string") {
        return nested;
      }
    }
  }
  const lifeStageId = data["lifeStageId"];
  return typeof lifeStageId === "string" ? lifeStageId : undefined;
}

function resolveOrganismKind(
  data: Record<string, unknown>,
  fallback?: string
): string | undefined {
  const direct = data["organismKind"];
  if (typeof direct === "string" && direct.trim().length > 0) {
    return direct;
  }
  const metadata = extractMetadata(data);
  const metadataKind = metadata?.["organismKind"];
  if (typeof metadataKind === "string" && metadataKind.trim().length > 0) {
    return metadataKind;
  }
  return fallback;
}

function chunkArray<T>(items: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

/**
 * Validate organism kind parameter
 */
function validateOrganismKind(kind: unknown): string | undefined {
  if (!kind) {
    return undefined;
  }

  if (typeof kind !== "string") {
    throw new Error("organismKind must be a string");
  }

  const normalized = kind.trim().toLowerCase();
  const canonical = ORGANISM_KIND_ALIASES[normalized] ?? normalized;

  if (!ALLOWED_ORGANISM_KINDS.includes(canonical)) {
    throw new Error(
      `Invalid organismKind: ${kind}. Allowed values: ${ALLOWED_ORGANISM_KINDS.join(", ")}`
    );
  }

  return canonical;
}

/**
 * Validate task status parameter
 */
function validateTaskStatus(status: unknown): string | undefined {
  if (!status) {
    return undefined;
  }

  if (typeof status !== "string") {
    throw new Error("status must be a string");
  }

  const normalized = status.trim().toLowerCase();
  const canonical = TASK_STATUS_ALIASES[normalized] ?? normalized;

  if (!ALLOWED_TASK_STATUSES.includes(canonical)) {
    throw new Error(
      `Invalid status: ${status}. Allowed values: ${ALLOWED_TASK_STATUSES.join(", ")}`
    );
  }

  return canonical;
}

/**
 * Sanitize search query to prevent injection
 */
function sanitizeSearchQuery(query: unknown): string {
  if (!query || typeof query !== "string") {
    return "";
  }

  // Trim whitespace and limit length
  const trimmed = query.trim().substring(0, 200);

  // Remove potentially dangerous characters
  // Allow alphanumeric, spaces, hyphens, underscores, and basic punctuation
  const sanitized = trimmed.replace(/[^a-zA-Z0-9\s\-_.,'?!]/g, "");

  return sanitized;
}

async function fetchEventDocs(
  organizationId: string,
  eventTypeIds: string[] | undefined,
  limit: number
) {
  const baseQuery = admin
    .firestore()
    .collection("events")
    .where("organizationId", "==", organizationId)
    .orderBy("createdAt", "desc");

  if (!eventTypeIds || eventTypeIds.length === 0) {
    const snapshot = await baseQuery.limit(limit).get();
    return snapshot.docs;
  }

  const uniqueEventTypeIds = Array.from(new Set(eventTypeIds));

  if (uniqueEventTypeIds.length === 1) {
    const snapshot = await baseQuery
      .where("eventTypeId", "==", uniqueEventTypeIds[0])
      .limit(limit)
      .get();
    return snapshot.docs;
  }

  const chunks = chunkArray(uniqueEventTypeIds, 10);
  const snapshots = await Promise.all(
    chunks.map((chunk) => baseQuery.where("eventTypeId", "in", chunk).limit(limit).get())
  );
  return snapshots.flatMap((snapshot) => snapshot.docs);
}

/**
 * Handle getOrganismHoldings function call
 * Query organismRecords collection (nested under organizations/{orgId}/organismRecords)
 */
async function handleGetOrganismHoldings(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const organismKind = validateOrganismKind(args["organismKind"]);
  const lifeStageId = normalizeString(args["lifeStageId"]) ?? normalizeString(args["lifeStage"]);
  const siteId = normalizeString(args["siteId"]);
  const groupId = normalizeString(args["groupId"]);
  const structureId = normalizeString(args["structureId"]);
  const genetId = normalizeString(args["genetId"]);
  const speciesId = normalizeString(args["speciesId"]);
  const readyForPropagation = parseOptionalBoolean(args["readyForPropagation"]);
  const readyForOutplant = parseOptionalBoolean(args["readyForOutplant"]);
  const healthStatus = normalizeString(args["healthStatus"]) ??
    normalizeString(args["healthStatusId"]);
  const normalizedHealthStatus = healthStatus?.toLowerCase();
  const limit = getSafeLimit(args);
  const treatMissingAsCoral = organismKind === "coral" || !organismKind;
  const fallbackOrganismKind = treatMissingAsCoral ? "coral" : undefined;

  // Organism records use nested collections: organizations/{orgId}/organismRecords
  let query: Query = admin
    .firestore()
    .collection("organizations")
    .doc(organizationId)
    .collection("organismRecords");

  // Apply filters in priority order (most specific first)
  // Note: These are mutually exclusive due to Firestore query limitations
  if (siteId) {
    query = query.where("siteId", "==", siteId);
  } else if (groupId) {
    query = query.where("groupId", "==", groupId);
  } else if (structureId) {
    query = query.where("structureId", "==", structureId);
  } else if (genetId) {
    query = query.where("genetId", "==", genetId);
  } else if (speciesId) {
    query = query.where("speciesId", "==", speciesId);
  } else if (organismKind) {
    // Always filter by organismKind when specified (including coral)
    // All modern organismRecords have the organismKind field set
    query = query.where("organismKind", "==", organismKind);
  }

  query = query.limit(limit);

  const snapshot = await query.get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: organismKind ?
        `No ${organismKind} organism records found` :
        "No organism records found",
    });
  }

  const holdings = snapshot.docs.map((doc) => {
    const data = doc.data();
    const resolvedOrganismKind = resolveOrganismKind(data, fallbackOrganismKind);
    const measurement = data.measurement ?? data.population;
    // Extract quantity: organismRecords use measurement.value, legacy records may use quantity/count
    const quantity = measurement?.value ?? data.quantity ?? data.count ?? 1;
    const resolvedLifeStageId = extractLifeStageId(data);
    const metadata = extractMetadata(data) ?? {};
    const readyForPropagationValue =
      metadata["readyForPropagation"] === true || data.readyForPropagation === true;
    const readyForOutplantValue =
      metadata["readyForOutplant"] === true || data.readyForOutplant === true;
    const pendingOutplant =
      metadata["pendingOutplant"] === true || data.pendingOutplant === true;
    const healthStatusValue = typeof metadata["healthStatus"] === "string" ?
      metadata["healthStatus"] :
      typeof data.healthStatus === "string" ? data.healthStatus : undefined;
    return {
      id: doc.id,
      name: data.name || data.displayName || data.slug || doc.id,
      organismKind: resolvedOrganismKind,
      quantity: quantity,
      lifeStageId: resolvedLifeStageId,
      lifeStage: resolvedLifeStageId,
      measurement: measurement,
      groupId: data.groupId,
      siteId: data.siteId,
      structureId: data.structureId,
      genetId: data.genetId,
      speciesId: data.speciesId,
      healthStatus: healthStatusValue,
      readyForPropagation: readyForPropagationValue,
      readyForOutplant: readyForOutplantValue,
      pendingOutplant: pendingOutplant,
      urlPath: data.urlPath,
      createdAt: data.createdAt,
    };
  }).filter((holding) => {
    if (organismKind && holding.organismKind !== organismKind) return false;
    if (lifeStageId && holding.lifeStageId !== lifeStageId) return false;
    if (siteId && holding.siteId !== siteId) return false;
    if (groupId && holding.groupId !== groupId) return false;
    if (structureId && holding.structureId !== structureId) return false;
    if (genetId && holding.genetId !== genetId) return false;
    if (speciesId && holding.speciesId !== speciesId) return false;
    if (readyForPropagation !== undefined &&
      holding.readyForPropagation !== readyForPropagation) {
      return false;
    }
    if (readyForOutplant !== undefined &&
      holding.readyForOutplant !== readyForOutplant) {
      return false;
    }
    if (normalizedHealthStatus &&
      holding.healthStatus?.toLowerCase() !== normalizedHealthStatus) {
      return false;
    }
    return true;
  });

  return JSON.stringify({
    count: holdings.length,
    holdings,
  });
}

/**
 * Handle getGenets function call
 * Query genets collection (nested under organizations/{orgId}/genets)
 */
async function handleGetGenets(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const organismKind = validateOrganismKind(args["organismKind"]);
  const searchAlias = normalizeString(args["searchAlias"]);
  const limit = getSafeLimit(args);

  // Genets use nested collections: organizations/{orgId}/genets
  let query: Query = admin
    .firestore()
    .collection("organizations")
    .doc(organizationId)
    .collection("genets")
    .limit(limit);

  if (organismKind) {
    query = query.where("organismKind", "==", organismKind);
  }

  const snapshot = await query.get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No genets found",
    });
  }

  const genets = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      organismKind: data.organismKind,
      species: data.speciesId || data.species,
      aliases: data.aliases || [],
      provenanceType: data.provenanceTypeId || data.provenanceType,
      provenanceId: data.provenanceId, // Primary identifier for community genetics
      provenanceKind: data.provenanceKind, // genet or cohort
      lifeStage: data.lifeStage,
      createdAt: data.createdAt,
    };
  }).filter((genet) => {
    if (organismKind && genet.organismKind !== organismKind) return false;
    if (searchAlias) {
      const aliases = Array.isArray(genet.aliases) ? genet.aliases : [];
      const match = aliases.some((alias) => {
        if (typeof alias === "string") {
          return alias.toLowerCase().includes(searchAlias.toLowerCase());
        }
        if (alias && typeof alias === "object") {
          const value = (alias as Record<string, unknown>)["value"];
          const label = (alias as Record<string, unknown>)["label"];
          const composite = `${value ?? ""} ${label ?? ""}`.toLowerCase();
          return composite.includes(searchAlias.toLowerCase());
        }
        return false;
      });
      if (!match) return false;
    }
    return true;
  });

  return JSON.stringify({
    count: genets.length,
    genets,
  });
}

/**
 * Handle getSites function call
 * Query sites collection
 */
async function handleGetSites(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const siteType = normalizeString(args["siteType"]);
  const includeArchived = normalizeBoolean(args["includeArchived"], false);
  const limit = getSafeLimit(args);

  const snapshot = await admin
    .firestore()
    .collection("sites")
    .where("organizationId", "==", organizationId)
    .limit(limit)
    .get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No sites found",
    });
  }

  const sites = snapshot.docs.map((doc) => {
    const data = doc.data();
    const resolvedSiteType = data.siteTypeId || data.siteType || data.type;
    return {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      siteTypeId: resolvedSiteType,
      siteType: resolvedSiteType,
      latitude: data.latitude || data.location?.latitude,
      longitude: data.longitude || data.location?.longitude,
      isArchived: data.isArchived || false,
      urlPath: data.urlPath,
      createdAt: data.createdAt,
    };
  }).filter((site) => {
    if (!includeArchived && site.isArchived) return false;
    if (siteType && site.siteTypeId !== siteType) return false;
    return true;
  });

  return JSON.stringify({
    count: sites.length,
    sites,
  });
}

/**
 * Handle getTasks function call
 * Query task events from events collection (tasks are stored as events with eventTypeId='event_task')
 */
async function handleGetTasks(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const statusId = validateTaskStatus(args["status"]);
  const assignedUserId = normalizeString(args["assignedUserId"]);
  const assignedRoleId = normalizeString(args["assignedRoleId"]);
  const recordId = normalizeString(args["recordId"]);
  const dueBefore = parseDateInput(args["dueBefore"], "dueBefore");
  const dueAfter = parseDateInput(args["dueAfter"], "dueAfter");
  const limit = getSafeLimit(args);

  // Tasks are stored in the events collection with eventTypeId='event_task'
  let query: Query = admin
    .firestore()
    .collection("events")
    .where("organizationId", "==", organizationId)
    .where("eventTypeId", "==", "event_task")
    .orderBy("createdAt", "desc")
    .limit(limit);

  if (recordId) {
    query = query.where("recordId", "==", recordId);
  }

  const snapshot = await query.get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: statusId ? `No ${statusId} tasks found` : "No tasks found",
    });
  }

  const tasks = snapshot.docs.map((doc) => {
    const data = doc.data();
    const deadline = data.deadline || data.dueDate;
    const status = data.statusId || data.status || "not_started";
    return {
      id: doc.id,
      title: data.title || data.name || "Untitled Task",
      description: data.description,
      statusId: status,
      status: status,
      priorityId: data.priorityId || data.priority,
      assignedUserId: data.assignedUserId,
      assignedRoleId: data.assignedRoleId,
      deadline: deadline,
      dueDate: deadline,
      createdAt: data.createdAt,
      recordId: data.recordId,
      recordModelType: data.recordModelType,
      urlPath: data.urlPath,
      isCompleted: data.isCompleted,
      completedAt: data.completedAt,
      husbandryActionTypeId: data.husbandryActionTypeId,
      husbandryTaskDefinitionId: data.husbandryTaskDefinitionId,
      parameters: data.parameters,
      metadata: data.metadata,
    };
  }).filter((task) => {
    if (statusId && task.statusId !== statusId) return false;
    if (assignedUserId && task.assignedUserId !== assignedUserId) return false;
    if (assignedRoleId && task.assignedRoleId !== assignedRoleId) return false;
    if (recordId && task.recordId !== recordId) return false;
    if (dueBefore || dueAfter) {
      if (!task.deadline) return false;
      const deadlineDate = new Date(task.deadline);
      if (dueBefore && deadlineDate > new Date(dueBefore)) return false;
      if (dueAfter && deadlineDate < new Date(dueAfter)) return false;
    }
    return true;
  });

  return JSON.stringify({
    count: tasks.length,
    tasks,
  });
}

/**
 * Handle getHoldings function call
 * Query holdings collection (nested under organizations/{orgId}/holdings)
 */
async function handleGetHoldings(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const organismKind = validateOrganismKind(args["organismKind"]);
  const lifeStageId = normalizeString(args["lifeStageId"]) ?? normalizeString(args["lifeStage"]);
  const siteId = normalizeString(args["siteId"]);
  const groupId = normalizeString(args["groupId"]);
  const structureId = normalizeString(args["structureId"]);
  const provenanceId = normalizeString(args["provenanceId"]);
  const cohortId = normalizeString(args["cohortId"]);
  const limit = getSafeLimit(args);
  const treatMissingAsCoral = organismKind === "coral" || !organismKind;
  const fallbackOrganismKind = treatMissingAsCoral ? "coral" : undefined;

  let query: Query = admin
    .firestore()
    .collection("organizations")
    .doc(organizationId)
    .collection("holdings");

  // Apply filters in priority order (most specific first)
  if (siteId) {
    query = query.where("siteId", "==", siteId);
  } else if (groupId) {
    query = query.where("groupId", "==", groupId);
  } else if (structureId) {
    query = query.where("structureId", "==", structureId);
  } else if (cohortId) {
    query = query.where("cohortId", "==", cohortId);
  } else if (provenanceId) {
    query = query.where("provenanceId", "==", provenanceId);
  } else if (organismKind) {
    // Always filter by organismKind when specified (including coral)
    query = query.where("organismKind", "==", organismKind);
  }

  const snapshot = await query.limit(limit).get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: organismKind ?
        `No ${organismKind} holdings found` :
        "No holdings found",
    });
  }

  const holdings = snapshot.docs.map((doc) => {
    const data = doc.data();
    const resolvedOrganismKind = resolveOrganismKind(data, fallbackOrganismKind);
    const resolvedLifeStageId = extractLifeStageId(data);
    const measurement = data.measurement ?? data.population;
    const quantity = measurement?.value ?? data.quantity ?? data.count ?? 1;
    return {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      organismKind: resolvedOrganismKind,
      lifeStageId: resolvedLifeStageId,
      lifeStage: resolvedLifeStageId,
      measurement: measurement,
      quantity: quantity,
      siteId: data.siteId,
      groupId: data.groupId,
      structureId: data.structureId,
      provenanceId: data.provenanceId,
      cohortId: data.cohortId,
      urlPath: data.urlPath,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    };
  }).filter((holding) => {
    if (organismKind && holding.organismKind !== organismKind) return false;
    if (lifeStageId && holding.lifeStageId !== lifeStageId) return false;
    if (siteId && holding.siteId !== siteId) return false;
    if (groupId && holding.groupId !== groupId) return false;
    if (structureId && holding.structureId !== structureId) return false;
    if (provenanceId && holding.provenanceId !== provenanceId) return false;
    if (cohortId && holding.cohortId !== cohortId) return false;
    return true;
  });

  return JSON.stringify({
    count: holdings.length,
    holdings,
  });
}

/**
 * Handle getCohorts function call
 * Query cohorts collection (nested under organizations/{orgId}/cohorts)
 */
async function handleGetCohorts(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const organismKind = validateOrganismKind(args["organismKind"]);
  const lifeStageId = normalizeString(args["lifeStageId"]) ?? normalizeString(args["lifeStage"]);
  const siteId = normalizeString(args["siteId"]);
  const groupId = normalizeString(args["groupId"]);
  const structureId = normalizeString(args["structureId"]);
  const provenanceId = normalizeString(args["provenanceId"]);
  const limit = getSafeLimit(args);

  let query: Query = admin
    .firestore()
    .collection("organizations")
    .doc(organizationId)
    .collection("cohorts");

  if (siteId) {
    query = query.where("siteId", "==", siteId);
  } else if (groupId) {
    query = query.where("groupId", "==", groupId);
  } else if (structureId) {
    query = query.where("structureId", "==", structureId);
  } else if (provenanceId) {
    query = query.where("provenanceId", "==", provenanceId);
  } else if (organismKind) {
    query = query.where("organismKind", "==", organismKind);
  }

  const snapshot = await query.limit(limit).get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No cohorts found",
    });
  }

  const cohorts = snapshot.docs.map((doc) => {
    const data = doc.data();
    const resolvedLifeStageId = extractLifeStageId(data);
    const population = data.population ?? data.measurement;
    return {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      organismKind: data.organismKind,
      lifeStageId: resolvedLifeStageId,
      lifeStage: resolvedLifeStageId,
      population: population,
      siteId: data.siteId,
      groupId: data.groupId,
      structureId: data.structureId,
      provenanceId: data.provenanceId,
      urlPath: data.urlPath,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      startedAt: data.startedAt,
      completedAt: data.completedAt,
    };
  }).filter((cohort) => {
    if (organismKind && cohort.organismKind !== organismKind) return false;
    if (lifeStageId && cohort.lifeStageId !== lifeStageId) return false;
    if (siteId && cohort.siteId !== siteId) return false;
    if (groupId && cohort.groupId !== groupId) return false;
    if (structureId && cohort.structureId !== structureId) return false;
    if (provenanceId && cohort.provenanceId !== provenanceId) return false;
    return true;
  });

  return JSON.stringify({
    count: cohorts.length,
    cohorts,
  });
}

/**
 * Handle getGroups function call
 * Query groups collection (nested under organizations/{orgId}/groups)
 */
async function handleGetGroups(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const siteId = normalizeString(args["siteId"]);
  const parentId = normalizeString(args["parentId"]);
  const groupTypeId = normalizeString(args["groupTypeId"]);
  const limit = getSafeLimit(args);

  let query: Query = admin
    .firestore()
    .collection("organizations")
    .doc(organizationId)
    .collection("groups");

  if (siteId) {
    query = query.where("siteId", "==", siteId);
  } else if (parentId) {
    query = query.where("parentId", "==", parentId);
  } else if (groupTypeId) {
    query = query.where("groupTypeId", "==", groupTypeId);
  }

  const snapshot = await query.limit(limit).get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No groups found",
    });
  }

  const groups = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      groupTypeId: data.groupTypeId,
      siteId: data.siteId,
      parentId: data.parentId,
      description: data.description,
      capacity: data.capacity,
      rowIndex: data.rowIndex,
      colIndex: data.colIndex,
      urlPath: data.urlPath,
      createdAt: data.createdAt,
    };
  }).filter((group) => {
    if (siteId && group.siteId !== siteId) return false;
    if (parentId && group.parentId !== parentId) return false;
    if (groupTypeId && group.groupTypeId !== groupTypeId) return false;
    return true;
  });

  return JSON.stringify({
    count: groups.length,
    groups,
  });
}

/**
 * Handle getZones function call
 * Query zones collection (nested under organizations/{orgId}/zones)
 */
async function handleGetZones(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const siteId = normalizeString(args["siteId"]);
  const limit = getSafeLimit(args);

  let query: Query = admin
    .firestore()
    .collection("organizations")
    .doc(organizationId)
    .collection("zones");

  if (siteId) {
    query = query.where("siteId", "==", siteId);
  }

  const snapshot = await query.limit(limit).get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No zones found",
    });
  }

  const zones = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      siteId: data.siteId,
      description: data.description,
      sortOrder: data.sortOrder,
      urlPath: data.urlPath,
      createdAt: data.createdAt,
    };
  }).filter((zone) => {
    if (siteId && zone.siteId !== siteId) return false;
    return true;
  });

  return JSON.stringify({
    count: zones.length,
    zones,
  });
}

/**
 * Handle getSubplots function call
 * Query subplots collection (nested under organizations/{orgId}/subplots)
 */
async function handleGetSubplots(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const siteId = normalizeString(args["siteId"]);
  const zoneId = normalizeString(args["zoneId"]);
  const limit = getSafeLimit(args);

  let query: Query = admin
    .firestore()
    .collection("organizations")
    .doc(organizationId)
    .collection("subplots");

  if (zoneId) {
    query = query.where("zoneId", "==", zoneId);
  } else if (siteId) {
    query = query.where("siteId", "==", siteId);
  }

  const snapshot = await query.limit(limit).get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No subplots found",
    });
  }

  const subplots = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      siteId: data.siteId,
      zoneId: data.zoneId,
      description: data.description,
      tagPrefix: data.tagPrefix,
      capacity: data.capacity,
      sortOrder: data.sortOrder,
      urlPath: data.urlPath,
      createdAt: data.createdAt,
    };
  }).filter((subplot) => {
    if (siteId && subplot.siteId !== siteId) return false;
    if (zoneId && subplot.zoneId !== zoneId) return false;
    return true;
  });

  return JSON.stringify({
    count: subplots.length,
    subplots,
  });
}

/**
 * Handle getEvents function call
 * Query events collection for general inventory/operations events
 */
async function handleGetEvents(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const eventTypeId = normalizeString(args["eventTypeId"]);
  const eventTypeIds = sanitizeStringArray(args["eventTypeIds"], 30);
  const recordId = normalizeString(args["recordId"]);
  const siteId = normalizeString(args["siteId"]);
  const startDate = parseDateInput(args["startDate"], "startDate");
  const endDate = parseDateInput(args["endDate"], "endDate");
  const limit = getSafeLimit(args);

  const resolvedEventTypeIds = eventTypeId ? [eventTypeId] : eventTypeIds;
  const docs = await fetchEventDocs(organizationId, resolvedEventTypeIds, limit);

  if (docs.length === 0) {
    return JSON.stringify({
      count: 0,
      message: "No events found",
    });
  }

  const events = docs.map((doc) => {
    const data = doc.data();
    const status = data.statusId || data.status;
    return {
      id: doc.id,
      eventTypeId: data.eventTypeId,
      title: data.title || data.name || data.description,
      description: data.description || data.comment,
      statusId: status,
      status: status,
      recordId: data.recordId,
      recordModelType: data.recordModelType,
      siteId: data.siteId,
      groupId: data.groupId,
      structureId: data.structureId,
      urlPath: data.urlPath,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      missionId: data.missionId,
      permitMetadata: data.permitMetadata,
      parameters: data.parameters,
      metadata: data.metadata,
    };
  }).filter((event) => {
    if (resolvedEventTypeIds && resolvedEventTypeIds.length > 0 &&
        !resolvedEventTypeIds.includes(event.eventTypeId)) {
      return false;
    }
    if (recordId && event.recordId !== recordId) return false;
    if (siteId && event.siteId !== siteId) return false;
    if (startDate || endDate) {
      if (!event.createdAt) return false;
      const createdAt = new Date(event.createdAt);
      if (startDate && createdAt < new Date(startDate)) return false;
      if (endDate && createdAt > new Date(endDate)) return false;
    }
    return true;
  }).sort((a, b) => {
    const left = a.createdAt ?? "";
    const right = b.createdAt ?? "";
    return right.localeCompare(left);
  }).slice(0, limit);

  return JSON.stringify({
    count: events.length,
    events,
  });
}

/**
 * Handle getHusbandryEvents function call
 * Query events collection for husbandry-related events
 */
async function handleGetHusbandryEvents(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const eventTypeId = normalizeString(args["eventTypeId"]);
  const eventTypeIds = sanitizeStringArray(args["eventTypeIds"], 30);
  const siteId = normalizeString(args["siteId"]);
  const recordId = normalizeString(args["recordId"]);
  const startDate = parseDateInput(args["startDate"], "startDate");
  const endDate = parseDateInput(args["endDate"], "endDate");
  const limit = getSafeLimit(args);

  const resolvedEventTypeIds = eventTypeId ? [eventTypeId] :
    eventTypeIds ?? HUSBANDRY_EVENT_TYPE_IDS;
  const docs = await fetchEventDocs(organizationId, resolvedEventTypeIds, limit);

  if (docs.length === 0) {
    return JSON.stringify({
      count: 0,
      message: "No husbandry events found",
    });
  }

  const events = docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      eventTypeId: data.eventTypeId,
      title: data.title || data.name || data.description,
      description: data.description || data.comment,
      recordId: data.recordId,
      recordModelType: data.recordModelType,
      siteId: data.siteId,
      groupId: data.groupId,
      structureId: data.structureId,
      urlPath: data.urlPath,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      parameters: data.parameters,
    };
  }).filter((event) => {
    if (resolvedEventTypeIds && resolvedEventTypeIds.length > 0 &&
        !resolvedEventTypeIds.includes(event.eventTypeId)) {
      return false;
    }
    if (recordId && event.recordId !== recordId) return false;
    if (siteId && event.siteId !== siteId) return false;
    if (startDate || endDate) {
      if (!event.createdAt) return false;
      const createdAt = new Date(event.createdAt);
      if (startDate && createdAt < new Date(startDate)) return false;
      if (endDate && createdAt > new Date(endDate)) return false;
    }
    return true;
  }).sort((a, b) => {
    const left = a.createdAt ?? "";
    const right = b.createdAt ?? "";
    return right.localeCompare(left);
  }).slice(0, limit);

  return JSON.stringify({
    count: events.length,
    events,
  });
}

/**
 * Handle getMonitoringEvents function call
 * Query monitoring_events collection (nested under organizations/{orgId}/monitoring_events)
 */
async function handleGetMonitoringEvents(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const siteId = normalizeString(args["siteId"]);
  const recordId = normalizeString(args["recordId"]);
  const startDate = parseDateInput(args["startDate"], "startDate");
  const endDate = parseDateInput(args["endDate"], "endDate");
  const limit = getSafeLimit(args);

  let query: Query = admin
    .firestore()
    .collection("organizations")
    .doc(organizationId)
    .collection("monitoring_events")
    .orderBy("createdAt", "desc");

  if (siteId) {
    query = query.where("siteId", "==", siteId);
  }
  if (startDate) {
    query = query.where("createdAt", ">=", startDate);
  }
  if (endDate) {
    query = query.where("createdAt", "<=", endDate);
  }

  const snapshot = await query.limit(limit).get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No monitoring events found",
    });
  }

  const monitoringEvents = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      siteId: data.siteId,
      siteName: data.siteName,
      monitoringTypeId: data.monitoringTypeId,
      monitoringDate: data.monitoringDate,
      healthStatus: data.healthStatus,
      percentCover: data.percentCover,
      percentBleaching: data.percentBleaching,
      percentDisease: data.percentDisease,
      totalCount: data.totalCount,
      createdAt: data.createdAt,
      recordId: data.recordId,
      recordModelType: data.recordModelType,
      urlPath: data.urlPath,
    };
  }).filter((event) => {
    if (recordId && event.recordId !== recordId) return false;
    return true;
  });

  return JSON.stringify({
    count: monitoringEvents.length,
    monitoringEvents,
  });
}

/**
 * Handle getMonitoringSchedules function call
 * Query monitoring_schedules collection
 */
async function handleGetMonitoringSchedules(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const siteId = normalizeString(args["siteId"]);
  const dueBefore = parseDateInput(args["dueBefore"], "dueBefore");
  const dueAfter = parseDateInput(args["dueAfter"], "dueAfter");
  const overdueOnly = normalizeBoolean(args["overdueOnly"], false);
  const limit = getSafeLimit(args);

  let query: Query = admin
    .firestore()
    .collection("monitoring_schedules")
    .where("organizationId", "==", organizationId)
    .orderBy("nextDueDate", "asc")
    .limit(limit);

  const snapshot = await query.get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No monitoring schedules found",
    });
  }

  const now = new Date();
  const schedules = snapshot.docs.map((doc) => {
    const data = doc.data();
    const nextDue = data.nextDueDate;
    const nextDueDate = nextDue ? new Date(nextDue) : undefined;
    return {
      id: doc.id,
      siteId: data.siteId,
      intervalDays: data.intervalDays,
      lastMonitoringDate: data.lastMonitoringDate,
      nextDueDate: data.nextDueDate,
      permitRequirement: data.permitRequirement,
      isOverdue: nextDueDate ? nextDueDate < now : false,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    };
  }).filter((schedule) => {
    if (siteId && schedule.siteId !== siteId) return false;
    if (overdueOnly && !schedule.isOverdue) return false;
    if (dueBefore || dueAfter) {
      if (!schedule.nextDueDate) return false;
      const dueDate = new Date(schedule.nextDueDate);
      if (dueBefore && dueDate > new Date(dueBefore)) return false;
      if (dueAfter && dueDate < new Date(dueAfter)) return false;
    }
    return true;
  });

  return JSON.stringify({
    count: schedules.length,
    schedules,
  });
}

/**
 * Handle getEnvironmentalEvents function call
 * Query environmental_events collection
 */
async function handleGetEnvironmentalEvents(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const eventType = normalizeString(args["eventType"]);
  const severity = normalizeString(args["severity"]);
  const siteId = normalizeString(args["siteId"]);
  const activeOnly = normalizeBoolean(args["activeOnly"], false);
  const limit = getSafeLimit(args);

  const snapshot = await admin
    .firestore()
    .collection("environmental_events")
    .where("organizationId", "==", organizationId)
    .orderBy("startDate", "desc")
    .limit(limit)
    .get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No environmental events found",
    });
  }

  const now = new Date().toISOString();
  const environmentalEvents = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      eventType: data.eventType,
      severity: data.severity,
      startDate: data.startDate,
      endDate: data.endDate,
      affectedSiteIds: data.affectedSiteIds || [],
      description: data.description,
      source: data.source,
      createdAt: data.createdAt,
    };
  }).filter((event) => {
    if (eventType && event.eventType !== eventType) return false;
    if (severity && event.severity !== severity) return false;
    if (siteId && !(event.affectedSiteIds || []).includes(siteId)) return false;
    if (activeOnly) {
      const endsAfterNow = !event.endDate || event.endDate > now;
      if (!endsAfterNow) return false;
    }
    return true;
  });

  return JSON.stringify({
    count: environmentalEvents.length,
    environmentalEvents,
  });
}

/**
 * Handle getMissions function call
 * Query missions collection
 */
async function handleGetMissions(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const statusId = normalizeString(args["statusId"]) ?? normalizeString(args["status"]);
  const startDate = parseDateInput(args["startDate"], "startDate");
  const endDate = parseDateInput(args["endDate"], "endDate");
  const limit = getSafeLimit(args);

  let query: Query = admin
    .firestore()
    .collection("missions")
    .where("organizationId", "==", organizationId)
    .orderBy("scheduledDate", "asc")
    .limit(limit);

  if (statusId) {
    query = query.where("statusId", "==", statusId);
  }
  if (startDate) {
    query = query.where("scheduledDate", ">=", startDate);
  }
  if (endDate) {
    query = query.where("scheduledDate", "<=", endDate);
  }

  const snapshot = await query.get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No missions found",
    });
  }

  const missions = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      description: data.description,
      statusId: data.statusId,
      scheduledDate: data.scheduledDate,
      endDate: data.endDate,
      siteIds: data.siteIds || [],
      taskIds: data.taskIds || [],
      vesselId: data.vesselId,
      vesselRequirements: data.vesselRequirements,
      deliverableIds: data.deliverableIds || [],
      crewUserIds: data.crewUserIds || [],
      estimatedDurationHours: data.estimatedDurationHours,
      notes: data.notes,
      weatherSnapshot: data.weatherSnapshot,
      plannedAllocations: data.plannedAllocations || [],
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    };
  });

  return JSON.stringify({
    count: missions.length,
    missions,
  });
}

/**
 * Handle getDeliverables function call
 * Query deliverables collection
 */
async function handleGetDeliverables(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const statusId = normalizeString(args["statusId"]) ?? normalizeString(args["status"]);
  const permitId = normalizeString(args["permitId"]);
  const funderId = normalizeString(args["funderId"]);
  const siteId = normalizeString(args["siteId"]);
  const dueBefore = parseDateInput(args["dueBefore"], "dueBefore");
  const dueAfter = parseDateInput(args["dueAfter"], "dueAfter");
  const limit = getSafeLimit(args);

  let query: Query = admin
    .firestore()
    .collection("deliverables")
    .where("organizationId", "==", organizationId)
    .orderBy("dueDate", "asc")
    .limit(limit);

  if (statusId) {
    query = query.where("statusId", "==", statusId);
  }

  const snapshot = await query.get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No deliverables found",
    });
  }

  const deliverables = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      description: data.description,
      permitId: data.permitId,
      statusId: data.statusId,
      typeId: data.typeId,
      frequencyId: data.frequencyId,
      dueDate: data.dueDate,
      completedAt: data.completedAt,
      lastReportGeneratedAt: data.lastReportGeneratedAt,
      progressPercent: data.progressPercent,
      requiredSiteIds: data.requiredSiteIds || [],
      funderIds: data.funderIds || [],
      funderName: data.funderName,
      funderContactName: data.funderContactName,
      funderContactEmail: data.funderContactEmail,
      grantNumber: data.grantNumber,
      isExclusive: data.isExclusive,
      assigneeUserIds: data.assigneeUserIds || [],
      totalOrganismTarget: data.totalOrganismTarget,
      genetDiversityTarget: data.genetDiversityTarget,
      speciesTargets: data.speciesTargets || [],
      siteAllocations: data.siteAllocations || [],
      monitoringRequirements: data.monitoringRequirements || [],
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    };
  }).filter((deliverable) => {
    if (permitId && deliverable.permitId !== permitId) return false;
    if (funderId && !(deliverable.funderIds || []).includes(funderId)) return false;
    if (siteId && !(deliverable.requiredSiteIds || []).includes(siteId)) return false;
    if (dueBefore || dueAfter) {
      if (!deliverable.dueDate) return false;
      const dueDate = new Date(deliverable.dueDate);
      if (dueBefore && dueDate > new Date(dueBefore)) return false;
      if (dueAfter && dueDate < new Date(dueAfter)) return false;
    }
    return true;
  });

  return JSON.stringify({
    count: deliverables.length,
    deliverables,
  });
}

/**
 * Handle getPermits function call
 * Query permits collection
 */
async function handleGetPermits(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const siteId = normalizeString(args["siteId"]);
  const activeOnly = normalizeBoolean(args["activeOnly"], false);
  const limit = getSafeLimit(args);

  const snapshot = await admin
    .firestore()
    .collection("permits")
    .where("organizationId", "==", organizationId)
    .orderBy("validTo", "asc")
    .limit(limit)
    .get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No permits found",
    });
  }

  const now = new Date();
  const permits = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      permitNumber: data.permitNumber,
      name: data.name || data.displayName || doc.id,
      issuingAuthority: data.issuingAuthority,
      typeId: data.typeId,
      validFrom: data.validFrom,
      validTo: data.validTo,
      siteIds: data.siteIds || [],
      contactName: data.contactName,
      contactEmail: data.contactEmail,
      authorizedActivities: data.authorizedActivities || [],
      regulatoryAgency: data.regulatoryAgency,
      permitConditions: data.permitConditions,
      attachmentUrls: data.attachmentUrls || [],
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    };
  }).filter((permit) => {
    if (siteId && !(permit.siteIds || []).includes(siteId)) return false;
    if (activeOnly && permit.validFrom && permit.validTo) {
      const validFrom = new Date(permit.validFrom);
      const validTo = new Date(permit.validTo);
      if (now < validFrom || now > validTo) return false;
    }
    return true;
  });

  return JSON.stringify({
    count: permits.length,
    permits,
  });
}

/**
 * Handle getVessels function call
 * Query vessels collection
 */
async function handleGetVessels(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const statusId = normalizeString(args["statusId"]) ?? normalizeString(args["status"]);
  const limit = getSafeLimit(args);

  const snapshot = await admin
    .firestore()
    .collection("vessels")
    .where("organizationId", "==", organizationId)
    .orderBy("name", "asc")
    .limit(limit)
    .get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No vessels found",
    });
  }

  const vessels = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      registrationNumber: data.registrationNumber,
      crewCapacity: data.crewCapacity,
      maxSpeedKnots: data.maxSpeedKnots,
      homePortSiteId: data.homePortSiteId,
      capabilities: data.capabilities || [],
      fuelCapacityGallons: data.fuelCapacityGallons,
      rangeNauticalMiles: data.rangeNauticalMiles,
      statusId: data.statusId,
      status: data.statusId,
      specifications: data.specifications,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    };
  }).filter((vessel) => {
    if (statusId && vessel.statusId !== statusId) return false;
    return true;
  });

  return JSON.stringify({
    count: vessels.length,
    vessels,
  });
}

/**
 * Handle getFunders function call
 * Query funders collection
 */
async function handleGetFunders(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const activeOnly = normalizeBoolean(args["activeOnly"], false);
  const limit = getSafeLimit(args);

  const snapshot = await admin
    .firestore()
    .collection("funders")
    .where("organizationId", "==", organizationId)
    .orderBy("name", "asc")
    .limit(limit)
    .get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No funders found",
    });
  }

  const funders = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      isActive: data.isActive,
      contactName: data.contactName,
      contactEmail: data.contactEmail,
      notes: data.notes,
      logoUrl: data.logoUrl,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    };
  }).filter((funder) => {
    if (activeOnly && funder.isActive !== true) return false;
    return true;
  });

  return JSON.stringify({
    count: funders.length,
    funders,
  });
}

/**
 * Handle searchWeb function call
 * Search public web resources using DuckDuckGo Instant Answer API
 */
async function handleSearchWeb(
  _organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const query = sanitizeSearchQuery(args["query"]);
  const limit = Math.min(getSafeLimit(args, MAX_WEB_RESULTS), MAX_WEB_RESULTS);

  if (!query) {
    return JSON.stringify({
      message: "Please provide a search query",
    });
  }

  const url = new URL("https://api.duckduckgo.com/");
  url.searchParams.set("q", query);
  url.searchParams.set("format", "json");
  url.searchParams.set("no_html", "1");
  url.searchParams.set("no_redirect", "1");
  url.searchParams.set("t", "seafoundry");

  const response = await fetch(url.toString(), {
    headers: {
      "User-Agent": "SeaFoundry-Sebastian/1.0",
    },
  });

  if (!response.ok) {
    return JSON.stringify({
      query,
      count: 0,
      error: `Web search failed with status ${response.status}`,
    });
  }

  const data = await response.json() as Record<string, unknown>;
  const results: Array<{title: string; url: string; snippet?: string}> = [];
  const seen = new Set<string>();

  const pushResult = (title?: string, url?: string, snippet?: string) => {
    if (!title || !url) return;
    if (seen.has(url)) return;
    seen.add(url);
    results.push({
      title: title.trim(),
      url: url.trim(),
      snippet: snippet?.trim(),
    });
  };

  if (typeof data["AbstractText"] === "string" && typeof data["AbstractURL"] === "string") {
    pushResult(
      typeof data["Heading"] === "string" ? data["Heading"] : "Summary",
      data["AbstractURL"],
      data["AbstractText"]
    );
  }

  const parseTopics = (topics: unknown) => {
    if (!Array.isArray(topics)) return;
    for (const entry of topics) {
      if (!entry || typeof entry !== "object") continue;
      const topic = entry as Record<string, unknown>;
      if (Array.isArray(topic["Topics"])) {
        parseTopics(topic["Topics"]);
      } else if (typeof topic["Text"] === "string" && typeof topic["FirstURL"] === "string") {
        pushResult(topic["Text"], topic["FirstURL"]);
      }
    }
  };

  parseTopics(data["RelatedTopics"]);

  const sliced = results.slice(0, limit);

  if (sliced.length === 0) {
    return JSON.stringify({
      query,
      count: 0,
      message: "No web results found.",
      provider: "duckduckgo",
    });
  }

  return JSON.stringify({
    query,
    count: sliced.length,
    results: sliced,
    provider: "duckduckgo",
  });
}

// Built-in help documentation for common topics
const HELP_DOCUMENTATION: Array<{
  topic: string;
  keywords: string[];
  content: string;
}> = [
  {
    topic: "Holdings & Inventory",
    keywords: ["holdings", "inventory", "count", "organisms", "coral", "quantity"],
    content: `Holdings represent your organization's inventory of organisms (corals, kelp, oysters, etc.).
    To view holdings: Navigate to Inventory > Holdings from the main menu.
    To add holdings: Click the + button on the holdings screen.
    Holdings track: quantity, life stage, location (structure/site), genetic lineage (genet).`,
  },
  {
    topic: "Genets & Genetics",
    keywords: ["genet", "genetics", "provenance", "clone", "lineage", "provenanceId"],
    content: `Genets (genetic individuals) track the provenance of your organisms.
    Each genet has: a unique provenance ID, species, aliases, provenance type (wild, sexual, asexual clone).
    To manage genets: Go to Genetics tab in Inventory.
    Cohorts group organisms from the same genetic lineage at different stages.`,
  },
  {
    topic: "Sites & Locations",
    keywords: ["site", "location", "nursery", "outplant", "field", "coordinates"],
    content: `Sites are physical locations where restoration work happens.
    Site types: Nursery (holding/growing), Outplant (deployment), Field (monitoring).
    To create a site: Dashboard > Sites > Add Site.
    Sites can contain multiple structures (racks, trees, tanks).`,
  },
  {
    topic: "Tasks & Workflows",
    keywords: ["task", "workflow", "todo", "assign", "husbandry", "schedule"],
    content: `Tasks help organize work across your team.
    Task types: Husbandry, Monitoring, Maintenance, Treatment.
    To create tasks: Click + on any record or from the Tasks dashboard.
    Tasks can be assigned to team members with due dates and priorities.`,
  },
  {
    topic: "Coral Biology & Ecology",
    keywords: [
      "coral biology",
      "polyp",
      "zooxanthellae",
      "symbiosis",
      "calcification",
      "reef ecology",
      "trophic",
    ],
    content: `Corals are colonial animals made of polyps that build calcium carbonate skeletons.
    Reef-building corals host symbiotic algae (zooxanthellae) that provide energy via photosynthesis.
    Corals also feed heterotrophically on plankton and organic particles.
    Growth and calcification depend on stable temperature, light, water chemistry, and flow.
    Ecological role: habitat creation, coastal protection, and biodiversity support.`,
  },
  {
    topic: "Bleaching & Stress",
    keywords: [
      "bleaching",
      "stress",
      "heat",
      "disease",
      "sedimentation",
      "acidification",
    ],
    content: `Bleaching occurs when corals expel or lose symbiotic algae under stress.
    Common stressors: heat spikes, high light, poor water quality, sedimentation, disease, and salinity shifts.
    Recovery depends on stress duration, species resilience, and post-stress conditions.
    Track bleaching, disease signs, and mortality in monitoring events for trend analysis.`,
  },
  {
    topic: "Coral Husbandry Basics",
    keywords: [
      "husbandry",
      "nursery",
      "water quality",
      "flow",
      "lighting",
      "cleaning",
      "feeding",
    ],
    content: `Husbandry focuses on stable water parameters, good flow, and consistent light exposure.
    Routine tasks include cleaning biofouling, checking equipment, and observing tissue health.
    Maintain records of treatments, feeding, and environmental adjustments.
    Use quarantine/isolation for new or stressed stock to reduce cross-contamination.
    Consult qualified experts for specific treatment protocols.`,
  },
  {
    topic: "Pests, Disease & Biosecurity",
    keywords: [
      "pest",
      "parasite",
      "disease",
      "biosecurity",
      "quarantine",
      "pathogen",
    ],
    content: `Biosecurity reduces disease spread via quarantine, tool disinfection, and separate workflows.
    Document symptoms with photos, health status, and location to enable pattern tracking.
    Isolate affected organisms when possible and avoid transferring between sites.
    Treatment approaches should follow vetted protocols and local regulations.`,
  },
  {
    topic: "Propagation & Fragmentation",
    keywords: [
      "propagation",
      "fragmentation",
      "asexual",
      "nursery growth",
      "fusion",
      "microfragment",
    ],
    content: `Asexual propagation uses fragments or microfragments to scale biomass.
    Track parent genet IDs to preserve lineage and avoid genetic bottlenecks.
    Monitor attachment success, tissue growth, and survival rates post-fragmentation.
    Record propagation events and update life stage status when fragments stabilize.`,
  },
  {
    topic: "Sexual Reproduction & Spawning",
    keywords: [
      "spawning",
      "gamete",
      "larvae",
      "settlement",
      "sexual reproduction",
    ],
    content: `Sexual reproduction increases genetic diversity and adaptive potential.
    Key stages: gamete collection, fertilization, larval rearing, settlement, and grow-out.
    Track cohorts by spawn date, parent genets, and settlement substrate.
    Capture survival and growth metrics to evaluate cohort performance.`,
  },
  {
    topic: "Outplanting Practices",
    keywords: [
      "outplant",
      "site selection",
      "attachment",
      "acclimation",
      "survival",
      "restoration site",
    ],
    content: `Site selection considers habitat suitability, stress exposure, access, and permitting.
    Match genets to microhabitats to spread risk and improve survival.
    Use standardized attachment methods and record methods/materials used.
    Monitor early survival and adjust practices based on performance data.`,
  },
  {
    topic: "Restoration Theory & Strategy",
    keywords: [
      "restoration theory",
      "genetic diversity",
      "resilience",
      "adaptive management",
      "assisted gene flow",
    ],
    content: `Effective restoration balances scale with genetic diversity and ecological fit.
    Use diverse genets and cohorts to increase resilience to stress and disease.
    Adaptive management: monitor outcomes, adjust protocols, and document changes.
    Consider connectivity, larval supply, and ecosystem interactions in planning.`,
  },
  {
    topic: "Monitoring & Evaluation",
    keywords: [
      "monitoring",
      "survival",
      "growth",
      "cover",
      "disease prevalence",
      "photogrammetry",
    ],
    content: `Monitoring tracks survival, growth, bleaching, disease, and ecological recovery.
    Use consistent timepoints and standardized methods to compare across sites.
    Combine field observations with imagery where possible for auditing.
    Use monitoring results to inform husbandry and outplant strategy updates.`,
  },
  {
    topic: "Missions & Operations",
    keywords: ["mission", "operations", "field work", "crew", "vessel"],
    content: `Missions coordinate field operations across sites, tasks, and crew.
    Missions can include scheduled dates, assigned vessels, and linked tasks.
    To manage missions: Go to Operations > Missions in the Mission Center.`,
  },
  {
    topic: "Permits & Deliverables",
    keywords: ["permit", "deliverable", "compliance", "report", "renewal"],
    content: `Permits define regulatory requirements and linked deliverables.
    Deliverables track required reports, surveys, and compliance milestones.
    Manage permits and deliverables via Operations > Permits.`,
  },
  {
    topic: "Outplanting",
    keywords: ["outplant", "deploy", "restoration", "transplant", "permit"],
    content: `Outplanting records the deployment of organisms to restoration sites.
    Before outplanting: Ensure target site exists and organisms are ready.
    Outplant data: date, location (coordinates), quantity, permit info.
    Access via: Inventory > Outplants or from the site/structure.`,
  },
  {
    topic: "Monitoring",
    keywords: ["monitor", "observation", "health", "bleaching", "mortality", "survey"],
    content: `Monitoring tracks organism health over time.
    Observation types: Health checks, Bleaching surveys, Mortality counts.
    To log observations: Select structure/site > Add Observation.
    Key metrics: % cover, % bleaching, mortality count, growth measurements.`,
  },
  {
    topic: "Transfers",
    keywords: ["transfer", "send", "receive", "qr", "manifest", "share"],
    content: `Transfers move organisms between organizations.
    To send: Select genet > Transfer > Choose destination org.
    To receive: Scan QR code or paste manifest payload.
    Transfers include: quantity, provenance info, permit data.`,
  },
  {
    topic: "Reports & Export",
    keywords: ["report", "export", "csv", "download", "data"],
    content: `Export your data for reporting and analysis.
    Available exports: Inventory, Holdings, Events, Monitoring.
    To export: Dashboard > Export > Select type.
    Formats: CSV (for Excel), detailed reports.`,
  },
  {
    topic: "Five-Axis Model",
    keywords: ["five axis", "taxonomy", "provenance", "location", "life stage", "measurement"],
    content: `SeaFoundry's Five-Axis Model organizes organism data:
    1. Taxonomy: Species classification
    2. Provenance: Genetic lineage (genet/cohort)
    3. Location/Permit: Physical location and compliance
    4. Life Stage: Current growth phase
    5. Measurement: Size, health, quantity data`,
  },
];

/**
 * Handle searchHelp function call
 * Search built-in help documentation
 */
async function handleSearchHelp(
  _organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const query = sanitizeSearchQuery(args["query"]);
  const limit = Math.min(getSafeLimit(args, 3), 10);

  if (!query) {
    return JSON.stringify({
      message: "Please provide a search query",
      topics: HELP_DOCUMENTATION.map((h) => h.topic),
    });
  }

  const queryLower = query.toLowerCase();
  const queryWords = queryLower.split(/\s+/);

  // Score each help topic by keyword matches
  const scored = HELP_DOCUMENTATION.map((help) => {
    let score = 0;

    // Check topic name match
    if (help.topic.toLowerCase().includes(queryLower)) {
      score += 10;
    }

    // Check keyword matches
    for (const keyword of help.keywords) {
      for (const word of queryWords) {
        if (keyword.includes(word) || word.includes(keyword)) {
          score += 5;
        }
      }
    }

    // Check content match
    const contentLower = help.content.toLowerCase();
    for (const word of queryWords) {
      if (contentLower.includes(word)) {
        score += 2;
      }
    }

    return {help, score};
  });

  // Sort by score and filter matches
  const matches = scored
    .filter((s) => s.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((s) => ({
      topic: s.help.topic,
      content: s.help.content,
    }));

    if (matches.length === 0) {
      return JSON.stringify({
        message: `No specific help found for "${query}". Here are available topics:`,
        topics: HELP_DOCUMENTATION.map((h) => h.topic),
        suggestion:
        "Try asking about coral biology, bleaching, husbandry, propagation, monitoring, permits, missions, or deliverables.",
      });
    }

  return JSON.stringify({
    query,
    results: matches,
    count: matches.length,
  });
}

/**
 * Handle getLifeStages function call
 * Returns hardcoded life stage values, optionally filtered by organism kind
 */
async function handleGetLifeStages(
  _organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const organismKind = validateOrganismKind(args["organismKind"]);

  // Currently all life stages apply to all organisms
  // Future: filter by organism kind if needed
  const lifeStages = LIFE_STAGES.map((stage) => ({
    ...stage,
    organismKind: organismKind || undefined,
  }));

  return JSON.stringify({
    count: lifeStages.length,
    lifeStages,
    note: organismKind ?
      `Life stages for ${organismKind}` :
      "All life stages (applicable to all organism types)",
  });
}

/**
 * Handle getGroupTypes function call
 * Returns hardcoded group/structure type values
 */
async function handleGetGroupTypes(
  _organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const category = normalizeString(args["category"]);

  let groupTypes = GROUP_TYPES;

  if (category) {
    const normalizedCategory = category.toLowerCase();
    groupTypes = GROUP_TYPES.filter(
      (gt) => gt.category.toLowerCase() === normalizedCategory
    );
  }

  if (groupTypes.length === 0) {
    return JSON.stringify({
      count: 0,
      message: category ?
        `No group types found for category: ${category}` :
        "No group types found",
      availableCategories: ["structure", "substructure", "superstructure"],
    });
  }

  return JSON.stringify({
    count: groupTypes.length,
    groupTypes,
  });
}

/**
 * Handle getSpecies function call
 * Query taxonomy_species collection (global, not org-scoped)
 */
async function handleGetSpecies(
  _organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const searchName = normalizeString(args["searchName"]);
  const organismKind = validateOrganismKind(args["organismKind"]);
  const limit = getSafeLimit(args);

  let query: Query = admin.firestore().collection("taxonomy_species");

  if (organismKind) {
    query = query.where("organismKind", "==", organismKind);
  }

  const snapshot = await query.limit(limit).get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: organismKind ?
        `No species found for organism kind: ${organismKind}` :
        "No species found",
    });
  }

  const species = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      scientificName: data.scientificName || data.name,
      commonName: data.commonName,
      organismKind: data.organismKind,
      genus: data.genus,
      family: data.family,
      order: data.order,
      class: data.class,
      phylum: data.phylum,
    };
  }).filter((sp) => {
    if (searchName) {
      const searchLower = searchName.toLowerCase();
      const scientificMatch = sp.scientificName?.toLowerCase().includes(searchLower);
      const commonMatch = sp.commonName?.toLowerCase().includes(searchLower);
      if (!scientificMatch && !commonMatch) return false;
    }
    return true;
  });

  return JSON.stringify({
    count: species.length,
    species,
  });
}

/**
 * Handle getUsers function call
 * Query users collection filtered by organizationId (SECURITY CRITICAL)
 */
async function handleGetUsers(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const role = normalizeString(args["role"]);
  const searchName = normalizeString(args["searchName"]);
  const limit = getSafeLimit(args);

  // SECURITY: Always filter by organizationId to ensure org isolation
  let query: Query = admin
    .firestore()
    .collection("users")
    .where("organizationId", "==", organizationId);

  if (role) {
    query = query.where("role", "==", role);
  }

  const snapshot = await query.limit(limit).get();

  if (snapshot.empty) {
    return JSON.stringify({
      count: 0,
      message: "No users found",
    });
  }

  // Only return safe user fields - never expose sensitive data
  const users = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.displayName || data.name || `${data.firstName || ""} ${data.lastName || ""}`.trim(),
      email: data.email,
      role: data.role,
      firstName: data.firstName,
      lastName: data.lastName,
    };
  }).filter((user) => {
    if (searchName) {
      const searchLower = searchName.toLowerCase();
      const nameMatch = user.name?.toLowerCase().includes(searchLower);
      const firstMatch = user.firstName?.toLowerCase().includes(searchLower);
      const lastMatch = user.lastName?.toLowerCase().includes(searchLower);
      if (!nameMatch && !firstMatch && !lastMatch) return false;
    }
    return true;
  });

  return JSON.stringify({
    count: users.length,
    users,
  });
}

/**
 * Handle getHoldingsSummary function call
 * Aggregate holdings counts by various dimensions
 */
async function handleGetHoldingsSummary(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const siteId = normalizeString(args["siteId"]);

  // Fetch ALL organism records for accurate aggregation (no limit)
  let query: Query = admin
    .firestore()
    .collection("organizations")
    .doc(organizationId)
    .collection("organismRecords");

  if (siteId) {
    query = query.where("siteId", "==", siteId);
  }

  const snapshot = await query.get();

  if (snapshot.empty) {
    return JSON.stringify({
      totalRecords: 0,
      totalQuantity: 0,
      byOrganismKind: {},
      bySite: {},
      byLifeStage: {},
      byHealthStatus: {},
      readiness: {
        readyForPropagation: {records: 0, quantity: 0},
        readyForOutplant: {records: 0, quantity: 0},
      },
      message: siteId ?
        `No organism records found for site ${siteId}` :
        "No organism records found",
    });
  }

  // Initialize aggregation buckets
  const byOrganismKind: Record<string, {records: number; quantity: number}> = {};
  const bySite: Record<string, {records: number; quantity: number}> = {};
  const byLifeStage: Record<string, {records: number; quantity: number}> = {};
  const byHealthStatus: Record<string, {records: number; quantity: number}> = {};
  let readyForPropagationRecords = 0;
  let readyForPropagationQuantity = 0;
  let readyForOutplantRecords = 0;
  let readyForOutplantQuantity = 0;
  let totalRecords = 0;
  let totalQuantity = 0;

  // Aggregate in memory
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const measurement = data.measurement ?? data.population;
    const rawQuantity = measurement?.value ?? data.quantity ?? data.count ?? 1;
    // Validate quantity is a valid number to prevent NaN propagation
    const quantity = (typeof rawQuantity === "number" && Number.isFinite(rawQuantity)) ? rawQuantity : 1;
    const organismKind = resolveOrganismKind(data, "coral") ?? "unknown";
    const recordSiteId = data.siteId ?? "unassigned";
    const lifeStageId = extractLifeStageId(data) ?? "unknown";
    const metadata = extractMetadata(data) ?? {};
    const healthStatus = (typeof metadata["healthStatus"] === "string" ?
      metadata["healthStatus"] :
      typeof data.healthStatus === "string" ? data.healthStatus : "unknown") as string;
    const isReadyForPropagation =
      metadata["readyForPropagation"] === true || data.readyForPropagation === true;
    const isReadyForOutplant =
      metadata["readyForOutplant"] === true || data.readyForOutplant === true;

    totalRecords++;
    totalQuantity += quantity;

    // By organism kind
    if (!byOrganismKind[organismKind]) {
      byOrganismKind[organismKind] = {records: 0, quantity: 0};
    }
    byOrganismKind[organismKind].records++;
    byOrganismKind[organismKind].quantity += quantity;

    // By site
    if (!bySite[recordSiteId]) {
      bySite[recordSiteId] = {records: 0, quantity: 0};
    }
    bySite[recordSiteId].records++;
    bySite[recordSiteId].quantity += quantity;

    // By life stage
    if (!byLifeStage[lifeStageId]) {
      byLifeStage[lifeStageId] = {records: 0, quantity: 0};
    }
    byLifeStage[lifeStageId].records++;
    byLifeStage[lifeStageId].quantity += quantity;

    // By health status
    if (!byHealthStatus[healthStatus]) {
      byHealthStatus[healthStatus] = {records: 0, quantity: 0};
    }
    byHealthStatus[healthStatus].records++;
    byHealthStatus[healthStatus].quantity += quantity;

    // Readiness flags
    if (isReadyForPropagation) {
      readyForPropagationRecords++;
      readyForPropagationQuantity += quantity;
    }
    if (isReadyForOutplant) {
      readyForOutplantRecords++;
      readyForOutplantQuantity += quantity;
    }
  }

  return JSON.stringify({
    totalRecords,
    totalQuantity,
    byOrganismKind,
    bySite,
    byLifeStage,
    byHealthStatus,
    readiness: {
      readyForPropagation: {
        records: readyForPropagationRecords,
        quantity: readyForPropagationQuantity,
      },
      readyForOutplant: {
        records: readyForOutplantRecords,
        quantity: readyForOutplantQuantity,
      },
    },
  });
}

/**
 * Handle getTaskCounts function call
 * Aggregate task counts by status and urgency
 */
async function handleGetTaskCounts(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const dueSoonDays = typeof args["dueSoonDays"] === "number" ?
    Math.max(1, Math.floor(args["dueSoonDays"])) : 7;

  // Fetch ALL tasks for accurate counts (no limit)
  const snapshot = await admin
    .firestore()
    .collection("events")
    .where("organizationId", "==", organizationId)
    .where("eventTypeId", "==", "event_task")
    .get();

  if (snapshot.empty) {
    return JSON.stringify({
      total: 0,
      byStatus: {
        not_started: 0,
        in_progress: 0,
        completed: 0,
      },
      overdue: 0,
      dueSoon: 0,
      unassigned: 0,
      message: "No tasks found",
    });
  }

  const now = new Date();
  const dueSoonThreshold = new Date(now.getTime() + dueSoonDays * 24 * 60 * 60 * 1000);

  const byStatus: Record<string, number> = {
    not_started: 0,
    in_progress: 0,
    completed: 0,
  };
  let overdue = 0;
  let dueSoon = 0;
  let unassigned = 0;
  let total = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const status = data.statusId || data.status || "not_started";
    const deadline = data.deadline || data.dueDate;
    const assignedUserId = data.assignedUserId;
    const assignedRoleId = data.assignedRoleId;

    total++;

    // Count by status
    if (status in byStatus) {
      byStatus[status]++;
    } else {
      // Handle any unexpected statuses
      byStatus[status] = (byStatus[status] || 0) + 1;
    }

    // Only count overdue/dueSoon for non-completed tasks
    if (status !== "completed" && deadline) {
      const deadlineDate = new Date(deadline);
      // Validate date is valid before comparing
      if (!Number.isNaN(deadlineDate.getTime())) {
        if (deadlineDate < now) {
          overdue++;
        } else if (deadlineDate <= dueSoonThreshold) {
          dueSoon++;
        }
      }
    }

    // Unassigned if no user and no role assigned
    if (!assignedUserId && !assignedRoleId) {
      unassigned++;
    }
  }

  return JSON.stringify({
    total,
    byStatus,
    overdue,
    dueSoon,
    unassigned,
    dueSoonDays,
  });
}

/**
 * Handle getSiteSummary function call
 * Get per-site summary with holdings and group counts
 */
async function handleGetSiteSummary(
  organizationId: string,
  args: FunctionArgs
): Promise<string> {
  const siteType = normalizeString(args["siteType"]);
  const includeArchived = normalizeBoolean(args["includeArchived"], false);

  // Fetch all sites (no limit for aggregation)
  const sitesSnapshot = await admin
    .firestore()
    .collection("sites")
    .where("organizationId", "==", organizationId)
    .get();

  if (sitesSnapshot.empty) {
    return JSON.stringify({
      totalSites: 0,
      sites: [],
      bySiteType: {},
      message: "No sites found",
    });
  }

  // Build site map
  const siteMap: Record<string, {
    id: string;
    name: string;
    siteTypeId: string;
    isArchived: boolean;
    holdingsCount: number;
    totalQuantity: number;
    groupCount: number;
  }> = {};

  for (const doc of sitesSnapshot.docs) {
    const data = doc.data();
    const resolvedSiteType = data.siteTypeId || data.siteType || data.type || "unknown";
    const isArchived = data.isArchived || false;

    // Apply filters
    if (!includeArchived && isArchived) continue;
    if (siteType && resolvedSiteType !== siteType) continue;

    siteMap[doc.id] = {
      id: doc.id,
      name: data.name || data.displayName || doc.id,
      siteTypeId: resolvedSiteType,
      isArchived,
      holdingsCount: 0,
      totalQuantity: 0,
      groupCount: 0,
    };
  }

  const siteIds = Object.keys(siteMap);
  if (siteIds.length === 0) {
    return JSON.stringify({
      totalSites: 0,
      sites: [],
      bySiteType: {},
      message: siteType ?
        `No sites found with type: ${siteType}` :
        "No sites found (all archived)",
    });
  }

  // Fetch all organism records for these sites (no limit)
  const holdingsSnapshot = await admin
    .firestore()
    .collection("organizations")
    .doc(organizationId)
    .collection("organismRecords")
    .get();

  for (const doc of holdingsSnapshot.docs) {
    const data = doc.data();
    const holdingSiteId = data.siteId;
    if (holdingSiteId && siteMap[holdingSiteId]) {
      const measurement = data.measurement ?? data.population;
      const rawQuantity = measurement?.value ?? data.quantity ?? data.count ?? 1;
      // Validate quantity is a valid number to prevent NaN propagation
      const quantity = (typeof rawQuantity === "number" && Number.isFinite(rawQuantity)) ? rawQuantity : 1;
      siteMap[holdingSiteId].holdingsCount++;
      siteMap[holdingSiteId].totalQuantity += quantity;
    }
  }

  // Fetch all groups for these sites (no limit)
  const groupsSnapshot = await admin
    .firestore()
    .collection("organizations")
    .doc(organizationId)
    .collection("groups")
    .get();

  for (const doc of groupsSnapshot.docs) {
    const data = doc.data();
    const groupSiteId = data.siteId;
    if (groupSiteId && siteMap[groupSiteId]) {
      siteMap[groupSiteId].groupCount++;
    }
  }

  // Build response
  const sites = Object.values(siteMap);

  // Aggregate by site type
  const bySiteType: Record<string, {sites: number; totalQuantity: number}> = {};
  for (const site of sites) {
    if (!bySiteType[site.siteTypeId]) {
      bySiteType[site.siteTypeId] = {sites: 0, totalQuantity: 0};
    }
    bySiteType[site.siteTypeId].sites++;
    bySiteType[site.siteTypeId].totalQuantity += site.totalQuantity;
  }

  return JSON.stringify({
    totalSites: sites.length,
    sites,
    bySiteType,
  });
}

/**
 * Handle submitFeedback function call
 * Submit bug reports, feature requests, or general feedback
 */
async function handleSubmitFeedback(
  organizationId: string,
  args: FunctionArgs,
  context?: SebastianContext
): Promise<string> {
  // Validate feedbackType
  const feedbackType = normalizeString(args["feedbackType"]);
  if (!feedbackType || !ALLOWED_FEEDBACK_TYPES.includes(feedbackType)) {
    return JSON.stringify({
      success: false,
      error: `Invalid feedback type. Allowed values: ${ALLOWED_FEEDBACK_TYPES.join(", ")}`,
    });
  }

  // Validate description (required, min 10 chars)
  const description = normalizeString(args["description"], 5000);
  if (!description || description.length < 10) {
    return JSON.stringify({
      success: false,
      error: "Description must be at least 10 characters",
    });
  }

  // Validate severity (optional, only for bug_report)
  const rawSeverity = normalizeString(args["severity"]);
  let severity: string | null = null;
  if (feedbackType === "bug_report" && rawSeverity) {
    if (!ALLOWED_SEVERITY_LEVELS.includes(rawSeverity)) {
      return JSON.stringify({
        success: false,
        error: `Invalid severity. Allowed values: ${ALLOWED_SEVERITY_LEVELS.join(", ")}`,
      });
    }
    severity = rawSeverity;
  }

  // Validate stepsToReproduce (optional)
  const stepsToReproduce = normalizeString(args["stepsToReproduce"], 2000);

  // Generate ticket ID: SF-{timestamp}-{random}
  const timestamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).substring(2, 6).toUpperCase();
  const ticketId = `SF-${timestamp}-${random}`;

  // Build document with safe user context
  const feedbackDoc = {
    ticketId,
    feedbackType,
    description,
    severity: feedbackType === "bug_report" ? severity : null,
    stepsToReproduce: stepsToReproduce || null,
    context: {
      organizationId,
      organizationName: context?.organizationName || null,
      tier: context?.tier || null,
      userId: context?.userId || null,
      userName: context?.userName || null,
      currentScreen: context?.currentScreen || null,
      currentNodeType: context?.currentNodeType || null,
    },
    status: "open",
    createdAt: new Date().toISOString(),
    source: "sebastian_chat",
  };

  // Store in Firestore feedback collection (not org-scoped for admin visibility)
  await admin.firestore().collection("feedback").doc(ticketId).set(feedbackDoc);

  // Format response message based on feedback type
  const typeLabel = feedbackType.replace(/_/g, " ");
  return JSON.stringify({
    success: true,
    ticketId,
    message: `Thank you for your ${typeLabel}! Ticket ID: ${ticketId}`,
    feedbackType,
  });
}

/**
 * Execute function call based on function name
 */
export async function executeFunctionCall(
  functionName: string,
  args: FunctionArgs,
  organizationId: string,
  context?: SebastianContext
): Promise<string> {
  switch (functionName) {
  case "getOrganismHoldings":
    return handleGetOrganismHoldings(organizationId, args);
  case "getHoldings":
    return handleGetHoldings(organizationId, args);
  case "getCohorts":
    return handleGetCohorts(organizationId, args);
  case "getGenets":
    return handleGetGenets(organizationId, args);
  case "getGroups":
    return handleGetGroups(organizationId, args);
  case "getZones":
    return handleGetZones(organizationId, args);
  case "getSubplots":
    return handleGetSubplots(organizationId, args);
  case "getSites":
    return handleGetSites(organizationId, args);
  case "getTasks":
    return handleGetTasks(organizationId, args);
  case "getEvents":
    return handleGetEvents(organizationId, args);
  case "getHusbandryEvents":
    return handleGetHusbandryEvents(organizationId, args);
  case "getMonitoringEvents":
    return handleGetMonitoringEvents(organizationId, args);
  case "getMonitoringSchedules":
    return handleGetMonitoringSchedules(organizationId, args);
  case "getEnvironmentalEvents":
    return handleGetEnvironmentalEvents(organizationId, args);
  case "getMissions":
    return handleGetMissions(organizationId, args);
  case "getDeliverables":
    return handleGetDeliverables(organizationId, args);
  case "getPermits":
    return handleGetPermits(organizationId, args);
  case "getVessels":
    return handleGetVessels(organizationId, args);
  case "getFunders":
    return handleGetFunders(organizationId, args);
  case "searchHelp":
    return handleSearchHelp(organizationId, args);
  case "searchWeb":
    return handleSearchWeb(organizationId, args);
  case "getLifeStages":
    return handleGetLifeStages(organizationId, args);
  case "getGroupTypes":
    return handleGetGroupTypes(organizationId, args);
  case "getSpecies":
    return handleGetSpecies(organizationId, args);
  case "getUsers":
    return handleGetUsers(organizationId, args);
  case "getHoldingsSummary":
    return handleGetHoldingsSummary(organizationId, args);
  case "getTaskCounts":
    return handleGetTaskCounts(organizationId, args);
  case "getSiteSummary":
    return handleGetSiteSummary(organizationId, args);
  case "submitFeedback":
    return handleSubmitFeedback(organizationId, args, context);
  default:
    throw new Error(`Unknown function: ${functionName}`);
  }
}
