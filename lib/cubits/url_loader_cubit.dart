// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

sealed class UrlLoaderState extends Equatable {
  const UrlLoaderState({required this.url});
  final String url;

  @override
  List<Object?> get props => [url];
}

class UrlLoaderInitial extends UrlLoaderState {
  const UrlLoaderInitial({required super.url});
}

class UrlLoaderLoading extends UrlLoaderState {
  const UrlLoaderLoading({required super.url});
}

class UrlLoaderNodeLoaded extends UrlLoaderState {
  const UrlLoaderNodeLoaded({required super.url, required this.node});
  final GraphNode node;
}

class UrlLoaderNodeNotFound extends UrlLoaderState {
  const UrlLoaderNodeNotFound({required super.url});
}

class UrlLoaderError extends UrlLoaderState {
  const UrlLoaderError({required super.url, required this.error});
  final Object error;

  @override
  List<Object?> get props => [url, error];
}

class UrlLoaderCubit extends SafeCubit<UrlLoaderState> {
  UrlLoaderCubit({required this.urlPath, required this.graphRepository}) : super(UrlLoaderInitial(url: urlPath));

  final String urlPath;
  final GraphRepository graphRepository;

  Future<void> load() async {
    emit(UrlLoaderLoading(url: urlPath));
    try {
      final node = await graphRepository.getNodeForUrlPath(urlPath);
      if (node == null) {
        emit(UrlLoaderNodeNotFound(url: urlPath));
      } else {
        emit(UrlLoaderNodeLoaded(url: urlPath, node: node));
      }
    } on FirebaseException catch (e, stackTrace) {
      LoggingService.instance.error('Firebase error loading URL $urlPath: ${e.message}', e, stackTrace);
      emit(UrlLoaderError(url: urlPath, error: e));
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error loading URL $urlPath', e, stackTrace);
      emit(UrlLoaderError(url: urlPath, error: e));
    }
  }
}
