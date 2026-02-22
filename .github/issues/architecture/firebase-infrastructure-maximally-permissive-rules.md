# Firebase Infrastructure: Maximally Permissive Rules + Cloud Functions Alignment

**Issue #414** | Created: 2026-01-31 | Author: seascott | Status: OPEN

## Guiding Principle

**Maximally permissive rules — just enough to keep organization data separate.** No tier gating, no role checks, no feature gates at the rules level. App-layer and cloud functions handle business logic.

---

## Part 1: Firestore Rules Rewrite (`firestore.rules`)

### Functions to REMOVE
- `orgHasTier()` — tier gating (7 call sites)
- `isAdmin()` — admin role check (12+ call sites)
- `getUserRoleLevel()` / `hasRoleLevel()` — role hierarchy (chat_rooms)
- `memberCountUnchanged()` — over-protective org doc guard
- `isSebastianConversationMember()` — inline to simple membership check
- All 6 org-channel inline functions (`isOrgChannelMember`, `isOrgChannelAdmin`, `isPublicOrgChannel`, etc.)
- Field-diff validation in chat messages, comments, community reactions

### Functions to KEEP
- `isAuthenticated()`, `getAuthUid()`, `getUserDoc()`, `userDocExists()`, `isMemberByUid()`, `isOrgMemberOf()` — core primitives
- `isTemplateContent()` — needed for template SOPs/training
- `isOnboardingBatchWrite()` — needed for atomic user+org+member creation
- `isCommunityPostEvent()`, `isCommunityPost()` — cross-org community posts
- Community channel / DM channel member checks — cross-org, channel-membership is the only boundary
- Transfer cross-org logic — both sender and receiver orgs need access

### Simplified Pattern
Every org-scoped collection collapses to:
```
match /organizations/{orgId}/{collectionName}/{docId} {
  allow read, write: if isOrgMemberOf(orgId);
}
```

Exceptions:
- **Community channels / DMs**: keep channel-membership checks (cross-org)
- **Transfers**: keep cross-org sender+receiver logic
- **Sebastian generated content**: open to org members (remove `if false` block)
- **User notification subcollections**: add client read for own user doc
- **Historical/reference data**: open writes to any org member

### Estimated Impact
~300 lines removed, ~50 lines simplified. File shrinks from ~1300 to ~900 lines.

---

## Part 2: Storage Rules (`storage.rules`)

**NO CHANGES NEEDED.** Already maximally permissive within org boundaries.

---

## Part 3: Firestore Indexes (`firestore.indexes.json`)

- Check `coralIds` index — may be stale if `organismIds` replaced it
- Check `life_stage_progression_events` collection — has index but no rule
- Check `path` field override on events — verify if queried vs `urlPath`
- No indexes reference `authorEmail` (already clean)
- Cross-reference against Dart query code; remove dead indexes

---

## Part 4: Cloud Functions Fixes

### BLOCKING
1. **`comment-notifications.ts`**: Rename local var `authorEmail` → `resolvedAuthorEmail` (lines 82, 89, 99, 100)
2. **`chat-stream.ts`**: Replace deprecated `canMakeRequest`/`recordUsage` with `reserveBudget`/`finalizeUsage` (matching `chat.ts` and `content.ts`)

### HIGH
3. **`function-handlers.ts`**: Remove snake_case fallbacks `site_type`, `assigned_to` (lines 576, 630, 2530)
4. **`feature_access.ts`**: Remove `upgrade_url` fallback (lines 99, 135)
5. **Extract `getCustomPromptForOrg`**: Deduplicate from `content.ts`, `chat.ts`, `chat-stream.ts` into shared module
6. **`package.json`**: Move `@types/nodemailer` to devDependencies, remove `@types/react`

### MODERATE
7. **`tsconfig.json`**: Update `target` to `es2022` for Node 22
8. **`example-test.ts`**: Exclude from deployed bundle (move or add to tsconfig exclude)
9. **`validators.ts`**: Verify `../../schemas/models/` path or remove dead import
10. **`ajv`**: Move from devDependencies to dependencies (runtime import)

---

## Part 5: Documentation Updates

Add to `CLAUDE.md`, `.claude/agents.md`, and `README.md`:

> **Security philosophy**: Firestore rules are maximally permissive — just enough to keep organization data separate. All feature gating, tier checks, and role-based access are handled at the app layer and cloud functions, NOT in Firestore rules. The only rules-level check is org membership via `isOrgMemberOf(orgId)`.

---

## Part 6: Deploy & Verify

```bash
# 1. Build cloud functions
cd functions && npm run build

# 2. Deploy everything
firebase deploy --only firestore:rules,firestore:indexes,functions,storage

# 3. Verify
flutter analyze lib/   # zero new issues
```

Manual smoke: authenticated user can read/write their org's data, CANNOT read another org's data.

---

## Execution Plan (6 Parallel Teams)

| Team | Scope | Files |
|------|-------|-------|
| 1 | Firestore rules rewrite | `firestore.rules` |
| 2 | Cloud functions BLOCKING fixes | `comment-notifications.ts`, `chat-stream.ts` |
| 3 | Cloud functions HIGH fixes | `function-handlers.ts`, `feature_access.ts`, shared module, `package.json` |
| 4 | Cloud functions MODERATE fixes | `tsconfig.json`, `example-test.ts`, `validators.ts` |
| 5 | Index audit + cleanup | `firestore.indexes.json` + Dart query grep |
| 6 | Documentation | `CLAUDE.md`, `.claude/agents.md`, `README.md` |

---

## ✅ Completed Plan Implementation

### Firestore Rules

- Removed tier/admin/role gates and field‑diff checks; rules are now org‑membership only (plus community/DM channel membership and transfer cross‑org).
- Opened historical CRC, taxonomy overrides/audit, reference data, and community genetics writes to authenticated users.
- Sebastian generated content now writable by org members; Sebastian legacy root messages use org membership.
- Community events allow authenticated updates; org transfer recipients can update events.
- Simplified org channel, chat, comments, purchases, and configuration subcollections to `isOrgMemberOf(orgId)`.

### Cloud Functions

- **`comment-notifications.ts`**: Renamed local `authorEmail` → `resolvedAuthorEmail`.
- **`chat-stream.ts`**: Migrated to `reserveBudget`/`finalizeUsage`/`releaseReservation` and added reservation rollback on errors.
- Deduplicated custom prompt into `custom-prompt.ts` and used in `chat.ts`, `content.ts`, `chat-stream.ts`.
- Removed snake_case fallbacks (`site_type`, `assigned_to`) in `function-handlers.ts`.
- Removed `upgrade_url` fallback in `feature_access.ts`.
- **`package.json`**: Moved `ajv` to dependencies, `@types/nodemailer` to devDependencies, removed `@types/react`.
- **`tsconfig.json`**: Target `es2022`, excluded `example-test.ts`.

### Indexes

- Removed stale `life_stage_progression_events` index (no rules/code usage).
- Kept both `coralIds` and `organismIds` indexes since both are queried.

### Documentation

- Updated `CLAUDE.md` and `README.md` to state maximally permissive rules (org separation only).
- Consolidated agent guidance by replacing `agents.md` with a pointer to `AGENTS.md` + security philosophy.

### Files Touched

- `firestore.rules`
- `firestore.indexes.json`
- `comment-notifications.ts`
- `custom-prompt.ts` (new)
- `chat-stream.ts`
- `chat.ts`
- `content.ts`
- `function-handlers.ts`
- `feature_access.ts`
- `package.json`
- `tsconfig.json`
- `CLAUDE.md`
- `README.md`
- `agents.md`
