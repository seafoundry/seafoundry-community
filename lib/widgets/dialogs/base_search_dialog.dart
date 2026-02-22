// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:seafoundry_app/blocs/auth/auth.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/human_sort.dart';
import 'package:seafoundry_app/widgets/dialogs/base/dialog_base.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

/// Base class for dialogs that search and select entities
///
/// This pattern provides:
/// - Async search with debouncing
/// - Loading states
/// - Empty/error states
/// - Recent selections
/// - Single or multi-select modes
///
/// Usage:
/// ```dart
/// class SearchOrganismDialog extends BaseSearchDialog<OrganismRecord> {
///   @override
///   String get title => 'Search Organisms';
///
///   @override
///   Future<List<OrganismRecord>> performSearch(String query) async {
///     final repo = context.read<OrganismRecordRepository>();
///     return await repo.searchByName(query);
///   }
///
///   @override
///   Widget buildSearchResult(BuildContext context, OrganismRecord item) {
///     return ListTile(
///       title: Text(item.name ?? item.id),
///       subtitle: Text('Species: ${item.speciesId}'),
///     );
///   }
/// }
/// ```
abstract class BaseSearchDialog<T> extends StatefulWidget {
  final bool multiSelect;
  final List<T>? initialSelection;
  final int? maxSelection;

  const BaseSearchDialog({
    super.key,
    this.multiSelect = false,
    this.initialSelection,
    this.maxSelection,
  });

  static Future<T?> showSingle<T>(
    BuildContext context, {
    required BaseSearchDialog<T> dialog,
  }) {
    final providers = _captureDialogProviders(context);
    final future = providers.isEmpty
        ? showDialog<List<T>>(
            context: context,
            useRootNavigator: false,
            barrierDismissible: false,
            builder: (context) => dialog,
          )
        : DialogBase.showDialogWithProviders<List<T>>(
            context: context,
            providers: providers,
            dialog: dialog,
            barrierDismissible: false,
          );
    return future.then((result) => result?.firstOrNull);
  }

  static Future<List<T>?> showMulti<T>(
    BuildContext context, {
    required BaseSearchDialog<T> dialog,
  }) {
    final providers = _captureDialogProviders(context);
    if (providers.isEmpty) {
      return showDialog<List<T>>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (context) => dialog,
      );
    }
    return DialogBase.showDialogWithProviders<List<T>>(
      context: context,
      providers: providers,
      dialog: dialog,
      barrierDismissible: false,
    );
  }

  @override
  State<BaseSearchDialog<T>> createState() => _BaseSearchDialogState<T>();
}

List<SingleChildWidget> _captureDialogProviders(BuildContext context) {
  final providers = <SingleChildWidget>[];

  void addBloc<T extends BlocBase<dynamic>>() {
    try {
      final bloc = context.read<T>();
      providers.add(BlocProvider<T>.value(value: bloc));
    } on ProviderNotFoundException {
      // Dialog can still render without this provider.
    }
  }

  addBloc<AuthBloc>();
  addBloc<CurrentUser>();
  addBloc<NavigationCubit>();

  return providers;
}

abstract class BaseSearchDialogState<T> extends State<BaseSearchDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  final Set<T> _selectedItems = {};
  List<T> _searchResults = [];
  List<T> _recentItems = [];
  bool _isSearching = false;
  String? _error;
  String _lastQuery = '';

  // Debounce timer
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelection != null) {
      _selectedItems.addAll(widget.initialSelection!);
    }
    _loadRecentItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// The dialog title
  String get title;

  /// Optional icon for the title
  Widget? get titleIcon => null;

  /// Dialog width
  double get dialogWidth => 600;

  /// Dialog height
  double get dialogHeight => 500;

  /// Search hint text
  String get searchHint => 'Search...';

  /// Debounce duration for search
  Duration get debounceDuration => const Duration(milliseconds: 300);

  /// Whether to show recent items when search is empty
  bool get showRecentItems => true;

  /// Maximum number of recent items to show
  int get maxRecentItems => 5;

  /// Perform the search operation
  Future<List<T>> performSearch(String query);

  /// Load recent items (optional)
  Future<List<T>> loadRecentItems() async => [];

  /// Build the display widget for a search result
  Widget buildSearchResult(BuildContext context, T item);

  /// Get a unique identifier for an item
  String getItemId(T item);

  /// Get display name for item (for accessibility)
  String getItemDisplayName(T item);

  /// Optional custom empty state
  Widget? buildEmptyState() => null;

  /// Optional custom error state
  Widget? buildErrorState(String error) => null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _buildTitle(),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildSearchField(),
            const SizedBox(height: 16),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        if (titleIcon != null) ...[titleIcon!, const SizedBox(width: 8)],
        Expanded(child: Text(title)),
        if (widget.multiSelect && _selectedItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedItems.length.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: searchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            : null,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      onChanged: _onSearchChanged,
    );
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();

    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
        _lastQuery = '';
      });
      return;
    }

    _debounceTimer = Timer(debounceDuration, () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query == _lastQuery) return;

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await performSearch(query);
      final sortedResults = _sortItems(results);
      if (mounted) {
        setState(() {
          _searchResults = sortedResults;
          _lastQuery = query;
          _isSearching = false;
        });
      }
    } catch (e) {
      LoggingService.instance.error('Search failed', e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _loadRecentItems() async {
    if (!showRecentItems) return;

    try {
      final items = await loadRecentItems();
      final sortedItems = _sortItems(items);
      if (mounted) {
        setState(() {
          _recentItems = sortedItems.take(maxRecentItems).toList();
        });
      }
    } catch (e) {
      LoggingService.instance.error('Failed to load recent items', e);
    }
  }

  Widget _buildContent() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return buildErrorState(_error!) ?? _buildDefaultErrorState(_error!);
    }

    final hasQuery = _searchController.text.isNotEmpty;
    final items = hasQuery ? _searchResults : _recentItems;

    if (items.isEmpty) {
      if (hasQuery) {
        return buildEmptyState() ?? _buildDefaultEmptyState();
      } else {
        return _buildInitialState();
      }
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedItems.contains(item);

        return InkWell(
          onTap: () => _toggleSelection(item),
          child: Container(
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : null,
            child: Row(
              children: [
                if (widget.multiSelect)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(item),
                  )
                else if (isSelected)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.check_circle, color: Colors.green),
                  )
                else
                  const SizedBox(width: 48),
                Expanded(child: buildSearchResult(context, item)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Start typing to search',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter at least 2 characters',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Search Error', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _performSearch(_searchController.text),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    return [
      TextButton(
        onPressed: () => popSafeDialogContext(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _selectedItems.isEmpty
            ? null
            : () => popSafeDialogContext(context, _selectedItems.toList()),
        child: Text(
          widget.multiSelect
              ? 'Select ${_selectedItems.length} Item${_selectedItems.length != 1 ? 's' : ''}'
              : 'Select',
        ),
      ),
    ];
  }

  void _toggleSelection(T item) {
    setState(() {
      if (widget.multiSelect) {
        if (_selectedItems.contains(item)) {
          _selectedItems.remove(item);
        } else {
          if (widget.maxSelection != null &&
              _selectedItems.length >= widget.maxSelection!) {
            showSafeDialogSnackBar(
              context,
              'Maximum ${widget.maxSelection} items can be selected',
            );
            return;
          }
          _selectedItems.add(item);
        }
      } else {
        _selectedItems.clear();
        _selectedItems.add(item);
      }
    });
  }

  /// Check if an item is selected
  bool isSelected(T item) => _selectedItems.contains(item);

  /// Get current selection
  List<T> get selectedItems => _selectedItems.toList();

  /// Clear selection
  void clearSelection() {
    setState(() {
      _selectedItems.clear();
    });
  }

  List<T> _sortItems(List<T> items) {
    if (items.length <= 1) return items;
    final sorted = List<T>.from(items);
    sorted.sort((a, b) {
      final labelA = getItemDisplayName(a);
      final labelB = getItemDisplayName(b);
      return compareHumanReadable(labelA, labelB);
    });
    return sorted;
  }
}

class _BaseSearchDialogState<T> extends BaseSearchDialogState<T> {
  @override
  String get title => 'Search';

  Future<List<T>> searchItems(String query) async {
    // Default implementation - override in subclasses
    return [];
  }

  Widget buildItem(BuildContext context, T item, bool isSelected) {
    return Text(item.toString());
  }

  @override
  String getItemDisplayName(T item) => item.toString();

  @override
  Future<List<T>> performSearch(String query) async {
    // Default implementation - override in subclasses
    return [];
  }

  @override
  Widget buildSearchResult(BuildContext context, T item) {
    return Text(item.toString());
  }

  @override
  String getItemId(T item) => item.toString();
}
