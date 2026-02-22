// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit that ignores emit calls after close to avoid StateError from async work.
abstract class SafeCubit<S> extends Cubit<S> {
  SafeCubit(super.initialState);

  @override
  void emit(S state) {
    if (isClosed) return;
    super.emit(state);
  }
}
