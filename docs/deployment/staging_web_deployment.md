# Staging Web Deployment

This guide documents the recommended staging deployment flow for SeaFoundry. The
goal is to validate changes in a production-like environment before promoting
them to production.

## Prerequisites

- Firebase CLI installed (`npm install -g firebase-tools`)
- Logged in to Firebase (`firebase login`)
- Access to the staging Firebase project (default: `seafoundry-staging`)
- Staging service account JSON (for seeding)
- `.env.staging` with Firebase web config values

## 1) Prepare environment

Create or update `.env.staging` with your staging Firebase web config:

```bash
cp .env.example .env.staging
# Edit .env.staging with staging project values
```

Generate dart defines from `.env.staging`:

```bash
ENV_FILE=.env.staging DART_DEFINES_OUTPUT=dart_defines.staging.json \
  npm run generate-dart-env --silent
```

## 2) Run CI locally (recommended)

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test test/unit/ test/blocs/ test/cubits/ test/services/ \
  --exclude-tags integration,comprehensive,golden \
  --concurrency=4 \
  --reporter expanded
```

Widget tests (sharded):

```bash
for i in 0 1 2 3; do
  flutter test test/widget/ test/widgets/ \
    --exclude-tags integration,comprehensive,golden \
    --total-shards=4 \
    --shard-index=$i \
    --concurrency=2 \
    --reporter expanded
done
```

## 3) Deploy to staging

Use the staging helper script:

```bash
./scripts/deploy-staging.sh
```

Optional flags:

```bash
./scripts/deploy-staging.sh --skip-functions --skip-storage
./scripts/deploy-staging.sh --skip-seed --skip-web
```

## 4) Seed demo data (if needed)

Seeding requires a staging service account JSON:

```bash
export FIREBASE_SERVICE_ACCOUNT=/path/to/staging-service-account.json
npm run seed:taxonomy
node scripts/seed-demo.js --seed-all-tiers --reset
```

## 5) Verify

- Open `https://seafoundry-staging.web.app`
- Log in with demo credentials
- Run smoke flows and capture regressions in `.github/issues/release/pre-release-audit.md`

## Troubleshooting

- **Wrong Firebase project**: Ensure `.firebaserc` includes `staging` and the
  script is using `seafoundry-staging`.
- **Seeding fails**: Check `FIREBASE_SERVICE_ACCOUNT` points to the correct JSON.
- **Auth/domain issues**: Confirm `FIREBASE_AUTH_DOMAIN` in `.env.staging`.
