// @tier: community
import 'package:equatable/equatable.dart';

import '../../models/models.dart';

class ArchivedRecordsState extends Equatable {
  const ArchivedRecordsState({
    this.organisms = const <OrganismRecord>[],
    this.genets = const <Genet>[],
    this.missions = const <Mission>[],
  });

  final List<OrganismRecord> organisms;
  final List<Genet> genets;
  final List<Mission> missions;

  ArchivedRecordsState copyWith({
    List<OrganismRecord>? organisms,
    List<Genet>? genets,
    List<Mission>? missions,
  }) {
    return ArchivedRecordsState(
      organisms: organisms ?? this.organisms,
      genets: genets ?? this.genets,
      missions: missions ?? this.missions,
    );
  }

  @override
  List<Object?> get props => [organisms, genets, missions];
}
