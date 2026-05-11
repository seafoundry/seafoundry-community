# Contributing to SeaFoundry Community

Thank you for your interest in contributing to SeaFoundry Community! This document provides guidelines and workflows for contributing to the project.

## Table of Contents
1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Workflow](#development-workflow)
4. [Code Style Guide](#code-style-guide)
5. [Testing Guidelines](#testing-guidelines)
6. [Pull Request Process](#pull-request-process)
7. [Communication Channels](#communication-channels)

## Code of Conduct

### Our Pledge
We are committed to providing a welcoming and inclusive environment for all contributors, regardless of background or experience level.

### Expected Behavior
- Be respectful and considerate in all interactions
- Provide constructive feedback
- Accept constructive criticism gracefully
- Focus on what is best for the community and project
- Show empathy towards other community members

### Unacceptable Behavior
- Harassment, discrimination, or offensive comments
- Personal attacks or trolling
- Publishing others' private information
- Other conduct which could reasonably be considered inappropriate

### Reporting
If you experience or witness unacceptable behavior, please contact the project maintainers at [conduct@seafoundry.com](mailto:conduct@seafoundry.com).

## Getting Started

### Prerequisites
Before contributing, ensure you have:
- Flutter 3.x or later (tested with 3.24+) installed
- Git configured with your name and email
- GitHub account
- Read the [Build Guide](docs/COMMUNITY_BUILD.md)

### Fork and Clone
```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/seafoundry-community.git
cd seafoundry-community

# Add upstream remote
git remote add upstream https://github.com/seafoundry/seafoundry-community.git
```

### Setup Development Environment
```bash
# Install dependencies
flutter pub get

# Verify setup
flutter doctor -v

# Start Firebase emulators
firebase emulators:start

# Run app in development
flutter run -d chrome
```

## Development Workflow

### 1. Create a Branch
```bash
# Update your fork
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/issue-description
```

### 2. Make Changes
- Write code following our [style guide](#code-style-guide)
- Add tests for new functionality
- Update documentation as needed
- Commit frequently with clear messages

### 3. Commit Messages
Follow the conventional commit format:
```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `docs`: Documentation changes
- `chore`: Maintenance tasks
- `style`: Code formatting (not visual style)

**Examples:**
```bash
feat(auth): add Google Sign-In support
fix(monitoring): resolve date picker timezone issue
refactor(coral): extract Coral model to OrganismRecord
test(nursery): add unit tests for NurseryCubit
docs(readme): update installation instructions
```

### 4. Keep Your Branch Updated
```bash
# Regularly sync with upstream
git fetch upstream
git rebase upstream/main

# Resolve conflicts if any
# Then continue
git rebase --continue
```

### 5. Run Tests and Checks
```bash
# Run all tests
flutter test

# Run analyzer
flutter analyze

# Format code
dart format lib/ test/ -l 120

# Verify build
flutter build web --release
```

## Code Style Guide

### Dart/Flutter Conventions

#### General Principles
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Prefer composition over inheritance
- Keep functions small and focused
- Use meaningful variable names
- Comment complex logic, not obvious code

#### File Organization
```
lib/
  models/          # Data models
  cubits/          # State management (BLoC pattern)
  blocs/           # Complex state management
  repositories/    # Data access layer
  services/        # Business logic
  widgets/         # Reusable UI components
  screens/         # Full-screen views
  theme/           # Theme and styling
  utils/           # Utility functions
  navigation/      # Routing
```

#### Naming Conventions
```dart
// Classes: PascalCase
class OrganismRecord {}
class CoralManagementCubit {}

// Files: snake_case
// coral_model.dart
// organism_repository.dart

// Variables/functions: camelCase
String coralId = 'abc123';
void fetchOrganisms() {}

// Constants: lowerCamelCase
const double maxDepth = 100.0;

// Private members: _leadingUnderscore
String _privateField;
void _privateMethod() {}
```

#### Code Formatting
```dart
// Line length: 120 characters max
dart format lib/ test/ -l 120

// Trailing commas for better diffs
Widget build(BuildContext context) {
  return Container(
    padding: EdgeInsets.all(16),
    child: Text('Hello'),  // <- trailing comma
  );
}

// Avoid deep nesting - extract methods
Widget _buildComplexWidget() {
  return Column(
    children: [
      _buildHeader(),
      _buildContent(),
      _buildFooter(),
    ],
  );
}
```

#### Documentation
```dart
/// Brief description of class/function.
///
/// More detailed explanation if needed.
/// Can span multiple lines.
///
/// Example:
/// ```dart
/// final organism = OrganismRecord(id: '123');
/// ```
class OrganismRecord {
  /// The unique identifier for this organism.
  final String id;

  /// Creates an [OrganismRecord] with the given [id].
  OrganismRecord({required this.id});
}
```

### BLoC Pattern Guidelines
```dart
// Cubit for simple state
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

// Bloc for complex event-driven state
class MyComplexBloc extends Bloc<MyEvent, MyState> {
  MyComplexBloc() : super(MyInitialState()) {
    on<EventOne>(_handleEventOne);
    on<EventTwo>(_handleEventTwo);
  }

  Future<void> _handleEventOne(EventOne event, Emitter<MyState> emit) async {
    // Handle event
  }
}
```

### Widget Organization
```dart
class MyWidget extends StatelessWidget {
  // 1. Constructor and fields
  final String title;
  final VoidCallback? onTap;

  const MyWidget({
    super.key,
    required this.title,
    this.onTap,
  });

  // 2. Build method
  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  // 3. Private build methods
  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildBody(),
      ],
    );
  }

  Widget _buildHeader() {
    return Text(title);
  }

  Widget _buildBody() {
    return Container();
  }
}
```

## Testing Guidelines

### Test Structure
```
test/
  unit/           # Unit tests for models, utilities
  widget/         # Widget tests
  blocs/          # BLoC/Cubit tests
  integration/    # End-to-end tests
```

### Unit Tests
```dart
// test/unit/models/organism_test.dart
void main() {
  group('OrganismRecord', () {
    test('should create organism with required fields', () {
      final organism = OrganismRecord(
        id: '123',
        taxonomy: TaxonomyRecord(scientificName: 'Acropora cervicornis'),
      );

      expect(organism.id, '123');
      expect(organism.taxonomy.scientificName, 'Acropora cervicornis');
    });

    test('should serialize to JSON correctly', () {
      final organism = OrganismRecord(id: '123');
      final json = organism.toJson();

      expect(json['id'], '123');
    });
  });
}
```

### Widget Tests
```dart
void main() {
  testWidgets('MyWidget displays title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyWidget(title: 'Test Title'),
      ),
    );

    expect(find.text('Test Title'), findsOneWidget);
  });
}
```

### BLoC Tests
```dart
blocTest<MyFeatureCubit, MyFeatureState>(
  'emits [Loading, Loaded] when loadData succeeds',
  build: () => MyFeatureCubit(),
  act: (cubit) => cubit.loadData(),
  expect: () => [
    MyFeatureLoading(),
    isA<MyFeatureLoaded>(),
  ],
);
```

### Test Coverage
- Aim for >80% coverage on critical paths
- Test edge cases and error conditions
- Mock external dependencies (Firebase, etc.)

```bash
# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Pull Request Process

### Before Submitting
1. **Update your branch**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run all checks**:
   ```bash
   flutter test
   flutter analyze
   dart format lib/ test/ -l 120
   ```

3. **Build successfully**:
   ```bash
   flutter build web --release
   ```

4. **Update documentation** if needed

### Creating the PR

1. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Open PR on GitHub**:
   - Use a clear, descriptive title
   - Follow the PR template
   - Link related issues
   - Add screenshots for UI changes

3. **PR Description Template**:
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Refactoring
   - [ ] Documentation

   ## Testing
   - [ ] Unit tests added/updated
   - [ ] Widget tests added/updated
   - [ ] Tested manually

   ## Screenshots (if applicable)

   ## Checklist
   - [ ] Code follows style guide
   - [ ] Tests pass
   - [ ] Documentation updated
   - [ ] No analyzer warnings
   ```

### Review Process
1. Maintainers will review your PR
2. Address feedback by pushing new commits
3. Once approved, maintainers will merge

### After Merge
```bash
# Update your main branch
git checkout main
git pull upstream main

# Delete feature branch
git branch -d feature/your-feature-name
git push origin --delete feature/your-feature-name
```

## Communication Channels

### GitHub
- **Issues**: Bug reports and feature requests
- **Discussions**: Questions, ideas, and general discussion
- **Pull Requests**: Code contributions

### Email
- General: [community@seafoundry.com](mailto:community@seafoundry.com)
- Security: [security@seafoundry.com](mailto:security@seafoundry.com)

### Guidelines for Issues

#### Bug Reports
```markdown
**Describe the bug**
Clear description of the issue

**To Reproduce**
1. Go to '...'
2. Click on '...'
3. See error

**Expected behavior**
What should happen

**Screenshots**
If applicable

**Environment:**
- Flutter version:
- Browser:
- OS:
```

#### Feature Requests
```markdown
**Problem Statement**
What problem does this solve?

**Proposed Solution**
How would you solve it?

**Alternatives Considered**
Other approaches you've thought about

**Additional Context**
Any other relevant information
```

## Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes for significant contributions
- Project README (for major features)

## Questions?

Don't hesitate to ask questions! We're here to help:
- Open a discussion on GitHub
- Email [community@seafoundry.com](mailto:community@seafoundry.com)

Thank you for contributing to SeaFoundry Community!
