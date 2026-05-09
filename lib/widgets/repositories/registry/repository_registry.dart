// @tier: community
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/repositories/registry/disposable.dart';

/// Simple type-based repository registry with lazy factory support.
///
/// Community is coral-only, so OrganismKind-aware APIs are maintained as thin
/// compatibility wrappers around type-based registration.
class RepositoryRegistry {
  final Map<Type, Object> _instances = {};
  final Map<Type, Object Function()> _factories = {};
  final List<Type> _creationOrder = [];
  final Set<Type> _instantiating = {};
  OrganismKind? _defaultOrganismKind;

  void register<T extends Object>({
    T? instance,
    T Function()? factory,
  }) {
    assert(
      (instance != null) != (factory != null),
      'Exactly one of instance or factory must be provided',
    );

    final type = T;
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

  T get<T extends Object>() {
    final type = T;

    final existing = _instances[type];
    if (existing != null) {
      return existing as T;
    }

    final factory = _factories[type];
    if (factory != null) {
      if (_instantiating.contains(type)) {
        final chain = _instantiating.toList()..add(type);
        throw StateError('Circular dependency detected: ${chain.join(' -> ')}');
      }

      _instantiating.add(type);
      try {
        final created = factory() as T;
        _factories.remove(type);
        _instances[type] = created;
        _creationOrder.add(type);
        return created;
      } finally {
        _instantiating.remove(type);
      }
    }

    throw StateError('No repository registered for type $T');
  }

  bool isRegistered<T extends Object>() {
    final type = T;
    return _instances.containsKey(type) || _factories.containsKey(type);
  }

  void setDefaultOrganismKind(OrganismKind kind) {
    _defaultOrganismKind = kind;
  }

  OrganismKind? getDefaultOrganismKind() => _defaultOrganismKind;

  void registerForKind<T extends Object>(
    OrganismKind kind, {
    T? instance,
    T Function()? factory,
  }) {
    register<T>(instance: instance, factory: factory);
  }

  T getForKind<T extends Object>(
    OrganismKind kind, {
    bool fallbackToDefault = true,
  }) {
    if (isRegistered<T>()) {
      return get<T>();
    }

    if (fallbackToDefault && _defaultOrganismKind != null && isRegistered<T>()) {
      return get<T>();
    }

    throw StateError(
      'No repository registered for type $T and OrganismKind ${kind.name}',
    );
  }

  void registerAllKinds<T extends Object>(Map<OrganismKind, T> kindToInstanceMap) {
    if (kindToInstanceMap.isEmpty) {
      return;
    }

    final preferredKind =
        _defaultOrganismKind != null && kindToInstanceMap.containsKey(_defaultOrganismKind)
        ? _defaultOrganismKind!
        : kindToInstanceMap.keys.first;

    final preferredInstance = kindToInstanceMap[preferredKind];
    if (preferredInstance == null) {
      return;
    }
    registerForKind<T>(preferredKind, instance: preferredInstance);
  }

  Map<OrganismKind, T> getAllKinds<T extends Object>() {
    if (!isRegistered<T>()) {
      return <OrganismKind, T>{};
    }

    final resolvedKind = _defaultOrganismKind ?? OrganismKind.coral;
    return <OrganismKind, T>{resolvedKind: get<T>()};
  }

  bool isRegisteredForKind<T extends Object>(OrganismKind kind) {
    return isRegistered<T>();
  }

  List<Type> get instantiatedTypes => List.unmodifiable(_creationOrder);

  Map<Type, Object> get instantiatedInstances => Map.unmodifiable(_instances);

  void dispose() {
    for (final type in _creationOrder.reversed) {
      final instance = _instances[type];
      if (instance is! Disposable) {
        continue;
      }
      try {
        instance.dispose();
      } catch (e) {
        LoggingService.instance.warning('Failed to dispose $type', e);
      }
    }

    _instances.clear();
    _factories.clear();
    _creationOrder.clear();
    _instantiating.clear();
    _defaultOrganismKind = null;
  }
}
