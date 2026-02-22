# Tour System Documentation

## Overview

The tour system provides a first-time login experience for non-admin users, introducing them to the SeaFoundry platform's critical infrastructure. It displays an interactive overlay with step-by-step guidance through key features.

## Architecture

### Core Components

#### 1. **TourService** (`lib/services/tour_service.dart`)
Central service managing tour state and logic.

**Key Methods**:
- `shouldShowTour(User, {bool organizationExists})` - Determines if tour should be shown
  - Returns `false` for admin users (they complete full onboarding)
  - Returns `false` when organization doesn't exist
  - Returns `true` when tour hasn't been completed OR tour version has changed
- `getTourPath(User)` - Returns tour path based on user role (currently all users get standard tour)
- `createTourCompletionMetadata()` - Creates metadata object to save tour completion

**Tour Version**:
```dart
static const String tourVersion = '1.0.1';
```
Increment this when tour content changes to re-show tour to existing users.

---

#### 2. **TourStep Model** (`lib/models/tour_step.dart`)
Defines individual tour steps with positioning and content.

**Fields**:
- `id` - Unique identifier
- `title` - Step title
- `description` - Step description (can be multi-line)
- `position` - Tooltip position (center, above, below, left, right)
- `targetKey` - Optional GlobalKey for element targeting (future enhancement)

**Standard Tour**:
```dart
CriticalInfrastructureTour.getStandardSteps()
```
Returns 6 steps covering:
1. Navigation breadcrumbs
2. Drawer menu
3. Tank context card (current group/tank status)
4. Action buttons (bottom action bar with FAB fallback)
5. Organization structure (Organization → Sites → Groups → Organisms)
6. Getting help

---

#### 3. **TourCubit** (`lib/cubits/tour/tour_cubit.dart`)
Manages tour state transitions using BLoC pattern.

**States**:
- `TourInitial` - Tour not started
- `TourInProgress` - Tour is running (includes currentStep, currentIndex, totalSteps)
- `TourSkipped` - User skipped tour
- `TourComplete` - Tour finished successfully

**Methods**:
- `startTour()` - Begin tour
- `nextStep()` - Move to next step (completes if on last step)
- `previousStep()` - Move to previous step (no-op if on first step)
- `skipTour()` - Skip tour entirely
- `completeTour()` - Mark tour as complete

**Getters**:
- `currentStep` - Returns current TourStep or null
- `isInProgress` - Returns true if state is TourInProgress

---

#### 4. **TourOverlay** (`lib/widgets/tour/tour_overlay.dart`)
Visual overlay widget displaying tour with spotlight effect.

**Features**:
- **Backdrop**: Semi-transparent dark overlay with optional spotlight hole
- **Tooltip**: Positioned card with title, description, and action buttons
- **Progress Indicator**: "Step X of Y" display
- **Skip Button**: Always accessible in top-right corner
- **Pulse Animation**: Subtle animation around spotlight area
- **Accessibility**: Semantic labels for screen readers

**Props**:
- `currentStep` - Current tour step
- `currentIndex` - Zero-based index of current step
- `totalSteps` - Total number of steps
- `onNext` - Callback for Next button
- `onBack` - Optional callback for Back button
- `onSkip` - Callback for Skip button
- `targetRect` - Optional target rectangle for spotlight

**Positioning Logic**:
- `center` - Centers tooltip regardless of target
- `above/below/left/right` - Positions relative to targetRect (falls back to center if no target)
- Clamps tooltip to screen bounds to prevent off-screen rendering

---

#### 5. **TourWrapper** (`lib/widgets/tour/tour_wrapper.dart`)
Wrapper widget that conditionally shows tour based on user state.

**Responsibilities**:
- Reads `CurrentUser` state
- Calls `TourService.shouldShowTour()` to determine if tour is needed
- Provides `TourCubit` to child widgets
- Listens for tour completion/skip and saves to user metadata
- Wraps `SimpleNavigationWidget` with tour overlay when active

**Tour Completion Save**:
- Uses `UserRepository.updateUserMetadata()` if available
- Falls back to direct Firestore update if repository not in widget tree
- Shows snackbar error message if save fails
- Reloads user to reflect changes only on successful save
- Protected against race conditions with `_isSavingCompletion` flag

---

## Integration

### Router Integration

In `lib/navigation/simple_router.dart`:

```dart
case CurrentUserLoaded():
  return const TourWrapper();
```

Tour only shows after:
1. User is authenticated
2. User data is loaded
3. Organization exists
4. User is not an admin
5. Tour hasn't been completed (or version changed)

---

## User Metadata Schema

Tour completion is tracked in user metadata:

```json
{
  "hasCompletedTour": true,
  "tourVersion": "1.0.1",
  "tourCompletedAt": "2025-11-23T10:30:00.000Z"
}
```

**Fields**:
- `hasCompletedTour` (bool) - True when user has completed any tour
- `tourVersion` (string) - Version of tour that was completed
- `tourCompletedAt` (ISO8601 string) - Timestamp of completion

---

## Testing

### Unit Tests

**TourService** (`test/unit/services/tour_service_test.dart`):
- Should show logic (admin bypass, org requirement, version checking)
- Tour completion metadata creation
- Tour path selection

**TourCubit** (`test/unit/cubits/tour_cubit_test.dart`):
- State transitions (start, next, previous, skip, complete)
- Boundary conditions (first/last step)
- Getters (currentStep, isInProgress)

### Widget Tests

**TourOverlay** (`test/widgets/tour/tour_overlay_test.dart`):
- Rendering of title, description, buttons
- Progress indicator display
- Button callbacks
- Accessibility labels

**TourWrapper** (`test/widgets/tour/tour_wrapper_test.dart`):
- Conditional rendering based on user state
- Admin bypass
- Tour completion tracking

---

## Customization Guide

### Adding New Tour Steps

1. Create new `TourStep` instances:

```dart
TourStep(
  id: 'my-new-step',
  title: 'New Feature',
  description: 'Learn about this new feature...',
  position: TourTooltipPosition.center,
)
```

2. Add to `CriticalInfrastructureTour.getStandardSteps()` or create custom tour:

```dart
static List<TourStep> getCustomSteps() {
  return [
    // ... your steps
  ];
}
```

3. Increment `TourService.tourVersion` to re-show tour to existing users.

---

### Creating Role-Based Tours

Currently, all users get the standard tour. To implement role-based tours:

1. Update `TourService.getTourPath()`:

```dart
static TourPath getTourPath(User user) {
  if (user.metadata?['role'] == 'field-tech') {
    return TourPath.fieldTech;
  }
  // ... other roles
  return TourPath.standard;
}
```

2. Create role-specific step sets:

```dart
class FieldTechTour {
  static List<TourStep> getSteps() {
    return [
      // Field operations focused steps
    ];
  }
}
```

3. Update `TourWrapper` to use appropriate tour based on path.

---

### Adding Element Targeting

To target specific UI elements with spotlight:

1. Add `GlobalKey` to target widget:

```dart
final _myWidgetKey = GlobalKey();

Widget build(BuildContext context) {
  return Container(
    key: _myWidgetKey,
    // ...
  );
}
```

2. Pass key to `TourStep`:

```dart
TourStep(
  id: 'my-step',
  title: 'Special Widget',
  description: 'This is the special widget...',
  position: TourTooltipPosition.above,
  targetKey: _myWidgetKey,
)
```

3. `TourOverlay` will automatically position tooltip and spotlight around target.

---

## Future Enhancements

### Planned Features

1. **Tour Replay** - Allow users to replay tour from settings
2. **Tour Analytics** - Track completion rates, skip rates, step engagement
3. **Context-Aware Tours** - Show tours based on user actions (e.g., first time creating organism)
4. **Video Integration** - Embed tutorial videos in tour steps
5. **Interactive Elements** - Allow users to interact with highlighted elements during tour

### Technical Improvements

1. **Tour Progress Persistence** - Save current step index to allow resuming mid-tour
2. **Tour Scheduling** - Show different tours at different times (onboarding, feature announcements)
3. **A/B Testing** - Test different tour content/flows
4. **Localization** - Multi-language tour support

---

## Troubleshooting

### Tour Not Showing

**Problem**: Tour doesn't appear for non-admin user

**Checklist**:
- Verify user has `isAdmin: false`
- Verify user has `organizationId` populated
- Check user metadata for `hasCompletedTour` flag
- Check user metadata for `tourVersion` (should not match or be missing)
- Verify `CurrentUserLoaded` state is emitted

### Tour Shows Every Login

**Problem**: Tour shows on every login even though completed

**Causes**:
- Tour completion save failed (check logs for errors)
- User metadata not being read correctly
- Tour version mismatch (check if version was incremented)

**Solution**:
- Verify Firestore permissions allow user metadata updates
- Check `UserRepository.updateUserMetadata()` implementation
- Check for error snackbars on tour completion

### Tour Overlay Rendering Issues

**Problem**: Tour overlay doesn't position correctly

**Causes**:
- Target widget not yet rendered when tour starts
- Screen size calculations incorrect
- Tooltip dimensions exceed screen bounds

**Solution**:
- Use `center` position for steps without specific targets
- Add padding to tooltip position calculations
- Test on different screen sizes (mobile, tablet, desktop)

---

## Best Practices

1. **Keep Steps Concise** - Each step should focus on ONE concept
2. **Use Clear Language** - Avoid jargon, explain technical terms
3. **Test on All Platforms** - Ensure tour works on web, mobile, tablet
4. **Accessibility First** - Add semantic labels, support screen readers
5. **Version Carefully** - Only increment version when content significantly changes
6. **Monitor Completion** - Track if users complete or skip tour
7. **Iterate Based on Feedback** - Adjust content based on user behavior

---

## References

- **Tour Models**: `lib/models/tour_step.dart`
- **Tour Service**: `lib/services/tour_service.dart`
- **Tour Cubit**: `lib/cubits/tour/tour_cubit.dart`
- **Tour UI**: `lib/widgets/tour/`
- **Tests**: `test/unit/services/tour_service_test.dart`, `test/unit/cubits/tour_cubit_test.dart`, `test/widgets/tour/`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
