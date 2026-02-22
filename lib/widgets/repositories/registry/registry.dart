// @tier: community

/// Registry package exports for repository management.
///
/// This barrel file exports the core components of the repository registry system:
/// - [RepositoryRegistry]: Central registry for managing repository instances
/// - [RepositoryModule]: Base class for grouping related repositories
/// - [Disposable]: Interface for type-safe disposal of resources
///
/// **Example Usage**:
/// ```dart
/// import 'package:seafoundry_app/widgets/repositories/registry/registry.dart';
///
/// final registry = RepositoryRegistry();
/// final module = CoreRepositoryModule();
///
/// module.register(registry, dependencies: {
///   'user': currentUser,
///   'organization': currentOrg,
///   // ... other dependencies
/// });
///
/// final siteRepo = registry.get<SiteRepository>();
/// ```
library;

export 'disposable.dart';
export 'repository_module.dart';
export 'repository_registry.dart';
export 'repository_registry_extensions.dart';
