// @tier: community
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared permit metadata UI used across deployment/transfer/husbandry dialogs.
///
/// The widget supports both controller-driven forms (dialogs that keep
/// TextEditingControllers in state) and value/change-callback bindings (Bloc /
/// Formz-backed forms). Provide either a controller or a `value` + `onChanged`
/// pair for each text field.
///
/// By default, the section is collapsed (hidden) unless `initiallyExpanded` is
/// set to true or `permitRequired` is true.
class PermitMetadataSection extends StatefulWidget {
  const PermitMetadataSection({
    super.key,
    this.permitIdController,
    this.permitTypeController,
    this.issuingAuthorityController,
    this.attachmentUrlsController,
    this.permitIdValue,
    this.permitTypeValue,
    this.issuingAuthorityValue,
    this.attachmentUrlsValue,
    this.onPermitIdChanged,
    this.onPermitTypeChanged,
    this.onIssuingAuthorityChanged,
    this.onAttachmentUrlsChanged,
    required this.onPickValidFrom,
    required this.onPickValidTo,
    this.validFrom,
    this.validTo,
    this.permitRequired = false,
    this.supportsPermits = true,
    this.disabledMessage,
    this.helperText =
        'Capture permit identifiers, issuing authority, validity window, '
        'and reference links so compliance exports stay complete.',
    this.headerText = 'Permit metadata',
    this.attachmentLabel = 'Attachment URLs (comma or newline separated)',
    this.dateButtonBuilder,
    this.fieldsEnabled = true,
    this.onClearDates,
    this.clearDatesEnabled = true,
    this.clearDatesLabel = 'Clear dates',
    this.permitIdFieldKey,
    this.permitTypeFieldKey,
    this.issuingAuthorityFieldKey,
    this.attachmentFieldKey,
    this.validFromButtonKey,
    this.validToButtonKey,
    this.initiallyExpanded,
  });

  final TextEditingController? permitIdController;
  final TextEditingController? permitTypeController;
  final TextEditingController? issuingAuthorityController;
  final TextEditingController? attachmentUrlsController;
  final String? permitIdValue;
  final String? permitTypeValue;
  final String? issuingAuthorityValue;
  final String? attachmentUrlsValue;
  final ValueChanged<String>? onPermitIdChanged;
  final ValueChanged<String>? onPermitTypeChanged;
  final ValueChanged<String>? onIssuingAuthorityChanged;
  final ValueChanged<String>? onAttachmentUrlsChanged;
  final DateTime? validFrom;
  final DateTime? validTo;
  final VoidCallback onPickValidFrom;
  final VoidCallback onPickValidTo;
  final bool permitRequired;
  final bool supportsPermits;
  final String? disabledMessage;
  final String helperText;
  final String headerText;
  final String attachmentLabel;
  final Widget Function({
    required DateTime? value,
    required String label,
    required VoidCallback onPressed,
  })?
  dateButtonBuilder;
  final bool fieldsEnabled;
  final VoidCallback? onClearDates;
  final bool clearDatesEnabled;
  final String clearDatesLabel;
  final Key? permitIdFieldKey;
  final Key? permitTypeFieldKey;
  final Key? issuingAuthorityFieldKey;
  final Key? attachmentFieldKey;
  final Key? validFromButtonKey;
  final Key? validToButtonKey;

  /// Whether the permit section should be expanded initially.
  /// If null, defaults to `permitRequired` value (expanded if required).
  final bool? initiallyExpanded;

  @override
  State<PermitMetadataSection> createState() => _PermitMetadataSectionState();
}

class _PermitMetadataSectionState extends State<PermitMetadataSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    // Default: collapsed unless permit is required or explicitly set to expanded
    _isExpanded = widget.initiallyExpanded ?? widget.permitRequired;
  }

  @override
  void didUpdateWidget(covariant PermitMetadataSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If permit becomes required, expand the section
    if (widget.permitRequired && !oldWidget.permitRequired) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.supportsPermits) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.disabledMessage ??
                      'Permit metadata is disabled for this site. '
                          'Enable permit uploads under Site Capabilities to capture compliance data.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    // Build header with expand/collapse toggle
    final headerRow = InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.headerText,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              _isExpanded ? 'Hide' : 'Show',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headerRow,
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              Text(widget.helperText, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              _buildTextField(
                fieldKey: widget.permitIdFieldKey,
                label: 'Permit ID',
                controller: widget.permitIdController,
                value: widget.permitIdValue,
                onChanged: widget.onPermitIdChanged,
                enabled: widget.fieldsEnabled,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                fieldKey: widget.permitTypeFieldKey,
                label: 'Permit Type',
                controller: widget.permitTypeController,
                value: widget.permitTypeValue,
                onChanged: widget.onPermitTypeChanged,
                enabled: widget.fieldsEnabled,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                fieldKey: widget.issuingAuthorityFieldKey,
                label: 'Issuing Authority',
                controller: widget.issuingAuthorityController,
                value: widget.issuingAuthorityValue,
                onChanged: widget.onIssuingAuthorityChanged,
                enabled: widget.fieldsEnabled,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDateButton(
                      context: context,
                      value: widget.validFrom,
                      label: 'Valid From',
                      onPressed: widget.onPickValidFrom,
                      buttonKey: widget.validFromButtonKey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateButton(
                      context: context,
                      value: widget.validTo,
                      label: 'Valid To',
                      onPressed: widget.onPickValidTo,
                      buttonKey: widget.validToButtonKey,
                    ),
                  ),
                ],
              ),
              if (widget.onClearDates != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: widget.fieldsEnabled && widget.clearDatesEnabled
                        ? widget.onClearDates
                        : null,
                    child: Text(widget.clearDatesLabel),
                  ),
                ),
              if (widget.onClearDates != null) const SizedBox(height: 8),
              _buildTextField(
                fieldKey: widget.attachmentFieldKey,
                label: widget.attachmentLabel,
                controller: widget.attachmentUrlsController,
                value: widget.attachmentUrlsValue,
                onChanged: widget.onAttachmentUrlsChanged,
                enabled: widget.fieldsEnabled,
                minLines: 2,
                maxLines: 4,
                alignLabelWithHint: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    Key? fieldKey,
    required String label,
    TextEditingController? controller,
    String? value,
    ValueChanged<String>? onChanged,
    required bool enabled,
    int minLines = 1,
    int maxLines = 1,
    bool alignLabelWithHint = false,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      initialValue: controller == null ? value : null,
      onChanged: controller == null ? onChanged : null,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        alignLabelWithHint: alignLabelWithHint || maxLines > 1,
      ),
    );
  }

  Widget _buildDateButton({
    required BuildContext context,
    required DateTime? value,
    required String label,
    required VoidCallback onPressed,
    Key? buttonKey,
  }) {
    if (widget.dateButtonBuilder != null) {
      return widget.dateButtonBuilder!(
        value: value,
        label: label,
        onPressed: onPressed,
      );
    }
    final formatted = value == null
        ? 'Select'
        : DateFormat.yMMMd().format(value.toLocal());
    return OutlinedButton.icon(
      key: buttonKey,
      onPressed: widget.fieldsEnabled ? onPressed : null,
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: $formatted'),
      ),
    );
  }
}
