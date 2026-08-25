import 'package:flutter_test/flutter_test.dart';
import 'package:seafoundry_community/cubits/organism_merge/organism_merge_bloc.dart';
import 'package:seafoundry_community/cubits/organism_merge/organism_merge_state.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_step.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/types/inventory_change_reason.dart';

import '../support/txn_order_fakes.dart';

/// Test subclass exposing [emit] so the bloc's state can be seeded directly.
class _SeedableMergeBloc extends OrganismMergeBloc {
  _SeedableMergeBloc({
    required super.availableOrganisms,
    required super.organismRepository,
    required super.graphRepository,
  });

  void seed(OrganismMergeState state) => emit(state);
}

OrganismMergeState _seededState(List<OrganismRecord> available, String targetId) {
  final selection = available.map((o) => o.id).toSet();
  return OrganismMergeState(
    availableOrganisms: available,
    steps: [
      BaseRecordFormStep(
        title: 'Select Records & Target',
        inputs: [
          MergeRecordSelectionInput.dirty(value: selection),
          MergeTargetInput.dirty(value: targetId),
        ],
      ),
      BaseRecordFormStep(
        title: 'Record Details',
        inputs: const [
          MergeRecordNameInput.dirty(value: 'Merged Colony'),
          MergeReasonInput.dirty(value: PhysicalFormChangeReason.fusion),
          MergeNotesInput.dirty(value: 'note'),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'MERGE mints the single event slug BEFORE entering the transaction',
    () async {
      final log = CallLog();
      final target = makeOrganism(id: 'tgt-1', tagId: 'Target');
      final absorbed = makeOrganism(id: 'abs-1', tagId: 'Absorbed');
      final available = [target, absorbed];
      final db = RecordingFirestore(log, target);
      final repo = FakeOrganismRecordRepository(db: db, log: log);

      final bloc = _SeedableMergeBloc(
        availableOrganisms: available,
        organismRepository: repo,
        graphRepository: FakeGraphRepository(),
      );
      bloc.seed(_seededState(available, target.id));

      await bloc.createRecord();

      // Regression guard: exactly one slug mint, before runTransaction.
      expect(
        log.entries,
        ['slug:event', 'runTransaction'],
        reason: 'the event slug must be pre-minted outside the outer transaction',
      );
      expect(log.slugEntries.length, 1);
      expect(log.transactionIndex, greaterThan(0));

      await bloc.close();
    },
  );
}
