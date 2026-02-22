# CI Quality Gates Documentation

## Overview

This document describes the CI/CD quality gates implemented for the Seafoundry application to prevent broken code from merging.

## Workflows

### 1. Main Branch: `ci.yml`
**Triggers:** Push and PR to `main`
**Job:** `analyze-and-test`

**Quality Gates:**
- `flutter analyze --fatal-infos --fatal-warnings` - Fails on ANY issues
- `flutter test --coverage` - All tests must pass
- `dart run tool/bin/tier_check.dart` - Tier manifest compliance
- Timeout: 30 minutes
- Coverage report uploaded as artifact

**Status:** ✅ BLOCKING - Must pass to merge

---

### 2. Pro Branch: `pro_full.yaml`
**Triggers:** Push and PR to `pro`
**Job:** `analyze-and-test`

**Quality Gates:**
- `flutter analyze --fatal-warnings` - Fails on errors and warnings
- `flutter test` - All tests must pass
- `dart run tool/bin/tier_check.dart` - Tier manifest compliance
- Timeout: 30 minutes

**Status:** ✅ BLOCKING - Must pass to merge

---

### 3. Community Branch: `community_web.yaml`
**Triggers:** Push and PR to `community`
**Job:** `build-test-web`

**Quality Gates:**
- `flutter analyze --fatal-warnings` - Fails on errors and warnings
- `flutter test --platform chrome` - All web tests must pass
- `dart run tool/bin/tier_check.dart` - Tier manifest compliance
- `flutter build web` - Must build successfully
- Timeout: 30 minutes

**Status:** ✅ BLOCKING - Must pass to merge

---

### 4. All Branches: `tier_lint.yml`
**Triggers:** All PRs and pushes to main/community/pro/scale
**Job:** `lint-tiers`

**Quality Gates:**
- `dart run tool/bin/tier_check.dart` - Tier manifest compliance
- Timeout: 10 minutes

**Status:** ✅ BLOCKING - Must pass to merge

---

## Branch Protection Setup

To enforce these quality gates, configure the following in **GitHub Repository Settings > Branches > Branch protection rules**:

### For `main` branch:
```
✓ Require status checks to pass before merging
  ✓ Require branches to be up to date before merging
  Required status checks:
    - analyze-and-test (from ci.yml)
    - lint-tiers (from tier_lint.yml)

✓ Require pull request reviews before merging
  - Require 1 approval

✓ Require conversation resolution before merging

✓ Do not allow bypassing the above settings
  (Uncheck "Allow specified actors to bypass required pull requests")
```

### For `pro` branch:
```
✓ Require status checks to pass before merging
  ✓ Require branches to be up to date before merging
  Required status checks:
    - analyze-and-test (from pro_full.yaml)
    - lint-tiers (from tier_lint.yml)

✓ Require pull request reviews before merging
  - Require 1 approval
```

### For `community` branch:
```
✓ Require status checks to pass before merging
  ✓ Require branches to be up to date before merging
  Required status checks:
    - build-test-web (from community_web.yaml)
    - lint-tiers (from tier_lint.yml)

✓ Require pull request reviews before merging
  - Require 1 approval
```

---

## Quality Standards Enforced

### 1. Code Analysis
- **Zero tolerance for errors** - Any analyzer error blocks merge
- **Zero tolerance for warnings** - Any analyzer warning blocks merge
- **Zero tolerance for infos** (main branch only) - Even info-level suggestions block merge

### 2. Testing
- **100% test pass rate** - A single failing test blocks merge
- **Coverage tracking** - Coverage reports generated for main branch
- **Platform-specific testing** - Community branch tests run on Chrome (web)

### 3. Tier Compliance
- **Manifest validation** - All files must have proper `@tier` annotations
- **Cross-tier dependency checks** - Enforced by tier_check.dart

### 4. Build Verification
- **Community branch** - Web builds must complete successfully
- **Timeout protection** - All jobs timeout after 30 minutes max

---

## Developer Workflow

### Before Creating a PR:
```bash
# Run locally to catch issues early
flutter pub get
dart run tool/bin/tier_check.dart
flutter analyze --fatal-warnings
flutter test
```

### If CI Fails:
1. **Analyze failures:** Check the specific step that failed in GitHub Actions
2. **Fix locally:** Run the same command locally to reproduce
3. **Re-test:** Verify fix passes locally before pushing
4. **Push fix:** CI will re-run automatically on push

### Common Failure Scenarios:

| Failure | Command to Reproduce | Typical Fix |
|---------|---------------------|-------------|
| Analyzer errors | `flutter analyze --fatal-warnings` | Fix code issues, add ignores with justification |
| Test failures | `flutter test` | Fix broken tests or code |
| Tier violations | `dart run tool/bin/tier_check.dart` | Add missing `@tier` annotations |
| Build failures | `flutter build web` | Fix compilation errors |

---

## Performance Optimizations

All workflows include:
- **Dependency caching** - Speeds up pub get via `cache: true`
- **Lock file caching** - Uses `${{ hashFiles('**/pubspec.lock') }}`
- **Timeouts** - Prevents hung jobs from consuming runner time
- **Selective triggers** - Only run on relevant branches

---

## Future Enhancements

Consider adding:
- [ ] Coverage thresholds (e.g., require 80% coverage)
- [ ] Performance benchmarking
- [ ] Bundle size checks for web builds
- [ ] Automated security scanning
- [ ] Dependency vulnerability scanning
- [ ] Format checking (`dart format --set-exit-if-changed`)

---

## Troubleshooting

### Workflow not running?
- Check that branch name matches trigger configuration
- Verify workflow file syntax (YAML indentation)
- Check GitHub Actions tab for error messages

### False positives from analyzer?
- Add `// ignore: rule_name` with justification comment
- Consider updating analysis_options.yaml if rule is too strict
- Document decision in PR description

### Tests timing out?
- Increase timeout in workflow file
- Optimize slow tests
- Check for infinite loops or deadlocks

---

## Maintenance

Review and update these workflows:
- **Quarterly** - Check for new Flutter/GitHub Actions versions
- **After major releases** - Verify compatibility with Flutter updates
- **When adding new branches** - Extend tier_lint.yml triggers
- **When test suite grows** - Adjust timeout values

---

## Contact

For questions about CI configuration or quality gates:
- Check `.github/workflows/` for workflow definitions
- Review `analysis_options.yaml` for analyzer rules
- See `tool/bin/tier_check.dart` for tier validation logic
