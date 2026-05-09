import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/cubits/record_display_preferences/record_display_preferences_cubit.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/search_service.dart';

import '../widgets/common/organism_reference_links.dart';

/// Simplified search bar that integrates with the navigation service
class SimpleSearchBar extends StatefulWidget {
  const SimpleSearchBar({super.key});

  @override
  State<SimpleSearchBar> createState() => _SimpleSearchBarState();
}

class _SimpleSearchBarState extends State<SimpleSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<SearchResult> _results = [];
  bool _isLoading = false;
  OverlayEntry? _overlayEntry;
  RecordDisplayPreferencesState? _displayPreferences;

  /// Flag to prevent overlay from being shown after navigation starts
  bool _isNavigating = false;

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    // Don't search if we're in the middle of navigating
    if (_isNavigating) {
      return;
    }

    if (query.trim().isEmpty) {
      setState(() => _results = []);
      _hideOverlay();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final searchService = context.read<SearchService>();
      final results = await searchService.search(query);

      // Check again after async operation
      if (mounted && !_isNavigating) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
        _showOverlay();
      }
    } on ProviderNotFoundException {
      // SearchService not available in this context
      if (mounted && !_isNavigating) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Search failed', e, stackTrace);
      if (mounted && !_isNavigating) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onResultTapped(SearchResult result) async {
    LoggingService.instance.debug(
      'Search result tapped: ${result.record.name} at ${result.record.urlPath}',
    );

    // Set navigation flag to prevent overlay from being shown again
    _isNavigating = true;

    // CRITICAL: Hide overlay FIRST before any state changes or navigation
    // This prevents the overlay from persisting if widget rebuilds during navigation
    _hideOverlay();

    // Capture navigation cubit before clearing state
    final navigationCubit = context.read<NavigationCubit>();

    // Clear search UI
    _controller.clear();
    _focusNode.unfocus();
    if (mounted) {
      setState(() => _results = []);
    }

    // Navigate AFTER UI is cleared to prevent stale overlay state
    LoggingService.instance.debug('Navigating to search result...');
    await navigationCubit.navigateToSearchResult(result.record);
    LoggingService.instance.debug('Navigation complete');

    // Reset navigation flag after navigation completes
    if (mounted) {
      _isNavigating = false;
    }
  }

  void _showOverlay() {
    // Don't show overlay if we're in the middle of navigating
    if (_isNavigating) {
      return;
    }

    _hideOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      // Cannot show overlay without render box
      return;
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final boxWidth = renderBox.size.width;
    final boxHeight = renderBox.size.height;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Tap anywhere outside to dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideOverlay,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          // Search results dropdown
          Positioned(
            left: position.dx,
            top: position.dy + boxHeight + 8.0,
            width: boxWidth,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildResultsList(),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    final overlay = _overlayEntry;
    _overlayEntry = null;
    // Use try-catch to handle edge case where overlay may have been
    // disposed during navigation or widget rebuild
    if (overlay != null) {
      try {
        overlay.remove();
      } catch (e) {
        // Overlay already removed, ignore
      }
    }
  }

  Widget _buildResultsList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No results found'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        final title = result.record is OrganismRecord
            ? _buildOrganismTitle(context, result.record as OrganismRecord)
            : Text(result.record.name);
        return ListTile(
          title: title,
          subtitle: Text(result.buildSubtitle()),
          onTap: () => _onResultTapped(result),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cache display preferences for use in overlay callbacks
    // (overlay context doesn't have access to parent providers)
    _displayPreferences = context.read<RecordDisplayPreferencesCubit>().state;

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _performSearch,
        decoration: InputDecoration(
          hintText: 'Search...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _results = []);
                    _hideOverlay();
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildOrganismTitle(BuildContext context, OrganismRecord organism) {
    // Use cached display preferences (overlay context doesn't have providers)
    final prefs = _displayPreferences;
    final displayInfo = resolveRecordDisplayInfo(
      showUuid: prefs?.showUuid ?? false,
      showIdentifier: prefs?.showIdentifier ?? true,
      recordId: organism.id,
      tagId: organism.tagId,
      localGenetId: organism.localGenetId,
    );

    return OrganismReferenceLinks(
      tagId: displayInfo.tagId,
      localGenetId: displayInfo.localGenetId,
      urlPath: organism.urlPath,
      genetRecordId: GenetIdResolver.resolve(organism),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      disableNavigation: displayInfo.isHidden,
    );
  }
}
