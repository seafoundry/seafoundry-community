# Community Web Deployment Guide

**Tier:** Community (OSS web-only)
**Updated:** 2025-11-20
**Branch:** `main` (Community tier deployments)

This guide covers deploying the SeaFoundry Community tier, a web-only, open-source platform for basic marine restoration workflows with Visual Engagement features.

---

## Overview

SeaFoundry Community tier is an **open-source, web-only** platform for marine restoration organizations. This guide covers:

- Building the Community web app with tier enforcement
- Deploying to Firebase Hosting (or self-hosting alternatives)
- Configuring Visual Engagement features (public holdings map, hero imagery, brand profiles)
- Verifying tier restrictions (1 nursery + 1 outplanting site limit)
- Setting up CI/CD automation

**Key Features**:
- Six-field CSV exports (species, provenance, location, life stage, quantity, date)
- Basic inventory management (holdings, transfers, mortality tracking)
- Public holdings map (anonymized location clusters)
- Visual identity (hero backgrounds, logos, public profiles)
- Web-only access (desktop/tablet browsers)

---

## Prerequisites

### System Requirements
- **Flutter** 3.35.7+ (stable channel)
- **Dart** 3.9.2+
- **Node.js** 18.x+ and npm 9+
- **Firebase CLI** 13.0.0+
- **Git**

### Firebase Project Setup

1. **Create Firebase Project**
   Visit [firebase.google.com](https://firebase.google.com) and create a new project (or use existing).

2. **Enable Firebase Services**:
   - **Firestore** (Database) - Primary data store
   - **Authentication** (Email/Password provider) - User authentication
   - **Cloud Functions** (Node.js 18+) - Visual Engagement features
   - **Firebase Hosting** - Web app hosting
   - **Cloud Storage** - Media uploads (hero images, logos)

3. **Install Firebase CLI**:
   ```bash
   npm install -g firebase-tools@13.0.0
   firebase login
   ```

4. **Verify Installation**:
   ```bash
   firebase projects:list
   # Should show your project ID
   ```

---

## Initial Setup

### 1. Clone Repository and Install Dependencies

```bash
# Clone the repository
git clone https://github.com/your-org/seafoundry_app.git
cd seafoundry_app

# Switch to main branch (Community tier)
git checkout main

# Install Flutter dependencies
flutter pub get

# Verify tier checker tool
dart run tool/bin/tier_check.dart

# Install Cloud Functions dependencies
cd functions
npm install
cd ..
```

### 2. Configure Environment Variables

Create `.env` file from template:
```bash
cp env.example .env
```

Edit `.env` with your Firebase project configuration:
```env
# Firebase Configuration (get from Firebase Console > Project Settings)
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-web-api-key
FIREBASE_AUTH_DOMAIN=your-project-id.firebaseapp.com
FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com
FIREBASE_MESSAGING_SENDER_ID=your-sender-id
FIREBASE_APP_ID=your-app-id

# Tier Configuration (DO NOT CHANGE for Community deployment)
SF_TIER=community

# Optional: Logging level
LOG_LEVEL=info
```

**IMPORTANT**: Never commit `.env` to version control. It's included in `.gitignore`.

### 3. Initialize Firebase Project

```bash
# Connect to your Firebase project
firebase use --add
# Select your project from the list or enter project ID

# Initialize Firestore (if not already done)
firebase init firestore
# Use existing firestore.rules and firestore.indexes.json

# Initialize Cloud Functions
firebase init functions
# Use existing functions/ directory, TypeScript, ESLint

# Initialize Hosting
firebase init hosting
# Public directory: build/web
# Configure as single-page app: Yes
# Set up automatic builds: Optional (recommended for CI/CD)
```

### 4. Verify Firebase Configuration

Check `firebase.json` contains:
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": [
    {
      "source": "functions",
      "codebase": "default"
    }
  ]
}
```

---

## Firestore Setup

### 1. Deploy Security Rules

Deploy Firestore security rules to enforce Community tier restrictions:
```bash
firebase deploy --only firestore:rules --project your-project-id
```

**Community Tier Security Rules**:
- Public read access to `public_orgs/{orgId}/*` collections (Visual Engagement)
- Authenticated users can read/write operational data
- Pro-only fields filtered at repository layer (not enforced in rules)

Verify rules deployment:
```bash
# Check Firestore rules in Firebase Console
# Navigate to: Firestore Database > Rules tab
```

### 2. Deploy Firestore Indexes

Deploy composite indexes for query optimization:
```bash
firebase deploy --only firestore:indexes --project your-project-id
```

**Wait for Index Build**: Indexes take 10-15 minutes to build. Monitor status:
```bash
firebase firestore:indexes --project your-project-id
# All indexes should show status: READY
```

### 3. Seed Taxonomy Data

Populate canonical taxonomy and species registries:

**Test Locally First** (recommended):
```bash
# Start emulators
firebase emulators:start --only firestore,functions

# In another terminal, seed emulator
npm run seed:taxonomy:emulator
```

**Deploy to Production**:
```bash
npm run seed:taxonomy:production
```

This seeds:
- Canonical organism types (coral, kelp, oyster, seagrass, genericMarine)
- Species registries (NOAA-compliant species data)
- Provenance scaffolding
- Life stage definitions
- Measurement field schemas

---

## Build & Deploy

### 1. Pre-Build Verification

Before building, verify code quality:

```bash
# Run tier checker (ensures no Pro/Scale imports in Community code)
dart run tool/bin/tier_check.dart

# Run Flutter analyzer (zero errors required)
flutter analyze

# Run tests (optional but recommended)
flutter test --platform chrome
```

All checks should pass before proceeding.

### 2. Build Web Application

Build the Community tier web app with tier enforcement:

```bash
flutter clean
flutter pub get

# Build for Community tier (web-only)
flutter build web \
  --release \
  --dart-define=SF_TIER=community \
  --web-renderer canvaskit
```

**Build Flags Explained**:
- `--release` - Production-optimized build (minified, no debug info)
- `--dart-define=SF_TIER=community` - **REQUIRED**: Enforces Community tier feature gating
- `--web-renderer canvaskit` - Better performance for complex UIs (spreadsheets, maps)

**Verify Build Output**:
```bash
ls -la build/web/
# Should contain: index.html, main.dart.js, flutter.js, assets/, icons/
```

**Expected Build Size**: ~15-25 MB (uncompressed web assets)

### 3. Deploy Cloud Functions

Build and deploy Visual Engagement Cloud Functions:

```bash
cd functions

# Install dependencies (if not already done)
npm install

# Lint TypeScript (recommended)
npm run lint

# Build TypeScript to JavaScript
npm run build

# Return to project root
cd ..

# Deploy all functions
firebase deploy --only functions --project your-project-id
```

**Community Tier Functions** (automatically deployed):
- `projectOrgImpactPoints` - Aggregates holdings/outplant data for public holdings map
- `buildOrgPlaylist` - Generates media playlists for public profiles (future)
- `onMediaUpload` - Processes uploaded imagery for hero backgrounds (future)

**Function Deployment Time**: 3-5 minutes per function.

**Verify Deployment**:
```bash
firebase functions:list --project your-project-id
# Should show deployed functions with HTTPS URLs
```

### 4. Deploy Storage Rules

Deploy Firebase Storage security rules:
```bash
firebase deploy --only storage --project your-project-id
```

### 5. Deploy to Firebase Hosting

Deploy the built web app:
```bash
firebase deploy --only hosting --project your-project-id
```

**Deployment Progress**:
1. Uploading build/web/ files (30-60 seconds)
2. Finalizing deployment
3. Returns hosting URL

**Your Community app will be available at**:
- `https://your-project-id.web.app`
- `https://your-project-id.firebaseapp.com` (alternate URL)

### 6. Verify Deployment

Test the deployed app:

1. **Visit Hosting URL**: Open `https://your-project-id.web.app` in browser
2. **Check Console**: Open browser DevTools, verify no errors
3. **Test Sign Up**: Create a test user account
4. **Complete Onboarding**: Create organization, select species
5. **Verify Tier Badge**: Check organization management shows "Community" tier
6. **Test Site Creation**: Create 1 nursery site (should succeed), try 2nd (should block with upgrade CTA)

---

## Visual Engagement Setup (Community Tier)

Community tier includes Visual Engagement features for public-facing marine restoration storytelling.

### 1. Enable Public Holdings Map

The public holdings map displays anonymized location clusters of holdings/outplants across participating organizations.

**Required Setup**:
1. Cloud Function `projectOrgImpactPoints` must be deployed (see Build & Deploy section)
2. Organization must have at least one site with holdings or outplant events
3. Public profile must be enabled

**Verify Map Function**:
```bash
# Check if function deployed
firebase functions:list --project your-project-id | grep projectOrgImpactPoints

# Test function manually (optional)
firebase functions:log --only projectOrgImpactPoints --project your-project-id
```

### 2. Brand Profile Configuration

Organizations can customize their public brand identity:

**Upload Hero Image**:
1. Log in to deployed app
2. Navigate to **Organization Management** → **Profile**
3. Click **Upload Hero Image**
4. Select image (recommended: 1920x1080px, landscape)
5. Image appears as:
   - Background in organization node screens
   - Avatar on public holdings map
   - Hero in public organization profile

**Upload Logo**:
1. Navigate to **Organization Management** → **Profile**
2. Click **Upload Logo**
3. Select image (recommended: 512x512px, square with transparency)
4. Logo appears in:
   - Navigation header
   - Public holdings map markers
   - Shared reports/exports

**Set Accent Color** (optional):
1. Navigate to **Organization Management** → **Profile**
2. Pick accent color (brand color for CTAs, highlights)
3. Color applied to buttons, links, progress indicators

### 3. Enable Public Profile

To appear on the Community holdings map:

1. Navigate to **Organization Management** → **Settings**
2. Toggle **Public Profile** to enabled
3. Save changes

Organization will now:
- Appear on public holdings map at `https://your-domain.web.app/public/map`
- Have public profile at `https://your-domain.web.app/public/org/{orgId}`
- Contribute holdings/outplant data to aggregated impact stats

### 4. Seed Sample Data (Testing)

For development/testing deployments, seed sample brand profiles:

```bash
node scripts/seed-brand-profiles.js
```

This creates sample organizations with hero images and logos for visual testing.

---

## Post-Deployment Configuration

### 1. Create First Organization

**Via Onboarding Flow** (recommended):
1. Visit deployed app URL
2. Click **Sign Up**
3. Complete onboarding:
   - Organization name
   - Primary organism types (select at least one)
   - Activities (nursery, outplanting, monitoring)
   - Species selection
   - Domain (optional)
   - Brand imagery (optional)

Organization created with tier automatically set to `community`.

**Via Firebase Console** (admin bypass):
1. Firebase Console → Authentication → Add User
2. Firestore → Create collection `organizations`
3. Add document with fields:
```json
{
  "name": "Test Organization",
  "tier": "community",
  "createdAt": [Timestamp],
  "ownerId": "[user-uid]",
  "primaryOrganisms": ["coral"],
  "activities": ["nursery", "outplanting"]
}
```

### 2. Verify Tier Enforcement

Test Community tier restrictions:

**Site Creation Limits**:
1. Create a nursery site (ex situ, in situ, or gene bank) - Should succeed
2. Try to create a 2nd nursery site - Should block with "Upgrade to Pro" CTA
3. Create an outplanting/restoration site - Should succeed
4. Try to create a 2nd outplanting site - Should block with upgrade CTA

**Feature Restrictions**:
1. Inventory → Quantity Change - Mortality reasons should be read-only chips (not editable dropdown)
2. Monitoring → Create observation - Should show "Upgrade to Pro" CTA instead of dialog
3. Settings → Offline Sync - Should not appear
4. Navigation - Mobile app download links should show upgrade CTA

**CSV Exports**:
1. Inventory → Export - Should generate 6-field CSV (species, provenance, location, life stage, quantity, date)
2. Pro-only fields (detailed measurements, attachments) should not appear

### 3. Configure Admin Access (Optional)

Promote user to admin for organization configuration:

1. Firestore → `users/{uid}`
2. Update role field:
```json
{
  "role": "admin"
}
```

Note: Admin status is computed from `role == 'admin'` - no separate `isAdmin` field is stored.

Admins can:
- Manage organization taxonomy (species, provenance, site types)
- Configure environmental thresholds
- Manage team members
- Access organization settings

---

## CI/CD Automation (Optional)

### GitHub Actions Workflow

The repository includes `.github/workflows/community_web.yaml` for automated testing and deployment.

**Workflow Triggers**:
- Push to `main` branch
- Pull requests to `main` branch

**Workflow Steps**:
1. Checkout code
2. Setup Flutter (stable channel)
3. Install dependencies (`flutter pub get`)
4. Run tier manifest check (`dart run tool/bin/tier_check.dart`)
5. Run Flutter analyzer (`flutter analyze`)
6. Run tests (`flutter test --platform chrome`)
7. Build web app (`flutter build web --dart-define=SF_TIER=community`)

**Enable GitHub Actions**:
1. Repository → Settings → Actions → Enable
2. Workflow automatically runs on push to `main`
3. View results in Actions tab

**Firebase Hosting GitHub Integration** (optional):
```bash
# Initialize hosting with GitHub deployment
firebase init hosting:github

# Follow prompts to connect repository
# Creates .github/workflows/firebase-hosting-*.yml
```

This auto-deploys to Firebase Hosting on push to `main`.

### Branch Protection Rules

Configure branch protection for `main`:

1. GitHub Repository → Settings → Branches
2. Add rule for `main`:
   - Require status checks to pass: `community_web`
   - Require branches to be up to date
   - Include administrators
3. Save changes

All PRs to `main` must pass CI checks before merging.

---

## Self-Hosting (Alternative to Firebase Hosting)

### Using Nginx

Self-host the web app while using Firebase backend services.

**1. Build Web App**:
```bash
flutter build web --release --dart-define=SF_TIER=community
```

**2. Copy to Web Server**:
```bash
scp -r build/web/* user@yourserver.com:/var/www/seafoundry/
```

**3. Configure Nginx**:
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name seafoundry.example.com;
    root /var/www/seafoundry;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Single-page app routing (fallback to index.html)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets aggressively
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Don't cache HTML (for updates)
    location ~* \.html$ {
        expires -1;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
```

**4. Enable HTTPS** (recommended via Let's Encrypt):
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d seafoundry.example.com
```

**5. Restart Nginx**:
```bash
sudo nginx -t  # Test configuration
sudo systemctl restart nginx
```

**Important**: You still need Firebase for backend services:
- Firestore (database)
- Cloud Functions
- Authentication
- Cloud Storage

Self-hosting only replaces Firebase Hosting, not the entire backend.

---

## Monitoring & Maintenance

### Application Health Checks

**Firebase Console Monitoring**:
1. **Hosting**: Console → Hosting → Check traffic metrics
2. **Firestore**: Console → Firestore → Usage tab (reads/writes/storage)
3. **Functions**: Console → Functions → Check invocations, errors, execution time
4. **Authentication**: Console → Authentication → Monitor user signups

**Command Line Monitoring**:
```bash
# View Cloud Functions logs
firebase functions:log --project your-project-id

# View specific function logs
firebase functions:log --only projectOrgImpactPoints --project your-project-id

# Check Firestore index status
firebase firestore:indexes --project your-project-id
```

**Performance Monitoring** (optional):
```bash
# Enable Performance Monitoring in Firebase Console
# Add Firebase Performance SDK to web app for detailed metrics
```

### Update Deployment

When updating to newer Community releases:

**1. Pull Latest Changes**:
```bash
cd seafoundry_app
git fetch origin
git pull origin main
```

**2. Update Dependencies**:
```bash
# Flutter dependencies
flutter pub get

# Functions dependencies
cd functions
npm install
npm audit fix  # Fix security vulnerabilities
cd ..
```

**3. Run Pre-Deployment Checks**:
```bash
# Tier checker
dart run tool/bin/tier_check.dart

# Analyzer
flutter analyze

# Tests (optional)
flutter test --platform chrome
```

**4. Rebuild and Redeploy**:
```bash
# Build web app
flutter build web --release --dart-define=SF_TIER=community

# Deploy everything
firebase deploy --project your-project-id

# Or deploy selectively
firebase deploy --only hosting,functions --project your-project-id
```

**5. Verify Update**:
- Visit hosting URL
- Check browser console for errors
- Test key workflows (site creation, CSV export, public map)

### Rollback Procedure

If deployment fails, rollback to previous version:

**Hosting Rollback**:
```bash
# List recent deployments
firebase hosting:channel:list --project your-project-id

# Rollback hosting
firebase hosting:rollback --project your-project-id
```

**Functions Rollback**:
```bash
# Redeploy previous version from git
git checkout <previous-commit-hash>
cd functions && npm run build && cd ..
firebase deploy --only functions --project your-project-id
git checkout main  # Return to main branch
```

### Firebase Cost Monitoring

**Community Tier Budget** (typical usage):
- **Firestore**: $1-5/month (reads, writes, storage)
- **Cloud Functions**: $0-2/month (invocations)
- **Hosting**: $0 (free tier sufficient for most deployments)
- **Cloud Storage**: $0-1/month (hero images, logos)
- **Authentication**: $0 (free)

**Total Estimated Cost**: $1-8/month for small-to-medium organizations (< 100 users)

**Set Budget Alerts**:
1. Firebase Console → Project Settings → Billing
2. Set budget alert (e.g., $10/month)
3. Receive email when approaching limit

---

## Community Tier Feature Matrix

### Included Features

| Category | Feature | Description |
|----------|---------|-------------|
| **Inventory** | Basic holdings tracking | Track coral/kelp/oyster/seagrass inventory |
| **Inventory** | Six-field CSV export | Species, provenance, location, life stage, quantity, date |
| **Inventory** | Internal transfers | Move organisms between structures |
| **Inventory** | Mortality tracking | Basic death events with read-only mortality reasons |
| **Genetics** | Provenance management | Track genets, cohorts, genetic lineage |
| **Genetics** | Fragging events | Record fragmentation with provenance chain |
| **Sites** | 1 Nursery site | Ex situ, in situ, or gene bank (1 total) |
| **Sites** | 1 Outplanting site | Restoration or field collection site (1 total) |
| **Outplanting** | Basic outplant events | Record outplants with centerpoint location |
| **Outplanting** | Public holdings map | Anonymized location clusters on public map |
| **Visual Engagement** | Hero imagery | Upload hero backgrounds for organization node |
| **Visual Engagement** | Logo upload | Organization logo for branding |
| **Visual Engagement** | Brand accent color | Customize button/link colors |
| **Visual Engagement** | Public org profile | Public-facing organization profile page |
| **Platform** | Web-only access | Desktop and tablet browser support |
| **Platform** | User authentication | Email/password sign in |
| **Platform** | Organization management | Admin controls for taxonomy, team, settings |

### Feature Restrictions (Pro/Scale Only)

| Category | Feature | Tier Required | Upgrade CTA |
|----------|---------|---------------|-------------|
| **Inventory** | Unlimited sites | Pro | In-app upgrade link |
| **Inventory** | Advanced mortality reasons | Pro | Read-only chips in Community |
| **Monitoring** | Monitoring observations | Pro | "Upgrade to Pro" CTA |
| **Monitoring** | KML geometry support | Pro | N/A |
| **Monitoring** | Event imagery attachments | Pro | Upload blocked with CTA |
| **Monitoring** | Detailed measurements | Pro | Filtered from CSV exports |
| **Platform** | Mobile app (iOS/Android) | Pro | Download links show CTA |
| **Platform** | Offline sync | Pro | Not visible in Community |
| **Collaboration** | Selective data sharing | Pro | N/A |
| **Reporting** | Custom report templates | Pro | N/A |
| **Workforce** | Training gates | Scale | N/A |
| **Workforce** | Recurring tasks | Scale | N/A |
| **Operations** | Deliverables integration | Scale | N/A |

**Upgrade Path**: Community → Pro via beta waitlist email form (configured in `config/tier_features.yaml`)

---

## Troubleshooting

### Build Errors

**Error: `SF_TIER not set` or `Undefined tier constant`**
```
Fix: Ensure --dart-define=SF_TIER=community in build command

# Correct
flutter build web --dart-define=SF_TIER=community

# Incorrect (missing flag)
flutter build web
```

**Error: `Undefined name 'context'` or compilation errors**
```
Fix: Pull latest changes from main branch

git fetch origin
git pull origin main
flutter clean
flutter pub get
```

**Error: Functions build fails with TypeScript errors**
```
Fix: Verify Node.js version and rebuild

node --version  # Should be 18.x+
cd functions
npm install
npm run build
```

**Error: `flutter analyze` fails with tier violations**
```
Fix: Run tier checker to identify Pro/Scale imports in Community code

dart run tool/bin/tier_check.dart

# Review violations, ensure files have correct // @tier: community headers
```

### Deployment Errors

**Error: `Permission denied` during `firebase deploy`**
```
Fix: Re-authenticate and verify project permissions

firebase login --reauth
firebase projects:list  # Verify access

# Ensure you have Owner or Editor role in Firebase Console
```

**Error: Firestore indexes still building after 30+ minutes**
```
Fix: Indexes can take 10-15 minutes normally, but sometimes longer

# Check index status
firebase firestore:indexes --project your-project-id

# If stuck in CREATING for > 30min, contact Firebase Support
```

**Error: Cloud Functions deployment timeout**
```
Fix: Functions can take 3-5 minutes per function

# Deploy one at a time if timeout occurs
firebase deploy --only functions:projectOrgImpactPoints

# Increase timeout (if supported by Firebase CLI)
firebase deploy --only functions --force
```

**Error: Hosting deployment succeeds but app shows blank page**
```
Fix: Check browser console for errors

Common causes:
1. Firebase config missing in .env
2. Firestore rules blocking reads
3. JavaScript load errors (check Network tab)

Verify .env contains correct Firebase config
Check Firebase Console > Firestore > Rules
```

### Runtime Errors

**Error: "Organization not found" after sign up**
```
Fix: Verify onboarding flow completed successfully

1. Check Firestore Console > organizations collection
2. Verify document exists with correct tier: "community"
3. If missing, manually create organization document
```

**Error: Public holdings map not showing organizations**
```
Fix: Verify Cloud Function deployed and organizations have public profiles enabled

# Check function deployment
firebase functions:list | grep projectOrgImpactPoints

# Check function logs
firebase functions:log --only projectOrgImpactPoints

# Verify organization has:
# - public profile enabled
# - at least one site with holdings
# - heroImageUrl or logoUrl set
```

**Error: Species dropdown empty in onboarding**
```
Fix: Re-run taxonomy seed script

npm run seed:taxonomy:production

# Verify species collection exists in Firestore Console
```

**Error: "Upgrade to Pro" CTA not working**
```
Fix: Verify upgrade URL configured in config/tier_features.yaml

Check tiers.community.upgrade_url is set to the beta waitlist email form URL
```

**Error: CSV export downloads empty file**
```
Fix: Verify holdings data exists

1. Check Firestore Console > holdings collection
2. Verify holdings have required fields (species, provenance, location, lifeStage, quantity)
3. Check browser console for export errors
```

### Performance Issues

**Issue: Slow page load times**
```
Optimize:
1. Enable browser caching (check Nginx/hosting config)
2. Enable CDN for Firebase Hosting
3. Reduce hero image sizes (optimize to < 500KB)
4. Enable Firestore persistence caching
```

**Issue: High Firebase costs**
```
Diagnose:
1. Firebase Console → Usage tab
2. Identify high read/write operations
3. Add indexes for slow queries
4. Review Cloud Function invocations

Common culprits:
- Missing Firestore indexes (full collection scans)
- Inefficient listeners (streamAll() without limits)
- Excessive function invocations
```

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Build with debug logging
flutter build web \
  --dart-define=SF_TIER=community \
  --dart-define=LOG_LEVEL=debug

# Or set in .env
LOG_LEVEL=debug
```

Check browser console for detailed logs from `LoggingService`.

---

## Security Considerations

### Firestore Security Rules

Community tier security rules allow:
- **Public read** for `public_orgs/{orgId}/*` collections
- **Authenticated read/write** for operational data
- **Pro-only fields** filtered at repository layer (not in rules)

**Test Security Rules**:
```bash
# Deploy rules
firebase deploy --only firestore:rules

# Test in Firebase Console > Firestore > Rules > Playground
```

### Environment Variables

**NEVER commit to version control**:
- `.env` file (Firebase credentials)
- `firebase-service-account.json` (admin credentials)
- Any API keys or secrets

Verify `.gitignore` includes:
```
.env
.env.*
firebase-service-account.json
*-service-account.json
```

### HTTPS Enforcement

Always use HTTPS for production deployments:
- Firebase Hosting: HTTPS automatic
- Self-hosted: Use Let's Encrypt (see Self-Hosting section)

---

## Getting Help

### Documentation

- **Project Docs**: `docs/` directory in repository
- **Architecture**: `docs/architecture/community_vs_pro_rfc.md`
- **Visual Engagement**: `docs/VisualEngagement.md`
- **Testing**: `test/helpers/README.md`
- **Firebase Deployment**: `docs/FIREBASE_DEPLOYMENT_CHECKLIST.md`
- **CI/CD**: `docs/architecture/ci_cd_split.md`

### Support Channels

- **GitHub Issues**: [github.com/your-org/seafoundry_app/issues](https://github.com/your-org/seafoundry_app/issues)
- **Community Forum**: [Link to community forum/Discord/Slack]
- **Email Support**: support@seafoundry.org (for Pro customers)

### Reporting Bugs

When reporting bugs, include:
1. **Environment**: Browser, OS, Firebase project ID
2. **Steps to reproduce**: Detailed steps
3. **Expected vs actual behavior**
4. **Screenshots/console errors**: Browser DevTools output
5. **Deployment details**: Tier (Community), branch, commit hash

---

## Post-Deployment Checklist

After completing deployment, verify:

- [ ] App accessible at hosting URL
- [ ] Firebase Authentication working (sign up/sign in)
- [ ] Onboarding flow completes successfully
- [ ] Organization created with tier="community"
- [ ] Site creation limits enforced (1 nursery + 1 outplanting)
- [ ] CSV export generates six-field format
- [ ] Hero image upload working
- [ ] Public holdings map displays (if org has holdings)
- [ ] Upgrade CTAs display when trying Pro features
- [ ] Browser console shows no errors
- [ ] Firestore indexes all READY status
- [ ] Cloud Functions deployed and invocable
- [ ] Firebase costs within budget ($1-8/month typical)

---

## Next Steps

After successful deployment:

1. **User Training**: Review `docs/user_guides/` for workflow tutorials
2. **CI/CD Setup**: Configure GitHub Actions (see CI/CD Automation section)
3. **Monitoring**: Set up Firebase budget alerts and performance monitoring
4. **Content**: Upload hero imagery and enable public profile
5. **Testing**: Create sample holdings and verify public map
6. **Backups**: Configure Firestore export schedule (Firebase Console → Firestore → Export)
7. **Pro Upgrade**: Explore Pro tier for mobile apps and advanced features

### Pro Tier Upgrade

When ready for mobile apps and advanced features:

1. Review Pro tier features in `docs/architecture/community_vs_pro_rfc.md`
2. Click **Upgrade to Pro** in app (Organization Management)
3. Submit the beta waitlist form and coordinate manual upgrade
4. Follow `docs/deployment/pro_mobile_deployment.md` for mobile app deployment
5. Migrate to `pro` branch for future deployments

---

## Additional Resources

- **SeaFoundry Website**: [www.seafoundry.org](https://www.seafoundry.org)
- **Flutter Documentation**: [flutter.dev](https://flutter.dev)
- **Firebase Documentation**: [firebase.google.com/docs](https://firebase.google.com/docs)
- **Community Forum**: [Link to forum]
- **YouTube Tutorials**: [Link to tutorial playlist]

**Document Version**: 2025-11-20
**Repository Branch**: `main` (Community tier)
**Maintainer**: SeaFoundry Team
