# Dialog Components

Shared components and mixins for safe dialog implementation.

## Safety Patterns

All dialogs must be protected from browser back button crashes and async operation issues. Use these patterns:

### SafeDialogMixin (Recommended for StatefulWidget Dialogs)

The unified mixin for all dialog safety features:

```dart
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

class _MyDialogState extends State<MyDialog>
    with SafeDialogMixin<MyDialog> {

  Future<void> _save() async {
    final result = await safeAsyncOperation(() => repository.save(data));
    if (mounted) {
      popDialog(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actions: [
        TextButton(
          onPressed: () => popDialog(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            safeSetState(() => _loading = true);
            await _save();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
```

#### API Reference

| Method/Property | Description |
|-----------------|-------------|
| `dialogNavigator` | Captured NavigatorState for safe async access |
| `dialogMessenger` | Captured ScaffoldMessengerState for safe async access |
| `safeContext` | Returns context if mounted, null otherwise |
| `popDialog([result])` | Safe navigation using captured NavigatorState |
| `safeNavigatePop([result])` | Navigate using context (requires mounted) |
| `safeSetState(fn)` | setState only if mounted |
| `withSafeContext(fn)` | Execute callback only if mounted |
| `withSafeContextAsync(fn)` | Execute async callback if mounted |
| `safeAsyncOperation(fn)` | Async with error handling and logging |
| `showDialogSnackBar(msg)` | Lifecycle-aware snackbar using captured messenger |
| `showSafeSnackBar(msg)` | Snackbar using context (requires mounted) |
| `showSafeDialog(builder)` | Show nested dialog safely |

### SafeDialog PopScope Wrapper

For dialogs needing back button interception:

```dart
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog.dart';

// Basic usage
showDialog(
  context: context,
  builder: (_) => SafeDialog(
    child: AlertDialog(...),
  ),
);

// With back button confirmation
SafeDialog(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) {
    if (didPop) return;
    _showExitConfirmation();
  },
  child: AlertDialog(...),
)

// With async confirmation check
SafeDialog.withAsyncCheck(
  canPopAsync: () async => await _confirmDiscard(),
  child: AlertDialog(...),
)

// Using extension method
context.showSafeDialog(
  builder: (_) => AlertDialog(...),
);
```

### Global Helper Functions (for StatelessWidget Dialogs)

```dart
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

// Pop dialog safely
popSafeDialogContext(context, result);

// Show snackbar safely
showSafeDialogSnackBar(context, 'Message', isError: true);

// Get dialog-aware navigator/messenger
final navigator = safeDialogNavigatorOf(context);
final messenger = safeDialogMessengerOf(context);
```

### ObservationTargetMixin (For Dialogs with Controllers)

For dialogs that manage `ObservationTargetController` instances:

```dart
import 'package:seafoundry_app/widgets/dialogs/components/observation_target_mixin.dart';

class _MyDialogState extends State<MyDialog>
    with SafeDialogMixin<MyDialog>, ObservationTargetMixin<MyDialog> {

  late final _controller = registerTargetController(
    ObservationTargetController(),
  );

  // Controller is automatically cleaned up on dispose
}
```

## Component Reference

| File | Description |
|------|-------------|
| `safe_dialog_mixin.dart` | Unified mixin for dialog lifecycle safety |
| `safe_dialog.dart` | PopScope wrapper for back button protection |
| `observation_target_mixin.dart` | Controller lifecycle management |
| `observation_target_selector.dart` | UI for selecting observation targets |
| `review_commit_ribbon.dart` | Standard save/cancel action ribbon |
| `dialog_message_box.dart` | Styled message box for dialogs |
| `csv_export_preview.dart` | CSV export preview component |
| `csv_import_preview.dart` | CSV import preview component |
| `csv_import_results_panel.dart` | CSV import results display |
| `permit_metadata_section.dart` | Permit metadata form section |
| `geometry_capture_section.dart` | Geometry/location capture UI |

## Related Documentation

- Architecture: `docs/architecture/MANAGEMENT_DIALOG_ARCHITECTURE.md`
- Claude guidelines: `.claude/CLAUDE.md` (Dialog & Screen Safety Patterns section)

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
