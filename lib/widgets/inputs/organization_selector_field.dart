import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/widgets/dialogs/base_search_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/transfer_shared.dart';

/// A text field that allows both manual text entry and organization search.
///
/// Shows a text field for manual entry with a search button that opens
/// [OrganizationSearchDialog] for finding existing organizations.
class OrganizationSelectorField extends StatefulWidget {
  const OrganizationSelectorField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.organizationRepository,
    this.hintText,
    this.helperText,
    this.excludeOrganizationId,
    this.enabled = true,
  });

  /// Label for the text field.
  final String label;

  /// Current value (organization ID or manually entered text).
  final String? value;

  /// Called when the value changes (either from text entry or search selection).
  final ValueChanged<String?> onChanged;

  /// Repository for searching organizations.
  final OrganizationRepository organizationRepository;

  /// Hint text for the text field.
  final String? hintText;

  /// Helper text shown below the field.
  final String? helperText;

  /// Organization ID to exclude from search results.
  final String? excludeOrganizationId;

  /// Whether the field is enabled.
  final bool enabled;

  @override
  State<OrganizationSelectorField> createState() =>
      _OrganizationSelectorFieldState();
}

class _OrganizationSelectorFieldState extends State<OrganizationSelectorField> {
  late TextEditingController _controller;
  Organization? _selectedOrganization;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _controller.addListener(_onTextChanged);
    // Try to resolve the initial value to an organization
    if (widget.value != null && widget.value!.isNotEmpty) {
      _resolveOrganization(widget.value!);
    }
  }

  @override
  void didUpdateWidget(OrganizationSelectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final newValue = widget.value ?? '';
      if (_controller.text != newValue) {
        _controller.text = newValue;
      }
      // Re-resolve if value changed externally
      if (widget.value != null && widget.value!.isNotEmpty) {
        _resolveOrganization(widget.value!);
      } else {
        _selectedOrganization = null;
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // When text changes manually, clear the selected organization
    // and notify parent with the raw text
    if (_selectedOrganization != null &&
        _controller.text != _selectedOrganization!.id &&
        _controller.text != _selectedOrganization!.name) {
      setState(() => _selectedOrganization = null);
    }
    widget.onChanged(_controller.text.isEmpty ? null : _controller.text);
  }

  Future<void> _resolveOrganization(String identifier) async {
    setState(() => _isSearching = true);
    try {
      final org =
          await widget.organizationRepository.resolveIdentifier(identifier);
      if (mounted) {
        setState(() => _selectedOrganization = org);
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _openSearch() async {
    final result = await BaseSearchDialog.showSingle<Organization>(
      context,
      dialog: OrganizationSearchDialog(
        repository: widget.organizationRepository,
        excludeOrganizationId: widget.excludeOrganizationId,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedOrganization = result;
        _controller.text = result.id;
      });
      widget.onChanged(result.id);
    }
  }

  void _clear() {
    setState(() {
      _selectedOrganization = null;
      _controller.clear();
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasOrganization = _selectedOrganization != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText ?? 'Enter organization ID or search',
            helperText: widget.helperText,
            border: const OutlineInputBorder(),
            prefixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(
                    hasOrganization ? Icons.check_circle : Icons.business,
                    color: hasOrganization ? Colors.green : null,
                  ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: widget.enabled ? _clear : null,
                    tooltip: 'Clear',
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: widget.enabled ? _openSearch : null,
                  tooltip: 'Search organizations',
                ),
              ],
            ),
          ),
        ),
        // Show resolved organization info when available
        if (hasOrganization) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              '${_selectedOrganization!.name} (${_selectedOrganization!.domain})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green[700],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
