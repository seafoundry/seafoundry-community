// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/widgets/inputs/organization_autocomplete_overlay.dart';

/// Self-contained autocomplete field for organization search.
/// Handles its own search state with debounce.
class OrganizationAutocompleteField extends StatefulWidget {
  const OrganizationAutocompleteField({
    super.key,
    required this.label,
    required this.hintText,
    required this.organizationRepository,
    required this.onOrganizationSelected,
    this.initialOrganizationId,
    this.excludeOrganizationId,
    this.helperText,
    this.enabled = true,
  });

  final String label;
  final String hintText;
  final OrganizationRepository organizationRepository;
  final ValueChanged<Organization?> onOrganizationSelected;

  /// Initial organization ID to resolve and display.
  final String? initialOrganizationId;

  /// Organization ID to exclude from search results (e.g., current org).
  final String? excludeOrganizationId;

  final String? helperText;
  final bool enabled;

  @override
  State<OrganizationAutocompleteField> createState() =>
      _OrganizationAutocompleteFieldState();
}

class _OrganizationAutocompleteFieldState
    extends State<OrganizationAutocompleteField> {
  final _controller = TextEditingController();
  final _layerLink = LayerLink();
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;

  List<Organization> _suggestions = [];
  bool _isSearching = false;
  int _highlightedIndex = -1;
  Organization? _selectedOrganization;
  Timer? _debounceTimer;

  static const _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    _focusNode.addListener(_onFocusChanged);
    _resolveInitialValue();
  }

  @override
  void didUpdateWidget(OrganizationAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOrganizationId != oldWidget.initialOrganizationId) {
      _resolveInitialValue();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideOverlay();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolveInitialValue() async {
    final id = widget.initialOrganizationId;
    if (id == null || id.isEmpty) {
      _selectedOrganization = null;
      _controller.clear();
      return;
    }

    final org = await widget.organizationRepository.resolveIdentifier(id);
    if (!mounted) return;

    setState(() {
      _selectedOrganization = org;
      _controller.text = org?.name ?? id;
    });
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();

    if (value.isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _selectedOrganization = null;
      });
      widget.onOrganizationSelected(null);
      _hideOverlay();
      return;
    }

    setState(() => _isSearching = true);
    _refreshOverlay();

    _debounceTimer = Timer(_debounceDuration, () => _performSearch(value));
  }

  Future<void> _performSearch(String query) async {
    if (!mounted || query.isEmpty) return;

    try {
      final result = await widget.organizationRepository.searchOrganizations(
        query: query,
        limit: 10,
      );

      if (!mounted) return;

      // Filter out the excluded organization
      final filtered = widget.excludeOrganizationId == null
          ? result.items
          : result.items
              .where((org) => org.id != widget.excludeOrganizationId)
              .toList();

      setState(() {
        _suggestions = filtered;
        _isSearching = false;
        _highlightedIndex = -1;
      });
      _refreshOverlay();
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isSearching = false;
        });
        _refreshOverlay();
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_overlayEntry == null || _suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightedIndex = (_highlightedIndex + 1) % _suggestions.length;
      });
      _overlayEntry?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightedIndex = _highlightedIndex <= 0
            ? _suggestions.length - 1
            : _highlightedIndex - 1;
      });
      _overlayEntry?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (_highlightedIndex >= 0 && _highlightedIndex < _suggestions.length) {
        _selectOrganization(_suggestions[_highlightedIndex]);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.escape) {
      _hideOverlay();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Show dropdown on focus if there's text
      if (_controller.text.isNotEmpty) {
        _performSearch(_controller.text);
      }
    } else {
      // Delay hiding to allow tap events on overlay to register
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideOverlay();
        }
      });
    }
  }

  void _refreshOverlay() {
    if (!_focusNode.hasFocus) return;
    final show = _isSearching ||
        _suggestions.isNotEmpty ||
        (!_isSearching && _controller.text.length >= 2);
    if (show) {
      if (_overlayEntry != null) {
        _overlayEntry!.markNeedsBuild();
      } else {
        _showOverlay();
      }
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    _hideOverlay();
    if (!mounted) return;
    _overlayEntry = OverlayEntry(builder: (_) => _buildOverlay());
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    _highlightedIndex = -1;
    entry?.remove();
    entry?.dispose();
  }

  Widget _buildOverlay() {
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 300.0;
    final height = box?.size.height ?? 56.0;

    return OrganizationAutocompleteOverlay(
      link: _layerLink,
      width: width,
      targetHeight: height,
      suggestions: _suggestions,
      isSearching: _isSearching,
      valueLength: _controller.text.length,
      highlightedIndex: _highlightedIndex,
      onSuggestionSelected: _selectOrganization,
    );
  }

  void _selectOrganization(Organization org) {
    _hideOverlay();
    _focusNode.unfocus();
    setState(() {
      _selectedOrganization = org;
      _controller.text = org.name;
      _suggestions = [];
    });
    widget.onOrganizationSelected(org);
  }

  void _clearSelection() {
    setState(() {
      _selectedOrganization = null;
      _controller.clear();
      _suggestions = [];
    });
    widget.onOrganizationSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = _selectedOrganization != null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        onChanged: _onTextChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          helperText: widget.helperText,
          border: const OutlineInputBorder(),
          prefixIcon: hasSelection
              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
              : const Icon(Icons.business),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSelection || _controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: widget.enabled ? _clearSelection : null,
                  tooltip: 'Clear',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
