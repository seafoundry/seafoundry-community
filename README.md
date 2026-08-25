# SeaFoundry Community Edition (OSS)

A free, open-source web platform for coral restoration: inventory management,
genetics tracking, outplanting records, and inter-organization transfers.

## Features

- **Coral Inventory**: track coral holdings, fragmentation, and movements across nursery sites.
- **Genetics & Lineage**: manage genets, provenance chains, and fragmentation lineage.
- **Outplanting**: record where and when corals are outplanted to restoration sites.
- **Transfers**: log external transfers (sending/receiving organisms to/from other organizations).
- **Data Portability**: full CSV import/export.

Community Edition is limited to **1 nursery site and 1 outplanting site per
organization**. The codebase is web-only.

## Prerequisites

- Flutter 3.35 or later (Dart 3.8+)
- Node.js 18 or later (for seed scripts)
- Firebase CLI (`npm install -g firebase-tools`)

## Quick Start (Firebase Emulators)

The fastest way to see the app running locally — no cloud account required.

```bash
git clone https://github.com/seafoundry/seafoundry-community.git
cd seafoundry-community
flutter pub get
npm install
./dev-emulator.sh
```

`dev-emulator.sh` starts Firebase Emulators, seeds demo data, and launches the
Flutter web app with `USE_FIREBASE_EMULATOR=true`. The app opens in Chrome.

## Running Against Your Own Firebase Project

```bash
# 1. Create a Firebase project, enable Email/Password Auth and Firestore.
firebase login
firebase use YOUR_PROJECT_ID

# 2. Generate firebase_options.dart for your project:
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID

# 3. Configure environment variables:
cp .env.community.example .env
# Edit .env with the values from Firebase Console > Project Settings > Web app.

# 4. Run the app:
./run.sh
```

Detailed deployment notes (Firebase Hosting, GitHub Pages, and other static
hosts) live
in [`docs/deployment/community_web_deployment.md`](docs/deployment/community_web_deployment.md).

## Architecture

- **Frontend**: Flutter (web)
- **State management**: Cubit (preferred), with BLoC for complex event-driven state
- **Database**: Firebase Firestore
- **Auth**: Firebase Auth (Email / Password, Google Sign-In)
- **Hosting**: Firebase Hosting (or any static host)

This fork runs on the Firebase Spark (free) plan — Firestore, Auth, and Hosting
only. There are no Cloud Functions or Cloud Storage. Feature gating happens at
the app layer; Firestore rules only enforce organization-membership boundaries.

## Contributing

We welcome PRs! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for the
development workflow, code style, and pull-request requirements.

## License

MIT — see [LICENSE](LICENSE).
