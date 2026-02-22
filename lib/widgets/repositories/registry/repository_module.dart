// @tier: community
import 'package:seafoundry_app/widgets/repositories/registry/repository_registry.dart';

/// Base class for repository modules that group related repositories together.
///
/// A module encapsulates the creation and registration logic for a logical
/// group of repositories (e.g., core repositories, inventory repositories,
/// training repositories).
///
/// **Purpose**:
/// - Organize repository creation into cohesive modules
/// - Declare which repository types the module provides
/// - Handle module-specific initialization and cleanup
///
/// **Implementation Pattern**:
/// ```dart
/// class CoreRepositoryModule extends RepositoryModule {
///   @override
///   List<Type> get providedTypes => [
///     GraphRepository,
///     SiteRepository,
///     GenetRepository,
///     EventRepository,
///   ];
///
///   @override
///   void register(
///     RepositoryRegistry registry, {
///     required Map<String, dynamic> dependencies,
///   }) {
///     final user = dependencies['user'] as User;
///     final organization = dependencies['organization'] as Organization;
///     final firestore = dependencies['firestore'] as FirebaseFirestore;
///
///     // Register repositories
///     registry.register<EventRepository>(
///       factory: () => EventRepository(
///         user: user,
///         organization: organization,
///         firestore: firestore,
///       ),
///     );
///     // ... register other repositories
///   }
/// }
/// ```
abstract class RepositoryModule {
  /// Returns the list of repository types this module provides.
  ///
  /// Used for dependency tracking and validation.
  List<Type> get providedTypes;

  /// Registers all repositories provided by this module.
  ///
  /// **Parameters**:
  /// - [registry]: The registry to register repositories into
  /// - [dependencies]: Map of named dependencies needed to create repositories
  ///
  /// **Common Dependencies**:
  /// - `user`: Current user (User)
  /// - `organization`: Current organization (Organization)
  /// - `firestore`: Firestore instance (FirebaseFirestore)
  /// - `featureAccessService`: Feature access service (FeatureAccessService)
  /// - `organismContext`: Organism context (OrganismContext)
  ///
  /// **Example**:
  /// ```dart
  /// @override
  /// void register(
  ///   RepositoryRegistry registry, {
  ///   required Map<String, dynamic> dependencies,
  /// }) {
  ///   final user = dependencies['user'] as User;
  ///   final firestore = dependencies['firestore'] as FirebaseFirestore;
  ///
  ///   registry.register<SiteRepository>(
  ///     factory: () => SiteRepository(
  ///       user: user,
  ///       organization: dependencies['organization'],
  ///       firestore: firestore,
  ///       eventRepository: registry.get<EventRepository>(),
  ///       snapshotService: dependencies['snapshotService'],
  ///     ),
  ///   );
  /// }
  /// ```
  void register(
    RepositoryRegistry registry, {
    required Map<String, dynamic> dependencies,
  });

  /// Disposes resources managed by this module.
  ///
  /// **Module Disposal Contract**:
  /// Modules are responsible for disposing their own internally-tracked instances.
  /// This includes instances stored in Maps, Lists, or other collections that are
  /// not directly registered in the registry.
  ///
  /// **Common Pattern**:
  /// ```dart
  /// class OrganismRepositoryModule extends RepositoryModule {
  ///   final Map<OrganismKind, OrganismRecordRepository> _repositories = {};
  ///
  ///   @override
  ///   void dispose() {
  ///     // Dispose internally-tracked instances
  ///     for (final repo in _repositories.values) {
  ///       repo.dispose();
  ///     }
  ///     _repositories.clear();
  ///   }
  /// }
  /// ```
  ///
  /// **Note**: The registry will dispose modules BEFORE disposing registry-managed
  /// instances, ensuring proper cleanup order.
  void dispose() {
    // Default: no module-level cleanup needed
    // Override to dispose internally-tracked instances
  }
}
