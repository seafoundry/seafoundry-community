import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/cubits/navigation/deep_link_cubit.dart';
import 'package:seafoundry_community/cubits/navigation/deep_link_state.dart';

/// Listens for deep-link state changes and surfaces user feedback.
class DeepLinkFeedbackListener extends StatelessWidget {
  const DeepLinkFeedbackListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<DeepLinkCubit, DeepLinkState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) {
          return;
        }

        if (state.status == DeepLinkStatus.failed) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  state.errorMessage ??
                      'Unable to open link. Please check that it belongs to this organization.',
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
        } else if (state.status == DeepLinkStatus.navigated) {
          messenger.hideCurrentSnackBar();
        }
      },
      child: child,
    );
  }
}
