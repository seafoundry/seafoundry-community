# SeaFoundry Community Edition

**Open-source coral restoration inventory tracking for the web.**

## What is SeaFoundry Community?

SeaFoundry Community is a free, open-source web application for coral
restoration practitioners to track nursery inventory, genetics, and
outplanting activities.

### What It Does

- **Track Coral Inventory**: Manage corals across nursery sites, structures (racks, trees, tables), and groups
- **Record Genetics**: Track genets and provenance chains
- **Log Fragmentation Events**: Record when corals are fragmented and track lineages
- **Document Outplanting**: Record where and when corals are outplanted to restoration sites
- **Transfer Tracking**: Log external transfers (sending/receiving corals to/from other organizations)
- **Export Data**: Download inventory data in standardized CSV format

## Quick Start

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.35 or later (Dart 3.8+)
- [Firebase CLI](https://firebase.google.com/docs/cli) — `npm install -g firebase-tools`
- Node.js 18 or later
- A Google account (only required for Option B)

The Community Edition runs entirely on the **free Firebase Spark plan** —
Firestore + Auth + Hosting only. There is no Cloud Functions or Cloud Storage
requirement, so the project never needs a billing account attached. Image
uploads (organism photos, brand logos) are out of scope; the app stores image
URLs only and expects you to host any images elsewhere.

### Option A: Run with Firebase Emulators (Recommended)

Everything runs locally — no Firebase cloud account needed.

```bash
# 1. Clone the repository
git clone https://github.com/seafoundry/seafoundry-community.git
cd seafoundry-community

# 2. Install dependencies
flutter pub get
npm install

# 3. Start emulators, seed demo data, and run the app:
./dev-emulator.sh
```

The app opens in Chrome at http://localhost:port (Flutter prints the URL).
Sign in with the demo user printed in the seed output, or create your own.

### Option B: Run with Your Own Firebase Project

For production use you'll want your own Firebase project.

```bash
# 1. Clone and install
git clone https://github.com/seafoundry/seafoundry-community.git
cd seafoundry-community
flutter pub get
npm install

# 2. Create a Firebase project and enable services in the Firebase Console:
#    - Authentication: Email/Password (and Google Sign-In if desired)
#    - Firestore Database (production mode)
firebase login
firebase use YOUR_PROJECT_ID

# 3. Regenerate firebase_options.dart for YOUR project:
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID

# 4. Configure environment variables:
cp .env.community.example .env
# Edit .env with values from Firebase Console > Project Settings > Web app.

# 5. Deploy Firestore rules and indexes:
firebase deploy --only firestore:rules,firestore:indexes

# 6. Run the app (run.sh generates dart_defines.json from .env):
./run.sh
```

> **Note**: `flutter run -d chrome` alone will not pick up your `.env` —
> always use `./run.sh` so `dart_defines.json` is generated first.

See [docs/deployment/community_web_deployment.md](docs/deployment/community_web_deployment.md)
for full deployment instructions (Firebase Hosting and static hosts).

## How It Works

### Data Model

SeaFoundry uses a **five-axis canonical inventory model** for tracking corals:

| Axis | Description | Example |
|------|-------------|---------|
| **Taxonomy** | Species identification | *Acropora cervicornis* |
| **Provenance** | Genetic lineage/origin via `ProvenanceType` | Wild, Fragment, Transfer |
| **Location** | Physical location and structure context | Site -> Structure -> Position |
| **Life Stage** | Lifecycle stage | Larva, Juvenile, Adult, Fragment |
| **Measurement** | Population quantity + size specification | Count, SizeSpec (XS-XL) |

### User Flow

1. **Create Account** -> Email/password or Google Sign-In
2. **Create/Join Organization** -> Set up your restoration org or accept an invitation
3. **Add Sites** -> Define your nursery and outplant locations
4. **Add Structures** -> Create racks, trees, tables within sites
5. **Add Organisms** -> Log individual corals or groups with genetic info
6. **Track Events** -> Record fragmentation, moves, outplanting, transfers
7. **Export Data** -> Download CSV reports for analysis

### Technology Stack

| Component | Technology |
|-----------|------------|
| Frontend | Flutter 3.35+ (Web) |
| State Management | Cubit (preferred); BLoC (flutter_bloc) for complex flows |
| Database | Firebase Firestore |
| Authentication | Firebase Auth (Email, Google) |
| Hosting | Firebase Hosting (or any static host) |

## Site Limits

Community Edition supports **1 nursery site** and **1 outplanting site** per
organization. This limit is enforced at the app layer.

## Deployment Options

### Firebase Hosting
```bash
flutter build web --release
firebase deploy --only hosting
```

### Any Static Host (GitHub Pages, Netlify, etc.)
```bash
flutter build web --release
# Upload contents of build/web/ to your host
```

See [docs/deployment/community_web_deployment.md](docs/deployment/community_web_deployment.md)
for detailed deployment instructions.

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── app.dart                     # App widget and providers
├── models/                      # Data models (Organism, Site, Event, etc.)
├── repositories/                # Data access layer (Firestore)
├── cubits/                      # State management (preferred)
├── blocs/                       # Complex event-driven state
├── screens/                     # Top-level screens
│   ├── auth/                    # Authentication
│   ├── graph/                   # Inventory navigation
│   ├── onboarding/              # New user setup
│   └── ...
├── widgets/                     # Reusable UI components
├── services/                    # Business logic services
├── navigation/                  # Routing
└── theme/                       # Theme and styling
```

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development setup
- Code style guidelines
- Pull request process

## Community & Support

- **Issues**: [Report bugs](https://github.com/seafoundry/seafoundry-community/issues)
- **Discussions**: [Ask questions](https://github.com/seafoundry/seafoundry-community/discussions)

## License

MIT License — see [LICENSE](LICENSE).

## About

SeaFoundry Community Edition makes professional coral inventory tracking
accessible to restoration organizations of all sizes.
