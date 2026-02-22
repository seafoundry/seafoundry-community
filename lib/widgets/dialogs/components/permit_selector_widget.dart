// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/permits/permit.dart';
import 'package:seafoundry_app/repositories/permit_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/theme/app_colors.dart';
import '../../notifications/toast_overlay.dart';

/// Callback for handling permit creation requests.
///
/// Called when user taps "Add Permit" in the selector.
/// Should show the permit creation dialog and return the created permit,
/// or null if cancelled.
typedef PermitCreationCallback = Future<Permit?> Function(
  BuildContext context,
  String organizationId,
  String userId,
);

/// Display configuration for [PermitSelectorWidget].
///
/// Groups visual customization options with sensible defaults.
/// Most callers can use [PermitSelectorDisplayOptions.standard] or
/// [PermitSelectorDisplayOptions.compact].
class PermitSelectorDisplayOptions {
  const PermitSelectorDisplayOptions({
    this.labelText = 'Permit',
    this.noneOptionText = 'No Permit Required',
    this.showValidityDates = true,
    this.showLabel = true,
    this.showOptionalSuffix = true,
    this.expiringThresholdDays = Permit.defaultExpiringThresholdDays,
  });

  /// Standard display with all features visible.
  static const standard = PermitSelectorDisplayOptions();

  /// Compact display without label (for use in sections with existing headers).
  static const compact = PermitSelectorDisplayOptions(
    showLabel: false,
    showOptionalSuffix: false,
  );

  /// Minimal display showing only permit names.
  static const minimal = PermitSelectorDisplayOptions(
    showLabel: false,
    showValidityDates: false,
    showOptionalSuffix: false,
  );

  /// Label for the dropdown.
  final String labelText;

  /// Text for the "no permit" option.
  final String noneOptionText;

  /// Whether to show validity dates in dropdown items.
  final bool showValidityDates;

  /// Whether to show the label above the dropdown (set false if parent
  /// already provides a section header).
  final bool showLabel;

  /// Whether to append "(Optional)" to the label.
  final bool showOptionalSuffix;

  /// Number of days before expiration to show "Expiring" warning chip.
  /// Defaults to [Permit.defaultExpiringThresholdDays] (90 days).
  final int expiringThresholdDays;
}

/// Sentinel value for "Add Permit..." dropdown option.
const String _addPermitValue = '__add_permit__';

/// A self-contained permit selector widget that loads and displays permits
/// from the organization's PermitRepository.
///
/// This widget handles its own loading state and can be dropped into any
/// dialog without requiring changes to the parent bloc/cubit.
///
/// ## User ID for Permit Creation
///
/// The [userId] parameter is required for permit creation via the "Add Permit"
/// option. If not provided, the widget attempts to read it from [CurrentUser]
/// in context. If neither is available, the "Add Permit" option will show an
/// error when tapped.
///
/// For best results, capture and provide [userId] when constructing this widget,
/// especially in dialog contexts where [CurrentUser] may not be available.
///
/// Usage:
/// ```dart
/// PermitSelectorWidget(
///   organizationId: orgId,
///   userId: userId, // Recommended for permit creation support
///   selectedPermitId: state.selectedPermitId,
///   onPermitSelected: (permit) {
///     // Update state with permit data
///     bloc.add(PermitChanged(permit));
///   },
///   enabled: !isSubmitting,
///   isPro: true, // Enable permit creation
/// )
/// ```
class PermitSelectorWidget extends StatefulWidget {
  const PermitSelectorWidget({
    super.key,
    required this.organizationId,
    this.userId,
    this.selectedPermitId,
    required this.onPermitSelected,
    this.enabled = true,
    this.displayOptions = PermitSelectorDisplayOptions.standard,
    this.preloadedPermits,
    this.isPro = false,
    this.showAddPermitOption = true,
    this.onPermitCreated,
    this.onAddPermitRequested,
  });

  /// The organization ID to load permits for
  final String organizationId;

  /// The user ID for permit creation. If not provided, falls back to reading
  /// from [CurrentUser] in context. If neither is available, the "Add Permit"
  /// option will show an error when tapped.
  final String? userId;

  /// Currently selected permit ID
  final String? selectedPermitId;

  /// Callback when a permit is selected (null means no permit)
  final void Function(Permit? permit) onPermitSelected;

  /// Whether the dropdown is enabled
  final bool enabled;

  /// Display configuration options for the widget.
  final PermitSelectorDisplayOptions displayOptions;

  /// Optional pre-loaded permits list. If provided, the widget will use these
  /// permits directly instead of loading from the repository. This is useful
  /// when the parent already has permits loaded (e.g., from bloc state).
  final List<Permit>? preloadedPermits;

  /// Whether the user has Pro tier access. Permits are a Pro feature.
  /// When false, the "Add Permit..." option is disabled with a hint.
  final bool isPro;

  /// Whether to show the "Add Permit..." option in the dropdown.
  final bool showAddPermitOption;

  /// Optional callback when a new permit is created. If not provided,
  /// the widget will refresh its own permits list after creation.
  final void Function(Permit permit)? onPermitCreated;

  /// Callback to handle permit creation. Required for "Add Permit" functionality.
  ///
  /// When provided (along with [isPro] = true), the "Add Permit" option
  /// becomes functional. When tapped, this callback is invoked to show the
  /// permit creation dialog. The callback should return the created permit,
  /// or null if cancelled.
  ///
  /// This callback pattern allows the community-tier widget to support
  /// permit creation without importing pro-tier dialog code directly.
  final PermitCreationCallback? onAddPermitRequested;

  @override
  State<PermitSelectorWidget> createState() => _PermitSelectorWidgetState();
}

class _PermitSelectorWidgetState extends State<PermitSelectorWidget> {
  List<Permit>? _permits;
  bool _isLoading = true;
  String? _error;
  PermitRepository? _permitRepo;
  bool _hasLoadedPermits = false;

  /// Version counter to guard against race conditions in concurrent _loadPermits
  /// calls. Each call captures the current version; if a newer load started
  /// before the async operation completed, the stale result is discarded.
  int _loadVersion = 0;

  /// Returns the effective permits list, preferring preloaded permits
  List<Permit>? get _effectivePermits => widget.preloadedPermits ?? _permits;

  /// Whether the "Add Permit" functionality is available.
  /// Requires: showAddPermitOption, isPro, and onAddPermitRequested callback.
  bool get _canAddPermit =>
      widget.showAddPermitOption &&
      widget.isPro &&
      widget.onAddPermitRequested != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely read repository in didChangeDependencies instead of initState
    _permitRepo ??= context.read<PermitRepository?>();
    if (!_hasLoadedPermits) {
      _hasLoadedPermits = true;
      _loadPermits();
    }
  }

  @override
  void didUpdateWidget(covariant PermitSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId ||
        oldWidget.preloadedPermits != widget.preloadedPermits) {
      _loadPermits();
    }
  }

  Future<void> _loadPermits() async {
    // Increment version to invalidate any in-flight async operations
    final currentVersion = ++_loadVersion;

    // If preloaded permits are provided, use them directly
    if (widget.preloadedPermits != null) {
      if (mounted && _loadVersion == currentVersion) {
        setState(() {
          _permits = widget.preloadedPermits;
          _isLoading = false;
          _error = null;
        });
      }
      LoggingService.instance.debug(
        'PermitSelectorWidget: Using ${widget.preloadedPermits!.length} '
        'preloaded permits',
      );
      return;
    }

    if (widget.organizationId.isEmpty) {
      if (mounted && _loadVersion == currentVersion) {
        setState(() {
          _isLoading = false;
          _permits = [];
        });
      }
      return;
    }

    if (_permitRepo == null) {
      LoggingService.instance.debug(
        'PermitSelectorWidget: PermitRepository not available in context, '
        'permits are optional',
      );
      // Gracefully degrade - permits are optional, so don't show error
      if (mounted && _loadVersion == currentVersion) {
        setState(() {
          _isLoading = false;
          _permits = [];
          // Don't set _error - just show empty state which is non-blocking
        });
      }
      return;
    }

    if (mounted && _loadVersion == currentVersion) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final permits = await _permitRepo!.getActivePermits(
        widget.organizationId,
      );
      // Guard: only apply results if this is still the latest load operation
      if (mounted && _loadVersion == currentVersion) {
        setState(() {
          _permits = permits;
          _isLoading = false;
        });
        LoggingService.instance.debug(
          'PermitSelectorWidget: Loaded ${permits.length} permits',
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'PermitSelectorWidget: Failed to load permits',
        e,
        stackTrace,
      );
      // Guard: only apply error state if this is still the latest load operation
      if (mounted && _loadVersion == currentVersion) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load permits';
          _permits = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permits = _effectivePermits;

    if (_isLoading && widget.preloadedPermits == null) {
      return _buildLoadingState();
    }

    if (_error != null && widget.preloadedPermits == null) {
      return _buildErrorState();
    }

    if (permits == null || permits.isEmpty) {
      return _buildEmptyState();
    }

    return _buildDropdown(permits);
  }

  Widget _buildLoadingState() {
    return _wrapWithLabel(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading permits...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return _wrapWithLabel(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(4),
          color: Theme.of(context).colorScheme.errorContainer,
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 20,
              color: Theme.of(context).colorScheme.error,
              semanticLabel: 'Error',
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_error!)),
            TextButton(onPressed: _loadPermits, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final canAddPermit = _canAddPermit;

    return _wrapWithLabel(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  semanticLabel: 'Information',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    canAddPermit
                        ? 'No permits configured. Add a permit to track compliance.'
                        : 'No permits available. You can continue without selecting a permit.',
                  ),
                ),
              ],
            ),
            if (widget.showAddPermitOption) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: canAddPermit && widget.enabled
                    ? () => _showAddPermitDialog()
                    : null,
                icon: Icon(
                  Icons.add,
                  size: 18,
                  color: canAddPermit
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38),
                  semanticLabel: 'Add permit',
                ),
                label: Text(
                  canAddPermit ? 'Add Permit...' : 'Add Permit (Pro)',
                  style: TextStyle(
                    color: canAddPermit
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.38),
                  ),
                ),
              ),
              if (!widget.isPro) ...[
                const SizedBox(height: 4),
                Text(
                  'Permits require a Pro subscription.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _wrapWithLabel({required Widget child}) {
    final options = widget.displayOptions;
    if (!options.showLabel || options.labelText.isEmpty) {
      return child;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          options.labelText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDropdown(List<Permit> permits) {
    final options = widget.displayOptions;
    final dateFormat = DateFormat('MMM d, yyyy');
    final expiringThreshold = Duration(days: options.expiringThresholdDays);
    final theme = Theme.of(context);
    final selectedPermitId = _resolveSelectedPermitId(permits);

    final computedLabel = options.showLabel
        ? (options.showOptionalSuffix
              ? '${options.labelText} (Optional)'
              : options.labelText)
        : null;

    return DropdownButtonFormField<String?>(
      key: ValueKey(selectedPermitId),
      initialValue: selectedPermitId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: computedLabel,
        border: const OutlineInputBorder(),
        hintText: 'Select a permit',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      selectedItemBuilder: (context) {
        // Custom builder for selected item to prevent overflow
        return [
          // "No permit" option
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              options.noneOptionText,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Permit options - show condensed version when selected
          ...permits.map((permit) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${permit.permitNumber} - ${permit.name}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          // "Add Permit..." option (should never be shown as selected)
          if (widget.showAddPermitOption)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add Permit...',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
        ];
      },
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            options.noneOptionText,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        ...permits.map((permit) {
          // Use configurable threshold for "expiring soon" warning
          final isExpiringSoon = permit.isExpiringWithin(expiringThreshold);

          return DropdownMenuItem<String?>(
            value: permit.id,
            enabled: !permit.isExpired, // Disable selection of expired permits
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Opacity(
                opacity: permit.isExpired ? 0.5 : 1.0,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${permit.permitNumber} - ${permit.name}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: permit.isExpired
                                  ? theme.colorScheme.error
                                  : null,
                            ),
                          ),
                          if (options.showValidityDates)
                            Text(
                              'Valid: ${dateFormat.format(permit.validFrom)} - ${dateFormat.format(permit.validTo)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: permit.isExpired
                                    ? theme.colorScheme.error
                                        .withValues(alpha: 0.7)
                                    : isExpiringSoon
                                        ? AppColors.warning
                                        : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (permit.isExpired)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Chip(
                          label: const Text('Expired'),
                          labelStyle: const TextStyle(fontSize: 10),
                          backgroundColor: theme.colorScheme.errorContainer,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                    else if (isExpiringSoon)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Chip(
                          label: const Text('Expiring'),
                          labelStyle: const TextStyle(fontSize: 10),
                          backgroundColor:
                              AppColors.warning.withValues(alpha: 0.2),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        // "Add Permit..." option
        if (widget.showAddPermitOption)
          DropdownMenuItem<String?>(
            value: _addPermitValue,
            enabled: _canAddPermit,
            child: Row(
              children: [
                Icon(
                  Icons.add,
                  size: 18,
                  color: _canAddPermit
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  semanticLabel: 'Add permit',
                ),
                const SizedBox(width: 8),
                Text(
                  _canAddPermit ? 'Add Permit...' : 'Add Permit (Pro)',
                  style: TextStyle(
                    color: _canAddPermit
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: widget.enabled ? _onPermitChanged : null,
    );
  }

  String? _resolveSelectedPermitId(List<Permit> permits) {
    final selected = widget.selectedPermitId;
    if (selected == null || selected.isEmpty) {
      return null;
    }
    final byId = permits.where((permit) => permit.id == selected).firstOrNull;
    if (byId != null) {
      return byId.id;
    }
    final byNumber = permits
        .where((permit) => permit.permitNumber == selected)
        .firstOrNull;
    return byNumber?.id;
  }

  void _onPermitChanged(String? permitId) {
    if (permitId == null) {
      widget.onPermitSelected(null);
      return;
    }

    // Handle "Add Permit..." selection
    if (permitId == _addPermitValue) {
      _showAddPermitDialog();
      return;
    }

    // Safe lookup with null check using effective permits
    final permit = _effectivePermits
        ?.where((p) => p.id == permitId)
        .firstOrNull;
    if (permit != null) {
      widget.onPermitSelected(permit);
    } else {
      LoggingService.instance.warning(
        'PermitSelectorWidget: Selected permit $permitId not found in list',
      );
      widget.onPermitSelected(null);
    }
  }

  Future<void> _showAddPermitDialog() async {
    if (!widget.isPro) {
      if (mounted) {
        ToastOverlay.showSnackBar(context,
          const SnackBar(content: Text('Permits require a Pro subscription')),
        );
      }
      return;
    }

    // Check if callback is provided
    final onAddPermitRequested = widget.onAddPermitRequested;
    if (onAddPermitRequested == null) {
      LoggingService.instance.warning(
        'PermitSelectorWidget: onAddPermitRequested callback not provided',
      );
      if (mounted) {
        ToastOverlay.showSnackBar(context,
          const SnackBar(content: Text('Permit creation not available')),
        );
      }
      return;
    }

    // Resolve userId: prefer widget parameter, fall back to CurrentUser
    String? userId = widget.userId;
    if (userId == null || userId.isEmpty) {
      try {
        final currentUserState = context.read<CurrentUser>().state;
        if (currentUserState is CurrentUserLoaded) {
          userId = currentUserState.user.id;
        }
      } catch (_) {
        // CurrentUser not available in context
      }
    }

    // organizationId always comes from widget parameter (consistent sourcing)
    final organizationId = widget.organizationId;

    if (userId == null || userId.isEmpty || organizationId.isEmpty) {
      LoggingService.instance.warning(
        'PermitSelectorWidget: Unable to create permit - '
        'userId=${userId ?? "null"}, organizationId=$organizationId',
      );
      if (mounted) {
        ToastOverlay.showSnackBar(context,
          const SnackBar(
            content: Text('Unable to create permit: user info not available'),
          ),
        );
      }
      return;
    }

    // Call the callback to show permit creation dialog
    final createdPermit = await onAddPermitRequested(
      context,
      organizationId,
      userId,
    );

    if (createdPermit == null || !mounted) return;

    // Notify parent if callback provided
    widget.onPermitCreated?.call(createdPermit);

    // Add to local permits list and select it
    setState(() {
      _permits = [...?_permits, createdPermit];
    });

    // Select the newly created permit
    widget.onPermitSelected(createdPermit);

    // Show success message
    if (mounted) {
      ToastOverlay.showSnackBar(context,
        SnackBar(content: Text('Created permit: ${createdPermit.name}')),
      );
    }

    // Refresh permits list from repository as fallback
    _loadPermits();
  }
}

/// Extension to easily extract permit metadata from a Permit object
extension PermitMetadataExtension on Permit? {
  /// Get permit number or empty string if null
  String get permitNumberOrEmpty => this?.permitNumber ?? '';

  /// Get permit type display name or empty string if null
  String get typeOrEmpty => this?.type.displayName ?? '';

  /// Get issuing authority or empty string if null
  String get issuingAuthorityOrEmpty => this?.issuingAuthority ?? '';

  /// Get attachment URLs as comma-separated string
  String get attachmentsOrEmpty => this?.attachmentUrls.join(', ') ?? '';

  /// Get valid from date formatted or empty string if null
  String formattedValidFrom([String pattern = 'MMM d, yyyy']) =>
      this != null ? DateFormat(pattern).format(this!.validFrom) : '';

  /// Get valid to date formatted or empty string if null
  String formattedValidTo([String pattern = 'MMM d, yyyy']) =>
      this != null ? DateFormat(pattern).format(this!.validTo) : '';
}
