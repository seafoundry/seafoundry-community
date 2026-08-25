# Contributing to SeaFoundry Community

Thank you for your interest in contributing! This guide covers the workflow,
style conventions, and PR requirements specific to this repository.

## Table of Contents
1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Workflow](#development-workflow)
4. [Code Style Guide](#code-style-guide)
5. [Pull Request Process](#pull-request-process)
6. [Communication](#communication)

## Code of Conduct

We are committed to a welcoming and inclusive environment for all contributors.

**Expected behavior**: Be respectful and considerate; offer constructive
feedback; accept constructive criticism gracefully; show empathy.

**Unacceptable behavior**: Harassment, discrimination, personal attacks,
publishing others' private information.

If you experience or witness unacceptable behavior, please report it to the
maintainers through the repository's issue tracker (use a private security
advisory for sensitive reports).

## Getting Started

### Prerequisites
- Flutter 3.35 or later (Dart 3.8+)
- Node.js 18+ (for seed scripts)
- Firebase CLI (`npm install -g firebase-tools`)

### Fork and Clone
```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/seafoundry-community.git
cd seafoundry-community
git remote add upstream https://github.com/seafoundry/seafoundry-community.git
```

### Set Up Local Dev (Emulator path)
```bash
# Bootstrap env and start emulators + seed demo + run app:
./dev-emulator.sh
```

See [COMMUNITY_README.md](COMMUNITY_README.md) for the alternate
"use your own Firebase project" path.

## Development Workflow

### 1. Create a Branch
```bash
git checkout main
git pull upstream main
git checkout -b feature/your-feature-name
```

### 2. Make Changes
- Follow the [style guide](#code-style-guide)
- Update affected docs in the same PR
- Commit frequently with clear messages

### 3. Commit Messages
Conventional-commit format:
```
type(scope): description
```

**Types**: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`

Examples:
```
feat(auth): add Google Sign-In support
fix(inventory): correct genet ID resolution
docs(readme): document emulator setup
```

### 4. Bump the version (required for every PR)

Increment the build number in `pubspec.yaml` before opening a PR:

```yaml
version: 1.1.1+14   # +N → +N+1 for every PR
```

- Build number `+N`: increment for every PR (required)
- Patch `x.x.N`: increment for bug fixes
- Minor `x.N.x`: increment for new features (reset patch)
- Major `N.x.x`: increment for breaking changes (reset minor and patch)

### 5. Pre-PR Checks
```bash
flutter analyze
flutter build web --release
dart format lib/ -l 120
```

There is currently no automated test suite (no `test/` directory). When you add
testable logic, add tests under `test/` and run them with `flutter test`.

## Code Style Guide

### Dart/Flutter Conventions

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart).
- Prefer composition over inheritance; small, focused functions; meaningful names.
- Comment the *why*, not the *what*.

### File Organization
```
lib/
  cubits/          # State management — Cubit is the standard here
  models/          # Data models
  repositories/    # Firestore data access
  services/        # Business logic
  widgets/         # Reusable UI components
  screens/         # Top-level screens
  theme/           # Theme and styling
  navigation/      # Routing
  utils/           # Utility helpers
```

### Naming Conventions
- Classes / enums / typedefs: `PascalCase`
- Files and directories: `snake_case`
- Variables and functions: `camelCase`
- Private members: `_leadingUnderscore`

Inside the codebase, **map keys, Firestore field names, and serialized data
must use camelCase** — this is a hard rule throughout the codebase.

### Formatting
- Line length: 120 characters
- Trailing commas in multi-line collections and parameter lists
- Run `dart format lib/ -l 120` before committing

### Documentation Comments
```dart
/// Brief description of class/function.
///
/// Add detail when behavior is non-obvious (constraints, invariants, edge cases).
class OrganismRecord {
  final String id;
  OrganismRecord({required this.id});
}
```

### State Management (Cubit-preferred)
```dart
class MyFeatureCubit extends Cubit<MyFeatureState> {
  MyFeatureCubit() : super(MyFeatureInitial());

  Future<void> loadData() async {
    emit(MyFeatureLoading());
    try {
      final data = await repository.fetchData();
      emit(MyFeatureLoaded(data));
    } catch (e) {
      emit(MyFeatureError(e.toString()));
    }
  }
}
```

Use a full BLoC (`Bloc<Event, State>`) when state transitions are
event-driven and complex enough to benefit from explicit events.

## Pull Request Process

### Before Submitting

1. **Update your branch**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```
2. **Bump `pubspec.yaml` build number** (required).
3. **Pass checks locally**:
   ```bash
   flutter analyze
   flutter build web --release
   ```

### Creating the PR
- Push to your fork
- Open a PR against `main`
- Use a clear title; link related issues
- Add screenshots for UI changes

### PR Description Template
```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Documentation

## Manual verification
What you did to confirm the change works.

## Checklist
- [ ] `pubspec.yaml` build number incremented
- [ ] `flutter analyze` passes
- [ ] Affected docs updated
```

### Review Process
1. Maintainers review the PR
2. Push new commits to address feedback
3. Once approved, a maintainer merges

## Communication

- **Issues**: bug reports and feature requests
- **Discussions**: open questions, ideas, design discussions
- **Pull Requests**: code contributions

Thank you for contributing to SeaFoundry Community!
