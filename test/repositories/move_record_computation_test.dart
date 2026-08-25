import 'package:flutter_test/flutter_test.dart';
import 'package:seafoundry_community/models/events/move_out_event.dart';
import 'package:seafoundry_community/models/events/move_in_event.dart';
import 'package:seafoundry_community/models/movement/partial_move_selection.dart';
import 'package:seafoundry_community/models/types/model_type.dart';

import '../support/move_computation_fakes.dart';

/// Unit tests for the pure per-node MOVE computation seam extracted for the
/// nested-transaction fix (PR-2), plus the key regression: the move-event
/// creators consume a PRE-MINTED slug and never mint (open a nested
/// transaction) when called inside an outer transaction.
///
/// These run under `flutter_test` (no emulator) because they assert the
/// branch/slug logic and call-ordering, not Firestore SDK nesting semantics.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const now = '2026-03-03T03:03:03.000Z';

  group('willSplitOnMove (split decision)', () {
    test('true when a partial quantity below the total is requested', () {
      final repos = buildMoveRepos();
      final source = buildOrganism(quantity: 10);
      final selection = const PartialMoveSelection(
        moveAll: false,
        partialQuantities: {'src-1': 4},
      );
      expect(repos.organisms.willSplitOnMove(source, selection), isTrue);
    });

    test('false for moveAll, null selection, or full/over quantity', () {
      final repos = buildMoveRepos();
      final source = buildOrganism(quantity: 10);
      expect(repos.organisms.willSplitOnMove(source, null), isFalse);
      expect(
        repos.organisms.willSplitOnMove(
          source,
          const PartialMoveSelection(moveAll: true),
        ),
        isFalse,
      );
      expect(
        repos.organisms.willSplitOnMove(
          source,
          const PartialMoveSelection(
            moveAll: false,
            partialQuantities: {'src-1': 10},
          ),
        ),
        isFalse,
      );
    });
  });

  group('computeMovedRecordForMove (full-move record op — U13)', () {
    test('organism -> group rebases urlPath/internalPath/groupId/siteId', () {
      final repos = buildMoveRepos();
      final source = buildOrganism();
      final dest = buildDestinationGroup();

      final moved = repos.organisms.computeMovedRecordForMove(
        record: source,
        toParent: dest,
        now: now,
      );

      expect(moved.id, source.id, reason: 'same doc id (full move)');
      expect(moved.slug, source.slug, reason: 'slug unchanged (no record slug)');
      expect(moved.urlPath, '${dest.urlPath}/${source.slug}');
      expect(moved.internalPath, '${dest.internalPath}/${source.id}');
      expect(moved.groupId, dest.id);
      expect(moved.siteId, dest.siteId);
      expect(moved.updatedAt, now);
    });

    test('organism -> non-group (else branch) rebases path only', () {
      final repos = buildMoveRepos();
      final source = buildOrganism();
      // A record standing in for a non-Group destination: reuse the source's
      // own record shape as a GraphNodeRecord parent.
      final dest = buildOrganism(
        id: 'dest-holder',
        slug: 'organismRecord-dest',
        urlPath: 'organizations/org1/groups/g9/records/dest-holder',
        internalPath: 'organizations/org1/groups/g9/records/dest-holder',
      );

      final moved = repos.organisms.computeMovedRecordForMove(
        record: source,
        toParent: dest,
        now: now,
      );

      expect(moved.urlPath, '${dest.urlPath}/${source.slug}');
      expect(moved.internalPath, '${dest.internalPath}/${source.id}');
      // else branch does not touch groupId/siteId
      expect(moved.groupId, source.groupId);
      expect(moved.siteId, source.siteId);
      expect(moved.updatedAt, now);
    });
  });

  group('computePartialMovedOrganism (split record op — U14)', () {
    test('new organism carries the requested qty, new slug/id/path, metadata',
        () {
      final repos = buildMoveRepos();
      final source = buildOrganism(quantity: 10);
      final dest = buildDestinationGroup();

      final moved = repos.organisms.computePartialMovedOrganism(
        record: source,
        toParent: dest,
        requestedQty: 4,
        newOrganismId: 'new-org-id',
        newSlug: 'organismRecord99',
        now: now,
      );

      expect(moved.id, 'new-org-id');
      expect(moved.slug, 'organismRecord99');
      expect(moved.urlPath, '${dest.urlPath}/organismRecord99');
      expect(moved.internalPath, '${dest.internalPath}/new-org-id');
      expect(moved.groupId, dest.id);
      expect(moved.siteId, dest.siteId);
      expect(moved.measurement.value, 4);
      expect(moved.metadata?['sourceOrganismId'], source.id);
      expect(moved.metadata?['splitFromAt'], now);
      expect(moved.createdAt, now);
    });
  });

  group('createMoveOutEvent / createMoveInEvent inside a transaction', () {
    test(
      'consume the passed slug and DO NOT mint (no nested slug transaction) — '
      'core PR-2 regression',
      () async {
        final repos = buildMoveRepos();
        final db = repos.db;
        final source = buildOrganism();
        final dest = buildDestinationGroup();

        late MoveOutEvent outEvent;
        late MoveInEvent inEvent;

        await db.runTransaction((txn) async {
          outEvent = await repos.events.createMoveOutEvent(
            source,
            source,
            dest,
            txn,
            slug: 'event-OUT',
            eventId: 'evt-out-id',
            quantity: 4,
          );
          inEvent = await repos.events.createMoveInEvent(
            source,
            source,
            dest,
            txn,
            slug: 'event-IN',
            eventId: 'evt-in-id',
            quantity: 4,
          );
        });

        expect(outEvent.slug, 'event-OUT');
        expect(outEvent.id, 'evt-out-id');
        expect(outEvent.urlPath, endsWith('/event-OUT'));
        expect(inEvent.slug, 'event-IN');
        expect(inEvent.id, 'evt-in-id');
        expect(inEvent.urlPath, endsWith('/event-IN'));

        // The regression guard: the event slug counter was NEVER touched. If a
        // future change re-adds `await nextSlugForModelType(...)` inside these
        // methods, the counter doc appears and this fails.
        final counter = await db
            .collection('organizations')
            .doc('org1')
            .collection('slugCounts')
            .doc(ModelType.event.name)
            .get();
        expect(
          counter.exists,
          isFalse,
          reason:
              'no slug should be minted inside the transaction; slugs are '
              'pre-minted by the GraphRepository move planner',
        );
      },
    );

    test('pre-minting via nextSlugForModelType DOES advance the counter', () async {
      final repos = buildMoveRepos();
      final db = repos.db;

      final s1 = await repos.events.nextSlugForModelType(ModelType.event);
      final s2 = await repos.events.nextSlugForModelType(ModelType.event);

      expect(s1, 'event1');
      expect(s2, 'event2');
      final counter = await db
          .collection('organizations')
          .doc('org1')
          .collection('slugCounts')
          .doc(ModelType.event.name)
          .get();
      expect(counter.get('count'), 2);
    });
  });

  group('moveEvents re-path (U17 — no slug consumed)', () {
    test('rewrites event urlPath/internalPath and mints nothing', () async {
      final repos = buildMoveRepos();
      final db = repos.db;
      final source = buildOrganism();
      final dest = buildDestinationGroup();

      // Seed one existing event under the source record.
      final existing = await repos.events.createObservationEvent(
        forRecord: source,
        comment: 'hello',
      );
      // createObservationEvent mints its own slug (outside any txn) -> counter=1.
      final beforeCounter = await db
          .collection('organizations')
          .doc('org1')
          .collection('slugCounts')
          .doc(ModelType.event.name)
          .get();
      final beforeCount = beforeCounter.get('count') as int;

      final moved = repos.organisms.computeMovedRecordForMove(
        record: source,
        toParent: dest,
        now: now,
      );

      await db.runTransaction((txn) async {
        await repos.events.moveEvents(
          events: [existing],
          fromRecord: source,
          toRecord: moved,
          transaction: txn,
        );
      });

      final rewritten = await db
          .collection(ModelType.event.collectionPath)
          .doc(existing.id)
          .get();
      final data = rewritten.data()!;
      expect(
        data['urlPath'],
        existing.urlPath.replaceFirst(source.urlPath, moved.urlPath),
      );
      expect(
        data['internalPath'],
        existing.internalPath.replaceFirst(source.internalPath, moved.internalPath),
      );

      final afterCounter = await db
          .collection('organizations')
          .doc('org1')
          .collection('slugCounts')
          .doc(ModelType.event.name)
          .get();
      expect(afterCounter.get('count'), beforeCount,
          reason: 're-pathing consumes no slug');
    });
  });
}
