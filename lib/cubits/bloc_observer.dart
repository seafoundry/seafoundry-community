// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/event/event_cubit.dart';

import '../services/crash_reporting_service.dart';
import '../services/logging_service.dart';

class AppBlocObserver extends BlocObserver {
  AppBlocObserver();

  final LoggingService _logger = LoggingService.instance;
  final CrashReportingService _crashReporting = CrashReportingService.instance;

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);

    final blocName = bloc.runtimeType.toString();
    final eventName = event.runtimeType.toString();

    _logger.logBlocEvent(blocName, eventName, details: {'event': event.toString()});

    // Add to crash reporting context
    _crashReporting.addLogMessage('BLoC Event: $blocName -> $eventName');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);

    final blocName = bloc.runtimeType.toString();

    _logger.error('BLoC Error in $blocName', error, stackTrace);

    // Log error to crash reporting
    _crashReporting.addLogMessage('BLoC Error: $blocName - $error', level: 'error');
    _crashReporting.addMetadata('last_bloc_error', '$blocName: $error');
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);

    if (bloc is EventCubit) {
      return;
    }

    final blocName = bloc.runtimeType.toString();
    final currentState = change.currentState.runtimeType.toString();
    final nextState = change.nextState.runtimeType.toString();

    // Format state strings for better readability
    final currentStateStr = change.currentState.toString();
    final nextStateStr = change.nextState.toString();

    // Create a formatted details map with clear separation
    final details = {
      '\n📤 CURRENT': currentStateStr,
      '\n━━━━━━━━━━': '────────────────────────────────────',
      '\n📥 NEXT': nextStateStr,
    };

    _logger.logBlocState(blocName, '$currentState -> $nextState', details: details);

    // Add to crash reporting context for the latest state
    _crashReporting.addMetadata('last_bloc_state', '$blocName: $nextState');
  }

  @override
  void onTransition(Bloc<dynamic, dynamic> bloc, Transition<dynamic, dynamic> transition) {
    super.onTransition(bloc, transition);

    final blocName = bloc.runtimeType.toString();
    final eventName = transition.event.runtimeType.toString();
    final currentState = transition.currentState.runtimeType.toString();
    final nextState = transition.nextState.runtimeType.toString();

    // Add transition to crash reporting context
    _crashReporting.addLogMessage('BLoC Transition: $blocName - $eventName: $currentState -> $nextState');
  }
}
