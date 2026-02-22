// @tier: community
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/repositories/registry/disposable.dart';
import 'package:seafoundry_app/widgets/repositories/registry/repository_module.dart';

/// Composite key for (Type, OrganismKind) lookups.
///
/// Used internally to support OrganismKind-specific repository registration
/// and retrieval. This enables different repository instances per organism kind.
class _RepositoryKindKey {
  const _RepositoryKindKey(this.type, this.kind);

  final Type type;
  final OrganismKind kind;

  @override
  bool operator ==(Object other) =>
      other is _RepositoryKindKey && other.type == type && other.kind == kind;

  @override
  int get hashCode => Object.hash(type, kind);

  @override
  String toString() => '_RepositoryKindKey($type, ${kind.name})';
}

/// A registry for managing repository instances with lazy instantiation support.
///
/// This class provides a centralized location for repository registration and
/// retrieval, supporting both eager and lazy instantiation patterns.
///
/// **Lazy Instantiation vs Lazy Initialization**:
/// - **Lazy Instantiation** (this registry): Repository object is created only when
///   first accessed via `get<T>()`. Enabled by registering with a factory function.
/// - **Lazy Initialization** (repository-specific): Repository object exists but
///   defers expensive operations (e.g., stream subscriptions) until `initialize()`
///   is called. This is handled by the repository itself, not by the registry.
///
/// **Usage Pattern**:
/// ```dart
/// final registry = RepositoryRegistry();
///
/// // Eager instantiation (instance already created)
/// registry.register<SiteRepository>(instance: siteRepository);
///
/// // Lazy instantiation (created on first access)
/// registry.register<EventRepository>(
///   factory: () => EventRepository(...)..initialize(), // instantiation + initialization
/// );
///
/// // Retrieval (triggers factory if not yet instantiated)
/// final siteRepo = registry.get<SiteRepository>();
/// ```
///
/// **OrganismKind-Aware Registration**: In addition to type-based registration,
/// this registry supports OrganismKind-specific repository instances. This enables
/// different repository configurations per organism type while maintaining a unified
/// lookup interface.
///
/// **Thread Safety**: This registry is designed for single-isolate use only
/// (Flutter's main isolate). It does not provide synchronization for concurrent
/// access from multiple isolates. All operations must be performed on the same
/// isolate to ensure correctness.
///
/// **Disposal**: Call `dispose()` to clean up all registered repositories.
/// Repositories are disposed in reverse order of creation to handle dependencies correctly.
/// Only instantiated repositories are disposed - factories never called are ignored.
class RepositoryRegistry {
  // Type-based registration (existing functionality)
  final Map<Type, Object> _instances = {};
  final Map<Type, Object Function()> _factories = {};
  final List<Type> _creationOrder = [];
  final Set<Type> _instantiating = {};
  final List<RepositoryModule> _modules = [];

  // OrganismKind-aware registration (new functionality)
  final Map<_RepositoryKindKey, Object> _kindInstances = {};
  final Map<_RepositoryKindKey, Object Function()> _kindFactories = {};
  final List<_RepositoryKindKey> _kindCreationOrder = [];
  final Set<_RepositoryKindKey> _kindInstantiating = {};
  OrganismKind? _defaultOrganismKind;

  /// Registers a repository instance or factory.
  ///
  /// Either [instance] or [factory] must be provided, but not both.
  ///
  /// **Parameters**:
  /// - [instance]: Pre-created repository instance (eager initialization)
  /// - [factory]: Factory function for lazy initialization
  ///
  /// **Throws**: [StateError] if the type is already registered. This prevents
  /// accidental duplicate registrations which could leak the first instance.
  ///
  /// **Example**:
  /// ```dart
  /// // Eager registration
  /// registry.register<SiteRepository>(siteRepository);
  ///
  /// // Lazy registration
  /// registry.register<EventRepository>(
  ///   factory: () => EventRepository(user: user, organization: org, ...),
  /// );
  /// ```
  void register<T extends Object>({
    T? instance,
    T Function()? factory,
  }) {
    assert(
      (instance != null) != (factory != null),
      'Exactly one of instance or factory must be provided',
    );

    final type = T;

    // Prevent duplicate registration
    if (_instances.containsKey(type) || _factories.containsKey(type)) {
      throw StateError(
        'Type $T is already registered. '
        'Duplicate registration would leak the first instance.',
      );
    }

    if (instance != null) {
      _instances[type] = instance;
      _creationOrder.add(type);
    } else if (factory != null) {
      _factories[type] = factory;
    }
  }

  /// Retrieves a registered repository instance.
  ///
  /// If the repository was registered with a factory, it will be instantiated
  /// on first access and cached for subsequent calls.
  ///
  /// **Throws**:
  /// - [StateError] if the repository type is not registered.
  /// - [StateError] if a circular dependency is detected during factory execution.
  ///
  /// **Factory Exception Safety**: If a factory throws during instantiation,
  /// the factory remains in the registry and can be retried on subsequent
  /// `get<T>()` calls. This allows for transient failures (e.g., network issues)
  /// to be recovered from by retrying after the underlying issue is resolved.
  ///
  /// **Example**:
  /// ```dart
  /// final siteRepo = registry.get<SiteRepository>();
  /// ```
  T get<T extends Object>() {
    final type = T;

    // Check if already instantiated
    final instance = _instances[type];
    if (instance != null) {
      return instance as T;
    }

    // Check if factory exists
    final factory = _factories[type];
    if (factory != null) {
      // Detect circular dependencies
      if (_instantiating.contains(type)) {
        // Build the full dependency chain for better debugging
        final chain = _instantiating.toList()..add(type);
        final chainStr = chain.join(' -> ');
        throw StateError(
          'Circular dependency detected: $chainStr\n'
          'The type $T is already being instantiated further up the dependency chain. '
          'Check your factory dependencies to avoid circular references.',
        );
      }

      // Track that we're instantiating this type (for circular dependency detection)
      _instantiating.add(type);

      try {
        final newInstance = factory() as T;
        // Only remove factory AFTER successful instantiation (allows retry on failure)
        _factories.remove(type);
        _instances[type] = newInstance;
        _creationOrder.add(type);
        return newInstance;
      } finally {
        // Always remove from instantiating set, even if factory throws
        _instantiating.remove(type);
      }
    }

    throw StateError('No repository registered for type $T');
  }

  /// Checks if a repository type is registered.
  ///
  /// Returns `true` if the type has been registered (either as an instance or factory).
  bool isRegistered<T extends Object>() {
    final type = T;
    return _instances.containsKey(type) || _factories.containsKey(type);
  }

  /// Sets the default OrganismKind for fallback behavior.
  ///
  /// When retrieving a repository with `getForKind<T>(kind)`, if no specific
  /// instance is registered for that kind and `fallbackToDefault=true`, the
  /// registry will attempt to return the instance for the default kind.
  ///
  /// **Example**:
  /// ```dart
  /// registry.setDefaultOrganismKind(OrganismKind.coral);
  /// registry.registerForKind<TaxonomyRepository>(
  ///   OrganismKind.coral,
  ///   instance: coralTaxonomyRepo,
  /// );
  /// // Returns coralTaxonomyRepo as fallback for unregistered kinds
  /// final oysterRepo = registry.getForKind<TaxonomyRepository>(OrganismKind.oyster);
  /// ```
  void setDefaultOrganismKind(OrganismKind kind) {
    _defaultOrganismKind = kind;
  }

  /// Returns the current default OrganismKind, or null if not set.
  ///
  /// This is used for fallback behavior in [getForKind] when a specific
  /// OrganismKind is not registered.
  OrganismKind? getDefaultOrganismKind() => _defaultOrganismKind;

  /// Registers a repository instance or factory for a specific OrganismKind.
  ///
  /// This enables kind-specific repository configurations while maintaining
  /// type safety. Either [instance] or [factory] must be provided, but not both.
  ///
  /// **Parameters**:
  /// - [kind]: The OrganismKind this repository instance serves
  /// - [instance]: Pre-created repository instance (eager initialization)
  /// - [factory]: Factory function for lazy initialization
  ///
  /// **Throws**: [StateError] if the (Type, OrganismKind) pair is already registered.
  /// This prevents accidental duplicate registrations which could leak the first instance.
  ///
  /// **Example**:
  /// ```dart
  /// // Register coral-specific taxonomy repository
  /// registry.registerForKind<TaxonomyRepository>(
  ///   OrganismKind.coral,
  ///   instance: coralTaxonomyRepo,
  /// );
  ///
  /// // Register oyster-specific taxonomy repository with lazy initialization
  /// registry.registerForKind<TaxonomyRepository>(
  ///   OrganismKind.oyster,
  ///   factory: () => OysterTaxonomyRepository(...),
  /// );
  /// ```
  void registerForKind<T extends Object>(
    OrganismKind kind, {
    T? instance,
    T Function()? factory,
  }) {
    assert(
      (instance != null) != (factory != null),
      'Exactly one of instance or factory must be provided',
    );

    final key = _RepositoryKindKey(T, kind);

    // Prevent duplicate registration
    if (_kindInstances.containsKey(key) || _kindFactories.containsKey(key)) {
      throw StateError(
        'Type $T for OrganismKind ${kind.name} is already registered. '
        'Duplicate registration would leak the first instance.',
      );
    }

    if (instance != null) {
      _kindInstances[key] = instance;
      _kindCreationOrder.add(key);
    } else if (factory != null) {
      _kindFactories[key] = factory;
    }
  }

  /// Retrieves a registered repository instance for a specific OrganismKind.
  ///
  /// If the repository was registered with a factory, it will be instantiated
  /// on first access and cached for subsequent calls.
  ///
  /// **Fallback Behavior**: When [fallbackToDefault] is true (default) and no
  /// instance exists for the requested kind, the registry will attempt to return
  /// the instance for the default OrganismKind (set via [setDefaultOrganismKind]).
  ///
  /// **Parameters**:
  /// - [kind]: The OrganismKind to retrieve the repository for
  /// - [fallbackToDefault]: Whether to fall back to default kind if not found (default: true)
  ///
  /// **Throws**:
  /// - [StateError] if the (Type, kind) pair is not registered and no fallback is available.
  /// - [StateError] if a circular dependency is detected during factory execution.
  ///
  /// **Example**:
  /// ```dart
  /// final coralTaxonomy = registry.getForKind<TaxonomyRepository>(OrganismKind.coral);
  /// final oysterTaxonomy = registry.getForKind<TaxonomyRepository>(
  ///   OrganismKind.oyster,
  ///   fallbackToDefault: false, // Throw if not explicitly registered
  /// );
  /// ```
  T getForKind<T extends Object>(
    OrganismKind kind, {
    bool fallbackToDefault = true,
  }) {
    final key = _RepositoryKindKey(T, kind);

    // Check if already instantiated
    final instance = _kindInstances[key];
    if (instance != null) {
      return instance as T;
    }

    // Check if factory exists
    final factory = _kindFactories[key];
    if (factory != null) {
      // Detect circular dependencies
      if (_kindInstantiating.contains(key)) {
        // Build the full dependency chain for better debugging
        final chain = _kindInstantiating.toList()..add(key);
        final chainStr = chain.map((k) => '${k.type}(${k.kind.name})').join(' -> ');
        throw StateError(
          'Circular dependency detected: $chainStr\n'
          'The type $T for ${kind.name} is already being instantiated further up the dependency chain. '
          'Check your factory dependencies to avoid circular references.',
        );
      }

      // Track that we're instantiating this type (for circular dependency detection)
      _kindInstantiating.add(key);

      try {
        final newInstance = factory() as T;
        // Only remove factory AFTER successful instantiation (allows retry on failure)
        _kindFactories.remove(key);
        _kindInstances[key] = newInstance;
        _kindCreationOrder.add(key);
        return newInstance;
      } finally {
        // Always remove from instantiating set, even if factory throws
        _kindInstantiating.remove(key);
      }
    }

    // Attempt fallback to default kind
    if (fallbackToDefault && _defaultOrganismKind != null) {
      final defaultKey = _RepositoryKindKey(T, _defaultOrganismKind!);
      final defaultInstance = _kindInstances[defaultKey];
      if (defaultInstance != null) {
        return defaultInstance as T;
      }

      // Try factory for default kind
      final defaultFactory = _kindFactories[defaultKey];
      if (defaultFactory != null) {
        // Use recursive call to handle factory instantiation with proper error handling
        return getForKind<T>(_defaultOrganismKind!, fallbackToDefault: false);
      }
    }

    throw StateError(
      'No repository registered for type $T and OrganismKind ${kind.name}'
      '${fallbackToDefault && _defaultOrganismKind != null ? ' (fallback to ${_defaultOrganismKind!.name} also not found)' : ''}',
    );
  }

  /// Registers multiple OrganismKind-specific instances at once.
  ///
  /// This is a convenience method for bulk registration when you have instances
  /// for multiple organism kinds ready at initialization time.
  ///
  /// **Example**:
  /// ```dart
  /// registry.registerAllKinds<TaxonomyRepository>({
  ///   OrganismKind.coral: coralTaxonomyRepo,
  ///   OrganismKind.oyster: oysterTaxonomyRepo,
  ///   OrganismKind.kelp: kelpTaxonomyRepo,
  /// });
  /// ```
  void registerAllKinds<T extends Object>(Map<OrganismKind, T> kindToInstanceMap) {
    // Validate all entries BEFORE registering any (fail-fast to prevent partial state)
    for (final entry in kindToInstanceMap.entries) {
      final key = _RepositoryKindKey(T, entry.key);
      if (_kindInstances.containsKey(key) || _kindFactories.containsKey(key)) {
        throw StateError(
          'Type $T for OrganismKind ${entry.key.name} is already registered. '
          'registerAllKinds() requires all entries to be unregistered.',
        );
      }
    }
    // All validated - now register
    for (final entry in kindToInstanceMap.entries) {
      registerForKind<T>(entry.key, instance: entry.value);
    }
  }

  /// Returns all registered instances for a given type across all OrganismKinds.
  ///
  /// This is useful for inspecting what kinds have been registered or for
  /// performing bulk operations across all organism-specific repositories.
  ///
  /// **Note**: Only returns already-instantiated instances. Factories that have
  /// not yet been called will not appear in the result.
  ///
  /// **Example**:
  /// ```dart
  /// final allTaxonomyRepos = registry.getAllKinds<TaxonomyRepository>();
  /// for (final entry in allTaxonomyRepos.entries) {
  ///   print('${entry.key.name}: ${entry.value}');
  /// }
  /// ```
  Map<OrganismKind, T> getAllKinds<T extends Object>() {
    final result = <OrganismKind, T>{};
    for (final entry in _kindInstances.entries) {
      if (entry.key.type == T) {
        result[entry.key.kind] = entry.value as T;
      }
    }
    return Map.unmodifiable(result);
  }

  /// Checks if a repository is registered for a specific (Type, OrganismKind) pair.
  ///
  /// Returns `true` if the pair has been registered (either as an instance or factory).
  ///
  /// **Example**:
  /// ```dart
  /// if (registry.isRegisteredForKind<TaxonomyRepository>(OrganismKind.coral)) {
  ///   final repo = registry.getForKind<TaxonomyRepository>(OrganismKind.coral);
  /// }
  /// ```
  bool isRegisteredForKind<T extends Object>(OrganismKind kind) {
    final key = _RepositoryKindKey(T, kind);
    return _kindInstances.containsKey(key) || _kindFactories.containsKey(key);
  }

  /// Registers a module and its dependencies.
  ///
  /// This method tracks modules separately so they can be disposed properly.
  /// Modules are responsible for disposing their own internally-tracked instances.
  ///
  /// **Parameters**:
  /// - [module]: The module to register
  /// - [dependencies]: Map of dependencies required by the module
  ///
  /// **Example**:
  /// ```dart
  /// final module = OrganismRepositoryModule();
  /// registry.registerModule(module, {
  ///   'user': currentUser,
  ///   'organization': currentOrg,
  ///   'firestore': firestore,
  ///   'eventRepository': eventRepo,
  /// });
  /// ```
  void registerModule(
    RepositoryModule module,
    Map<String, dynamic> dependencies,
  ) {
    // Prevent duplicate module registration
    final moduleType = module.runtimeType;
    if (_modules.any((m) => m.runtimeType == moduleType)) {
      throw StateError(
        'Module $moduleType is already registered. '
        'Duplicate module registration would cause duplicate repository registrations.',
      );
    }

    // Note: We cannot validate module.providedTypes against existing registrations
    // at runtime due to Dart's type system limitations. However, registerForKind()
    // and register() will throw StateError on duplicate registration, so conflicts
    // will be caught during the module's register() call.

    _modules.add(module);
    module.register(this, dependencies: dependencies);
  }

  /// Returns an unmodifiable list of all instantiated types in creation order.
  ///
  /// This is useful for introspection and for systems that need to enumerate
  /// which repository types have been instantiated. Note that factories that
  /// have not yet been called will not appear in this list.
  ///
  /// **Example**:
  /// ```dart
  /// final types = registry.instantiatedTypes;
  /// for (final type in types) {
  ///   print('Instantiated: $type');
  /// }
  /// ```
  List<Type> get instantiatedTypes => List.unmodifiable(_creationOrder);

  /// Returns a map of all instantiated instances keyed by their Type.
  ///
  /// This enables systems like WrappedNavigator to iterate over all instances
  /// and create appropriate provider wrappers. The map is unmodifiable to
  /// prevent external mutation.
  ///
  /// **Note**: This returns `Object` values which lose compile-time type
  /// information. Callers must use runtime type checking or maintain their
  /// own type metadata.
  Map<Type, Object> get instantiatedInstances => Map.unmodifiable(_instances);

  /// Disposes all registered repositories and modules.
  ///
  /// **Disposal Order**:
  /// 1. Modules are disposed first (in reverse registration order)
  /// 2. OrganismKind-specific instances are disposed (in reverse creation order)
  /// 3. Type-based registry instances are disposed (in reverse creation order)
  ///
  /// This ensures that:
  /// - Modules can clean up their internally-tracked instances
  /// - Kind-specific instances are disposed before type-based singletons
  /// - Registry-managed instances are disposed after module cleanup
  ///
  /// **CRITICAL - Repository Disposal Contract**:
  ///
  /// Disposal uses reverse creation order, which approximates but does NOT guarantee
  /// dependency order. This design imposes strict constraints on repository dispose()
  /// implementations:
  ///
  /// 1. **No Dependency Access**: Repositories MUST NOT access other repositories
  ///    during dispose(). Only clean up directly-owned resources (streams, subscriptions,
  ///    controllers). Other repositories may already be disposed when your dispose() runs.
  ///
  /// 2. **Synchronous Only**: The dispose() method must be synchronous (void, not
  ///    Future\<void\>). Asynchronous cleanup creates shutdown race conditions.
  ///
  /// 3. **Idempotent**: Calling dispose() multiple times must be safe (no-op on
  ///    subsequent calls). Error handling may result in duplicate dispose calls.
  ///
  /// 4. **No Exceptions**: Catch and log exceptions internally rather than throwing.
  ///    The registry continues disposal on exceptions, but throwing complicates debugging.
  ///
  /// **See [Disposable] interface documentation for detailed contract and examples.**
  ///
  /// **If You Need Pre-Dispose Coordination**:
  /// If repositories require cleanup involving other services (e.g., flushing data,
  /// sending telemetry), implement an explicit shutdown sequence BEFORE dispose():
  ///
  /// ```dart
  /// // 1. Coordinate across repositories (async allowed)
  /// await myRepository.shutdown();
  ///
  /// // 2. Then dispose (synchronous, no cross-repository access)
  /// registry.dispose();
  /// ```
  ///
  /// **Type-Safe Disposal**: Only instances implementing the [Disposable]
  /// interface will have their dispose() method called. This provides compile-time
  /// safety instead of dynamic dispatch.
  ///
  /// **Error Handling**: Exceptions during individual dispose() calls are caught,
  /// logged, and do not prevent disposal of other instances. This ensures all
  /// resources get cleanup attempts even if some fail.
  ///
  /// **Post-Disposal State**: After calling dispose(), the registry clears all
  /// internal state and should not be used further. Any subsequent calls will fail.
  void dispose() {
    // Step 1: Dispose modules in reverse order (they manage their own instances)
    for (final module in _modules.reversed) {
      try {
        module.dispose();
      } catch (e) {
        LoggingService.instance.warning(
          'Failed to dispose module ${module.runtimeType}',
          e,
        );
      }
    }

    // Step 2: Dispose kind-specific instances in reverse order of creation
    for (final key in _kindCreationOrder.reversed) {
      final instance = _kindInstances[key];
      if (instance == null) continue;

      // Type-safe disposal using Disposable interface
      if (instance is Disposable) {
        try {
          instance.dispose();
        } catch (e) {
          LoggingService.instance.warning(
            'Failed to dispose ${key.type} for ${key.kind.name}',
            e,
          );
        }
      }
    }

    // Step 3: Dispose type-based registry instances in reverse order of creation
    for (final type in _creationOrder.reversed) {
      final instance = _instances[type];
      if (instance == null) continue;

      // Type-safe disposal using Disposable interface
      if (instance is Disposable) {
        try {
          instance.dispose();
        } catch (e) {
          LoggingService.instance.warning('Failed to dispose $type', e);
        }
      }
    }

    _modules.clear();
    _kindInstances.clear();
    _kindFactories.clear();
    _kindCreationOrder.clear();
    _kindInstantiating.clear();
    _defaultOrganismKind = null;
    _instances.clear();
    _factories.clear();
    _creationOrder.clear();
    _instantiating.clear();
  }
}
