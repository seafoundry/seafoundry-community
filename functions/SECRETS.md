# Firebase Functions Secrets Management

This document explains how to configure secrets for Firebase Cloud Functions.

## Required Secrets

### GEMINI_API_KEY
**Purpose**: API key for Google Gemini AI service (used by Sebastian AI assistant)

**Required by**: `sebastianChat` Cloud Function

### RESEND_API_KEY
**Purpose**: API key for Resend email service (invitation emails)

**Required by**: `sendInvitationEmail`, `resendInvitationEmail` Cloud Functions

### STRIPE_SECRET_KEY
**Purpose**: Secret key for Stripe API (billing portal + checkout sessions)

**Required by**: `createCustomerPortalSession` Cloud Function

## Production Setup

### Setting Secrets in Firebase

To configure secrets for production deployment:

```bash
# Navigate to functions directory
cd functions

# Set the Gemini API key
firebase functions:secrets:set GEMINI_API_KEY

# Set the Resend API key
firebase functions:secrets:set RESEND_API_KEY

# Set the Stripe API key
firebase functions:secrets:set STRIPE_SECRET_KEY
```

You will be prompted to enter the secret value. The secret will be encrypted and stored securely in Google Cloud Secret Manager.

### Verifying Secrets

To list all configured secrets:

```bash
firebase functions:secrets:access GEMINI_API_KEY
firebase functions:secrets:access RESEND_API_KEY
firebase functions:secrets:access STRIPE_SECRET_KEY
```

### Updating Secrets

To update an existing secret:

```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set RESEND_API_KEY
firebase functions:secrets:set STRIPE_SECRET_KEY
```

### Granting Access

Secrets are automatically made available to functions that declare them in their configuration. The `sebastianChat` function includes `secrets: [geminiApiKey]`, the invitation email functions include `secrets: [resendApiKey]`, and the billing portal function includes `secrets: [stripeSecretKey]`.

## Local Development Setup

For local development and testing:

1. **Create or update `.env` file** in the `functions/` directory:
   ```bash
   cd functions
   nano .env  # or use your preferred editor
   ```

2. **Add the secret**:
   ```
   GEMINI_API_KEY=your-actual-gemini-api-key-here
   RESEND_API_KEY=your-actual-resend-api-key-here
   STRIPE_SECRET_KEY=your-stripe-secret-key-here
   ```

3. **Security**: The `.env` file is gitignored and should NEVER be committed to version control.

4. **Get an API key**: Obtain a Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey)

## Deployment

When deploying functions that use secrets:

```bash
# Deploy all functions (secrets must be set first)
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:sebastianChat
```

If a secret is missing during deployment, you'll see an error message. Set the secret using the production setup commands above.

## Troubleshooting

### Error: "GEMINI_API_KEY secret is not configured"

**Cause**: The secret has not been set in Firebase Secret Manager

**Solution**:
```bash
firebase functions:secrets:set GEMINI_API_KEY
```

### Error: "RESEND_API_KEY secret is not configured"

**Cause**: The secret has not been set in Firebase Secret Manager

**Solution**:
```bash
firebase functions:secrets:set RESEND_API_KEY
```

### Error: "STRIPE_SECRET_KEY secret is not configured"

**Cause**: The secret has not been set in Firebase Secret Manager

**Solution**:
```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
```

### Local Function Returns "Secret not configured" Error

**Cause**: Missing or incorrect `.env` file in functions directory

**Solution**:
1. Ensure `.env` file exists at `/functions/.env`
2. Verify it contains: `GEMINI_API_KEY=your-key-here`
3. Restart the Firebase emulator if running

### Permission Denied When Accessing Secrets

**Cause**: Service account doesn't have Secret Manager permissions

**Solution**:
```bash
# Grant Secret Accessor role to the default service account
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:YOUR_PROJECT_ID@appspot.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Function Deployment Fails with Secret Error

**Cause**: Function declares a secret that hasn't been created

**Solution**: Set all required secrets before deploying:
```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set RESEND_API_KEY
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase deploy --only functions
```

## Security Best Practices

1. **Never commit secrets** to version control
2. **Rotate secrets regularly** (at least quarterly)
3. **Use different secrets** for development and production
4. **Limit secret access** to only functions that need them
5. **Monitor secret usage** through Google Cloud Console
6. **Delete unused secrets** to reduce attack surface

## Additional Resources

- [Firebase Functions Secrets Documentation](https://firebase.google.com/docs/functions/config-env#secret-manager)
- [Google Cloud Secret Manager](https://cloud.google.com/secret-manager/docs)
- [Google AI Studio](https://makersuite.google.com/)
