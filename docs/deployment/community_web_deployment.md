# Deploying SeaFoundry Community (Web)

This guide covers deploying the SeaFoundry Community web app to production.
For local development, see [`COMMUNITY_README.md`](../../COMMUNITY_README.md).

## Prerequisites

- Flutter 3.35 or later (Dart 3.8+)
- Node.js 18 or later
- Firebase CLI: `npm install -g firebase-tools`
- A Firebase project (free Spark plan is sufficient for small deployments)

## 1. Create and Configure Your Firebase Project

In the [Firebase Console](https://console.firebase.google.com/):

1. Create a new project (or pick an existing one).
2. Enable **Authentication** -> Email/Password (and Google Sign-In if desired).
3. Enable **Firestore Database** in production mode.

This fork uses only Firestore, Auth, and Hosting — the free Spark plan is
sufficient. There are no Cloud Functions or Cloud Storage to enable.

Then sign in and select the project locally:

```bash
firebase login
firebase use YOUR_PROJECT_ID
```

## 2. Regenerate `firebase_options.dart`

The committed `lib/firebase_options.dart` points at the maintainer's Firebase
project. To point the app at **your** project, regenerate it:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID
```

Select **web** as the target platform.

## 3. Configure Environment Variables

```bash
cp .env.community.example .env
```

Edit `.env` and fill in the values from Firebase Console -> Project Settings ->
Your apps -> Web app. The required values are:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_API_KEY`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_APP_ID`

Optional values (in `.env.community.example`) cover shareable link prefixes
and other app configuration.

## 4. Lock Down Your Firebase Project

The Firebase web API key in `lib/firebase_options.dart` is public by Google's
design — it identifies your project, not your user. **The steps below
must be configured before opening the app to public traffic**, or anyone who
inspects your bundle can hammer your project's quota or impersonate the app.

### 4.1 Restrict Authorized Domains

1. Firebase Console -> **Authentication** -> **Settings** -> **Authorized domains**
2. Remove `localhost` (and any test domain) from the list
3. Add only the production domain you intend to serve from
   (e.g. `app.example.org`)
4. Save

### 4.2 Restrict the Web API Key (HTTP referrers)

1. [Google Cloud Console](https://console.cloud.google.com/) -> select your
   Firebase project
2. **APIs & Services** -> **Credentials**
3. Click the **Browser key (auto created by Firebase)** (or whatever your web
   API key is named)
4. Under **Application restrictions**, choose **HTTP referrers (web sites)**
5. Add referrer entries:
   - `https://app.example.org/*` (your production hosting domain)
   - Add additional entries for each domain you serve from
6. Under **API restrictions**, choose **Restrict key** and select only the
   APIs your app uses: **Firebase Installations API**, **Identity Toolkit
   API**, **Token Service API**, **Cloud Firestore API**
7. Save

> **App Check (optional, not enabled in this build):** This fork does not ship
> or wire up App Check — the `firebase_app_check` package is not a dependency.
> If you want App Check enforcement, add `firebase_app_check` to `pubspec.yaml`
> yourself and follow the
> [Firebase App Check docs](https://firebase.google.com/docs/app-check/flutter/default-providers).

### 4.3 Configure and Restrict the Google Sign-In OAuth Client (if enabled)

Google Sign-In is optional, and the OSS build ships **no** OAuth client id (the
old one was removed for public release). If you enable Google Sign-In:

1. [Google Cloud Console](https://console.cloud.google.com/) -> **APIs &
   Services** -> **Credentials** -> **Create Credentials** -> **OAuth client ID**
   -> **Web application** (or reuse the one Firebase created for your project).
2. Under **Authorized JavaScript origins**, add ONLY your production origin(s)
   (e.g. `https://app.example.org`). Do not leave `localhost` in a production
   client.
3. Provide the client id to the app either through the `google_sign_in` Dart
   configuration, or by adding this tag inside the `<head>` of
   `web/index.html`:
   ```html
   <meta name="google-signin-client_id"
         content="YOUR_ID.apps.googleusercontent.com">
   ```
4. Save. Restricting origins prevents the client id from being used from other
   sites.

If you do not enable Google Sign-In, skip this section — Email/Password auth
needs no OAuth client.

### 4.4 Verify the Lockdown

1. Open your deployed app — sign in and load a Firestore screen. Confirm
   data loads (legitimate path works).
2. Use `curl` against your project's Firestore REST endpoint with a stolen
   API key from a different referrer — it should fail with a `403`
   `requests-from-referer-... are blocked`.

If you skip either of these steps, treat the project as compromised the
moment your repo goes public.

## 5. Deploy Firestore Rules and Indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

The committed `firestore.rules` enforces org-membership boundaries only.
Feature gating happens at the app layer.

## 6. Build and Deploy the Web App

### Option A: Firebase Hosting (easiest)

```bash
npm run flutter:build:web
firebase deploy --only hosting
```

The site is served from `build/web/`.

### Option B: Any Static Host

```bash
npm run flutter:build:web
# Upload the contents of build/web/ to your static host
# (GitHub Pages, Netlify, Cloudflare Pages, S3, etc.)
```

The Flutter web build is fully static (HTML + JS + WASM) and works on any
static host. Firebase Auth and Firestore are reached over the public Firebase
endpoints — no server-side runtime is required.

## 8. Verify the Deployment

1. Open the deployed URL in a browser.
2. Create an account.
3. Create or join an organization.
4. Add a nursery site and a sample coral organism.
5. Confirm data persists across reloads.

If anything fails:

- Check the browser console for Firebase errors.
- Confirm the API key restrictions and authorized domains in step 4 above.
- Confirm Firestore rules deployed successfully
  (`firebase firestore:rules:get` or via the console).

## CI / GitHub Actions

The `.github/workflows/community_web.yaml` workflow runs `flutter analyze` and
builds the web bundle on every push. If you fork the repo and want CI to run
against your own Firebase project, add the relevant `FIREBASE_*` values as
GitHub Actions secrets and adjust the workflow to consume them.

## Upgrading

To pull the latest community release:

```bash
git fetch upstream
git merge upstream/main
flutter pub get
npm install
npm run flutter:build:web
firebase deploy --only hosting
```

Always read the release notes for breaking changes before deploying.

## Support

- **GitHub Issues**: bug reports and feature requests
- **GitHub Discussions**: questions and design discussions
