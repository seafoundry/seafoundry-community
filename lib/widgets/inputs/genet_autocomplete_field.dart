// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/widgets/inputs/genet_autocomplete_overlay.dart';

/// Self-contained autocomplete field for genet (local ID) search.
/// Handles its own search state with debounce.
class GenetAutocompleteField extends StatefulWidget {
  const GenetAutocompleteField({
    super.key,
    required this.genetRepository,
    required this.onGenetSelected,
    this.initialGenet,
    this.initialLocalId,
    this.label = 'Local ID',
    this.hintText = 'Type to search genets',
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.onAdvancedSelect,
    this.isRequired = false,
  });

  final GenetRepository genetRepository;
  final ValueChanged<Genet?> onGenetSelected;

  /// Initial genet to display.
  final Genet? initialGenet;

  /// Initial local ID text to display (used when genet is not available).
  final String? initialLocalId;

  final String label;
  final String hintText;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final bool isRequired;

  /// Callback when user wants to open advanced selection dialog.
  /// If null, the advanced select option is hidden.
  final VoidCallback? onAdvancedSelect;

  @override
  State<GenetAutocompleteField> createState() => _GenetAutocompleteFieldState();
}

class _GenetAutocompleteFieldState extends State<GenetAutocompleteField> {
  final _controller = TextEditingController();
  final _layerLink = LayerLink();
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;

  List<Genet> _suggestions = [];
  bool _isSearching = false;
  int _highlightedIndex = -1;
  Genet? _selectedGenet;
  Timer? _debounceTimer;

  static const _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    _focusNode.addListener(_onFocusChanged);
    _initializeValue();
  }

  @override
  void didUpdateWidget(GenetAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update display when initial values change externally
    if (widget.initialGenet != oldWidget.initialGenet ||
        widget.initialLocalId != oldWidget.initialLocalId) {
      _initializeValue();
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

  void _initializeValue() {
    if (widget.initialGenet != null) {
      _selectedGenet = widget.initialGenet;
      _controller.text = widget.initialGenet!.name;
    } else if (widget.initialLocalId != null &&
        widget.initialLocalId!.isNotEmpty) {
      _controller.text = widget.initialLocalId!;
    } else {
      _selectedGenet = null;
      _controller.clear();
    }
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();

    // Clear selection when text changes and notify cubit
    if (_selectedGenet != null && value != _selectedGenet!.name) {
      setState(() => _selectedGenet = null);
      widget.onGenetSelected(null);
    }

    if (value.isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _selectedGenet = null;
      });
      widget.onGenetSelected(null);
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
      final results = await widget.genetRepository.searchGenetsByNamePrefix(
        query,
        limit: 10,
      );

      if (!mounted) return;

      setState(() {
        _suggestions = results;
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
        _selectGenet(_suggestions[_highlightedIndex]);
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
      if (_controller.text.isNotEmpty && _selectedGenet == null) {
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

    return GenetAutocompleteOverlay(
      link: _layerLink,
      width: width,
      targetHeight: height,
      suggestions: _suggestions,
      isSearching: _isSearching,
      valueLength: _controller.text.length,
      highlightedIndex: _highlightedIndex,
      onSuggestionSelected: _selectGenet,
      onAdvancedSelect: widget.onAdvancedSelect != null
          ? () {
              _hideOverlay();
              widget.onAdvancedSelect!();
            }
          : null,
    );
  }

  void _selectGenet(Genet genet) {
    _hideOverlay();
    _focusNode.unfocus();
    setState(() {
      _selectedGenet = genet;
      _controller.text = genet.name;
      _suggestions = [];
    });
    widget.onGenetSelected(genet);
  }

  void _clearSelection() {
    setState(() {
      _selectedGenet = null;
      _controller.clear();
      _suggestions = [];
    });
    widget.onGenetSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = _selectedGenet != null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        onChanged: _onTextChanged,
        decoration: InputDecoration(
          labelText: widget.isRequired ? '${widget.label} *' : widget.label,
          hintText: widget.hintText,
          helperText: widget.helperText,
          errorText: widget.errorText,
          border: const OutlineInputBorder(),
          prefixIcon: hasSelection
              ? Icon(Icons.link, color: theme.colorScheme.primary)
              : const Icon(Icons.eco_outlined),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSelection || _controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: widget.enabled ? _clearSelection : null,
                  tooltip: 'Clear',
                ),
              if (widget.onAdvancedSelect != null && widget.enabled)
                IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: () {
                    _hideOverlay();
                    widget.onAdvancedSelect!();
                  },
                  tooltip: 'Advanced selection',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
