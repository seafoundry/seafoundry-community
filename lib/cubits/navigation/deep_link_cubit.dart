import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/models/graph/graph_node.dart';
import 'package:seafoundry_community/patterns/navigation/deep_link_handler.dart';
import 'package:seafoundry_community/repositories/graph_repository.dart';
import 'package:seafoundry_community/services/deep_link_service.dart';
import 'package:seafoundry_community/services/logging_service.dart';

import 'deep_link_state.dart';

typedef DeepLinkResolver = Future<GraphNode?> Function(Uri uri);
typedef DeepLinkNavigator = Future<void> Function(GraphNode node);

/// Context for invitation deep links
class InviteContext {
  final String invitationId;
  final DateTime receivedAt;

  const InviteContext({
    required this.invitationId,
    required this.receivedAt,
  });

  @override
  String toString() => 'InviteContext(invitationId: $invitationId, receivedAt: $receivedAt)';
}

class DeepLinkCubit extends Cubit<DeepLinkState> {
  DeepLinkCubit({
    required DeepLinkServiceBase deepLinkService,
    required DeepLinkResolver resolver,
    required DeepLinkNavigator navigator,
  })  : _deepLinkService = deepLinkService,
        _resolver = resolver,
        _navigator = navigator,
        super(const DeepLinkState()) {
    _initialize();
  }

  final DeepLinkServiceBase _deepLinkService;
  final DeepLinkResolver _resolver;
  final DeepLinkNavigator _navigator;

  InviteContext? _pendingInviteContext;

  InviteContext? get pendingInviteContext => _pendingInviteContext;

  void clearInviteContext() {
    _pendingInviteContext = null;
  }

  void _initialize() {
    unawaited(
      _deepLinkService.start(
        onUri: _handleUri,
        onError: (error, stackTrace) {
          emit(
            state.copyWith(
              status: DeepLinkStatus.failed,
              errorMessage: error.toString(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleUri(Uri uri) async {
    emit(
      state.copyWith(
        status: DeepLinkStatus.handling,
        lastUri: uri,
        errorMessage: null,
      ),
    );

    // Check if this is an invite link and store context
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'invite') {
      final invitationId = uri.pathSegments.length > 1
          ? uri.pathSegments[1]
          : uri.queryParameters['id'] ?? uri.queryParameters['token'];
      if (invitationId != null && invitationId.isNotEmpty) {
        _pendingInviteContext = InviteContext(
          invitationId: invitationId,
          receivedAt: DateTime.now(),
        );
        LoggingService.instance.info('DeepLinkCubit: Stored invite context for $invitationId');
      }
    }

    try {
      final node = await _resolver(uri);
      if (isClosed) return;
      if (node == null) {
        emit(
          state.copyWith(
            status: DeepLinkStatus.failed,
            errorMessage: 'No graph node could be resolved for $uri',
          ),
        );
        return;
      }

      await _navigator(node);
      if (isClosed) return;
      emit(
        state.copyWith(status: DeepLinkStatus.navigated),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      LoggingService.instance.error(
        'Failed to handle deep link $uri',
        error,
        stackTrace,
      );
      emit(
        state.copyWith(
          status: DeepLinkStatus.failed,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _deepLinkService.dispose();
    return super.close();
  }

  // Convenience helper for manual string-based handling (e.g., debug console).
  Future<void> handleDeepLinkString(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      emit(
        state.copyWith(
          status: DeepLinkStatus.failed,
          errorMessage: 'Invalid deep link: $link',
        ),
      );
      return;
    }
    await _handleUri(uri);
  }

  static DeepLinkResolver resolverForGraphRepository(
    GraphRepository graphRepository,
  ) {
    return (uri) => DeepLinkHandler.parseUri(
          uri,
          graphRepository: graphRepository,
        );
  }
}
