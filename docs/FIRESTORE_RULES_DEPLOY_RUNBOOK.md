# Firestore Rules Deployment Runbook

**Version:** 1.0
**Last Updated:** January 6, 2026
**Owner:** Engineering Team

## Table of Contents
1. [Overview](#overview)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Deployment Procedures](#deployment-procedures)
4. [Verification](#verification)
5. [Rollback Procedures](#rollback-procedures)
6. [Emergency Procedures](#emergency-procedures)
7. [Drift Detection & Resolution](#drift-detection--resolution)
8. [Troubleshooting](#troubleshooting)

---

## Overview

This runbook covers deployment procedures for all Firebase security rules:
- `firestore.rules` - Production Firestore database rules (primary project: `seafoundryapp`)
- `firestore.rules` - Community tier Firestore rules when deploying via `firebase.community.json`
- `storage.rules` - Cloud Storage security rules

**Critical Safety Principle:** Security rules are the last line of defense for data access control. Never deploy without thorough testing and verification.

---

## Pre-Deployment Checklist

### 1. Code Review & Testing
- [ ] All rules changes have been peer-reviewed
- [ ] Changes documented with clear comments explaining intent
- [ ] Security tests pass locally: `cd functions && npm run test:security`
- [ ] CI security tests pass (Demo Mode Verification workflow)
- [ ] CI quality gates pass (analyze, tests)
- [ ] No analyzer errors: `flutter analyze` shows 0 errors

### 2. Environment Verification
- [ ] Firebase CLI installed and up-to-date: `firebase --version` (minimum v13.0.0)
- [ ] Authenticated to correct Firebase account: `firebase login:list`
- [ ] Correct project selected: `firebase projects:list` and `firebase use <project>`
- [ ] Service account credentials available (for automated deploys)

### 3. Backup Current Rules
```bash
# Production project
firebase --project=seafoundryapp firestore:rules:get > firestore.rules.backup.$(date +%Y%m%d_%H%M%S)

# Community project (if applicable)
firebase --project=demo-seafoundry firestore:rules:get > firestore.rules.community.backup.$(date +%Y%m%d_%H%M%S)

# Storage rules (both projects use same storage bucket structure)
firebase --project=seafoundryapp storage:rules:get > storage.rules.backup.$(date +%Y%m%d_%H%M%S)
```

### 4. Diff Against Deployed Rules
```bash
# Compare local changes with deployed rules
firebase --project=seafoundryapp firestore:rules:get > /tmp/deployed.rules
diff firestore.rules /tmp/deployed.rules

# For community rules (if applicable)
firebase --project=demo-seafoundry firestore:rules:get > /tmp/deployed.community.rules
diff firestore.rules /tmp/deployed.community.rules

# For storage rules
firebase --project=seafoundryapp storage:rules:get > /tmp/deployed.storage.rules
diff storage.rules /tmp/deployed.storage.rules
```

### 5. Stakeholder Communication
- [ ] Notify team in #engineering channel before deploying
- [ ] If during business hours, confirm no critical operations in progress
- [ ] For major changes, schedule deployment during low-traffic window
- [ ] Have rollback plan ready and communicated

---

## Deployment Procedures

### Option A: Interactive Deployment (Recommended for Manual Deploys)

#### Step 1: Deploy Firestore Rules (Production)
```bash
# Switch to production project
firebase use seafoundryapp

# Deploy rules only (not functions/hosting)
firebase deploy --only firestore:rules

# Verify deployment
firebase firestore:rules:get
```

**Expected Output:**
```
=== Deploying to 'seafoundryapp'...

i  deploying firestore
i  firestore: checking firestore.rules for compilation errors...
✔  firestore: rules file firestore.rules compiled successfully
i  firestore: uploading rules firestore.rules...
✔  firestore: released rules firestore.rules to cloud.firestore

✔  Deploy complete!
```

#### Step 2: Deploy Storage Rules (Production)
```bash
# Still using seafoundryapp project
firebase deploy --only storage

# Verify deployment
firebase storage:rules:get
```

**Expected Output:**
```
=== Deploying to 'seafoundryapp'...

i  deploying storage
i  storage: checking storage.rules for compilation errors...
✔  storage: rules file storage.rules compiled successfully
i  storage: uploading rules storage.rules...
✔  storage: released rules storage.rules

✔  Deploy complete!
```

#### Step 3: Deploy Community Rules (If Applicable)
```bash
# Switch to community/demo project
firebase use demo-seafoundry

# Deploy community rules
firebase deploy --only firestore:rules --config firebase.community.json

# Verify deployment
firebase firestore:rules:get
```

### Option B: Automated Deployment (CI/CD)

**Prerequisites:**
- Service account with Firebase Security Rules Admin role
- `FIREBASE_SERVICE_ACCOUNT` secret configured in GitHub Actions
- Deployment only triggered from `main` branch after all checks pass

**Automated via GitHub Actions:**
Deployments are automatically triggered when rules files are merged to `main` and all CI checks pass. See `.github/workflows/deploy-rules.yml` for implementation.

### Option C: Emergency Hotfix Deployment

For critical security issues requiring immediate deployment:

```bash
# 1. Create hotfix branch
git checkout -b hotfix/security-rules-YYYYMMDD

# 2. Make minimal changes to fix security issue
# 3. Test locally with emulator
firebase emulators:start --only firestore,storage
cd functions && npm run test:security

# 4. Deploy immediately (skip normal review if critical)
firebase use seafoundryapp
firebase deploy --only firestore:rules,storage

# 5. Verify deployment
firebase firestore:rules:get
firebase storage:rules:get

# 6. Create PR for documentation/review after deployment
git add firestore.rules storage.rules
git commit -m "fix(security): emergency hotfix for [describe issue]"
git push origin hotfix/security-rules-YYYYMMDD
```

---

## Verification

### Automated Verification (CI)

The `demo-mode-verification.yml` workflow automatically runs security tests on every rules change:
- Tests demo user isolation
- Tests org-scoped access control
- Tests unauthenticated access denial
- Tests privilege escalation prevention

### Manual Verification (Post-Deploy)

#### 1. Verify Deployment Timestamp
```bash
# Check last deployment time
firebase --project=seafoundryapp firestore:rules:list

# Expected: Shows recent timestamp matching deployment
```

#### 2. Test Critical Access Paths

**Test 1: Authenticated org member can access own org data**
```bash
# Use Firebase Console > Firestore > Rules Playground
# Auth: test@example.com (org: test_org)
# Operation: get /sites/test_site_id
# Expected: Allow (if site.organizationId == 'test_org')
```

**Test 2: Demo user isolation**
```bash
# Auth: demo@example.com (org: demo_org_community)
# Operation: get /sites/real_site_id
# Expected: Deny
```

**Test 3: Unauthenticated access**
```bash
# Auth: None
# Operation: get /sites/any_site_id
# Expected: Deny
```

#### 3. Monitor Error Logs
```bash
# Check for permission denied errors in Cloud Logging
gcloud logging read "severity>=ERROR" --limit=50 --format=json \
  --project=seafoundryapp \
  --filter='resource.type="cloud_firestore_database" AND timestamp>="$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S)Z"'
```

#### 4. Test in Production App
- [ ] Log in as test user
- [ ] Navigate to key screens (Inventory, Sites, Community)
- [ ] Verify data loads correctly
- [ ] Check browser console for permission errors
- [ ] Test creating/updating/deleting records
- [ ] Test demo mode access (if applicable)

---

## Rollback Procedures

### Scenario 1: Rules Cause Permission Errors

**Symptoms:**
- Users reporting "permission denied" errors
- Cloud Logging shows spike in PERMISSION_DENIED errors
- App functionality broken after deployment

**Immediate Rollback:**
```bash
# 1. Switch to production project
firebase use seafoundryapp

# 2. Find backup file from pre-deployment
ls -lt firestore.rules.backup.* | head -n 1

# 3. Deploy backup rules
cp firestore.rules.backup.YYYYMMDD_HHMMSS firestore.rules
firebase deploy --only firestore:rules

# 4. Verify rollback
firebase firestore:rules:get

# 5. Test app functionality
# 6. Communicate rollback to team
```

**Post-Rollback:**
1. Investigate root cause using Rules Playground and logs
2. Create fix in separate branch with comprehensive tests
3. Re-review and re-deploy following normal procedures

### Scenario 2: Storage Rules Cause Upload Failures

```bash
# 1. Switch to production project
firebase use seafoundryapp

# 2. Restore storage rules backup
cp storage.rules.backup.YYYYMMDD_HHMMSS storage.rules
firebase deploy --only storage

# 3. Verify rollback
firebase storage:rules:get

# 4. Test file uploads in app
```

### Scenario 3: Community Rules Deployment Failed

```bash
# 1. Switch to community project
firebase use demo-seafoundry

# 2. Restore community rules backup
cp firestore.rules.community.backup.YYYYMMDD_HHMMSS firestore.rules
firebase deploy --only firestore:rules --config firebase.community.json

# 3. Verify rollback
firebase firestore:rules:get
```

---

## Emergency Procedures

### Security Incident: Rules Too Permissive

**If you discover deployed rules allow unauthorized access:**

1. **IMMEDIATE ACTION - Lock Down Access (1-2 minutes):**
   ```bash
   # Create emergency lockdown rules
   cat > firestore.rules.emergency <<'EOF'
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // EMERGENCY LOCKDOWN - Deny all access except admins
       // TODO: Replace placeholder UIDs with actual admin UIDs
       match /{document=**} {
         allow read, write: if request.auth != null &&
           request.auth.uid in ['ADMIN_UID_1', 'ADMIN_UID_2'];
       }
     }
   }
   EOF

   # Deploy lockdown
   cp firestore.rules.emergency firestore.rules
   firebase use seafoundryapp
   firebase deploy --only firestore:rules

   # Notify team immediately
   ```

2. **ASSESS DAMAGE (5-10 minutes):**
   - Check Cloud Logging for unauthorized access attempts
   - Identify affected data and users
   - Document incident timeline
   - Notify security team and stakeholders

3. **DEVELOP FIX (15-30 minutes):**
   - Review rules diff to identify vulnerability
   - Create fix with comprehensive tests
   - Test fix in emulator thoroughly
   - Peer review fix with senior engineer

4. **DEPLOY FIX:**
   ```bash
   # Deploy corrected rules
   cp firestore.rules.fixed firestore.rules
   firebase deploy --only firestore:rules

   # Verify with Rules Playground
   ```

5. **POST-INCIDENT:**
   - Document incident in post-mortem
   - Review and improve security testing
   - Update runbook with lessons learned
   - Consider data breach notification if applicable

### Firebase Console Access Issues

If deployment fails due to authentication:

```bash
# Re-authenticate
firebase logout
firebase login

# Verify account has correct permissions
firebase projects:list

# If service account, verify credentials
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
firebase use seafoundryapp
```

---

## Drift Detection & Resolution

**Drift** occurs when deployed rules don't match the repository version.

### Causes of Drift
1. Manual console deployments (discouraged)
2. Failed CI deployments that partially succeeded
3. Hotfix deployments not committed to repo
4. Multiple developers deploying simultaneously

### Detecting Drift

**Manual Check:**
```bash
# Production rules drift check
firebase --project=seafoundryapp firestore:rules:get > /tmp/deployed.rules
diff firestore.rules /tmp/deployed.rules

# If diff shows differences, drift exists
```

**CI Automated Check:**
The `demo-mode-verification.yml` workflow includes a drift check job that runs on PRs modifying rules files. See "CI Drift Check" section below.

### Resolving Drift

**Option 1: Repository is Correct**
If local rules are the intended state:
```bash
# Deploy local rules to production
firebase use seafoundryapp
firebase deploy --only firestore:rules,storage

# Verify deployment matches repo
firebase firestore:rules:get > /tmp/deployed.rules
diff firestore.rules /tmp/deployed.rules
# Should show no differences
```

**Option 2: Deployed Rules are Correct**
If production rules contain intentional changes not in repo (rare):
```bash
# Pull deployed rules into repo
firebase --project=seafoundryapp firestore:rules:get > firestore.rules

# Review changes carefully
git diff firestore.rules

# Commit to repo
git add firestore.rules
git commit -m "fix(rules): sync deployed rules to repository"
git push origin main
```

**Option 3: Force Deploy (Override Drift)**
If CI drift check is blocking a deploy but you've verified the change is correct:
```bash
# Add comment to PR explaining why drift is acceptable
# Deploy using --force flag (use with extreme caution)
firebase use seafoundryapp
firebase deploy --only firestore:rules --force

# Document forced deploy in commit message
```

### Preventing Drift
1. **Never deploy manually from console** - always use CLI or CI/CD
2. **Always commit rules changes before deploying**
3. **Use branch protection** to require PR reviews for rules files
4. **Run drift check regularly** - CI automatically checks on every PR
5. **Document all emergency deploys** with follow-up PRs

---

## CI Drift Check

The CI workflow automatically checks for drift on every PR that modifies rules files.

### How It Works

**On Pull Request:**
1. Workflow exports currently deployed rules from Firebase
2. Compares deployed rules with rules in the PR branch
3. Fails check if drift detected (deployed ≠ repo)
4. Requires manual resolution before merge

**Workflow File:** `.github/workflows/demo-mode-verification.yml`

**Job:** `rules-drift-check`

### Drift Check Job Details

```yaml
rules-drift-check:
  name: Check Rules Drift
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '22'

    - name: Install Firebase CLI
      run: npm install -g firebase-tools@latest

    - name: Authenticate to Firebase
      env:
        GOOGLE_APPLICATION_CREDENTIALS_JSON: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
      run: |
        echo "$GOOGLE_APPLICATION_CREDENTIALS_JSON" > $HOME/gcp-key.json
        export GOOGLE_APPLICATION_CREDENTIALS=$HOME/gcp-key.json
        firebase use seafoundryapp

    - name: Check Firestore Rules Drift
      run: |
        echo "Checking deployed rules vs repository..."
        firebase --project=seafoundryapp firestore:rules:get > /tmp/deployed.rules

        if ! diff -q firestore.rules /tmp/deployed.rules > /dev/null; then
          echo "ERROR: Deployed Firestore rules differ from repository!"
          echo "Diff:"
          diff firestore.rules /tmp/deployed.rules || true
          exit 1
        fi

        echo "✓ Firestore rules match deployed version"

    - name: Check Storage Rules Drift
      run: |
        echo "Checking deployed storage rules vs repository..."
        firebase --project=seafoundryapp storage:rules:get > /tmp/deployed.storage.rules

        if ! diff -q storage.rules /tmp/deployed.storage.rules > /dev/null; then
          echo "ERROR: Deployed storage rules differ from repository!"
          echo "Diff:"
          diff storage.rules /tmp/deployed.storage.rules || true
          exit 1
        fi

        echo "✓ Storage rules match deployed version"
```

### Handling Drift Check Failures

**If drift check fails on your PR:**

1. **Investigate why drift exists:**
   - Was there a recent hotfix deployment?
   - Did someone manually deploy from console?
   - Is there an ongoing incident requiring manual intervention?

2. **Resolve drift before merging:**
   - If repo is correct: Deploy local rules to production
   - If deployed is correct: Pull deployed rules into repo
   - Document resolution in PR comments

3. **Get approval to proceed:**
   - For intentional drift (rare), document reason
   - Tag senior engineer for review
   - Consider if this indicates process issue to fix

---

## Troubleshooting

### Issue: Deployment Fails with Compilation Error

**Symptom:**
```
Error: firestore.rules:123:5 - Syntax error
```

**Resolution:**
1. Check syntax carefully around reported line number
2. Validate with emulator: `firebase emulators:start --only firestore`
3. Use Firebase Console Rules Playground to test syntax
4. Common issues:
   - Missing semicolons
   - Unmatched braces or parentheses
   - Invalid function references
   - Incorrect match path syntax

### Issue: Rules Deploy But Don't Take Effect

**Symptom:**
- Deployment succeeds
- `firebase firestore:rules:get` shows new rules
- App still behaves like old rules are active

**Resolution:**
1. Wait 60 seconds for rules to propagate
2. Clear browser cache and reload app
3. Check Firebase Console > Firestore > Rules tab shows updated rules
4. Verify correct project: `firebase projects:list` and `firebase use`
5. Check if client SDK is caching: Restart app/clear app data

### Issue: Permission Denied During Deployment

**Symptom:**
```
Error: HTTP Error: 403, Permission denied
```

**Resolution:**
1. Verify authentication: `firebase login:list`
2. Check account has "Security Rules Admin" role in Firebase Console
3. For service accounts, verify `GOOGLE_APPLICATION_CREDENTIALS` is set
4. Confirm project ownership: `firebase projects:list`
5. Re-authenticate: `firebase logout && firebase login`

### Issue: Deployed Rules Cause App Crashes

**Symptom:**
- App crashes or shows blank screens after deployment
- Console shows permission denied errors for expected operations

**Resolution:**
1. **Immediate:** Rollback to previous rules (see Rollback Procedures)
2. Test rules locally with emulator before re-deploying
3. Review helper function changes - ensure backward compatibility
4. Check for breaking changes in collection access patterns
5. Verify `organizationId` field access doesn't cause null pointer errors

### Issue: Community Rules Not Deploying

**Symptom:**
- Production rules deploy successfully
- Community rules fail or don't update

**Resolution:**
1. Verify community project exists: `firebase projects:list`
2. Switch to community project: `firebase use demo-seafoundry`
3. Check `firebase.community.json` exists and is configured
4. Deploy with explicit config: `firebase deploy --only firestore:rules --config firebase.community.json`
5. Verify authentication to community project account

### Issue: Storage Rules Prevent Uploads

**Symptom:**
- File uploads fail with permission denied
- `storage.rules` recently deployed

**Resolution:**
1. Check user UID lookup in rules uses `request.auth.uid`:
   ```javascript
   request.auth.uid
   ```
2. Verify user document exists at `/users/{uid}`
3. Test with Firebase Console Storage Rules Playground
4. Ensure `organizationId` field exists on user document
5. Check file path matches expected pattern in rules

---

## Appendix: Rule File Locations

| File | Purpose | Production Project | Community Project |
|------|---------|-------------------|-------------------|
| `firestore.rules` | Main Firestore database rules (shared) | `seafoundryapp` | `demo-seafoundry` |
| `storage.rules` | Cloud Storage security rules | `seafoundryapp` | `seafoundryapp` |

---

## Appendix: Firebase Projects

| Project ID | Environment | Purpose |
|-----------|-------------|---------|
| `seafoundryapp` | Production | Main production database and storage |
| `demo-seafoundry` | Demo/Testing | Demo mode sandbox using `firestore.rules` via `firebase.community.json` |

---

## Appendix: Required Permissions

**For Manual Deploys:**
- Firebase Security Rules Admin role
- Firebase Viewer role (to read current rules)

**For CI/CD Deploys:**
- Service account with "Security Rules Admin" role
- Service account key stored in GitHub Secrets as `FIREBASE_SERVICE_ACCOUNT`

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-06 | Engineering Team | Initial runbook for Phase 3 Pod C deployment guardrails |

---

## Related Documentation

- [Firestore Security Rules Reference](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Demo Mode Reseed Guide](DEMO_RESEED.md)
- [Firestore Permissions Remediation Plan](../FIRESTORE_PERMISSIONS_REMEDIATION.md) (if exists)

---

**Questions or Issues?**
Contact #engineering on Slack or file an issue in GitHub.
