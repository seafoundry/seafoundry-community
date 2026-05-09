# Smoke Test Quick Start Guide

**Quick reference for running Firestore permissions smoke tests (FP3-B1)**

## Prerequisites

```bash
# Install dependencies
npm install

# Ensure Firebase emulators installed
firebase --version
```

## Running Smoke Tests

### Option 1: Automated Tests (Recommended)

```bash
# 1. Start Firebase emulators (in terminal 1)
firebase emulators:start --only auth,firestore,storage

# 2. Seed demo data (in terminal 2)
npm run seed:demo
npm run seed:taxonomy:emulator

# 3. Run all smoke tests (in terminal 2)
npm run test:smoke

# Or run specific categories
npm run test:smoke:onboarding
npm run test:smoke:taxonomy
npm run test:smoke:training
npm run test:smoke:storage
npm run test:smoke:demo
```

### Option 2: Manual Testing (In-App)

See detailed checklist in `/docs/SMOKE_TEST_CHECKLIST.md`

```bash
# 1. Start emulators
firebase emulators:start --only auth,firestore,storage,ui

# 2. Seed demo data
npm run seed:demo

# 3. Run app against emulators
npm run flutter:run:web

# 4. Follow manual test steps in SMOKE_TEST_CHECKLIST.md
```

### Option 3: Production Verification (Use with Caution)

```bash
# Requires service account credentials
export GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json

# Run smoke tests against production
npm run test:smoke:production
```

## Test Categories

| Category | Description | Key Verifications |
|----------|-------------|-------------------|
| `onboarding` | New user/org creation | Email-based user docs, org setup |
| `taxonomy` | Global taxonomy access | Species/provenances readable, overrides admin-only |
| `training` | Training progress UID access | Uses UID (not email), isolated per user |
| `storage` | Storage upload permissions | Email-based user lookup works |
| `demo` | Demo mode isolation | Correct prefixing, global collections shared |

## Expected Output

### Successful Run

```
🔬 Firestore Permissions Verification
================================================================================
Category: all - All Test Categories
Mode: EMULATOR

📋 ONBOARDING TESTS
────────────────────────────────────────────────────────────────────────────────
  ✅ User document keyed by lowercase email
  ✅ Organization document accessible
  ✅ Sites query succeeds
  ✅ No UID-based user document (correct)

🌿 TAXONOMY TESTS
────────────────────────────────────────────────────────────────────────────────
  ✅ taxonomy_species accessible (global)
  ✅ taxonomy_provenances accessible (global)
  ✅ taxonomy_lineages accessible (global)
  ✅ taxonomy_overrides accessible (global)

...

================================================================================
TEST SUMMARY
================================================================================
Total Tests: 20
✅ Passed: 18
❌ Failed: 0
⚠️  Warnings: 2
⏭️  Skipped: 0

✅ ALL TESTS PASSED WITH WARNINGS
```

### Warning Example

```
⚠️  No demo sites found
   Warning: Run: npm run seed:demo
```

### Failure Example

```
❌ Storage rules use UID-based lookup
   Error: storage.rules:8 uses request.auth.uid instead of email
```

## Common Issues

### Emulator Not Running

**Error**: `❌ FIRESTORE_EMULATOR_HOST not set for emulator mode`

**Fix**:
```bash
# Start emulators first
firebase emulators:start --only auth,firestore,storage
```

### Demo Data Missing

**Error**: `⚠️ Demo user document not found`

**Fix**:
```bash
# Seed demo data
npm run seed:demo
npm run seed:demo
npm run seed:taxonomy:emulator
```

### Production Credentials Missing

**Error**: `❌ GOOGLE_APPLICATION_CREDENTIALS not set for production mode`

**Fix**:
```bash
# Set service account path
export GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json
```

### User Not Found

**Error**: `⏭️ User document not found (may need manual creation)`

**Fix**: Create test user manually in the app or adjust `--email` parameter to existing user

## Advanced Usage

### Test Specific User

```bash
# Test with custom email
FIRESTORE_EMULATOR_HOST=localhost:58080 \
  node scripts/verify-permissions.js --email="your.email@example.com"
```

### Test Demo Mode

```bash
# Test community tier (community build only supports community tier)
npm run test:smoke:demo
```

### Verbose Output

```bash
# Enable verbose logging
FIRESTORE_EMULATOR_HOST=localhost:58080 \
  node scripts/verify-permissions.js --verbose
```

## Documentation

- **Full Checklist**: `/docs/SMOKE_TEST_CHECKLIST.md`
- **Verification Script**: `/scripts/verify-permissions.js`
- **Identity Scheme**: `/docs/architecture/identity_scheme.md`

## Next Steps After Phase 3-B1

1. Review test results and fix any failures
2. Update security rules if needed
3. Re-run tests until all pass
4. Proceed to Phase 3-C: Deploy guardrails (CI rule drift detection)
