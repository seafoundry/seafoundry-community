// @tier: pro
// ignore_for_file: deprecated_member_use_from_same_package
// NOTE: This file is a template for community builds - copied and patched during sync
import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/cubits/navigation/deep_link_cubit.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/cubits/navigation_view_mode/navigation_view_mode_cubit.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/organism_context.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/repositories/repositories.dart';
// Pro-tier repositories (not exported from barrel)
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/services/services.dart';
// Pro-tier services (not exported from barrel)
import 'package:seafoundry_app/navigation/navigation_cubit_connector.dart';
import 'package:seafoundry_app/widgets/navigation/deep_link_feedback_listener.dart';
import 'package:seafoundry_app/widgets/repositories/registry/registry.dart';

class RepositoriesProviderWrapper extends StatelessWidget {
  const RepositoriesProviderWrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CurrentUser, CurrentUserState>(
      // CRITICAL: Only rebuild when user/org identity changes, not on every stream update.
      // Without this, each Firestore stream emission (even with identical data) creates
      // new User/Organization instances which trigger rebuilds, recreating RepositoriesProvider
      // and NavigationCubit, which resets navigation state.
      buildWhen: (previous, current) {
        // Always rebuild when transitioning to/from loaded state
        if (previous is! CurrentUserLoaded || current is! CurrentUserLoaded) {
          return true;
        }
        // Only rebuild if user or organization identity changes
        return previous.user.id != current.user.id ||
            previous.organization.id != current.organization.id;
      },
      builder: (context, currentUserState) {
        if (currentUserState is! CurrentUserLoaded) {
          return child;
        }

        final user = currentUserState.user;
        final organization = currentUserState.organization;

        return RepositoriesProvider(
          key: ValueKey('${user.id}-${organization.id}'),
          user: user,
          organization: organization,
          initialPath: currentUserState.targetPath,
          child: child,
        );
      },
    );
  }
}

class RepositoriesProvider extends StatefulWidget {
  const RepositoriesProvider({
    super.key,
    required this.user,
    required this.organization,
    this.initialPath,
    required this.child,
  });

  final User user;
  final Organization organization;
  final String? initialPath;
  final Widget child;

  @override
  State<RepositoriesProvider> createState() => _RepositoriesProviderState();
}

class _RepositoriesProviderState extends State<RepositoriesProvider> {
  late List<SingleChildWidget> _repositoryProviders;
  late GraphRepository _graphRepository;
  late EventPropagationService _eventPropagationService;
  late OrganismContext _organismContext;
  late Map<OrganismKind, OrganismContext> _organismContexts;
  late TaxonomyService _taxonomyService;
  late SpeciesRegistry _speciesRegistry;
  late SiteBaselineService _siteBaselineService;
  late RepositoryRegistry _registry;
  late HoldingSummaryService _holdingSummaryService;
  late OrganismRecordChangeService _organismRecordChangeService;
  late Map<OrganismKind, SeededLineRepository> _seededLineRepositories;
  late Map<OrganismKind, OysterBagRepository> _oysterBagRepositories;
  late Map<OrganismKind, GameteBatchRepository> _gameteBatchRepositories;
  late Map<OrganismKind, LarvalBatchRepository> _larvalBatchRepositories;
  late Map<OrganismKind, FinfishPenRepository> _finfishPenRepositories;
  late Map<OrganismKind, CrabPondRepository> _crabPondRepositories;
  late Map<OrganismKind, SeagrassModuleRepository>
  _seagrassModuleRepositories;
  late Map<OrganismKind, MangrovePlotRepository>
  _mangrovePlotRepositories;
  late Map<OrganismKind, UrchinTankRepository> _urchinTankRepositories;
  late Map<OrganismKind, SeaCucumberTankRepository>
  _seaCucumberTankRepositories;
  late Map<OrganismKind, ActivityEventRepository>
  _activityEventRepositories;
  late Map<OrganismKind, OrganismRecordRepository>
  _organismRecordRepositories;
  late StructureCapacityService _structureCapacityService;
  late FeatureAccessService _featureAccessService;
  late DeliverableRepository _deliverableRepository;
  static const _environmentalThresholdsDocId = 'environmental_thresholds';
  static const _validationRulesDocId = 'validation_rules';
  static const _mortalityCausesDocId = 'mortality_causes';

  @override
  void initState() {
    super.initState();
    _buildRepositoryProviders();
  }

  @override
  void dispose() {
    // NOTE: HoldingRepository subclasses do NOT need disposal
    for (final repo in _activityEventRepositories.values) {
      repo.dispose();
    }

    // Dispose OrganismRecordRepository instances
    for (final repo in _organismRecordRepositories.values) {
      repo.dispose();
    }

    // Dispose graph repository
    _graphRepository.dispose();

    // Dispose custom type resolver service (cancels Firestore subscriptions)

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: _repositoryProviders,
      child: MultiProvider(
        providers: [
          Provider<User>.value(value: widget.user),
          Provider<Organization>.value(value: widget.organization),
          Provider<EventPropagationService>.value(
            value: _eventPropagationService,
          ),
          Provider<TaxonomyService?>.value(value: _taxonomyService),
          ChangeNotifierProvider<SpeciesRegistry>.value(
            value: _speciesRegistry,
          ),
          ChangeNotifierProvider<FeatureAccessService>.value(
            value: _featureAccessService,
          ),
          Provider<OrganismContext>.value(value: _organismContext),
          Provider<SiteBaselineService>.value(value: _siteBaselineService),
          Provider<StructureCapacityService>.value(
            value: _structureCapacityService,
          ),
          Provider<RepositoryRegistry>.value(
            value: _registry,
          ),
          Provider<HoldingSummaryService>.value(value: _holdingSummaryService),
          Provider<Map<OrganismKind, SeededLineRepository>>.value(
            value: UnmodifiableMapView(_seededLineRepositories),
          ),
          Provider<Map<OrganismKind, OysterBagRepository>>.value(
            value: UnmodifiableMapView(_oysterBagRepositories),
          ),
          Provider<Map<OrganismKind, GameteBatchRepository>>.value(
            value: UnmodifiableMapView(_gameteBatchRepositories),
          ),
          Provider<Map<OrganismKind, LarvalBatchRepository>>.value(
            value: UnmodifiableMapView(_larvalBatchRepositories),
          ),
          Provider<Map<OrganismKind, FinfishPenRepository>>.value(
            value: UnmodifiableMapView(_finfishPenRepositories),
          ),
          Provider<Map<OrganismKind, CrabPondRepository>>.value(
            value: UnmodifiableMapView(_crabPondRepositories),
          ),
          Provider<Map<OrganismKind, SeagrassModuleRepository>>.value(
            value: UnmodifiableMapView(_seagrassModuleRepositories),
          ),
          Provider<Map<OrganismKind, UrchinTankRepository>>.value(
            value: UnmodifiableMapView(_urchinTankRepositories),
          ),
          Provider<Map<OrganismKind, SeaCucumberTankRepository>>.value(
            value: UnmodifiableMapView(_seaCucumberTankRepositories),
          ),
          Provider<Map<OrganismKind, MangrovePlotRepository>>.value(
            value: UnmodifiableMapView(_mangrovePlotRepositories),
          ),
          Provider<Map<OrganismKind, OrganismRecordRepository>>.value(
            value: UnmodifiableMapView(_organismRecordRepositories),
          ),
          Provider<Map<OrganismKind, ActivityEventRepository>>.value(
            value: UnmodifiableMapView(_activityEventRepositories),
          ),
          Provider<OrganismRecordRepository>.value(
            value: _organismRecordRepositories[_organismContext.kind]!,
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<NavigationCubit>(
              create: (_) =>
                  NavigationCubit(graphRepository: _graphRepository)
                    ..initialize(initialPath: widget.initialPath),
            ),
            BlocProvider<DeepLinkCubit>(
              create: (context) => DeepLinkCubit(
                deepLinkService: DeepLinkService(),
                resolver: DeepLinkCubit.resolverForGraphRepository(
                  _graphRepository,
                ),
                navigator: (node) async {
                  await context.read<NavigationCubit>().navigateTo(node);
                },
              ),
            ),
            BlocProvider<NavigationViewModeCubit>(
              create: (_) => NavigationViewModeCubit(
                hasOrganization: widget.organization.id.isNotEmpty,
              ),
            ),
          ],
          child: NavigationCubitConnector(
            child: DeepLinkFeedbackListener(child: widget.child),
          ),
        ),
      ),
    );
  }

  void _buildRepositoryProviders() {
    final user = widget.user;
    final organization = widget.organization;

    // Initialize FeatureAccessService with community tier
    _featureAccessService = FeatureAccessService(
      defaultTier: Tier.community,
      organizationTier: 'community',
    );
    unawaited(_featureAccessService.loadManifest());

    final firebaseService = context.read<FirebaseService>();
    final firestore = firebaseService.firestore;

    // Initialize custom types repository and resolver service
    // Community tier uses these for readonly access to builtin types

    // Initialize deliverable repository for permit tracking
    _deliverableRepository = DeliverableRepository(firestore: firestore);

    // Create RecordRepository for user and invitation management
    final recordRepository = RecordRepository(db: firestore);

    _organismContexts = _buildOrganismContexts();
    _organismContext = _organismContexts.values.first;
    _taxonomyService = TaxonomyService(firestore: firestore);
    _speciesRegistry = SpeciesRegistry(taxonomyService: _taxonomyService);
    SpeciesRegistry.installGlobal(_speciesRegistry);
    unawaited(_speciesRegistry.refresh());
    _siteBaselineService = SiteBaselineService(firestore: firestore);
    _structureCapacityService = StructureCapacityService.disabled();
    _organismRecordChangeService = const OrganismRecordChangeService();
    unawaited(_structureCapacityService.ensureInitialized());
    unawaited(
      _structureCapacityService.refreshOverrides(
        organizationId: organization.id,
      ),
    );
    final organismConfigFuture = _initializeOrganismConfigs(firestore);
    unawaited(organismConfigFuture);

    final eventRepository = OrganismAwareEventRepository(
      user: user,
      organization: organization,
      firestore: firestore,
      organismContext: _organismContext,
    );

    final organizationRepository = OrganizationRepository(firestore: firestore);

    final snapshotService = SnapshotService(
      firestore: firestore,
      tier: _featureAccessService.tier,
    );

    final siteRepository = SiteRepository(
      organization: organization,
      user: user,
      eventRepository: eventRepository,
      snapshotService: snapshotService,
      firestore: firestore,
    )..initialize();
    final groupRepository = GroupRepository(
      organization: organization,
      user: user,
      eventRepository: eventRepository,
      snapshotService: snapshotService,
      firestore: firestore,
      structureCapacityService: _structureCapacityService,
      siteRepository: siteRepository,
    )..initialize();
    final genetRepository = GenetRepository(
      organization: organization,
      user: user,
      eventRepository: eventRepository,
      snapshotService: snapshotService,
      organizationRepository: organizationRepository,
      firestore: firestore,
      recordRepository: recordRepository,
    )..initialize();
    final provenanceRepository = ProvenanceRepository(
      organization: organization,
      user: user,
      firestore: firestore,
      eventRepository: eventRepository,
      snapshotService: snapshotService,
    );

    // Create Provenance crosswalk service for community genetics integration
    final crosswalkService = ProvenanceCrosswalkService(firestore: firestore);
    final provenanceLookupService = ProvenanceLookupService(
      crosswalkService: crosswalkService,
    );

    final cohortRepositories = <OrganismKind, CohortRepository>{};
    final reproductiveEventRepositories =
        <OrganismKind, ReproductiveEventRepository>{};
    final seededLineRepositories = <OrganismKind, SeededLineRepository>{};
    final oysterBagRepositories = <OrganismKind, OysterBagRepository>{};
    final gameteBatchRepositories = <OrganismKind, GameteBatchRepository>{};
    final larvalBatchRepositories = <OrganismKind, LarvalBatchRepository>{};
    final finfishPenRepositories = <OrganismKind, FinfishPenRepository>{};
    final crabPondRepositories = <OrganismKind, CrabPondRepository>{};
    final seagrassModuleRepositories =
        <OrganismKind, SeagrassModuleRepository>{};
    final mangrovePlotRepositories = <OrganismKind, MangrovePlotRepository>{};
    final urchinTankRepositories = <OrganismKind, UrchinTankRepository>{};
    final seaCucumberTankRepositories =
        <OrganismKind, SeaCucumberTankRepository>{};
    final activityEventRepositories = <OrganismKind, ActivityEventRepository>{};
    final organismRecordRepositories =
        <OrganismKind, OrganismRecordRepository>{};
    _seededLineRepositories = seededLineRepositories;
    _oysterBagRepositories = oysterBagRepositories;
    _gameteBatchRepositories = gameteBatchRepositories;
    _larvalBatchRepositories = larvalBatchRepositories;
    _finfishPenRepositories = finfishPenRepositories;
    _crabPondRepositories = crabPondRepositories;
    _seagrassModuleRepositories = seagrassModuleRepositories;
    _mangrovePlotRepositories = mangrovePlotRepositories;
    _urchinTankRepositories = urchinTankRepositories;
    _seaCucumberTankRepositories = seaCucumberTankRepositories;
    _activityEventRepositories = activityEventRepositories;
    _organismRecordRepositories = organismRecordRepositories;
    SeededLineRepository? seededLineRepository;
    OysterBagRepository? oysterBagRepository;
    GameteBatchRepository? gameteBatchRepository;
    LarvalBatchRepository? larvalBatchRepository;
    _organismContexts.forEach((kind, context) {
      organismRecordRepositories[kind] = OrganismRecordRepository(
        organization: organization,
        user: user,
        firestore: firestore,
        eventRepository: eventRepository,
        organismContext: context,
        structureCapacityService: _structureCapacityService,
      )..initialize();

      cohortRepositories[kind] = CohortRepository(
        organization: organization,
        user: user,
        firestore: firestore,
        eventRepository: eventRepository,
        changeService: _organismRecordChangeService,
        organismContext: context,
        structureCapacityService: _structureCapacityService,
      );
      reproductiveEventRepositories[kind] = ReproductiveEventRepository(
        organization: organization,
        user: user,
        firestore: firestore,
        organismContext: context,
      );
      gameteBatchRepositories[kind] = GameteBatchRepository(
        organization: organization,
        user: user,
        firestore: firestore,
        eventRepository: eventRepository,
        changeService: _organismRecordChangeService,
        snapshotService: snapshotService,
        organismContext: context,
        structureCapacityService: _structureCapacityService,
      );
      larvalBatchRepositories[kind] = LarvalBatchRepository(
        organization: organization,
        user: user,
        firestore: firestore,
        eventRepository: eventRepository,
        changeService: _organismRecordChangeService,
        snapshotService: snapshotService,
        organismContext: context,
        structureCapacityService: _structureCapacityService,
      );
      if (kind == OrganismKind.oyster) {
        final repository = OysterBagRepository(
          organization: organization,
          user: user,
          firestore: firestore,
          eventRepository: eventRepository,
          changeService: _organismRecordChangeService,
          snapshotService: snapshotService,
          organismContext: context,
          structureCapacityService: _structureCapacityService,
        );
        oysterBagRepositories[kind] = repository;
        if (kind == _organismContext.kind) {
          oysterBagRepository = repository;
        }
      }
      if (kind == OrganismKind.kelp) {
        final repository = SeededLineRepository(
          organization: organization,
          user: user,
          firestore: firestore,
          eventRepository: eventRepository,
          changeService: _organismRecordChangeService,
          snapshotService: snapshotService,
          organismContext: context,
          structureCapacityService: _structureCapacityService,
        );
        seededLineRepositories[kind] = repository;
        if (kind == _organismContext.kind) {
          seededLineRepository = repository;
        }
      }
      if (kind == _organismContext.kind) {
        gameteBatchRepository = gameteBatchRepositories[kind];
        larvalBatchRepository = larvalBatchRepositories[kind];
      }
      if (kind == OrganismKind.finfish) {
        final repository = FinfishPenRepository(
          organization: organization,
          user: user,
          firestore: firestore,
          eventRepository: eventRepository,
          changeService: _organismRecordChangeService,
          snapshotService: snapshotService,
          organismContext: context,
          structureCapacityService: _structureCapacityService,
        );
        finfishPenRepositories[kind] = repository;
      }
      if (kind == OrganismKind.crab) {
        final repository = CrabPondRepository(
          organization: organization,
          user: user,
          firestore: firestore,
          eventRepository: eventRepository,
          changeService: _organismRecordChangeService,
          snapshotService: snapshotService,
          organismContext: context,
          structureCapacityService: _structureCapacityService,
        );
        crabPondRepositories[kind] = repository;
      }
      if (kind == OrganismKind.seagrass) {
        final repository = SeagrassModuleRepository(
          organization: organization,
          user: user,
          firestore: firestore,
          eventRepository: eventRepository,
          changeService: _organismRecordChangeService,
          snapshotService: snapshotService,
          organismContext: context,
          structureCapacityService: _structureCapacityService,
        );
        seagrassModuleRepositories[kind] = repository;
      }
      if (kind == OrganismKind.mangrove) {
        final repository = MangrovePlotRepository(
          organization: organization,
          user: user,
          firestore: firestore,
          eventRepository: eventRepository,
          changeService: _organismRecordChangeService,
          snapshotService: snapshotService,
          organismContext: context,
          structureCapacityService: _structureCapacityService,
        );
        mangrovePlotRepositories[kind] = repository;
      }
      if (kind == OrganismKind.echinoid) {
        final repository = UrchinTankRepository(
          organization: organization,
          user: user,
          firestore: firestore,
          eventRepository: eventRepository,
          changeService: _organismRecordChangeService,
          snapshotService: snapshotService,
          organismContext: context,
          structureCapacityService: _structureCapacityService,
        );
        urchinTankRepositories[kind] = repository;
      }
      if (kind == OrganismKind.seaCucumber) {
        final repository = SeaCucumberTankRepository(
          organization: organization,
          user: user,
          firestore: firestore,
          eventRepository: eventRepository,
          changeService: _organismRecordChangeService,
          snapshotService: snapshotService,
          organismContext: context,
          structureCapacityService: _structureCapacityService,
        );
        seaCucumberTankRepositories[kind] = repository;
      }
      activityEventRepositories[kind] = ActivityEventRepository(
        organization: organization,
        user: user,
        firestore: firestore,
        organismContext: context,
      );
    });
    final cohortRepository = cohortRepositories[_organismContext.kind]!;
    final reproductiveEventRepository =
        reproductiveEventRepositories[_organismContext.kind]!;
    final activityEventRepository =
        activityEventRepositories[_organismContext.kind]!;
    _graphRepository = GraphRepository(
      eventRepository: eventRepository,
      siteRepository: siteRepository,
      groupRepository: groupRepository,
      organismRecordRepository: _organismRecordRepositories[_organismContext.kind]!,
      genetRepository: genetRepository,
      recordRepository: recordRepository,
      firestore: firestore,
    );

    // CSVImportService removed - community tier doesn't include CSV import

    CsvTranslationAdapterRegistry.instance.installAdaptersForOrganization(
      organization,
    );

    final eventHistoryRepository = EventHistoryRepository(
      firestore: firestore,
      organization: organization,
    );
    final snapshotRepository = SnapshotRepository(
      firestore: firestore,
      organizationId: organization.id,
      tier: _featureAccessService.tier,
    );
    _registry = RepositoryRegistry()
      ..setDefaultOrganismKind(_organismContext.kind)
      ..registerForKind<SiteRepository>(_organismContext.kind, instance: siteRepository)
      ..registerForKind<GroupRepository>(_organismContext.kind, instance: groupRepository)
      ..registerForKind<GenetRepository>(_organismContext.kind, instance: genetRepository)
      ..registerForKind<OrganismAwareEventRepository>(_organismContext.kind, instance: eventRepository);

    cohortRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<CohortRepository>(kind, instance: repository),
    );
    reproductiveEventRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<ReproductiveEventRepository>(kind, instance: repository),
    );
    seededLineRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<SeededLineRepository>(kind, instance: repository),
    );
    oysterBagRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<OysterBagRepository>(kind, instance: repository),
    );
    gameteBatchRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<GameteBatchRepository>(kind, instance: repository),
    );
    larvalBatchRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<LarvalBatchRepository>(kind, instance: repository),
    );
    finfishPenRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<FinfishPenRepository>(kind, instance: repository),
    );
    crabPondRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<CrabPondRepository>(kind, instance: repository),
    );
    seagrassModuleRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<SeagrassModuleRepository>(kind, instance: repository),
    );
    mangrovePlotRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<MangrovePlotRepository>(kind, instance: repository),
    );
    urchinTankRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<UrchinTankRepository>(kind, instance: repository),
    );
    seaCucumberTankRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<SeaCucumberTankRepository>(kind, instance: repository),
    );
    activityEventRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<ActivityEventRepository>(kind, instance: repository),
    );
    organismRecordRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<OrganismRecordRepository>(kind, instance: repository),
    );
    _holdingSummaryService = HoldingSummaryService(
      registry: _registry,
    );
    _eventPropagationService = EventPropagationService(
      activityEventRepository: activityEventRepository,
      organismContext: _organismContext,
    );
    final eventHistoryService = EventHistoryService(
      eventHistoryRepository: eventHistoryRepository,
      siteRepository: siteRepository,
      groupRepository: groupRepository,
      organismRepository: _organismRecordRepositories[_organismContext.kind]!,
    );
    final snapshotComparisonService = SnapshotComparisonService();
    final searchService = SearchService(
      siteRepository: siteRepository,
      groupRepository: groupRepository,
      organismRecordRepository: _organismRecordRepositories[_organismContext.kind]!,
    );
    final imageService = context.read<ImageService>();
    final geneBankMetricsService = GeneBankMetricsService(
      organismRecordRepository: _organismRecordRepositories[_organismContext.kind]!,
      groupRepository: groupRepository,
    );
    final userRepository = UserRepository(
      firestore: firestore,
      recordRepository: recordRepository,
    );
    final invitationRepository = InvitationRepository(
      firestore: firestore,
      recordRepository: recordRepository,
    );

    final postRepository = PostRepository(
      organizationId: organization.id,
      userId: user.id,
      firestore: firestore,
    );

    final communityPostRepository = CommunityPostRepository(
      userId: user.id,
      firestore: firestore,
    );

    final missionRepository = MissionRepository(
      firestore: firestore,
    );

    final permitRepository = PermitRepository(firestore: firestore);
    final funderRepository = FunderRepository(firestore: firestore);
    final vesselRepository = VesselRepository(firestore: firestore);

    final communityCommentRepository = CommunityCommentRepository(
      userId: user.id,
      firestore: firestore,
    );

    final feedRepository = FeedRepository(
      organizationId: organization.id,
      userId: user.id,
      postRepository: postRepository,
    );

    final transferService = TransferService(
      provenanceRepository: provenanceRepository,
      eventRepository: eventRepository,
      organizationRepository: organizationRepository,
      recordRepository: recordRepository,
      organismRecordRepository: _organismRecordRepositories[_organismContext.kind]!,
      db: firestore,
      crosswalkService: crosswalkService,
    );

    _repositoryProviders = [
      RepositoryProvider<RecordRepository>(create: (_) => recordRepository),
      // Note: FeatureAccessService is provided via ChangeNotifierProvider in build() method
      // because it extends ChangeNotifier and requires ChangeNotifierProvider, not RepositoryProvider.
      RepositoryProvider<OrganizationRepository>(
        create: (_) => organizationRepository,
      ),
      RepositoryProvider<UserRepository>(create: (_) => userRepository),
      RepositoryProvider<InvitationRepository>(
        create: (_) => invitationRepository,
      ),
      RepositoryProvider<MissionRepository>(
        create: (_) => missionRepository,
      ),
      RepositoryProvider<PermitRepository>(
        create: (_) => permitRepository,
      ),
      RepositoryProvider<FunderRepository>(
        create: (_) => funderRepository,
      ),
      RepositoryProvider<VesselRepository>(
        create: (_) => vesselRepository,
      ),
      RepositoryProvider<EventRepository>(
        create: (_) => eventRepository,
        dispose: (repository) => repository.dispose(),
      ),
      RepositoryProvider<SiteRepository>(
        create: (_) => siteRepository,
        dispose: (repository) => repository.dispose(),
      ),
      RepositoryProvider<GroupRepository>(
        create: (_) => groupRepository,
        dispose: (repository) => repository.dispose(),
      ),
      RepositoryProvider<GenetRepository>(
        create: (_) => genetRepository,
        dispose: (repository) => repository.dispose(),
      ),
      RepositoryProvider<ProvenanceRepository>(
        create: (_) => provenanceRepository,
      ),
      RepositoryProvider<CohortRepository>(create: (_) => cohortRepository),
      RepositoryProvider<ReproductiveEventRepository>(
        create: (_) => reproductiveEventRepository,
      ),
      if (gameteBatchRepository != null)
        RepositoryProvider<GameteBatchRepository>(
          create: (_) => gameteBatchRepository!,
        ),
      if (larvalBatchRepository != null)
        RepositoryProvider<LarvalBatchRepository>(
          create: (_) => larvalBatchRepository!,
        ),
      if (seededLineRepository != null)
        RepositoryProvider<SeededLineRepository>(
          create: (_) => seededLineRepository!,
        ),
      if (oysterBagRepository != null)
        RepositoryProvider<OysterBagRepository>(
          create: (_) => oysterBagRepository!,
        ),
      RepositoryProvider<TransferService>(create: (_) => transferService),
      RepositoryProvider<ManualTransferRegistrationService>.value(
        value: transferService,
      ),
      RepositoryProvider<GraphRepository>(
        create: (_) => _graphRepository,
        dispose: (repository) => repository.dispose(),
      ),
      RepositoryProvider<ActivityEventRepository>(
        create: (_) => activityEventRepository,
        dispose: (repository) => repository.dispose(),
      ),
      // CSVImportService provider removed - community tier doesn't include CSV import
      RepositoryProvider<EventHistoryRepository>(
        create: (_) => eventHistoryRepository,
      ),
      RepositoryProvider<SnapshotRepository>(create: (_) => snapshotRepository),
      RepositoryProvider<EventHistoryService>(
        create: (_) => eventHistoryService,
      ),
      RepositoryProvider<SnapshotComparisonService>(
        create: (_) => snapshotComparisonService,
      ),
      RepositoryProvider<SnapshotService>(create: (_) => snapshotService),
      RepositoryProvider<SearchService>(create: (_) => searchService),
      RepositoryProvider<ImageService>(create: (_) => imageService),
      RepositoryProvider<GeneBankMetricsService>(
        create: (_) => geneBankMetricsService,
      ),
      RepositoryProvider<PostRepository>(
        create: (_) => postRepository,
      ),
      RepositoryProvider<CommunityPostRepository>(
        create: (_) => communityPostRepository,
      ),
      RepositoryProvider<CommunityCommentRepository>(
        create: (_) => communityCommentRepository,
      ),
      RepositoryProvider<FeedRepository>(
        create: (_) => feedRepository,
      ),
      // Custom types services - community tier provides readonly access to builtin types
      // Deliverable repository for permit tracking
      RepositoryProvider<DeliverableRepository>.value(
        value: _deliverableRepository,
      ),
      RepositoryProvider<ProvenanceLookupService>.value(
        value: provenanceLookupService,
      ),
    ];
  }

  Map<OrganismKind, OrganismContext> _buildOrganismContexts() {
    final kinds = _resolveSupportedOrganismKinds();
    final contexts = <OrganismKind, OrganismContext>{};
    for (final kind in kinds) {
      contexts[kind] = OrganismContext.forKind(kind);
    }
    return contexts;
  }

  List<OrganismKind> _resolveSupportedOrganismKinds() {
    final kinds = widget.organization.supportedOrganismKinds;
    final deduped = LinkedHashSet<OrganismKind>.of(kinds);
    if (deduped.isEmpty) {
      deduped.add(OrganismKind.coral);
    }
    return List<OrganismKind>.unmodifiable(deduped);
  }

  Future<void> _initializeOrganismConfigs(FirebaseFirestore firestore) async {
    await Future.wait([
      _loadEnvironmentalThresholds(firestore),
      _loadValidationRules(firestore),
      _loadMortalityCauses(firestore),
    ]);
  }

  Future<void> _loadEnvironmentalThresholds(FirebaseFirestore firestore) async {
    final registry = EnvironmentalThresholdRegistry.instance;
    try {
      final bundled = await rootBundle.loadString(
        'config/environmental_thresholds.defaults.yaml',
      );
      registry.loadFromYaml(bundled, overrideExisting: true);
    } catch (error) {
      LoggingService.instance.warning('Failed loading bundled environmental thresholds', error);
    }

    try {
      final snapshot = await firestore
          .collection('taxonomy_overrides')
          .doc(_environmentalThresholdsDocId)
          .get();
      final yaml = snapshot.data()?['yaml']?.toString();
      if (yaml != null && yaml.trim().isNotEmpty) {
        registry.loadFromYaml(yaml, overrideExisting: true);
      }
    } catch (error) {
      LoggingService.instance.warning('Failed loading environmental threshold overrides', error);
    }
  }

  Future<void> _loadValidationRules(FirebaseFirestore firestore) async {
    final registry = ValidationRuleRegistry.instance;
    try {
      final bundled = await rootBundle.loadString(
        'config/validation_rules.defaults.yaml',
      );
      registry.loadRulesFromYaml(bundled, overrideExisting: true);
    } catch (error) {
      LoggingService.instance.warning('Failed loading bundled validation rules', error);
    }

    try {
      final snapshot = await firestore
          .collection('taxonomy_overrides')
          .doc(_validationRulesDocId)
          .get();
      final yaml = snapshot.data()?['yaml']?.toString();
      if (yaml != null && yaml.trim().isNotEmpty) {
        registry.loadRulesFromYaml(yaml, overrideExisting: true);
      }
    } catch (error) {
      LoggingService.instance.warning('Failed loading validation rule overrides', error);
    }
  }

  Future<void> _loadMortalityCauses(FirebaseFirestore firestore) async {
    final registry = MortalityCauseRegistry.instance;
    try {
      final bundled = await rootBundle.loadString(
        'config/mortality_causes.defaults.yaml',
      );
      registry.loadFromYaml(bundled, overrideExisting: true);
    } catch (error) {
      LoggingService.instance.warning('Failed loading bundled mortality causes', error);
    }

    try {
      final snapshot = await firestore
          .collection('taxonomy_overrides')
          .doc(_mortalityCausesDocId)
          .get();
      final yaml = snapshot.data()?['yaml']?.toString();
      if (yaml != null && yaml.trim().isNotEmpty) {
        registry.loadFromYaml(yaml, overrideExisting: true);
      }
    } catch (error) {
      LoggingService.instance.warning('Failed loading mortality cause overrides', error);
    }
  }
}
