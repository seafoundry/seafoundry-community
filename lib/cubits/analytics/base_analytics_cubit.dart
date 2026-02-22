// @tier: community
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Base sealed class for analytics states
sealed class BaseAnalyticsState extends Equatable {
  const BaseAnalyticsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded
final class AnalyticsInitial extends BaseAnalyticsState {
  const AnalyticsInitial();
}

/// Loading state while fetching data
final class AnalyticsLoading extends BaseAnalyticsState {
  const AnalyticsLoading();
}

/// Successfully loaded state with analytics data
base class AnalyticsLoaded<T> extends BaseAnalyticsState {
  const AnalyticsLoaded({required this.data, required this.sites});

  final T data;
  final List<Site> sites;

  @override
  List<Object?> get props => [data, sites];
}

/// Error state when data loading fails
final class AnalyticsError extends BaseAnalyticsState {
  const AnalyticsError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Abstract base cubit for analytics implementations using Template Method pattern
///
/// Subclasses must implement:
/// - [createDataStream]: Stream of raw data to process
/// - [processData]: Transform raw data into analytics state
///
/// The base class handles:
/// - Date window filtering via [startDate] and [endDate]
/// - Site caching
/// - Subscription lifecycle management
/// - Error handling and state transitions
///
/// **Site Caching Design Note (C7/C9)**:
/// Each analytics cubit maintains its own [_cachedSites] list rather than sharing
/// a single cache. This is intentional for the following reasons:
/// 1. **Lifecycle isolation**: Each cubit has independent lifecycle management
/// 2. **Stream subscription ownership**: Sites are updated via subscriptions that
///    must be managed per-cubit to ensure proper cleanup
/// 3. **Processing independence**: Different cubits may process site data at
///    different times and shouldn't block each other
/// 4. **Testability**: Independent caches allow cubits to be tested in isolation
///
/// The memory overhead is minimal (site lists are small reference copies) and
/// Firestore's client-side cache ensures the underlying data isn't duplicated.
abstract class BaseAnalyticsCubit<T> extends Cubit<BaseAnalyticsState>
    with CubitStreamSubscriptionMixin {
  BaseAnalyticsCubit({
    DateTime? startDate,
    DateTime? endDate,
  })  : _startDate = startDate,
        _endDate = endDate,
        super(const AnalyticsInitial());

  final DateTime? _startDate;
  final DateTime? _endDate;
  List<Site> _cachedSites = [];

  /// Date window start (inclusive)
  DateTime? get startDate => _startDate;

  /// Date window end (inclusive)
  DateTime? get endDate => _endDate;

  /// Cached sites for analytics computation
  List<Site> get cachedSites => _cachedSites;

  /// Initialize the cubit by setting up data stream subscription
  void init() {
    emit(const AnalyticsLoading());
    listenWithKey<List<dynamic>>(
      'analytics_data',
      createDataStream(),
      onData: _onData,
      onError: _onError,
    );
  }

  /// Create the stream of data that the cubit will process
  ///
  /// Called by [init] to set up the data subscription.
  /// Subclasses should return a stream that emits data updates.
  Stream<List<dynamic>> createDataStream();

  /// Process raw data into an analytics state
  ///
  /// Called when new data arrives from [createDataStream].
  /// Subclasses should transform the raw data into their specific state.
  Future<BaseAnalyticsState> processData(
    List<dynamic> data,
    List<Site> sites,
  );

  /// Refresh the analytics by resubscribing to the data stream
  Future<void> refresh() async {
    init();
  }

  void _onData(List<dynamic> data) async {
    try {
      final state = await processData(data, _cachedSites);
      if (!isClosed) {
        emit(state);
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to process analytics data',
        e,
        stackTrace,
      );
      if (!isClosed) {
        emit(AnalyticsError(message: 'Failed to process data: $e'));
      }
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    LoggingService.instance.error(
      'Analytics data stream error',
      error,
      stackTrace,
    );
    if (!isClosed) {
      emit(AnalyticsError(message: 'Failed to load analytics: $error'));
    }
  }

  /// Update the cached sites list
  void updateSites(List<Site> sites) {
    _cachedSites = sites;
  }

  // Subscriptions are automatically cancelled by CubitStreamSubscriptionMixin
}
