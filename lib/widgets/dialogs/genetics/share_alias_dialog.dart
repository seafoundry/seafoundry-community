// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/services/alias_uniqueness_service.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

class ShareAliasDialogResult {
  ShareAliasDialogResult({required this.alias, required this.entry});

  final OrganismAlias alias;
  final AliasIndexEntry entry;
}

Future<ShareAliasDialogResult?> showShareAliasDialog({
  required BuildContext context,
  AliasUniquenessService? aliasService,
}) {
  final service = aliasService ??
      AliasUniquenessService(
        firestore: context.read<FirebaseService>().firestore,
      );
  return showDialog<ShareAliasDialogResult>(
    context: context,
    useRootNavigator: false,
    builder: (context) => _ShareAliasDialog(aliasService: service),
  );
}

class _ShareAliasDialog extends StatefulWidget {
  const _ShareAliasDialog({required this.aliasService});

  final AliasUniquenessService aliasService;

  @override
  State<_ShareAliasDialog> createState() => _ShareAliasDialogState();
}

class _ShareAliasDialogState extends State<_ShareAliasDialog>
    with SafeDialogMixin<_ShareAliasDialog> {
  late String _sourceSystem;
  final TextEditingController _valueController = TextEditingController();
  AliasIndexEntry? _entry;
  String? _error;
  bool _isLookupInFlight = false;

  @override
  void initState() {
    super.initState();
    _sourceSystem = AliasUniquenessService.defaultSystems.keys.first;
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _entry == null || _isLookupInFlight;
    return AlertDialog(
      title: const Text('Share Existing Alias'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _sourceSystem,
            items: [
              ...AliasUniquenessService.defaultSystems.entries.map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              ),
              const DropdownMenuItem<String>(
                value: 'custom',
                child: Text('Custom source…'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              if (value == 'custom') {
                _promptCustomSource();
                return;
              }
              setState(() => _sourceSystem = value);
            },
            decoration: const InputDecoration(labelText: 'Source System'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueController,
            decoration: InputDecoration(
              labelText: 'Alias value',
              errorText: _error,
              helperText: 'Enter the identifier you want to adopt',
            ),
            onSubmitted: (_) => _lookupAlias(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _isLookupInFlight ? null : _lookupAlias,
              icon: _isLookupInFlight
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: const Text('Lookup alias'),
            ),
          ),
          if (_entry != null) ...[
            const SizedBox(height: 12),
            _AliasEntryDetails(entry: _entry!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLookupInFlight ? null : () => popDialog(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: disabled ? null : _submit,
          child: const Text('Share alias'),
        ),
      ],
    );
  }

  Future<void> _promptCustomSource() async {
    final controller = TextEditingController(text: _sourceSystem);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Source'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter system name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (context.mounted) Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null && value.trim().isNotEmpty) {
      setState(() => _sourceSystem = value.trim());
    }
  }

  Future<void> _lookupAlias() async {
    final value = _valueController.text.trim();
    if (value.isEmpty) {
      setState(() {
        _error = 'Alias value is required';
        _entry = null;
      });
      return;
    }
    setState(() {
      _isLookupInFlight = true;
      _error = null;
      _entry = null;
    });
    final alias = OrganismAlias(sourceSystem: _sourceSystem, value: value);
    try {
      final result = await widget.aliasService.fetchAlias(alias);
      if (mounted) {
        setState(() {
          _entry = result;
          _error = result == null
              ? 'Alias "$value" was not found. Verify the value and try again.'
              : null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Lookup failed: $error';
          _entry = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLookupInFlight = false);
      }
    }
  }

  void _submit() {
    final entry = _entry;
    if (entry == null) return;
    final alias = OrganismAlias(
      sourceSystem: _sourceSystem,
      value: _valueController.text.trim(),
    );
    popDialog(ShareAliasDialogResult(alias: alias, entry: entry));
  }
}

class _AliasEntryDetails extends StatelessWidget {
  const _AliasEntryDetails({required this.entry});

  final AliasIndexEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alias found',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text('Record ID: ${entry.recordId}'),
        Text('Model: ${entry.modelType.name}'),
        if (entry.provenanceId.isNotEmpty) Text('Provenance ID: ${entry.provenanceId}'),
        const SizedBox(height: 8),
        Text(
          'Organizations referencing this alias:',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        if (entry.organizationRefs.isEmpty)
          Text(
            'No organizations currently linked.',
            style: theme.textTheme.bodySmall,
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entry.organizationRefs.entries
                .map(
                  (org) => Text(
                    '${org.key} • local ID: ${org.value.localId}',
                    style: theme.textTheme.bodySmall,
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}
