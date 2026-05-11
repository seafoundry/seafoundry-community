# CI Firebase Setup Guide

This guide explains how to configure GitHub Actions to perform automated Firebase rules drift checks.

## Overview

The `demo-mode-verification.yml` workflow includes a drift detection job that compares deployed Firebase rules against the repository version. This requires authentication to Firebase production projects.

## Prerequisites

- Admin access to Firebase Console for `seafoundryapp` project
- Admin access to GitHub repository settings

## Setup Steps

### 1. Create Firebase Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: `seafoundryapp`
3. Navigate to **IAM & Admin** > **Service Accounts**
4. Click **Create Service Account**
5. Configure:
   - **Name:** `github-actions-rules-drift-check`
   - **Description:** `Service account for GitHub Actions to check Firebase rules drift`
   - Click **Create and Continue**

6. Grant roles:
   - **Firebase Admin** or **Cloud Firestore Admin** (to read deployed rules)
   - Click **Continue**

7. Skip granting users access (click **Done**)

### 2. Generate Service Account Key

1. Click on the newly created service account
2. Go to **Keys** tab
3. Click **Add Key** > **Create new key**
4. Select **JSON** format
5. Click **Create**
6. Save the downloaded JSON file securely (delete after adding to GitHub)

### 3. Add Secret to GitHub

1. Go to your GitHub repository
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Configure:
   - **Name:** `FIREBASE_SERVICE_ACCOUNT`
   - **Secret:** Paste the entire contents of the JSON file from step 2
5. Click **Add secret**

### 4. Verify Setup

Create a test PR that modifies a rules file and verify the drift check job runs successfully.

## Security Considerations

- The service account has **read-only** access to Firebase rules
- It **cannot** deploy rules or access Firestore data
- The secret is encrypted and only exposed to GitHub Actions during workflow execution
- Rotate the service account key periodically (recommended: every 90 days)

## Troubleshooting

### Drift check shows "WARNING: FIREBASE_SERVICE_ACCOUNT secret not configured"

The secret hasn't been added to GitHub. Follow steps 1-3 above.

### Drift check shows "Could not fetch deployed rules"

The service account may not have sufficient permissions. Verify:
1. Service account has "Firebase Admin" or "Cloud Firestore Admin" role
2. Service account JSON is valid and complete in GitHub secret
3. Project ID in workflow (`seafoundryapp`) matches your Firebase project

### Drift check fails with authentication error

The service account key may be invalid or expired:
1. Delete the old key from Google Cloud Console
2. Generate a new key (step 2)
3. Update GitHub secret with new key (step 3)

## Optional: Skip Drift Check

If you cannot configure the service account (e.g., lack of permissions), the drift check will gracefully skip and not block PRs. However, this is not recommended for production repositories.

To completely disable the drift check job, add this condition to the job:

```yaml
rules-drift-check:
  if: false  # Disable drift check
```

## Maintenance

### Rotating Service Account Keys

Recommended frequency: Every 90 days

1. Create a new key for the service account (step 2)
2. Update GitHub secret with new key (step 3)
3. Delete the old key from Google Cloud Console
4. Verify drift check still works on a test PR

### Adding Community Project Support

If using a separate community Firebase project (`demo-seafoundry`):

1. Grant the same service account "Firebase Admin" or "Cloud Firestore Admin" role on the community project
2. Update the workflow to check community rules drift as well

## Related Documentation

- [Firebase Security Rules Deployment Runbook](FIRESTORE_RULES_DEPLOY_RUNBOOK.md)
- [GitHub Actions Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Google Cloud Service Accounts](https://cloud.google.com/iam/docs/service-accounts)
