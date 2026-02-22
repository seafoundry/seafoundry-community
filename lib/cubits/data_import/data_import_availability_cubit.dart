// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/constants/data_import_config.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/cubits/data_import/data_import_availability_state.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Cubit that tracks data import step availability based on existing data.
///
/// Combines streams from multiple repositories to determine which import
/// steps are available and which have been completed. Steps unlock
/// sequentially: Genetics -> Inventory -> Outplanting -> Monitoring.
///
/// ## Usage
/// ```dart
/// BlocProvider(
///   create: (context) => DataImportAvailabilityCubit(
///     genetRepository: context.read<GenetRepository>(),
///     organismRepository: context.read<OrganismRecordRepository>(),
///     eventRepository: context.read<EventRepository>(),
///   )..initialize(),
///   child: BlocBuilder<DataImportAvailabilityCubit, DataImportAvailabilityState>(
///     builder: (context, state) {
///       if (state.isLoading) return CircularProgressIndicator();
///       if (state.hasError) return ErrorWidget(state.error!);
///       return StepCards(availability: state.availability);
///     },
///   ),
/// )
/// ```
class DataImportAvailabilityCubit extends Cubit<DataImportAvailabilityState>
    with CubitStreamSubscriptionMixin {
  final GenetRepository _genetRepository;
  final OrganismRecordRepository _organismRepository;
  final EventRepository _eventRepository;

  DataImportAvailabilityCubit({
    required GenetRepository genetRepository,
    required OrganismRecordRepository organismRepository,
    required EventRepository eventRepository,
    OrganismKind initialOrganism = OrganismKind.coral,
  })  : _genetRepository = genetRepository,
        _organismRepository = organismRepository,
        _eventRepository = eventRepository,
        super(DataImportAvailabilityState.loading(
          selectedOrganism: initialOrganism,
        ));

  /// Start watching repository streams for the current organism filter.
  void initialize() {
    if (isClosed) return;
    _subscribeToAvailability();
  }

  /// Change the organism filter and resubscribe to streams.
  ///
  /// This cancels the previous subscription and creates a new one
  /// filtered by the selected organism kind.
  void setOrganismFilter(OrganismKind organism) {
    if (isClosed) return;
    if (organism == state.selectedOrganism) return;

    emit(DataImportAvailabilityState.loading(selectedOrganism: organism));
    _subscribeToAvailability();
  }

  void _subscribeToAvailability() {
    final organism = state.selectedOrganism;

    // Stream counts for each data type filtered by organism kind
    final geneticsStream = _genetRepository.streamAll.map(
      (genets) => genets.where((g) => g.organismKind == organism).length,
    );

    final inventoryStream = _organismRepository.streamAll.map(
      (records) => records.where((r) => r.organismKind == organism).length,
    );

    // Note: OutplantEvent and MonitoringEventRecord do not have an organismKind
    // field directly. The organism kind can only be determined by looking up the
    // organisms referenced in allocations/entries via their genetId or speciesId,
    // which would require additional repository queries. For now, we show the
    // total count across all organism kinds.
    final outplantingStream = _eventRepository.streamAll.map(
      (events) => events.whereType<OutplantEvent>().length,
    );

    final monitoringStream = _eventRepository.streamAll.map(
      (events) => events.whereType<MonitoringEventRecord>().length,
    );

    // Combine all four streams and compute availability
    listenWithKey<StepAvailability>(
      'availability',
      Rx.combineLatest4(
        geneticsStream,
        inventoryStream,
        outplantingStream,
        monitoringStream,
        (int genetics, int inventory, int outplanting, int monitoring) =>
            StepAvailability(
          geneticsAvailable: true,
          geneticsComplete: genetics > 0,
          inventoryAvailable: genetics > 0,
          inventoryComplete: inventory > 0,
          outplantingAvailable: inventory > 0,
          outplantingComplete: outplanting > 0,
          monitoringAvailable: outplanting > 0,
          monitoringComplete: monitoring > 0,
        ),
      ),
      onData: _handleAvailabilityUpdate,
      onError: _handleError,
    );
  }

  void _handleAvailabilityUpdate(StepAvailability availability) {
    if (isClosed) return;
    emit(DataImportAvailabilityState.loaded(
      availability: availability,
      selectedOrganism: state.selectedOrganism,
    ));
  }

  void _handleError(Object error, StackTrace stackTrace) {
    LoggingService.instance.error(
      'DataImportAvailabilityCubit: Stream error',
      error,
      stackTrace,
    );

    if (isClosed) return;
    emit(DataImportAvailabilityState.error(
      message: 'Failed to load import status. Please try again.',
      selectedOrganism: state.selectedOrganism,
    ));
  }
}
