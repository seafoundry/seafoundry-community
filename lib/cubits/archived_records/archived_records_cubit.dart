// @tier: community
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import 'archived_records_state.dart';

class ArchivedRecordsCubit extends Cubit<ArchivedRecordsState> {
  ArchivedRecordsCubit({
    required ArchivedOrganismRecordRepository organismRepository,
    required ArchivedGenetRepository genetRepository,
    required ArchivedMissionRepository missionRepository,
  })  : _organismRepository = organismRepository,
        _genetRepository = genetRepository,
        _missionRepository = missionRepository,
        super(const ArchivedRecordsState()) {
    _organismSubscription = _organismRepository.streamAll().listen(
      (records) => emit(state.copyWith(organisms: records)),
    );
    _genetSubscription = _genetRepository.streamAll().listen(
      (records) => emit(state.copyWith(genets: records)),
    );
    _missionSubscription = _missionRepository.streamAll().listen(
      (records) => emit(state.copyWith(missions: records)),
    );
  }

  final ArchivedOrganismRecordRepository _organismRepository;
  final ArchivedGenetRepository _genetRepository;
  final ArchivedMissionRepository _missionRepository;

  late final StreamSubscription<List<OrganismRecord>> _organismSubscription;
  late final StreamSubscription<List<Genet>> _genetSubscription;
  late final StreamSubscription<List<Mission>> _missionSubscription;

  Future<void> restoreOrganism(OrganismRecord record) {
    return _organismRepository.restoreRecord(record);
  }

  Future<void> restoreGenet(Genet genet) {
    return _genetRepository.restoreGenet(genet);
  }

  Future<void> restoreMission(Mission mission) {
    return _missionRepository.restoreMission(mission);
  }

  @override
  Future<void> close() async {
    await _organismSubscription.cancel();
    await _genetSubscription.cancel();
    await _missionSubscription.cancel();
    return super.close();
  }
}
