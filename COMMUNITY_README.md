# SeaFoundry Community Edition

**Open-source marine restoration inventory tracking for the web.**

*Last Updated: 2026-01-13*

## What is SeaFoundry Community?

SeaFoundry Community is a free, open-source web application for marine restoration practitioners to track nursery inventory, genetics, and outplanting activities. It provides a streamlined subset of the full SeaFoundry platform focused on core inventory management.

### What It Does

- **Track Organism Inventory**: Manage organisms across nursery sites, structures (racks, trees, tables, longlines), and groups
- **Record Genetics**: Track genets, cohorts, and provenance chains across generations
- **Log Fragmentation Events**: Record when organisms are fragmented and track lineages
- **Document Outplanting**: Record where and when organisms are outplanted to restoration sites
- **Transfer Tracking**: Log external transfers (sending/receiving organisms to/from other organizations)
- **Export Data**: Download inventory data in standardized CSV format (five-axis format: Taxonomy, Provenance, Location, Life Stage, Measurement)
- **Multi-Species Support**: Works with corals, seagrass, oysters, kelp, mangroves, crustaceans, finfish, and echinoderms

### What It Does NOT Do (Pro Features)

The Community Edition intentionally excludes advanced features to keep the codebase simple and focused:

- **No Mobile Apps**: Web-only (no iOS/Android apps)
- **No Offline Mode**: Requires internet connection
- **No Monitoring/Field Work Kit**: No field monitoring workflows, imagery collection, or growth tracking
- **No Public Holdings Map**: No public-facing map of restoration sites
- **No Demo Mode**: Must create an account to use
- **No Husbandry Workflows**: No health observations, disease tracking, or mortality logging
- **No AI Assistant (Sebastian)**: No AI-powered data assistance
- **No Training/SOPs**: No standard operating procedure management
- **No Push Notifications**: No mobile or web push notifications
- **No Permit Tracking**: No regulatory compliance features

## Quick Start (5 Minutes)

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.24 or later
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- A Google account (for Firebase)

### Option A: Run with Firebase Emulators (Recommended for Testing)

This option runs everything locally - no cloud account needed.

```bash
# 1. Clone the repository
git clone https://github.com/seafoundry/seafoundry-community.git
cd seafoundry-community

# 2. Install Flutter dependencies
flutter pub get

# 3. Start Firebase emulators (in a separate terminal)
firebase emulators:start

# 4. Run the app
flutter run -d chrome
```

The app will open in Chrome. Create an account and start tracking!

### Option B: Run with Your Own Firebase Project

For production use, you'll want your own Firebase project.

```bash
# 1. Clone and install
git clone https://github.com/seafoundry/seafoundry-community.git
cd seafoundry-community
flutter pub get

# 2. Create Firebase project
firebase login
firebase projects:create my-restoration-tracker
firebase use my-restoration-tracker

# 3. Enable services in Firebase Console (https://console.firebase.google.com):
#    - Authentication: Enable Email/Password and Google Sign-In
#    - Firestore Database: Create database in production mode
#    - Cloud Storage: Enable for image uploads

# 4. Configure the app
cp .env.community.example .env
# Edit .env with your Firebase config (from Firebase Console > Project Settings > Web app)

# 5. Deploy security rules
firebase deploy --only firestore:rules,storage

# 6. Run the app
flutter run -d chrome
```

See [docs/COMMUNITY_BUILD.md](docs/COMMUNITY_BUILD.md) for detailed setup and deployment instructions.

## How It Works

### Data Model

SeaFoundry uses a **five-axis canonical inventory model** for tracking organisms:

| Axis | Description | Example |
|------|-------------|---------|
| **Taxonomy** | Species identification via `OrganismKind` + `speciesId` | *Acropora cervicornis*, *Crassostrea virginica* |
| **Provenance** | Genetic lineage/origin via `ProvenanceType` | Wild, Sexual Cohort, Graduated Individual, Transfer |
| **Location** | Physical location with permit metadata | Site → Structure → Position |
| **Life Stage** | Neutral lifecycle stage with optional subtype | Larva, Juvenile, Adult, Fragment |
| **Measurement** | Population quantity + size specification | Count, SizeSpec (XS-XL), measured values |

This model supports all organism types (coral, oyster, kelp, seagrass, mangrove, crustacean, finfish, echinoderm) with organism-specific presets and validation.

### User Flow

1. **Create Account** → Email/password or Google Sign-In
2. **Create/Join Organization** → Set up your restoration org or accept an invitation
3. **Add Sites** → Define your nursery and outplant locations
4. **Add Structures** → Create racks, trees, tables within sites
5. **Add Organisms** → Log individual corals or groups with genetic info
6. **Track Events** → Record fragmentation, moves, outplanting, transfers
7. **Export Data** → Download CSV reports for analysis

### Technology Stack

| Component | Technology |
|-----------|------------|
| Frontend | Flutter 3.24+ (Web) |
| State Management | BLoC Pattern (flutter_bloc) |
| Database | Firebase Firestore |
| Authentication | Firebase Auth (Email, Google) |
| File Storage | Firebase Cloud Storage |
| Hosting | Firebase Hosting (or self-hosted) |

## Deployment Options

### Firebase Hosting (Easiest)
```bash
flutter build web --release
firebase deploy --only hosting
```

### Docker
```bash
flutter build web --release
docker build -t seafoundry-community .
docker run -p 8080:80 seafoundry-community
```

### GitHub Pages / Netlify / Any Static Host
```bash
flutter build web --release
# Upload contents of build/web/ to your host
```

See [docs/COMMUNITY_BUILD.md](docs/COMMUNITY_BUILD.md) for detailed deployment instructions.

## Project Structure

```
lib/
├── community_main.dart          # App entry point
├── community_app.dart           # App widget and providers
├── models/                      # Data models (Organism, Site, Event, etc.)
├── repositories/                # Data access layer (Firestore)
├── cubits/                      # State management (BLoC)
├── screens/                     # UI screens
│   ├── auth/                    # Authentication
│   ├── graph/                   # Inventory navigation
│   ├── onboarding/              # New user setup
│   └── ...
├── widgets/                     # Reusable UI components
├── services/                    # Business logic services
└── navigation/                  # Routing
```

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development setup
- Code style guidelines
- Testing requirements
- Pull request process

## Upgrade Path to Pro

Need advanced features? **SeaFoundry Pro** adds:
- Native iOS/Android apps with offline sync
- Monitoring workflows and field data collection
- Public holdings map for stakeholder visibility
- Husbandry tracking and health observations
- AI-powered data assistant
- Multi-team workspace management
- Priority support

Contact: [contact@seafoundry.com](mailto:contact@seafoundry.com)

## Community & Support

- **Issues**: [Report bugs](https://github.com/seafoundry/seafoundry-community/issues)
- **Discussions**: [Ask questions](https://github.com/seafoundry/seafoundry-community/discussions)
- **Email**: [community@seafoundry.com](mailto:community@seafoundry.com)

## License

MIT License - See [LICENSE](LICENSE)

You can use, modify, and distribute this software freely. The only requirement is including the original copyright notice.

## About

SeaFoundry is built to support coral restoration practitioners worldwide. The Community Edition makes professional inventory tracking accessible to organizations of all sizes.

For the full-featured Pro version, visit [seafoundry.com](https://seafoundry.com).
