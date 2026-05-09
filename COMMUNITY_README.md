# SeaFoundry Community Edition

**Open-source coral restoration inventory tracking for the web.**

*Last Updated: 2026-02-23*

## What is SeaFoundry Community?

SeaFoundry Community is a free, open-source web application for coral restoration practitioners to track nursery inventory, genetics, and outplanting activities.

### What It Does

- **Track Coral Inventory**: Manage corals across nursery sites, structures (racks, trees, tables), and groups
- **Record Genetics**: Track genets and provenance chains
- **Log Fragmentation Events**: Record when corals are fragmented and track lineages
- **Document Outplanting**: Record where and when corals are outplanted to restoration sites
- **Transfer Tracking**: Log external transfers (sending/receiving corals to/from other organizations)
- **Public Holdings Map**: Visualize restoration sites on an interactive map
- **Export Data**: Download inventory data in standardized CSV format

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

SeaFoundry uses a **five-axis canonical inventory model** for tracking corals:

| Axis | Description | Example |
|------|-------------|---------|
| **Taxonomy** | Species identification | *Acropora cervicornis* |
| **Provenance** | Genetic lineage/origin via `ProvenanceType` | Wild, Fragment, Transfer |
| **Location** | Physical location with permit metadata | Site -> Structure -> Position |
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
├── main.dart                    # App entry point
├── app.dart                     # App widget and providers
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

## Community & Support

- **Issues**: [Report bugs](https://github.com/seafoundry/seafoundry-community/issues)
- **Discussions**: [Ask questions](https://github.com/seafoundry/seafoundry-community/discussions)
- **Email**: [community@seafoundry.com](mailto:community@seafoundry.com)

## License

MIT License - See [LICENSE](LICENSE)

You can use, modify, and distribute this software freely. The only requirement is including the original copyright notice.

## About

SeaFoundry Community Edition makes professional coral inventory tracking accessible to restoration organizations of all sizes.
