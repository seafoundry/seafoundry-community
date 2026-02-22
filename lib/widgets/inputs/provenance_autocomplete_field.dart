// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/widgets/inputs/provenance_autocomplete_overlay.dart';

/// Reusable autocomplete field for provenance alias search.
/// Driven entirely by external BLoC/Cubit state.
class ProvenanceAutocompleteField extends StatefulWidget {
  const ProvenanceAutocompleteField({
    super.key,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.value,
    required this.suggestions,
    required this.isSearching,
    required this.onTextChanged,
    required this.onSuggestionSelected,
    this.errorText,
    this.enabled = true,
    this.onFocusGained,
    this.onFocusLost,
    this.onEditingComplete,
    this.onDisabledTap,
    this.displayValueBuilder,
    this.showOtherAliases = true,
  });

  final String label;
  final String hintText;
  final IconData icon;
  final String value;
  final List<ProvenanceSuggestion> suggestions;
  final bool isSearching;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<ProvenanceSuggestion> onSuggestionSelected;
  final String? errorText;
  final bool enabled;
  final VoidCallback? onFocusGained;
  final VoidCallback? onFocusLost;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onDisabledTap;
  final String Function(ProvenanceSuggestion suggestion)? displayValueBuilder;
  final bool showOtherAliases;

  @override
  State<ProvenanceAutocompleteField> createState() =>
      _ProvenanceAutocompleteFieldState();
}

class _ProvenanceAutocompleteFieldState
    extends State<ProvenanceAutocompleteField> {
  final _controller = TextEditingController();
  final _layerLink = LayerLink();
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;
  int _highlightedIndex = -1;
  bool _pendingFocus = false;
  bool _skipBlurCallback = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.value;
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(ProvenanceAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection =
          TextSelection.collapsed(offset: widget.value.length);
    }
    if (widget.suggestions != oldWidget.suggestions ||
        widget.isSearching != oldWidget.isSearching) {
      _highlightedIndex = -1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshOverlay();
      });
    }
    if (_pendingFocus && widget.enabled) {
      _pendingFocus = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).requestFocus(_focusNode);
        }
      });
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_overlayEntry == null || widget.suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightedIndex =
            (_highlightedIndex + 1) % widget.suggestions.length;
      });
      _overlayEntry?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightedIndex = _highlightedIndex <= 0
            ? widget.suggestions.length - 1
            : _highlightedIndex - 1;
      });
      _overlayEntry?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (_highlightedIndex >= 0 &&
          _highlightedIndex < widget.suggestions.length) {
        _selectSuggestion(widget.suggestions[_highlightedIndex]);
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
      widget.onFocusGained?.call();
      // Trigger search immediately on focus (empty/dropdown behavior)
      widget.onTextChanged(_controller.text);
    } else {
      if (_skipBlurCallback) {
        _skipBlurCallback = false;
      } else {
        widget.onFocusLost?.call();
      }
      // Delay hiding to allow tap events on the overlay to register
      // before the overlay is removed.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideOverlay();
        }
      });
    }
  }

  void _refreshOverlay() {
    if (!_focusNode.hasFocus) return;
    final show = widget.isSearching ||
        widget.suggestions.isNotEmpty ||
        (!widget.isSearching && widget.value.length >= 2);
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
    // Extract size values explicitly to avoid web JS type coercion issues
    final width = box?.size.width;
    final height = box?.size.height;

    return ProvenanceAutocompleteOverlay(
      link: _layerLink,
      width: width ?? 300.0,
      targetHeight: height ?? 56.0,
      suggestions: widget.suggestions,
      isSearching: widget.isSearching,
      valueLength: widget.value.length,
      highlightedIndex: _highlightedIndex,
      onSuggestionSelected: _selectSuggestion,
      displayValueBuilder: widget.displayValueBuilder,
      showOtherAliases: widget.showOtherAliases,
    );
  }

  void _selectSuggestion(ProvenanceSuggestion suggestion) {
    _hideOverlay();
    _skipBlurCallback = true;
    _focusNode.unfocus();
    widget.onSuggestionSelected(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      onChanged: widget.onTextChanged,
      onEditingComplete: widget.onEditingComplete,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        prefixIcon: Icon(widget.icon),
        errorText: widget.errorText,
        border: const OutlineInputBorder(),
      ),
    );

    final child = widget.enabled || widget.onDisabledTap == null
        ? field
        : Stack(
            children: [
              AbsorbPointer(child: field),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleDisabledTap,
                  ),
                ),
              ),
            ],
          );

    return CompositedTransformTarget(
        link: _layerLink,
        child: child,
      );
  }

  void _handleDisabledTap() {
    widget.onDisabledTap?.call();
    _pendingFocus = true;
  }
}
