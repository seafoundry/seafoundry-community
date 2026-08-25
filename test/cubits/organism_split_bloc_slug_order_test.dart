import 'package:flutter_test/flutter_test.dart';
import 'package:seafoundry_community/cubits/organism_split/organism_split_bloc.dart';
import 'package:seafoundry_community/cubits/organism_split/organism_split_state.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_step.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/types/inventory_change_reason.dart';

import '../support/txn_order_fakes.dart';

/// Test subclass exposing [emit] so the bloc's state can be seeded directly,
/// avoiding the multi-step form event flow.
class _SeedableSplitBloc extends OrganismSplitBloc {
  _SeedableSplitBloc({
    required super.sourceOrganism,
    required super.organismRepository,
    required super.graphRepository,
  });

  void seed(OrganismSplitState state) => emit(state);
}

OrganismSplitState _seededState(OrganismRecord source) {
  return OrganismSplitState(
    sourceOrganism: source,
    steps: [
      BaseRecordFormStep(
        title: 'Select Quantity',
        inputs: [
          SplitQuantityInput.dirty(value: 4, maxQuantity: 10),
        ],
      ),
      BaseRecordFormStep(
        title: 'Record Details',
        inputs: const [
          SplitRecordNameInput.dirty(value: 'Baby Frag'),
          SplitReasonInput.dirty(value: PhysicalFormChangeReason.fragmentation),
          SplitNotesInput.dirty(value: 'note'),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SPLIT mints both slugs BEFORE entering the transaction (2 mints, ordered)',
    () async {
      final log = CallLog();
      final source = makeOrganism(id: 'src-1', tagId: 'Original');
      final db = RecordingFirestore(log, source);
      final repo = FakeOrganismRecordRepository(db: db, log: log);

      final bloc = _SeedableSplitBloc(
        sourceOrganism: source,
        organismRepository: repo,
        graphRepository: FakeGraphRepository(),
      );
      bloc.seed(_seededState(source));

      await bloc.createRecord();

      // Regression guard: exactly two slug mints, both before runTransaction.
      expect(
        log.entries,
        ['slug:organismRecord', 'slug:event', 'runTransaction'],
        reason: 'both slugs must be pre-minted outside the outer transaction',
      );
      expect(log.slugEntries.length, 2);
      expect(
        log.slugEntries.every(
          (e) => log.entries.indexOf(e) < log.transactionIndex,
        ),
        isTrue,
      );

      await bloc.close();
    },
  );
}
