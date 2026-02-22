// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A dropdown that allows selecting multiple items with checkmarks.
/// Selections are accumulated while open and committed when the dropdown closes.
/// Displays selected items as chips below the dropdown.
class MultiselectDropdown<T> extends StatefulWidget {
  const MultiselectDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.selectedValues,
    required this.onChanged,
    this.displayValue,
    this.enabled = true,
    this.enableSearch = false,
    this.searchHint = 'Search...',
    this.orphanedValues = const {},
  });

  final String label;
  final List<DropdownMenuItem<T>> items;
  final Set<T> selectedValues;
  final ValueChanged<Set<T>> onChanged;
  final String Function(T value)? displayValue;
  final bool enabled;

  /// When true, adds a search field at the top of the dropdown overlay
  /// for filtering items. Useful for dropdowns with 100+ options.
  final bool enableSearch;

  /// Placeholder text for the search field when [enableSearch] is true.
  final String searchHint;

  /// Values that are selected but have no matches in the current filter context.
  /// These will be displayed with a warning indicator to help users understand
  /// why their selection may not be affecting the results.
  final Set<T> orphanedValues;

  @override
  State<MultiselectDropdown<T>> createState() => _MultiselectDropdownState<T>();
}

class _MultiselectDropdownState<T> extends State<MultiselectDropdown<T>> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _buttonKey = GlobalKey();

  /// Pending selections accumulated while the dropdown is open.
  /// Only committed to [widget.onChanged] when the dropdown closes.
  Set<T> _pendingSelections = {};

  void _toggleDropdown() {
    if (_overlayEntry != null) {
      _hideDropdown();
    } else {
      _showDropdown();
      // Trigger rebuild to update suffix icon state
      setState(() {});
    }
  }

  void _showDropdown() {
    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final overlay = Overlay.of(context);

    // Snapshot current selections as the starting point for pending edits
    _pendingSelections = Set<T>.from(widget.selectedValues);

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hideDropdown,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 4),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: _DropdownContent<T>(
                    items: widget.items,
                    selectedValues: _pendingSelections,
                    enabled: widget.enabled,
                    enableSearch: widget.enableSearch,
                    searchHint: widget.searchHint,
                    displayValue: widget.displayValue,
                    onToggle: _onPendingToggle,
                    onRebuildOverlay: _rebuildOverlay,
                    orphanedValues: widget.orphanedValues,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _onPendingToggle(T value) {
    if (_pendingSelections.contains(value)) {
      _pendingSelections.remove(value);
    } else {
      _pendingSelections.add(value);
    }
    _rebuildOverlay();
  }

  void _rebuildOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _hideDropdown() {
    if (_overlayEntry == null) return;
    final changed = !_setEquals(_pendingSelections, widget.selectedValues);
    _overlayEntry!.remove();
    _overlayEntry!.dispose();
    _overlayEntry = null;
    if (changed) {
      widget.onChanged(Set<T>.from(_pendingSelections));
    }
    setState(() {});
  }

  static bool _setEquals<E>(Set<E> a, Set<E> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  @override
  void didUpdateWidget(covariant MultiselectDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If selectedValues changed externally while the overlay is open
    // (e.g., chip deletion, "clear all" button, another filter reset),
    // rebase _pendingSelections to stay in sync.
    if (_overlayEntry != null &&
        !_setEquals(oldWidget.selectedValues, widget.selectedValues)) {
      // Compute the user's pending edits (adds/removes relative to the
      // original snapshot) and apply them on top of the new external state.
      final userAdded = _pendingSelections.difference(oldWidget.selectedValues);
      final userRemoved =
          oldWidget.selectedValues.difference(_pendingSelections);
      _pendingSelections = Set<T>.from(widget.selectedValues)
        ..addAll(userAdded)
        ..removeAll(userRemoved);
      // Defer overlay rebuild — didUpdateWidget runs during the build phase,
      // so calling markNeedsBuild synchronously would throw.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildOverlay();
      });
    }
  }

  @override
  void deactivate() {
    // Clean up overlay without committing pending selections on teardown
    _discardDropdown();
    super.deactivate();
  }

  @override
  void dispose() {
    _discardDropdown();
    super.dispose();
  }

  /// Removes the overlay without committing pending selections.
  /// Used during widget teardown to avoid calling onChanged after dispose.
  void _discardDropdown() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  /// Handles key events and returns whether the event was consumed.
  KeyEventResult _handleKeyPress(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _overlayEntry != null) {
      _hideDropdown();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter && widget.enabled) {
      _toggleDropdown();
      return KeyEventResult.handled;
    }

    // Don't swallow unhandled keys (Tab, Shift+Tab, etc.) for accessibility
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = widget.selectedValues.length;
    final displayText = selectedCount == 0
        ? 'All'
        : selectedCount == 1
        ? (widget.displayValue?.call(widget.selectedValues.first) ??
              widget.selectedValues.first.toString())
        : '$selectedCount selected';

    return Focus(
      onKeyEvent: (node, event) => _handleKeyPress(event),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              key: _buttonKey,
              onTap: widget.enabled ? _toggleDropdown : null,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: widget.label,
                  border: const OutlineInputBorder(),
                  enabled: widget.enabled,
                  suffixIcon: Icon(
                    _overlayEntry != null
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    color: widget.enabled ? null : theme.disabledColor,
                  ),
                ),
                child: Text(
                  displayText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: widget.enabled ? null : theme.disabledColor,
                  ),
                ),
              ),
            ),
            if (selectedCount > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: widget.selectedValues.map((value) {
                  final displayName =
                      widget.displayValue?.call(value) ?? value.toString();
                  final isOrphaned = widget.orphanedValues.contains(value);
                  return _OrphanAwareChip(
                    displayName: displayName,
                    isOrphaned: isOrphaned,
                    enabled: widget.enabled,
                    onDeleted: widget.enabled
                        ? () {
                            final newSet = Set<T>.from(widget.selectedValues);
                            newSet.remove(value);
                            widget.onChanged(newSet);
                          }
                        : null,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Internal widget for dropdown content with search functionality.
class _DropdownContent<T> extends StatefulWidget {
  const _DropdownContent({
    required this.items,
    required this.selectedValues,
    required this.enabled,
    required this.enableSearch,
    required this.searchHint,
    required this.displayValue,
    required this.onToggle,
    required this.onRebuildOverlay,
    required this.orphanedValues,
  });

  final List<DropdownMenuItem<T>> items;
  final Set<T> selectedValues;
  final bool enabled;
  final bool enableSearch;
  final String searchHint;
  final String Function(T value)? displayValue;
  final ValueChanged<T> onToggle;
  final VoidCallback onRebuildOverlay;
  final Set<T> orphanedValues;

  @override
  State<_DropdownContent<T>> createState() => _DropdownContentState<T>();
}

class _DropdownContentState<T> extends State<_DropdownContent<T>> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  String _searchQuery = '';

  static const _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    if (widget.enableSearch) {
      // Auto-focus search field when dropdown opens
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (mounted) {
        setState(() {
          _searchQuery = value.toLowerCase();
        });
      }
    });
  }

  String _getDisplayValue(T value) {
    return widget.displayValue?.call(value) ?? value.toString();
  }

  bool _matchesSearch(T value) {
    if (_searchQuery.isEmpty) return true;
    final displayText = _getDisplayValue(value).toLowerCase();
    return displayText.contains(_searchQuery);
  }

  List<DropdownMenuItem<T>> _getFilteredItems() {
    if (_searchQuery.isEmpty) {
      return widget.items;
    }

    final filteredItems = <DropdownMenuItem<T>>[];
    final selectedButNotMatching = <DropdownMenuItem<T>>[];

    for (final item in widget.items) {
      final value = item.value;
      if (value == null) continue;

      final isSelected = widget.selectedValues.contains(value);
      final matchesSearch = _matchesSearch(value);

      if (matchesSearch) {
        filteredItems.add(item);
      } else if (isSelected) {
        // Preserve selected items even if they don't match search
        selectedButNotMatching.add(item);
      }
    }

    // Show selected items that don't match search at the top
    return [...selectedButNotMatching, ...filteredItems];
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final hasSearchField = widget.enableSearch;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: hasSearchField ? 350 : 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSearchField) _buildSearchField(),
          Flexible(
            child: filteredItems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final value = item.value;
                      if (value == null) return const SizedBox.shrink();

                      final isSelected = widget.selectedValues.contains(value);
                      final matchesSearch = _matchesSearch(value);
                      final isOrphaned = widget.orphanedValues.contains(value);

                      return ListTile(
                        onTap: widget.enabled
                            ? () => widget.onToggle(value)
                            : null,
                        title: _buildListItemTitle(
                          context,
                          item.child,
                          matchesSearch: matchesSearch,
                          isOrphaned: isOrphaned,
                          isSelected: isSelected,
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        dense: true,
                        selected: isSelected,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: widget.searchHint,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'No items match "$_searchQuery"',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Builds the title widget for a list item, handling search mismatch,
  /// orphaned states, and selected styling.
  Widget _buildListItemTitle(
    BuildContext context,
    Widget child, {
    required bool matchesSearch,
    required bool isOrphaned,
    required bool isSelected,
  }) {
    // Apply bold styling for selected items
    final styledChild = isSelected
        ? DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w600),
            child: child,
          )
        : child;

    // Orphaned items get warning styling (highest priority indicator)
    if (isOrphaned) {
      return Row(
        children: [
          Expanded(child: styledChild),
          const SizedBox(width: 4),
          Tooltip(
            message: 'No matches with current filters',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 2),
                Text(
                  '0',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Items that don't match current search (but are selected)
    if (!matchesSearch) {
      return Row(
        children: [
          Expanded(child: styledChild),
          const SizedBox(width: 4),
          Icon(
            Icons.filter_alt_off,
            size: 14,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ],
      );
    }

    // Normal items
    return styledChild;
  }
}

/// A chip that displays with warning styling when the selection is orphaned
/// (has no matches in the current filter context).
class _OrphanAwareChip extends StatelessWidget {
  const _OrphanAwareChip({
    required this.displayName,
    required this.isOrphaned,
    required this.enabled,
    required this.onDeleted,
  });

  final String displayName;
  final bool isOrphaned;
  final bool enabled;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isOrphaned) {
      return Tooltip(
        message: 'No matches with current filters',
        child: Chip(
          avatar: Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: theme.colorScheme.error,
          ),
          label: Text(
            displayName,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.error,
            ),
          ),
          deleteIcon: Icon(
            Icons.close,
            size: 16,
            color: theme.colorScheme.error,
          ),
          onDeleted: onDeleted,
          backgroundColor: theme.colorScheme.errorContainer.withValues(
            alpha: 0.3,
          ),
          side: BorderSide(
            color: theme.colorScheme.error.withValues(alpha: 0.5),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Chip(
      label: Text(
        displayName,
        style: const TextStyle(fontSize: 12),
      ),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}
