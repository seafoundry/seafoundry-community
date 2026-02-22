# Dialog Provider Pattern & Architectural Debt - January 2026

**Status**: 🔄 In Progress
**Priority**: P2 — Architecture Improvements
**Labels**: `architecture`, `di`, `dialogs`, `tech-debt`

## Overview

Fixed production errors where dialogs crashed with "Provider not found" due to `showDialog` creating disconnected overlay contexts. This issue tracks the fixes applied and remaining architectural debt.

---

## Completed Fixes

### 1. Dialog Provider Inheritance Fix ✅

**Problem**: `showDialog` creates a new overlay context that doesn't inherit providers from the widget tree. Dialogs using `context.read<SomeProvider>()` crash in production.

**Solution**: Capture providers from calling context BEFORE `showDialog`, then wrap dialog with `MultiRepositoryProvider`/`MultiProvider`.

**Dialogs Fixed**:

| Dialog | Providers Added |
|--------|-----------------|
| `edit_organization_profile_dialog.dart` | ImageService, OrganizationRepository, CurrentUser |
| `funder_edit_dialog.dart` | FunderRepository, Organization, User |
| `permit_edit_dialog.dart` | PermitRepository, Organization, User |
| `mission_edit_dialog.dart` | SiteRepository, UserRepository, VesselRepository, PermitRepository, MissionRepository, User |
| `mission_task_add_dialog.dart` | UserRepository, TaskEventRepository, MissionRepository |

---

### 2. Payment Service Mock Mode Fix ✅

**Problem**: `PaymentService._createDefaultProvider()` defaulted `MOCK_PAYMENTS` to `'true'`, causing production builds to use `MockPaymentProvider`. This made `getCustomerPortalUrl()` return `null`.

**Solution**:
- Debug mode (`kDebugMode`): Always use `MockPaymentProvider`
- Release mode: Default to `StripePaymentProvider`, only use mock if `MOCK_PAYMENTS=true` is explicitly set

---

### 3. Billing Portal Error Handling ✅

**Problem**: Vague error message "Could not generate billing portal URL" when mock mode was active.

**Solution**: Added explicit mock mode check with user-friendly message: "Billing portal is not available in demo mode"

---

## Remaining Architectural Debt

### Task 1: Convert Dialogs from StatefulWidget to Cubit ⏳

**Priority**: Medium
**Effort**: Large

All fixed dialogs use `StatefulWidget` with `setState()`, which violates the project guideline: "DO NOT USE StatefulWidget use BLoC/Cubit."

**Affected Dialogs**:
- `EditOrganizationProfileDialog`
- `FunderEditDialog`
- `PermitEditDialog`
- `MissionEditDialog`
- `MissionTaskAddDialog`

**Recommendation**: Create form-specific Cubits (e.g., `EditOrgProfileCubit`) managing:
- Loading state
- Saving state
- Form field values
- Validation errors

---

### Task 2: Extend DialogBase for Mixed Provider Types ⏳

**Priority**: Low
**Effort**: Medium

The existing `DialogBase.showDialogWithProviders` only accepts `List<RepositoryProvider>`. Many dialogs need a mix of:
- `RepositoryProvider` (for repositories)
- `BlocProvider` (for Cubits)
- `Provider` (for services like ImageService)

**Current Workaround**: Manual nesting of `MultiRepositoryProvider`, `MultiBlocProvider`, and `Provider`.

**Recommendation**: Extend `DialogBase` to accept a `List<SingleChildWidget>` or create a new `MultiTypeDialogBase`.

---

### Task 3: Payment Mode Enum ⏳

**Priority**: Low
**Effort**: Small

Per project guidelines: "ALWAYS use custom enums in place of int or string constants."

**Current Code**:
```dart
const useMock = String.fromEnvironment('MOCK_PAYMENTS', defaultValue: 'false');
if (useMock.toLowerCase() == 'true') { ... }
```

**Recommendation**:
```dart
enum PaymentMode { mock, stripe }

static PaymentMode _determinePaymentMode() {
  if (kDebugMode) return PaymentMode.mock;
  const envMode = String.fromEnvironment('PAYMENT_MODE', defaultValue: 'stripe');
  return PaymentMode.values.firstWhere(
    (m) => m.name == envMode.toLowerCase(),
    orElse: () => PaymentMode.stripe,
  );
}
```

---

### Task 4: Stripe Cloud Functions ⏳

**Priority**: Medium
**Effort**: Large

The `StripePaymentProvider` calls Cloud Functions that don't exist yet:
- `createCheckoutSession`
- `cancelSubscription`
- `createCustomerPortalSession`

These are stub implementations. Full Stripe integration requires:
1. Deploying Cloud Functions
2. Configuring Stripe API keys in Firebase
3. Setting up webhook endpoints

---

## Dialogs Already Correctly Handling Providers

These dialogs were found to already implement the correct pattern:
- `health_status_dialog.dart`
- `outplant_action_event_dialog.dart`
- `monitoring_dialog.dart`
- `asexual_propagation_dialog.dart`
- `bulk_update_dialog.dart`
- `event_overview_dialog.dart`
- `location_selection_dialog.dart`
- `training_media_management_dialog.dart`

---

## Related Files

- `lib/widgets/dialogs/base/dialog_base.dart` - Existing base class for dialogs
- `lib/services/payment_service.dart` - Payment provider selection
- `lib/services/payment/stripe_payment_provider.dart` - Stripe integration stub
- `lib/services/payment/mock_payment_provider.dart` - Mock payment provider

---

## Testing Checklist

- [ ] Open EditOrganizationProfileDialog and save changes
- [ ] Open FunderEditDialog and create/edit a funder
- [ ] Open PermitEditDialog and create/edit a permit
- [ ] Open MissionEditDialog and create/edit a mission
- [ ] Open MissionTaskAddDialog and create a task
- [ ] Click "Manage Subscription" in Organization Settings (should show appropriate message)
- [ ] Verify no "Provider not found" errors in production builds
