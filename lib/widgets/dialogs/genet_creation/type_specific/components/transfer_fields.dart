// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/info_tooltip_icon.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

import 'date_fields.dart';
import '../../../components/dialog_scroll_view.dart';

class TransferTargetPicker extends StatefulWidget {
  const TransferTargetPicker({super.key});

  @override
  State<TransferTargetPicker> createState() => _TransferTargetPickerState();
}

class _TransferTargetPickerState extends State<TransferTargetPicker>
    with SafeDialogMixin<TransferTargetPicker> {
  final TextEditingController _orgQuery = TextEditingController();
  Timer? _timer;
  bool _searching = false;
  List<Organization> _results = [];

  @override
  void dispose() {
    _timer?.cancel();
    _orgQuery.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search('');
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _searching = true;
    });

    try {
      final repository = context.read<OrganizationRepository>();
      final response = await repository.searchOrganizations(
        query: query.trim(),
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _results = response.items;
        _searching = false;
      });
    } catch (e, stack) {
      LoggingService.instance.error('Organization search failed', e, stack);
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
      });
      showDialogSnackBar('Failed to search organizations', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final state = context.watch<GenetCreationBloc>().state;
    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }

    final formState = state.formState;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _orgQuery,
          decoration: const InputDecoration(
            labelText: 'Search partner organization',
            border: OutlineInputBorder(),
            suffixIcon: InfoTooltipIcon(
              message:
                  'Look up partner organizations to record transfer provenance.',
            ),
          ),
          onChanged: (v) {
            _timer?.cancel();
            if (v.trim().isEmpty) {
              _search('');
              return;
            }
            _timer = Timer(const Duration(milliseconds: 300), () => _search(v));
          },
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        SizedBox(
          height: 120,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: DialogScrollView(
              child: Column(
                children: [
                  ListTile(
                    title: Text('Unknown Organization'),
                    subtitle: Text('unknown'),
                    trailing: formState.transferOrgId == 'unknown'
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      bloc.onTransferOrgChanged('unknown');
                      _orgQuery.text = 'unknown';
                    },
                  ),
                  if (_results.isEmpty && !_searching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No organizations found. Try a different search term.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ..._results.map((org) {
                    final selected = formState.transferOrgId == org.id;
                    return ListTile(
                      title: Text(org.name),
                      subtitle: Text(org.domain),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        bloc.onTransferOrganizationSelected(org);
                        _orgQuery.text = org.name;
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TransferCollectorField extends StatelessWidget {
  const TransferCollectorField({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final state = context.watch<GenetCreationBloc>().state;
    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }

    final formState = state.formState;
    return TextFormField(
      key: ValueKey(formState.provCollector.value),
      decoration: const InputDecoration(
        labelText: 'Collector',
        border: OutlineInputBorder(),
        suffixIcon: InfoTooltipIcon(
          message:
              'Name of the individual or team who provided this genet to you.',
        ),
      ),
      initialValue: formState.provCollector.value,
      onChanged: bloc.onProvCollectorChanged,
    );
  }
}

class TransferInstitutionField extends StatelessWidget {
  const TransferInstitutionField({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final state = context.watch<GenetCreationBloc>().state;
    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }

    final formState = state.formState;
    return TextFormField(
      key: ValueKey(formState.provInstitution.value),
      decoration: const InputDecoration(
        labelText: 'Collecting Institution',
        hintText: 'Organization that transferred this genet',
        border: OutlineInputBorder(),
        suffixIcon: InfoTooltipIcon(
          message:
              'If the partner organization was not found, enter their name here.',
        ),
      ),
      initialValue: formState.provInstitution.value,
      onChanged: bloc.onTransferOrgNameEdited,
    );
  }
}

class TransferEmailField extends StatelessWidget {
  const TransferEmailField({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final state = context.watch<GenetCreationBloc>().state;
    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }

    final formState = state.formState;
    return TextFormField(
      key: ValueKey(formState.transferEmail),
      decoration: const InputDecoration(
        labelText: 'Partner email',
        hintText: 'contact@example.org',
        border: OutlineInputBorder(),
        suffixIcon: InfoTooltipIcon(
          message:
              'Email we can use to invite the partner to join SeaFoundry.',
        ),
      ),
      initialValue: formState.transferEmail,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      onChanged: bloc.onTransferEmailChanged,
    );
  }
}

class TransferDateField extends StatelessWidget {
  const TransferDateField({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final state = context.watch<GenetCreationBloc>().state;
    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }

    final formState = state.formState;
    final selectedDate = formState.transferDate.value;
    final hasError = formState.sendTransfer && selectedDate == null;

    return GenetDatePickerField(
      label: 'Transfer Date *',
      placeholder: 'Select a transfer date',
      selectedDate: selectedDate,
      onDateSelected: bloc.onTransferDateChanged,
      errorText: hasError ? 'Transfer date is required' : null,
      tooltip:
          'Date when the genet was received from the partner organization.',
    );
  }
}

class TransferNotesField extends StatelessWidget {
  const TransferNotesField({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final state = context.watch<GenetCreationBloc>().state;
    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }

    final formState = state.formState;
    final hasError =
        formState.sendTransfer && formState.transferNotes.value.trim().isEmpty;
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Transfer Notes *',
        border: const OutlineInputBorder(),
        errorText: hasError ? 'Transfer notes are required' : null,
        suffixIcon: const InfoTooltipIcon(
          message:
              'Record context provided by the partner organization during the transfer.',
        ),
      ),
      initialValue: formState.transferNotes.value,
      maxLines: 2,
      onChanged: bloc.onTransferNotesChanged,
    );
  }
}