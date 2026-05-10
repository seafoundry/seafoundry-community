# Cloud Functions Tests

Mocha + ts-node tests for the community-fork Cloud Functions in
`functions/src/`.

## Test Structure

```
tests/
├── validators.test.ts          # Model validation tests
└── README.md                   # This file
```

> The Visual Engagement (VE) test suite was removed alongside
> `functions/src/visual_engagement.ts`. That feature is not part of
> the community fork.

## Running Tests

From the repo root:

```bash
npm --prefix functions test
```

Or from `functions/`:

```bash
cd functions
npm test
```

### Run a Specific Test File

```bash
cd functions
npx mocha --require ts-node/register tests/validators.test.ts
```

## Test Configuration

Tests use `firebase-functions-test` in offline mode for unit testing:

```typescript
import functionsTest from "firebase-functions-test";
const test = functionsTest();
```

For integration tests against the emulator, set environment variables:

```bash
export FIRESTORE_EMULATOR_HOST="localhost:8080"
export FIREBASE_AUTH_EMULATOR_HOST="localhost:9099"
```

## Naming Conventions

- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
