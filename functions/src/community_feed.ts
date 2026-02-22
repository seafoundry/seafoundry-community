import * as admin from "firebase-admin";
import {createHash} from "crypto";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {getCorsOrigins} from "./cors";

const COMMUNITY_CHANNELS_COLLECTION = "community_channels";
const COMMUNITY_AUTOMATION_COLLECTION = "community_automation";
const COMMUNITY_POST_DEDUPE_COLLECTION = "community_post_dedupe";
const EVENTS_COLLECTION = "events";
const ORGANIZATIONS_COLLECTION = "organizations";
const USERS_COLLECTION = "users";

const SYSTEM_USER_ID = "sebastian";
const SYSTEM_USER_NAME = "Sebastian AI";
const SYSTEM_ORG_ID = "provenanceapp";
const SYSTEM_ORG_NAME = "SeaFoundry";
const OUTPLANT_BOT_ID = "community_bot";
const OUTPLANT_BOT_NAME = "SeaFoundry Updates";

const DATA_PRIVACY_DOC_ID = "data_privacy";

const NURSERY_SITE_TYPES = new Set([
  "site_type_nursery_ex_situ",
  "site_type_nursery_in_situ",
  "site_type_gene_bank",
]);

const OUTPLANT_SITE_TYPES = new Set([
  "site_type_outplanting",
  "site_type_mangrove_outplant",
]);

const DEFAULT_CHANNELS = [
  {
    name: "general",
    iconEmoji: "💬",
    description: "General community discussion and updates.",
  },
  {
    name: "restoration",
    iconEmoji: "🌊",
    description: "Restoration updates, outplanting activity, and field notes.",
  },
  {
    name: "research",
    iconEmoji: "🔬",
    description: "Research insights, monitoring data, and experimentation.",
  },
  {
    name: "equipment",
    iconEmoji: "🛠️",
    description: "Equipment tips, maintenance, and field setup workflows.",
  },
  {
    name: "opportunities",
    iconEmoji: "🎯",
    description: "Funding, grants, partnerships, and volunteer opportunities.",
  },
  {
    name: "issues",
    iconEmoji: "⚠️",
    description: "Report issues, bugs, and platform feedback.",
  },
];

const DAILY_TEMPLATES: Record<string, Array<{title: string; body: string}>> = {
  general: [
    {
      title: "Community pulse for {weekday}",
      body:
        "Quick check-in: what is the biggest restoration win from your week? " +
        "Share a photo or a short note; small updates add up.",
    },
    {
      title: "{weekday} field highlights",
      body:
        "Friendly reminder to log site photos and any unusual observations. " +
        "Consistent notes help everyone compare outcomes across regions.",
    },
    {
      title: "Today's community prompt",
      body:
        "What is one tool, trick, or workflow that saved you time recently? " +
        "Drop it here so others can try it.",
    },
    {
      title: "Weekly rhythm check",
      body:
        "If you are planning fieldwork this week, share your schedule window. " +
        "Cross-team visibility helps reduce overlap and improves safety.",
    },
    {
      title: "Community sync: {date}",
      body:
        "Any lessons learned from the last field day? Short writeups help " +
        "the whole network move faster.",
    },
  ],
  restoration: [
    {
      title: "Restoration focus: {weekday}",
      body:
        "If you are scheduling outplants this week, double-check attachment methods " +
        "and crew roles so the field day runs smoothly.",
    },
    {
      title: "Outplanting checklist",
      body:
        "Before heading out: confirm permits, verify site coordinates, and prep backup " +
        "attachment kits. A 10-minute review saves hours offshore.",
    },
    {
      title: "Post-outplant watchlist",
      body:
        "After outplanting, log any early stress signs in the first 48-72 hours. " +
        "Early detection makes a big difference.",
    },
    {
      title: "Site readiness nudge",
      body:
        "Check substrate condition and attachment points before transport. " +
        "A quick pre-flight scan prevents surprises on site.",
    },
    {
      title: "Restoration recap",
      body:
        "If you completed a field day recently, log counts and photos while they are fresh. " +
        "Clear records improve outcome tracking.",
    },
  ],
  research: [
    {
      title: "Research roundup for {weekday}",
      body:
        "Consider logging baseline conditions before any interventions. " +
        "Those comparisons are gold when reviewing outcomes later.",
    },
    {
      title: "Monitoring note",
      body:
        "If you are sampling this week, align photo framing and metadata tags. " +
        "Consistent capture makes analysis much faster.",
    },
    {
      title: "Data hygiene tip",
      body:
        "Run a quick audit for missing species or provenance fields. " +
        "Clean inputs now save time during reporting.",
    },
    {
      title: "Method consistency",
      body:
        "If you are running repeated observations, keep camera height and distance " +
        "consistent. It improves repeatability across seasons.",
    },
    {
      title: "Research check-in",
      body:
        "Any anomalies worth flagging from recent monitoring? Capture context and " +
        "share a quick note so others can watch for patterns.",
    },
  ],
  equipment: [
    {
      title: "Equipment tip of the day",
      body:
        "Rinse and dry fasteners after each field day; salt creep is sneaky. " +
        "A small routine can add months to hardware life.",
    },
    {
      title: "Field kit check",
      body:
        "Restock consumables (zip ties, labels, epoxy) before your next trip. " +
        "A lightweight checklist prevents last-minute scrambles.",
    },
    {
      title: "Preventative maintenance",
      body:
        "Inspect camera housings and O-rings on a weekly cadence. " +
        "A quick inspection beats a lost data day.",
    },
    {
      title: "Gear rotation reminder",
      body:
        "Rotate batteries and memory cards so your backups are truly ready. " +
        "Labeling your rotation cycle avoids surprises in the field.",
    },
    {
      title: "Field setup tip",
      body:
        "Pack a small dry bag with labeled spares (gloves, markers, ties). " +
        "It is a low-cost backup that saves a trip.",
    },
  ],
  opportunities: [
    {
      title: "Opportunities prompt",
      body:
        "If you are applying for funding soon, capture recent restoration metrics now. " +
        "Fresh numbers strengthen proposals.",
    },
    {
      title: "Partnership spotlight",
      body:
        "Looking for collaborators? Share a brief note about your current focus " +
        "and the kind of partnership you are seeking.",
    },
    {
      title: "Volunteer ask",
      body:
        "Need extra hands in the field this month? Post dates, location, and skills " +
        "required so others can help.",
    },
    {
      title: "Grant readiness",
      body:
        "Draft a short outcomes summary from the last quarter. That paragraph can " +
        "be reused across grant applications.",
    },
    {
      title: "Partner update",
      body:
        "Share any open collaboration needs (divers, data, nursery capacity). " +
        "Clear asks lead to faster matches.",
    },
  ],
};

type ScrapedItem = {
  title: string;
  url: string;
  summary?: string;
  source?: string;
  publishedDate?: string;
  citedByCount?: number;
  company?: string;
  location?: string;
};

type WebResult = {
  title: string;
  url: string;
  snippet?: string;
};

type ScraperStatus = "posted" | "no_results" | "skipped" | "error";

const SEBASTIAN_INTROS = [
  "Sebastian thought this might be interesting",
  "Sebastian flagged this for the community",
  "Sebastian surfaced this for the community",
  "Sebastian wanted to share this",
];

const RESEARCH_QUERY = "coral restoration";
const RESEARCH_RECENT_DAYS = 365;
const RESEARCH_CITED_YEARS = 10;
const JOB_SEARCH_QUERIES = [
  "coral restoration",
  "reef restoration",
  "marine restoration",
  "marine conservation",
  "ocean conservation",
  "coral reef",
];
const JOB_KEYWORDS = [
  "coral",
  "reef",
  "marine",
  "ocean",
  "restoration",
  "conservation",
  "aquaculture",
  "aquarist",
];
const EQUIPMENT_SEARCH_QUERIES = [
  "aquarium pump sale",
  "reef tank pump sale",
  "aquarium light discount",
  "reef tank light sale",
  "aquarium feeder sale",
  "automatic feeder discount",
  "protein skimmer sale",
  "aquarium filter sale",
];
const EQUIPMENT_KEYWORDS = [
  "pump",
  "light",
  "feeder",
  "skimmer",
  "filter",
  "heater",
  "doser",
  "dosing",
];
const DEAL_KEYWORDS = [
  "sale",
  "deal",
  "discount",
  "clearance",
  "coupon",
  "% off",
];

const SCRAPER_USER_AGENT = "SeaFoundry-Sebastian/1.0";
const MS_PER_DAY = 24 * 60 * 60 * 1000;

function sanitizeId(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-_]/g, "_");
}

function formatDailyKey(date: Date): string {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/New_York",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(date);
}

function formatWeekday(date: Date): string {
  return new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    weekday: "long",
  }).format(date);
}

function formatShortDate(date: Date): string {
  return new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    month: "short",
    day: "numeric",
  }).format(date);
}

function hashString(value: string): number {
  let hash = 0;
  for (let i = 0; i < value.length; i += 1) {
    hash = (hash << 5) - hash + value.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
}

function hashValue(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 24);
}

function normalizeWhitespace(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function stripHtml(value: string): string {
  return value.replace(/<[^>]*>/g, " ");
}

function truncateText(value: string, maxLength: number): string {
  if (value.length <= maxLength) return value;
  return `${value.slice(0, Math.max(0, maxLength - 3)).trim()}...`;
}

function formatDateParam(date: Date): string {
  const year = date.getUTCFullYear();
  const month = `${date.getUTCMonth() + 1}`.padStart(2, "0");
  const day = `${date.getUTCDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function formatMonthYear(value?: string): string | null {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    year: "numeric",
  }).format(date);
}

function pickSebastianIntro(seed: string): string {
  const index = hashString(seed) % SEBASTIAN_INTROS.length;
  return SEBASTIAN_INTROS[index];
}

async function fetchJson<T>(
  url: string,
  timeoutMs = 12000
): Promise<T | null> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent": SCRAPER_USER_AGENT,
      },
      signal: controller.signal,
    });
    if (!response.ok) {
      console.warn(`[community_scrape] Request failed: ${response.status} ${url}`);
      return null;
    }
    return (await response.json()) as T;
  } catch (error) {
    console.warn(`[community_scrape] Request error for ${url}`, error);
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

function matchesKeyword(value: string, keywords: string[]): boolean {
  const lower = value.toLowerCase();
  return keywords.some((keyword) => lower.includes(keyword));
}

function dedupeItems(items: ScrapedItem[]): ScrapedItem[] {
  const seen = new Set<string>();
  const results: ScrapedItem[] = [];
  for (const item of items) {
    const key = item.url.trim().toLowerCase();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    results.push(item);
  }
  return results;
}

function extractDuckDuckGoResults(
  data: Record<string, unknown>,
  limit: number
): WebResult[] {
  const results: WebResult[] = [];
  const seen = new Set<string>();

  const pushResult = (title?: string, url?: string, snippet?: string) => {
    if (!title || !url) return;
    const normalizedUrl = url.trim();
    if (!normalizedUrl || seen.has(normalizedUrl)) return;
    seen.add(normalizedUrl);
    results.push({
      title: normalizeWhitespace(stripHtml(title)),
      url: normalizedUrl,
      snippet: snippet ? normalizeWhitespace(stripHtml(snippet)) : undefined,
    });
  };

  if (
    typeof data["AbstractText"] === "string" &&
    typeof data["AbstractURL"] === "string"
  ) {
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
      } else if (
        typeof topic["Text"] === "string" &&
        typeof topic["FirstURL"] === "string"
      ) {
        pushResult(topic["Text"], topic["FirstURL"]);
      }
    }
  };

  parseTopics(data["RelatedTopics"]);

  return results.slice(0, limit);
}

async function searchDuckDuckGo(
  query: string,
  limit = 6
): Promise<WebResult[]> {
  const url = new URL("https://api.duckduckgo.com/");
  url.searchParams.set("q", query);
  url.searchParams.set("format", "json");
  url.searchParams.set("no_html", "1");
  url.searchParams.set("no_redirect", "1");
  url.searchParams.set("t", "seafoundry");

  const data = await fetchJson<Record<string, unknown>>(url.toString());
  if (!data) return [];
  return extractDuckDuckGoResults(data, limit);
}

function buildCommunityDescription(params: {
  introSeed: string;
  title: string;
  details?: string | null;
  url: string;
}): string {
  const intro = pickSebastianIntro(params.introSeed);
  const details = params.details ? ` ${params.details}` : "";
  const content = `${intro}: ${params.title}.${details}`;
  return `${content}\n\nLink: ${params.url}`;
}

function computeNextRunAt(base: Date): string {
  const days = 3 + Math.floor(Math.random() * 3);
  const jitterHours = Math.floor(Math.random() * 6);
  const jitterMinutes = Math.floor(Math.random() * 60);
  const next = new Date(
    base.getTime() +
      days * MS_PER_DAY +
      jitterHours * 60 * 60 * 1000 +
      jitterMinutes * 60 * 1000
  );
  return next.toISOString();
}

async function claimScraperRun(
  db: FirebaseFirestore.Firestore,
  jobId: string
): Promise<{
  shouldRun: boolean;
  configRef: FirebaseFirestore.DocumentReference;
  nowIso: string;
  nextRunAtIso: string;
}> {
  const configRef = db.collection(COMMUNITY_AUTOMATION_COLLECTION).doc(jobId);
  const now = new Date();
  const nowIso = now.toISOString();
  const nextRunAtIso = computeNextRunAt(now);

  const shouldRun = await db.runTransaction(async (tx) => {
    const snap = await tx.get(configRef);
    const data = snap.data() ?? {};
    const existingNext = typeof data.nextRunAt === "string"
      ? new Date(data.nextRunAt)
      : null;
    if (existingNext && existingNext.getTime() > now.getTime()) {
      return false;
    }
    tx.set(
      configRef,
      {
        nextRunAt: nextRunAtIso,
        lastStartedAt: nowIso,
        updatedAt: nowIso,
      },
      {merge: true}
    );
    return true;
  });

  return {
    shouldRun,
    configRef,
    nowIso,
    nextRunAtIso,
  };
}

function extractCrossrefDate(dateParts?: number[][]): string | undefined {
  if (!dateParts || dateParts.length === 0) return undefined;
  const [year, month, day] = dateParts[0] ?? [];
  if (!year) return undefined;
  const safeMonth = month ? `${month}`.padStart(2, "0") : "01";
  const safeDay = day ? `${day}`.padStart(2, "0") : "01";
  return `${year}-${safeMonth}-${safeDay}`;
}

async function fetchOpenAlexWorks(params: {
  query: string;
  fromDate?: string;
  sort?: string;
  perPage?: number;
}): Promise<ScrapedItem[]> {
  const url = new URL("https://api.openalex.org/works");
  url.searchParams.set("search", params.query);
  if (params.fromDate) {
    url.searchParams.set("filter", `from_publication_date:${params.fromDate}`);
  }
  url.searchParams.set("sort", params.sort ?? "publication_date:desc");
  url.searchParams.set("per-page", `${params.perPage ?? 8}`);

  const data = await fetchJson<{results?: Array<Record<string, unknown>>}>(
    url.toString()
  );
  if (!data || !Array.isArray(data.results)) return [];

  const items: ScrapedItem[] = [];
  for (const result of data.results) {
    const title = typeof result.display_name === "string"
      ? result.display_name
      : "";
    if (!title) continue;
    const primaryLocation = result.primary_location as Record<string, unknown> | undefined;
    const landingPage = primaryLocation?.landing_page_url as string | undefined;
    const ids = result.ids as Record<string, unknown> | undefined;
    const doi = (result.doi as string | undefined) ??
      (ids?.doi as string | undefined);
    const urlValue = landingPage || doi;
    if (!urlValue) continue;
    const citedByCount = typeof result.cited_by_count === "number"
      ? result.cited_by_count
      : undefined;
    const publishedDate = result.publication_date as string | undefined;
    const sourceName =
      (primaryLocation?.source as Record<string, unknown> | undefined)?.display_name as
        | string
        | undefined;

    items.push({
      title: normalizeWhitespace(title),
      url: urlValue,
      publishedDate,
      citedByCount,
      source: sourceName ?? "OpenAlex",
    });
  }

  return items;
}

async function fetchCrossrefWorks(params: {
  query: string;
  fromDate?: string;
  rows?: number;
}): Promise<ScrapedItem[]> {
  const url = new URL("https://api.crossref.org/works");
  url.searchParams.set("query", params.query);
  if (params.fromDate) {
    url.searchParams.set("filter", `from-pub-date:${params.fromDate}`);
  }
  url.searchParams.set("rows", `${params.rows ?? 8}`);
  url.searchParams.set("sort", "published");
  url.searchParams.set("order", "desc");

  const data = await fetchJson<{
    message?: {items?: Array<Record<string, unknown>>};
  }>(url.toString());
  const items = data?.message?.items;
  if (!Array.isArray(items)) return [];

  const results: ScrapedItem[] = [];
  for (const item of items) {
    const titleArray = item.title as string[] | undefined;
    const title = Array.isArray(titleArray) ? titleArray[0] : undefined;
    const urlValue = item.URL as string | undefined;
    if (!title || !urlValue) continue;
    const publishedPrint = item["published-print"] as {["date-parts"]?: number[][]} | undefined;
    const issued = item.issued as {["date-parts"]?: number[][]} | undefined;
    const publishedDate =
      extractCrossrefDate(publishedPrint?.["date-parts"]) ??
      extractCrossrefDate(issued?.["date-parts"]);
    const citedByCount = typeof item["is-referenced-by-count"] === "number"
      ? (item["is-referenced-by-count"] as number)
      : undefined;

    results.push({
      title: normalizeWhitespace(title),
      url: urlValue,
      publishedDate,
      citedByCount,
      source: "Crossref",
    });
  }

  return results;
}

async function fetchResearchItems(): Promise<ScrapedItem[]> {
  const now = new Date();
  const recentSince = formatDateParam(
    new Date(now.getTime() - RESEARCH_RECENT_DAYS * MS_PER_DAY)
  );
  const citedSince = formatDateParam(
    new Date(now.getTime() - RESEARCH_CITED_YEARS * 365 * MS_PER_DAY)
  );

  const [openAlexRecent, openAlexCited, crossrefRecent] = await Promise.all([
    fetchOpenAlexWorks({
      query: RESEARCH_QUERY,
      fromDate: recentSince,
      sort: "publication_date:desc",
    }),
    fetchOpenAlexWorks({
      query: RESEARCH_QUERY,
      fromDate: citedSince,
      sort: "cited_by_count:desc",
    }),
    fetchCrossrefWorks({
      query: RESEARCH_QUERY,
      fromDate: recentSince,
    }),
  ]);

  return dedupeItems([...openAlexRecent, ...openAlexCited, ...crossrefRecent]);
}

async function fetchRemotiveJobs(): Promise<ScrapedItem[]> {
  const results: ScrapedItem[] = [];
  for (const query of JOB_SEARCH_QUERIES) {
    const url = new URL("https://remotive.com/api/remote-jobs");
    url.searchParams.set("search", query);
    const data = await fetchJson<{jobs?: Array<Record<string, unknown>>}>(
      url.toString()
    );
    if (!data || !Array.isArray(data.jobs)) continue;
    for (const job of data.jobs) {
      const title = job.title as string | undefined;
      const jobUrl = job.url as string | undefined;
      if (!title || !jobUrl) continue;
      const company = job.company_name as string | undefined;
      const location = job.candidate_required_location as string | undefined;
      results.push({
        title: normalizeWhitespace(title),
        url: jobUrl,
        company: company ? normalizeWhitespace(company) : undefined,
        location: location ? normalizeWhitespace(location) : undefined,
        source: "Remotive",
        publishedDate: job.publication_date as string | undefined,
      });
    }
  }
  return results;
}

async function fetchArbeitNowJobs(): Promise<ScrapedItem[]> {
  const data = await fetchJson<{data?: Array<Record<string, unknown>>}>(
    "https://www.arbeitnow.com/api/job-board-api"
  );
  if (!data || !Array.isArray(data.data)) return [];

  const results: ScrapedItem[] = [];
  for (const job of data.data) {
    const title = job.title as string | undefined;
    const url = job.url as string | undefined;
    const description = job.description as string | undefined;
    if (!title || !url) continue;
    const combined = normalizeWhitespace(
      `${title} ${stripHtml(description ?? "")}`
    );
    if (!matchesKeyword(combined, JOB_KEYWORDS)) continue;
    results.push({
      title: normalizeWhitespace(title),
      url,
      company: job.company_name as string | undefined,
      location: job.location as string | undefined,
      source: "Arbeitnow",
    });
  }

  return results;
}

async function fetchJobItems(): Promise<ScrapedItem[]> {
  const [remotive, arbeitnow] = await Promise.all([
    fetchRemotiveJobs(),
    fetchArbeitNowJobs(),
  ]);

  const ddgResults: ScrapedItem[] = [];
  if (remotive.length === 0 && arbeitnow.length === 0) {
    for (const query of JOB_SEARCH_QUERIES) {
      const results = await searchDuckDuckGo(`${query} jobs`, 6);
      for (const result of results) {
        if (!matchesKeyword(result.title, JOB_KEYWORDS)) continue;
        ddgResults.push({
          title: result.title,
          url: result.url,
          summary: result.snippet,
          source: "DuckDuckGo",
        });
      }
    }
  }

  return dedupeItems([...remotive, ...arbeitnow, ...ddgResults]);
}

async function fetchEquipmentDealItems(): Promise<ScrapedItem[]> {
  const results: ScrapedItem[] = [];
  for (const query of EQUIPMENT_SEARCH_QUERIES) {
    const entries = await searchDuckDuckGo(query, 6);
    for (const entry of entries) {
      const combined = `${entry.title} ${entry.snippet ?? ""} ${entry.url}`;
      if (!matchesKeyword(combined, EQUIPMENT_KEYWORDS)) continue;
      if (!matchesKeyword(combined, DEAL_KEYWORDS)) continue;
      results.push({
        title: entry.title,
        url: entry.url,
        summary: entry.snippet,
        source: "DuckDuckGo",
      });
    }
  }

  return dedupeItems(results);
}

async function tryCreateScrapedPost(params: {
  db: FirebaseFirestore.Firestore;
  channelId: string;
  category: string;
  source: string;
  item: ScrapedItem;
  buildTitle: (item: ScrapedItem) => string;
  buildDescription: (item: ScrapedItem) => string;
}): Promise<string | null> {
  const url = params.item.url?.trim();
  if (!url || !url.startsWith("http")) return null;

  const dedupeId = hashValue(url);
  const postId = `sebastian_${sanitizeId(params.category)}_${dedupeId}`;
  const nowIso = new Date().toISOString();

  const payload = buildCommunityPost({
    id: postId,
    title: params.buildTitle(params.item),
    description: params.buildDescription(params.item),
    channelId: params.channelId,
    createdById: SYSTEM_USER_ID,
    createdByName: SYSTEM_USER_NAME,
    createdByOrgId: SYSTEM_ORG_ID,
    createdByOrgName: SYSTEM_ORG_NAME,
    organizationId: SYSTEM_ORG_ID,
    source: params.source,
    sourceUrl: url,
    sourceTitle: params.item.title,
    sourceProvider: params.item.source,
    sourceCategory: params.category,
    metadata: {
      scrapedAt: nowIso,
    },
  });

  const postRef = params.db.collection(EVENTS_COLLECTION).doc(postId);
  const dedupeRef = params.db
    .collection(COMMUNITY_POST_DEDUPE_COLLECTION)
    .doc(dedupeId);

  const created = await params.db.runTransaction(async (tx) => {
    const dedupeSnap = await tx.get(dedupeRef);
    if (dedupeSnap.exists) return false;
    const postSnap = await tx.get(postRef);
    if (postSnap.exists) return false;
    tx.set(postRef, payload);
    tx.set(dedupeRef, {
      id: dedupeId,
      sourceUrl: url,
      category: params.category,
      eventId: postId,
      createdAt: nowIso,
    });
    return true;
  });

  return created ? postId : null;
}

async function runCommunityScraper(params: {
  jobId: string;
  channelName: string;
  category: string;
  source: string;
  fetchItems: () => Promise<ScrapedItem[]>;
  buildTitle: (item: ScrapedItem) => string;
  buildDescription: (item: ScrapedItem) => string;
}): Promise<void> {
  const db = admin.firestore();
  const claim = await claimScraperRun(db, params.jobId);
  if (!claim.shouldRun) return;

  const channelIds = await ensureDefaultCommunityChannels(db);
  const channelId = channelIds.get(params.channelName);
  if (!channelId) {
    await claim.configRef.set(
      {
        lastRunAt: claim.nowIso,
        lastRunStatus: "error",
        lastRunError: `Missing channel: ${params.channelName}`,
        updatedAt: new Date().toISOString(),
      },
      {merge: true}
    );
    return;
  }

  let status: ScraperStatus = "no_results";
  let postId: string | null = null;
  let errorMessage: string | null = null;

  try {
    const items = await params.fetchItems();
    for (const item of items) {
      const result = await tryCreateScrapedPost({
        db,
        channelId,
        category: params.category,
        source: params.source,
        item,
        buildTitle: params.buildTitle,
        buildDescription: params.buildDescription,
      });
      if (result) {
        postId = result;
        status = "posted";
        break;
      }
    }
  } catch (error) {
    status = "error";
    errorMessage = error instanceof Error ? error.message : "Unknown error";
    console.error(`[community_scrape] ${params.jobId} failed`, error);
  }

  if (!postId && status !== "error") {
    status = "no_results";
  }

  await claim.configRef.set(
    {
      lastRunAt: claim.nowIso,
      lastRunStatus: status,
      lastRunPostId: postId,
      lastRunError: errorMessage,
      updatedAt: new Date().toISOString(),
    },
    {merge: true}
  );
}

function renderTemplate(
  template: {title: string; body: string},
  tokens: Record<string, string>
): {title: string; body: string} {
  const replaceTokens = (value: string) =>
    value.replace(/\{(\w+)\}/g, (_, key) => tokens[key] ?? "");
  return {
    title: replaceTokens(template.title),
    body: replaceTokens(template.body),
  };
}

async function ensureDefaultCommunityChannels(
  db: FirebaseFirestore.Firestore
): Promise<Map<string, string>> {
  const snapshot = await db.collection(COMMUNITY_CHANNELS_COLLECTION).get();
  const existingByName = new Map<string, FirebaseFirestore.DocumentSnapshot>();
  snapshot.forEach((doc) => {
    const data = doc.data();
    if (data?.name) {
      existingByName.set(data.name, doc);
    }
  });

  const nameToId = new Map<string, string>();
  for (const [name, doc] of existingByName.entries()) {
    nameToId.set(name, doc.id);
  }

  const now = new Date().toISOString();

  for (const channel of DEFAULT_CHANNELS) {
    const existing = existingByName.get(channel.name);
    if (existing) {
      nameToId.set(channel.name, existing.id);
      const data = existing.data() ?? {};
      const updates: Record<string, unknown> = {};
      if (data.iconEmoji !== channel.iconEmoji) {
        updates.iconEmoji = channel.iconEmoji;
      }
      if (data.description !== channel.description) {
        updates.description = channel.description;
      }
      if (data.visibility !== "public") {
        updates.visibility = "public";
      }
      if (data.isArchived === true) {
        updates.isArchived = false;
      }
      if (Object.keys(updates).length > 0) {
        await existing.ref.update(updates);
      }
      continue;
    }

    let channelRef = db
      .collection(COMMUNITY_CHANNELS_COLLECTION)
      .doc(sanitizeId(channel.name));
    const idSnap = await channelRef.get();
    if (idSnap.exists) {
      channelRef = db.collection(COMMUNITY_CHANNELS_COLLECTION).doc();
    }

    const payload = {
      id: channelRef.id,
      name: channel.name,
      channelType: "community",
      visibility: "public",
      description: channel.description,
      iconEmoji: channel.iconEmoji,
      memberIds: [SYSTEM_USER_ID],
      memberCount: 1,
      adminIds: [SYSTEM_USER_ID],
      createdAt: now,
      createdById: SYSTEM_USER_ID,
      lastMessageAt: now,
      isArchived: false,
    };

    await channelRef.set(payload, {merge: false});
    nameToId.set(channel.name, channelRef.id);
  }

  return nameToId;
}

function buildCommunityPost(params: {
  id: string;
  title: string;
  description: string;
  channelId: string;
  createdById: string;
  createdByName: string;
  createdByOrgId: string;
  createdByOrgName: string;
  organizationId: string;
  source: string;
  sourceUrl?: string;
  sourceTitle?: string;
  sourceProvider?: string;
  sourceCategory?: string;
  sourceEventId?: string;
  sourceEventType?: string;
  dailyKey?: string;
  metadata?: Record<string, unknown>;
}): Record<string, unknown> {
  const now = new Date().toISOString();
  return {
    id: params.id,
    organizationId: params.organizationId,
    eventTypeId: "event_update",
    scope: "community",
    recordId: params.organizationId,
    recordModelType: "organization",
    title: params.title,
    description: params.description,
    notes: params.description,
    createdAt: now,
    createdById: params.createdById,
    createdByName: params.createdByName,
    updatedAt: now,
    updatedById: params.createdById,
    modelType: "event",
    urlPath: `/${params.organizationId}/events/${params.id}`,
    internalPath: `organizations/${params.organizationId}/events/${params.id}`,
    slug: params.id,
    metadata: {
      isCommunityPost: true,
      title: params.title,
      description: params.description,
      createdByName: params.createdByName,
      createdByOrgName: params.createdByOrgName,
      createdByOrgId: params.createdByOrgId,
      reactions: {},
      communityChannelId: params.channelId,
      source: params.source,
      sourceUrl: params.sourceUrl ?? null,
      sourceTitle: params.sourceTitle ?? null,
      sourceProvider: params.sourceProvider ?? null,
      sourceCategory: params.sourceCategory ?? null,
      sourceEventId: params.sourceEventId ?? null,
      sourceEventType: params.sourceEventType ?? null,
      dailyKey: params.dailyKey ?? null,
      ...params.metadata,
    },
  };
}

async function getOrganizationData(
  db: FirebaseFirestore.Firestore,
  orgId: string
): Promise<{id: string; name: string; tier: string} | null> {
  const orgDoc = await db.collection(ORGANIZATIONS_COLLECTION).doc(orgId).get();
  if (!orgDoc.exists) return null;
  const data = orgDoc.data() ?? {};
  return {
    id: orgId,
    name: (data.name as string) ?? orgId,
    tier: (data.tier as string) ?? "community",
  };
}

function normalizeModelType(value?: string): string | null {
  if (!value) return null;
  const lower = value.toLowerCase();
  if (lower === "sites") return "site";
  if (lower === "groups") return "group";
  if (lower === "zones") return "zone";
  if (lower === "subplots") return "subplot";
  return lower;
}

async function resolveOutplantSiteContext(
  db: FirebaseFirestore.Firestore,
  recordModelType: string | undefined,
  recordId: string | undefined
): Promise<{siteId: string; siteName: string; siteTypeId?: string} | null> {
  if (!recordModelType || !recordId) return null;
  const normalized = normalizeModelType(recordModelType);
  if (!normalized) return null;

  let siteId = recordId;
  if (normalized === "group") {
    const groupDoc = await db.collection("groups").doc(recordId).get();
    if (!groupDoc.exists) return null;
    const groupData = groupDoc.data() ?? {};
    siteId = (groupData.siteId as string) ?? "";
  } else if (normalized === "zone") {
    const zoneDoc = await db.collection("zones").doc(recordId).get();
    if (!zoneDoc.exists) return null;
    const zoneData = zoneDoc.data() ?? {};
    siteId = (zoneData.siteId as string) ?? "";
  } else if (normalized === "subplot") {
    const subplotDoc = await db.collection("subplots").doc(recordId).get();
    if (!subplotDoc.exists) return null;
    const subplotData = subplotDoc.data() ?? {};
    siteId = (subplotData.siteId as string) ?? "";
  } else if (normalized !== "site") {
    return null;
  }

  if (!siteId) return null;
  const siteDoc = await db.collection("sites").doc(siteId).get();
  if (!siteDoc.exists) return null;
  const siteData = siteDoc.data() ?? {};
  const siteName = (siteData.name as string) || "an outplanting site";
  const siteTypeId = siteData.siteTypeId as string | undefined;

  return {siteId, siteName, siteTypeId};
}

async function getDataPrivacyConfig(
  db: FirebaseFirestore.Firestore,
  orgId: string
): Promise<{
  shareNurseryHoldings: boolean;
  shareOutplantSites: boolean;
  shareOutplantEvents: boolean;
}> {
  const doc = await db
    .collection(ORGANIZATIONS_COLLECTION)
    .doc(orgId)
    .collection("config")
    .doc(DATA_PRIVACY_DOC_ID)
    .get();
  const data = doc.data() ?? {};
  return {
    shareNurseryHoldings: data.shareNurseryHoldings === true,
    shareOutplantSites: data.shareOutplantSites === true,
    shareOutplantEvents: data.shareOutplantEvents === true,
  };
}

async function syncImpactPointForSite(params: {
  db: FirebaseFirestore.Firestore;
  organization: {id: string; name: string; tier: string};
  privacy: {shareNurseryHoldings: boolean; shareOutplantSites: boolean};
  siteId: string;
  siteData?: Record<string, unknown> | null;
}): Promise<void> {
  const {db, organization, privacy, siteId, siteData} = params;
  const pointRef = db
    .collection("public_orgs")
    .doc("community")
    .collection("impact_points")
    .doc(`community_${sanitizeId(organization.id)}_${sanitizeId(siteId)}`);

  if (!siteData) {
    await pointRef.delete().catch(() => undefined);
    return;
  }

  const siteTypeId = siteData.siteTypeId as string | undefined;
  const pointType = resolvePointType(siteTypeId);
  if (!pointType) {
    await pointRef.delete().catch(() => undefined);
    return;
  }

  if (!shouldShareSite({tier: organization.tier, pointType, privacy})) {
    await pointRef.delete().catch(() => undefined);
    return;
  }

  const latitude =
    typeof siteData.latitude === "number" ? siteData.latitude : null;
  const longitude =
    typeof siteData.longitude === "number" ? siteData.longitude : null;
  if (latitude == null || longitude == null) {
    await pointRef.delete().catch(() => undefined);
    return;
  }

  const now = new Date().toISOString();
  const label = (siteData.name as string) || organization.name;

  const payload = {
    id: pointRef.id,
    modelType: "publicImpactPoint",
    organizationId: organization.id,
    siteId,
    latitude,
    longitude,
    label,
    pointType,
    magnitude: 1,
    createdAt: now,
    createdById: "system",
    updatedAt: now,
    updatedById: "system",
    metadata: {
      source: "community_site",
      siteId,
      siteTypeId: siteTypeId ?? null,
      organizationName: organization.name,
    },
  };

  await pointRef.set(payload, {merge: true});
}

function resolvePointType(siteTypeId?: string): "holding" | "outplant" | null {
  if (!siteTypeId) return null;
  if (NURSERY_SITE_TYPES.has(siteTypeId)) return "holding";
  if (OUTPLANT_SITE_TYPES.has(siteTypeId)) return "outplant";
  return null;
}

function shouldShareSite(params: {
  tier: string;
  pointType: "holding" | "outplant";
  privacy: {shareNurseryHoldings: boolean; shareOutplantSites: boolean};
}): boolean {
  if (params.tier === "community") return true;
  if (params.pointType === "holding") {
    return params.privacy.shareNurseryHoldings;
  }
  return params.privacy.shareOutplantSites;
}

function shouldShareOutplantEvents(params: {
  tier: string;
  privacy: {shareOutplantEvents: boolean};
}): boolean {
  if (params.tier === "community") return true;
  return params.privacy.shareOutplantEvents;
}

export const postDailySebastianCommunityUpdates = onSchedule(
  {schedule: "0 7 * * *", timeZone: "America/New_York"},
  async () => {
    const db = admin.firestore();
    const channelIds = await ensureDefaultCommunityChannels(db);
    const now = new Date();
    const dailyKey = formatDailyKey(now);
    const weekday = formatWeekday(now);
    const dateLabel = formatShortDate(now);

    for (const channel of DEFAULT_CHANNELS) {
      if (channel.name == "issues") continue;
      const channelId = channelIds.get(channel.name);
      if (!channelId) continue;

      const templates = DAILY_TEMPLATES[channel.name] ?? DAILY_TEMPLATES.general;
      const seed = `${channel.name}-${dailyKey}`;
      const template = templates[hashString(seed) % templates.length];
      const rendered = renderTemplate(template, {
        weekday,
        date: dateLabel,
        channel: channel.name,
      });

      const postId = `sebastian_daily_${sanitizeId(channelId)}_${dailyKey}`;
      const postRef = db.collection(EVENTS_COLLECTION).doc(postId);
      const existing = await postRef.get();
      if (existing.exists) continue;

      const payload = buildCommunityPost({
        id: postId,
        title: rendered.title,
        description: rendered.body,
        channelId,
        createdById: SYSTEM_USER_ID,
        createdByName: SYSTEM_USER_NAME,
        createdByOrgId: SYSTEM_ORG_ID,
        createdByOrgName: SYSTEM_ORG_NAME,
        organizationId: SYSTEM_ORG_ID,
        source: "sebastian_daily",
        dailyKey,
      });

      await postRef.set(payload);
    }
  }
);

export const scrapeCommunityResearchPosts = onSchedule(
  {schedule: "15 7 * * *", timeZone: "America/New_York"},
  async () => {
    await runCommunityScraper({
      jobId: "sebastian_research_scrape",
      channelName: "research",
      category: "research",
      source: "sebastian_scrape_research",
      fetchItems: fetchResearchItems,
      buildTitle: (item) =>
        truncateText(`Research: ${normalizeWhitespace(item.title)}`, 140),
      buildDescription: (item) => {
        const published = formatMonthYear(item.publishedDate);
        const detailsParts: string[] = [];
        if (published) detailsParts.push(`Published ${published}`);
        if (typeof item.citedByCount === "number") {
          detailsParts.push(`${item.citedByCount} citations`);
        }
        if (item.source) detailsParts.push(`Source: ${item.source}`);
        const details = detailsParts.length > 0 ? detailsParts.join(" • ") : null;
        return buildCommunityDescription({
          introSeed: item.url,
          title: truncateText(normalizeWhitespace(item.title), 160),
          details,
          url: item.url,
        });
      },
    });
  }
);

export const scrapeCommunityOpportunities = onSchedule(
  {schedule: "30 7 * * *", timeZone: "America/New_York"},
  async () => {
    await runCommunityScraper({
      jobId: "sebastian_opportunities_scrape",
      channelName: "opportunities",
      category: "opportunities",
      source: "sebastian_scrape_opportunities",
      fetchItems: fetchJobItems,
      buildTitle: (item) =>
        truncateText(`Opportunity: ${normalizeWhitespace(item.title)}`, 140),
      buildDescription: (item) => {
        const detailsParts: string[] = [];
        if (item.company) detailsParts.push(`at ${item.company}`);
        if (item.location) detailsParts.push(item.location);
        if (item.source) detailsParts.push(`Source: ${item.source}`);
        const details = detailsParts.length > 0 ? detailsParts.join(" • ") : null;
        return buildCommunityDescription({
          introSeed: item.url,
          title: truncateText(normalizeWhitespace(item.title), 160),
          details,
          url: item.url,
        });
      },
    });
  }
);

export const scrapeCommunityEquipmentDeals = onSchedule(
  {schedule: "45 7 * * *", timeZone: "America/New_York"},
  async () => {
    await runCommunityScraper({
      jobId: "sebastian_equipment_deals",
      channelName: "equipment",
      category: "equipment",
      source: "sebastian_scrape_equipment",
      fetchItems: fetchEquipmentDealItems,
      buildTitle: (item) =>
        truncateText(`Equipment deal: ${normalizeWhitespace(item.title)}`, 140),
      buildDescription: (item) => {
        const summary = item.summary
          ? truncateText(normalizeWhitespace(item.summary), 160)
          : "Possible equipment deal";
        const details = item.source ? `${summary} • Source: ${item.source}` : summary;
        return buildCommunityDescription({
          introSeed: item.url,
          title: truncateText(normalizeWhitespace(item.title), 160),
          details,
          url: item.url,
        });
      },
    });
  }
);

export const publishCommunityOutplantPost = onDocumentWritten(
  "events/{eventId}",
  async (event) => {
    const afterSnap = event.data?.after;
    const beforeSnap = event.data?.before;
    const after = afterSnap?.data();
    const before = beforeSnap?.data();
    if (!after) return;

    if (after.scope === "community" || after?.metadata?.isCommunityPost === true) {
      return;
    }

    const orgId = after.organizationId as string | undefined;
    if (!orgId) return;

    const db = admin.firestore();
    const organization = await getOrganizationData(db, orgId);
    if (!organization) return;

    const privacy = await getDataPrivacyConfig(db, orgId);
    if (!shouldShareOutplantEvents({tier: organization.tier, privacy})) {
      return;
    }

    const eventTypeId = after.eventTypeId as string | undefined;
    const eventId = event.params.eventId as string;

    let postTitle: string | null = null;
    let postDescription: string | null = null;
    let sourceType: string | null = null;

    if (eventTypeId === "outplant_event") {
      sourceType = "outplant_event";
      const allocations = Array.isArray(after.allocations) ? after.allocations : [];
      const total = allocations.reduce((sum: number, alloc: any) => {
        const qty = typeof alloc?.quantity === "number" ? alloc.quantity : 0;
        return sum + qty;
      }, 0);
      const siteId = (after.siteId as string) ?? (after.recordId as string);
      let siteName = "an outplanting site";
      if (siteId) {
        const siteDoc = await db.collection("sites").doc(siteId).get();
        if (siteDoc.exists) {
          const siteData = siteDoc.data() ?? {};
          siteName = (siteData.name as string) || siteName;
        }
      }
      postTitle =
        total > 0
          ? `${organization.name} outplanted ${total} colonies`
          : `${organization.name} logged an outplanting event`;
      postDescription =
        `Outplanting activity recorded at ${siteName}. ` +
        "Thanks for sharing this restoration milestone with the community.";
    } else if (eventTypeId === "event_task") {
      const statusId = after.statusId as string | undefined;
      const beforeStatus = before?.statusId as string | undefined;
      if (statusId !== "completed" || beforeStatus === "completed") {
        return;
      }
      const recordModelType = after.recordModelType as string | undefined;
      const recordId = after.recordId as string | undefined;
      const siteContext = await resolveOutplantSiteContext(
        db,
        recordModelType,
        recordId
      );
      if (!siteContext) return;
      if (!OUTPLANT_SITE_TYPES.has(siteContext.siteTypeId ?? "")) return;
      const siteName = siteContext.siteName;

      sourceType = "outplant_task";
      postTitle = `${organization.name} completed an outplanting task`;
      postDescription =
        `Work completed at ${siteName}. ` +
        "Consistent field execution keeps restoration on track.";
    }

    if (!postTitle || !postDescription || !sourceType) {
      return;
    }

    const channelIds = await ensureDefaultCommunityChannels(db);
    const restorationChannelId = channelIds.get("restoration");
    if (!restorationChannelId) return;

    const postId = `${sourceType}_${sanitizeId(eventId)}`;
    const postRef = db.collection(EVENTS_COLLECTION).doc(postId);
    const existing = await postRef.get();
    if (existing.exists) return;

    const payload = buildCommunityPost({
      id: postId,
      title: postTitle,
      description: postDescription,
      channelId: restorationChannelId,
      createdById: OUTPLANT_BOT_ID,
      createdByName: OUTPLANT_BOT_NAME,
      createdByOrgId: organization.id,
      createdByOrgName: organization.name,
      organizationId: organization.id,
      source: "outplant_auto",
      sourceEventId: eventId,
      sourceEventType: eventTypeId,
    });

    await postRef.set(payload);
  }
);

export const syncCommunityImpactPoint = onDocumentWritten(
  "sites/{siteId}",
  async (event) => {
    const afterSnap = event.data?.after;
    const beforeSnap = event.data?.before;
    const after = afterSnap?.data();
    const before = beforeSnap?.data();
    const siteId = event.params.siteId as string;

    const orgId = (after?.organizationId ?? before?.organizationId) as string | undefined;
    if (!orgId) return;

    const db = admin.firestore();
    const organization = await getOrganizationData(db, orgId);
    if (!organization) return;

    const privacy = await getDataPrivacyConfig(db, orgId);
    await syncImpactPointForSite({
      db,
      organization,
      privacy,
      siteId,
      siteData: after ?? null,
    });
  }
);

export const syncCommunityImpactPointsForPrivacyChange = onDocumentWritten(
  "organizations/{orgId}/config/data_privacy",
  async (event) => {
    const orgId = event.params.orgId as string;
    const db = admin.firestore();
    const organization = await getOrganizationData(db, orgId);
    if (!organization) return;

    const privacy = await getDataPrivacyConfig(db, orgId);
    const sitesSnap = await db
      .collection("sites")
      .where("organizationId", "==", orgId)
      .get();

    for (const siteDoc of sitesSnap.docs) {
      await syncImpactPointForSite({
        db,
        organization,
        privacy,
        siteId: siteDoc.id,
        siteData: siteDoc.data(),
      });
    }
  }
);

export const searchDirectory = onCall({ cors: getCorsOrigins() }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const rawQuery = request.data?.query;
  if (typeof rawQuery !== "string") {
    throw new HttpsError("invalid-argument", "query must be a string.");
  }
  const query = rawQuery.trim();
  if (!query) {
    return {users: [], organizations: []};
  }

  const limitRaw = request.data?.limit;
  const limit = Math.min(Math.max(Number(limitRaw ?? 10), 1), 20);
  const queryLower = query.toLowerCase();
  const db = admin.firestore();

  const users: Array<{
    id: string;
    name: string;
    email: string;
    organizationId?: string;
    organizationName?: string;
  }> = [];
  const organizationIds = new Set<string>();
  const organizationsById = new Map<string, {id: string; name: string; domain: string}>();

  if (queryLower.includes("@")) {
    const user = await findUserByEmail(db, queryLower);
    if (user) {
      users.push(user);
      if (user.organizationId) {
        organizationIds.add(user.organizationId);
      }
    }
  }

  const orgsByName = await queryOrganizationsByPrefix(db, "name", query, limit);
  const orgsByDomain = await queryOrganizationsByPrefix(db, "domain", queryLower, limit);
  for (const doc of [...orgsByName, ...orgsByDomain]) {
    const data = doc.data() ?? {};
    const id = doc.id;
    const name = (data.name as string) ?? id;
    const domain = (data.domain as string) ?? "";
    organizationsById.set(id, {id, name, domain});
    organizationIds.add(id);
  }

  const organizations: Array<Record<string, unknown>> = [];
  for (const orgId of organizationIds) {
    let org = organizationsById.get(orgId);
    if (!org) {
      const orgDoc = await db.collection(ORGANIZATIONS_COLLECTION).doc(orgId).get();
      if (!orgDoc.exists) continue;
      const data = orgDoc.data() ?? {};
      org = {
        id: orgId,
        name: (data.name as string) ?? orgId,
        domain: (data.domain as string) ?? "",
      };
    }
    const members = await fetchOrganizationMembers(db, orgId, org.name);
    organizations.push({
      id: org.id,
      name: org.name,
      domain: org.domain,
      members,
    });
  }

  for (const user of users) {
    if (user.organizationId && !user.organizationName) {
      const org = organizationsById.get(user.organizationId);
      if (org) {
        user.organizationName = org.name;
      }
    }
  }

  return {users, organizations};
});

async function queryOrganizationsByPrefix(
  db: FirebaseFirestore.Firestore,
  field: "name" | "domain",
  prefix: string,
  limit: number
): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  if (!prefix) return [];
  const snapshot = await db
    .collection(ORGANIZATIONS_COLLECTION)
    .orderBy(field)
    .startAt(prefix)
    .endAt(`${prefix}\uf8ff`)
    .limit(limit)
    .get();
  return snapshot.docs;
}

async function findUserByEmail(
  db: FirebaseFirestore.Firestore,
  emailLower: string
): Promise<{
  id: string;
  name: string;
  email: string;
  organizationId?: string;
  organizationName?: string;
} | null> {
  const byEmail = await db
    .collection(USERS_COLLECTION)
    .where("email", "==", emailLower)
    .limit(1)
    .get();
  if (!byEmail.empty) {
    return buildUserResult(byEmail.docs[0]);
  }

  return null;
}

function buildUserResult(
  doc: FirebaseFirestore.DocumentSnapshot,
  organizationName?: string
): {
  id: string;
  name: string;
  email: string;
  organizationId?: string;
  organizationName?: string;
} {
  const data = doc.data() as Record<string, unknown> | undefined;
  const email = (data?.email as string) ?? "";
  const name = (data?.name as string) ?? email ?? "Member";
  const organizationId = data?.organizationId as string | undefined;
  return {
    id: doc.id,
    name,
    email,
    organizationId,
    organizationName,
  };
}

async function fetchOrganizationMembers(
  db: FirebaseFirestore.Firestore,
  orgId: string,
  organizationName?: string
): Promise<
  Array<{
    id: string;
    name: string;
    email: string;
    organizationId?: string;
    organizationName?: string;
  }>
> {
  const membersSnap = await db
    .collection(ORGANIZATIONS_COLLECTION)
    .doc(orgId)
    .collection("members")
    .get();

  if (membersSnap.empty) return [];

  const memberIds = membersSnap.docs.map((doc) => doc.id);
  const memberDocs = await db.getAll(
    ...memberIds.map((id) => db.collection(USERS_COLLECTION).doc(id))
  );

  const results: Array<{
    id: string;
    name: string;
    email: string;
    organizationId?: string;
    organizationName?: string;
  }> = [];

  for (let i = 0; i < memberDocs.length; i += 1) {
    const userDoc = memberDocs[i];
    if (userDoc.exists) {
      results.push(buildUserResult(userDoc, organizationName));
      continue;
    }
    const membershipData = membersSnap.docs[i]?.data() ?? {};
    const fallbackEmail = membershipData.email as string | undefined;
    const fallbackId = memberIds[i];
    results.push({
      id: fallbackId,
      name: fallbackEmail ?? "Member",
      email: fallbackEmail ?? "",
      organizationId: orgId,
      organizationName,
    });
  }

  return results;
}
