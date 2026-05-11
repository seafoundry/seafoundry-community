// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
// Internal repositories (not exported from barrel)
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/services/services.dart';
// Internal services (not exported from barrel)
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
  late OrganismContext _organismContext;
  late Map<OrganismKind, OrganismContext> _organismContexts;
  late TaxonomyService _taxonomyService;
  late SpeciesRegistry _speciesRegistry;
  late RepositoryRegistry _registry;
  late Map<OrganismKind, OrganismRecordRepository>
  _organismRecordRepositories;
  late StructureCapacityService _structureCapacityService;

  @override
  void initState() {
    super.initState();
    _buildRepositoryProviders();
  }

  @override
  void dispose() {
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
          Provider<TaxonomyService?>.value(value: _taxonomyService),
          ChangeNotifierProvider<SpeciesRegistry>.value(
            value: _speciesRegistry,
          ),
          Provider<OrganismContext>.value(value: _organismContext),
          Provider<StructureCapacityService>.value(
            value: _structureCapacityService,
          ),
          Provider<RepositoryRegistry>.value(
            value: _registry,
          ),
          Provider<Map<OrganismKind, OrganismRecordRepository>>.value(
            value: UnmodifiableMapView(_organismRecordRepositories),
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

    final firebaseService = context.read<FirebaseService>();
    final firestore = firebaseService.firestore;

    // Initialize custom types repository and resolver service
    // Community tier uses these for readonly access to builtin types

    // Create RecordRepository for user and invitation management
    final recordRepository = RecordRepository(db: firestore);

    _organismContexts = _buildOrganismContexts();
    _organismContext = _organismContexts.values.first;
    _taxonomyService = TaxonomyService(firestore: firestore);
    _speciesRegistry = SpeciesRegistry(taxonomyService: _taxonomyService);
    SpeciesRegistry.installGlobal(_speciesRegistry);
    unawaited(_speciesRegistry.refresh());
    _structureCapacityService = StructureCapacityService.disabled();
    final organismConfigFuture = _initializeOrganismConfigs(firestore);
    unawaited(organismConfigFuture);

    final eventRepository = EventRepository(
      user: user,
      organization: organization,
      firestore: firestore,
      organismContext: _organismContext,
    );

    final organizationRepository = OrganizationRepository(firestore: firestore);

    final snapshotService = SnapshotService(
      firestore: firestore,
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

    final organismRecordRepositories =
        <OrganismKind, OrganismRecordRepository>{};
    _organismRecordRepositories = organismRecordRepositories;
    _organismContexts.forEach((kind, context) {
      organismRecordRepositories[kind] = OrganismRecordRepository(
        organization: organization,
        user: user,
        firestore: firestore,
        eventRepository: eventRepository,
        organismContext: context,
        structureCapacityService: _structureCapacityService,
      )..initialize();
    });
    _graphRepository = GraphRepository(
      eventRepository: eventRepository,
      siteRepository: siteRepository,
      groupRepository: groupRepository,
      organismRecordRepository: _organismRecordRepositories[_organismContext.kind]!,
      genetRepository: genetRepository,
      recordRepository: recordRepository,
      firestore: firestore,
    );

    final csvImportService = CSVImportService(
      genetRepository: genetRepository,
      organismRecordRepository: _organismRecordRepositories[_organismContext.kind]!,
      groupRepository: groupRepository,
      siteRepository: siteRepository,
      eventRepository: eventRepository,
    );

    CsvTranslationAdapterRegistry.instance.installAdaptersForOrganization(
      organization,
    );

    _registry = RepositoryRegistry()
      ..setDefaultOrganismKind(_organismContext.kind)
      ..registerForKind<SiteRepository>(_organismContext.kind, instance: siteRepository)
      ..registerForKind<GroupRepository>(_organismContext.kind, instance: groupRepository)
      ..registerForKind<GenetRepository>(_organismContext.kind, instance: genetRepository)
      ..registerForKind<EventRepository>(_organismContext.kind, instance: eventRepository);

    organismRecordRepositories.forEach(
      (kind, repository) =>
          _registry.registerForKind<OrganismRecordRepository>(kind, instance: repository),
    );
    final searchService = SearchService(
      siteRepository: siteRepository,
      groupRepository: groupRepository,
      organismRecordRepository: _organismRecordRepositories[_organismContext.kind]!,
    );
    final invitationRepository = InvitationRepository(
      firestore: firestore,
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
      RepositoryProvider<OrganizationRepository>(
        create: (_) => organizationRepository,
      ),
      RepositoryProvider<InvitationRepository>(
        create: (_) => invitationRepository,
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
      RepositoryProvider<TransferService>(create: (_) => transferService),
      RepositoryProvider<ManualTransferRegistrationService>.value(
        value: transferService,
      ),
      RepositoryProvider<GraphRepository>(
        create: (_) => _graphRepository,
        dispose: (repository) => repository.dispose(),
      ),
      RepositoryProvider<CSVImportService>(
        create: (_) => csvImportService,
      ),
      RepositoryProvider<SnapshotService>(create: (_) => snapshotService),
      RepositoryProvider<SearchService>(create: (_) => searchService),
      // Custom types services - community tier provides readonly access to builtin types
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
    // Coral-only build
    return const [OrganismKind.coral];
  }

  Future<void> _initializeOrganismConfigs(FirebaseFirestore firestore) async {
    await Future.wait([
      _loadValidationRules(firestore),
    ]);
  }

  Future<void> _loadValidationRules(FirebaseFirestore firestore) async {
    final registry = ValidationRuleRegistry.instance;
    registry.loadDefaultRules(overrideExisting: true);
  }

}
