import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_async.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_bloc.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_event.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_state.dart';
import 'package:seafoundry_community/models/records/record.dart';
import 'package:seafoundry_community/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'components/dialog_scroll_view.dart';

typedef StructureStepBuilder<
  TRecord extends Record,
  TState extends RecordFormState<TRecord>
> = Widget Function(BuildContext context, TState state);

typedef StructureDialogSuccessHandler<
  TRecord extends Record,
  TState extends RecordFormState<TRecord>
> = Future<void> Function(BuildContext context, TState state);

typedef StructureDialogErrorHandler<
  TRecord extends Record,
  TState extends RecordFormState<TRecord>
> = void Function(BuildContext context, TState state, String message);

typedef StructureDialogResultBuilder<
  TRecord extends Record,
  TState extends RecordFormState<TRecord>
> = TRecord? Function(TState state);

class StructureDialogConfig<
  TRecord extends Record,
  TState extends RecordFormState<TRecord>
> {
  const StructureDialogConfig({
    required this.icon,
    required this.progressTitle,
    required this.stepBuilders,
    required this.submitButtonLabel,
    this.titleBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.successHandler,
    this.errorHandler,
    this.resultBuilder,
    this.width = 480,
    this.maxHeight,
    this.contentPadding = const EdgeInsets.all(24),
    this.cancelButtonLabel = 'Cancel',
    this.backButtonLabel = 'Back',
    this.nextButtonLabel = 'Next',
    this.retryButtonLabel = 'Try Again',
    this.reviewBannerBuilder,
    this.actionsBuilder,
    this.autoInitialize = false,
  });

  final IconData icon;
  final String progressTitle;
  final Map<Type, StructureStepBuilder<TRecord, TState>> stepBuilders;
  final String submitButtonLabel;
  final String Function(TState state)? titleBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, String message)? errorBuilder;
  final StructureDialogSuccessHandler<TRecord, TState>? successHandler;
  final StructureDialogErrorHandler<TRecord, TState>? errorHandler;
  final StructureDialogResultBuilder<TRecord, TState>? resultBuilder;
  final double width;
  final double? maxHeight;
  final EdgeInsetsGeometry contentPadding;
  final String cancelButtonLabel;
  final String backButtonLabel;
  final String nextButtonLabel;
  final String retryButtonLabel;
  final Widget? Function(BuildContext context, TState state)?
  reviewBannerBuilder;
  final List<Widget> Function(BuildContext context, TState state)?
  actionsBuilder;
  final bool autoInitialize;
}

class StructureDialogShell<
  TRecord extends Record,
  TState extends RecordFormState<TRecord>,
  TBloc extends RecordFormBloc<TRecord, TState>
>
    extends StatelessWidget {
  const StructureDialogShell({super.key, required this.config});

  final StructureDialogConfig<TRecord, TState> config;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TBloc, TState>(
      listener: (context, state) async {
        if (state.submissionStatus == FormzSubmissionStatus.success) {
          if (config.successHandler != null) {
            await config.successHandler!(context, state);
          }
          if (!context.mounted) return;
          popSafeDialogContext(context, config.resultBuilder?.call(state));
        } else if (state.submissionStatus == FormzSubmissionStatus.failure &&
            state.submissionError != null) {
          config.errorHandler?.call(context, state, state.submissionError!);
        }
      },
      builder: (context, state) {
        if (config.autoInitialize &&
            state is AsyncRecordFormState<TRecord> &&
            state.loadStatus == RecordFormLoadStatus.initial) {
          final bloc = context.read<TBloc>();
          if (bloc is AsyncRecordFormBlocBase) {
            (bloc as AsyncRecordFormBlocBase).initialize();
          } else {
            bloc.add(const RecordFormInitialize());
          }
        }

        final theme = Theme.of(context);
        final asyncState = state is AsyncRecordFormState<TRecord>
            ? state
            : null;
        final isLoading =
            state.submissionStatus == FormzSubmissionStatus.inProgress ||
            asyncState?.loadStatus == RecordFormLoadStatus.loading;
        final hasError = state.submissionError != null;

        final titleText =
            config.titleBuilder?.call(state) ??
            (isLoading ? config.progressTitle : state.currentStep.title);

        final content = _buildContent(context, state, isLoading, hasError);
        final actions =
            config.actionsBuilder?.call(context, state) ??
            _buildActions(context, state, isLoading, hasError);

        return AlertDialog(
          title: Row(
            children: [
              Icon(config.icon, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(titleText)),
              if (!isLoading)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => popSafeDialogContext(context),
                ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: config.width,
              maxHeight: config.maxHeight ?? double.infinity,
            ),
            child: DialogScrollView(
              child: Padding(padding: config.contentPadding, child: content),
            ),
          ),
          actions: actions,
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    TState state,
    bool isLoading,
    bool hasError,
  ) {
    if (state is AsyncRecordFormState<TRecord>) {
      switch (state.loadStatus) {
        case RecordFormLoadStatus.initial:
        case RecordFormLoadStatus.loading:
          return config.loadingBuilder?.call(context) ??
              const _DefaultLoading();
        case RecordFormLoadStatus.failure:
          final message = state.loadError ?? 'Failed to load dialog data.';
          return config.errorBuilder?.call(context, message) ??
              _DefaultError(message: message);
        case RecordFormLoadStatus.success:
          break;
      }
    }

    if (hasError && state.submissionError != null) {
      return config.errorBuilder?.call(context, state.submissionError!) ??
          _DefaultError(message: state.submissionError!);
    }

    if (isLoading) {
      return config.loadingBuilder?.call(context) ?? const _DefaultLoading();
    }

    final builder = config.stepBuilders[state.currentStep.runtimeType];
    if (builder == null) {
      return const SizedBox.shrink();
    }

    final banner = config.reviewBannerBuilder?.call(context, state);

    final stepContent = builder(context, state);

    if (banner == null) {
      return stepContent;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [banner, const SizedBox(height: 12), stepContent],
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    TState state,
    bool isLoading,
    bool hasError,
  ) {
    final bloc = context.read<TBloc>();

    if (state is AsyncRecordFormState<TRecord>) {
      if (state.loadStatus == RecordFormLoadStatus.loading ||
          state.loadStatus == RecordFormLoadStatus.initial) {
        return [
          TextButton(
            onPressed: () => popSafeDialogContext(context),
            child: Text(config.cancelButtonLabel),
          ),
        ];
      }

      if (state.loadStatus == RecordFormLoadStatus.failure) {
        return [
          TextButton(
            onPressed: () => popSafeDialogContext(context),
            child: Text(config.cancelButtonLabel),
          ),
          ElevatedButton(
            onPressed: () {
              if (bloc is AsyncRecordFormBlocBase) {
                (bloc as AsyncRecordFormBlocBase).initialize();
              } else {
                bloc.add(const RecordFormInitialize());
              }
            },
            child: Text(config.retryButtonLabel),
          ),
        ];
      }
    }

    if (hasError) {
      return [
        TextButton(
          onPressed: () => popSafeDialogContext(context),
          child: Text(config.cancelButtonLabel),
        ),
        ElevatedButton(
          onPressed: () => bloc.add(const RecordFormReset()),
          child: Text(config.retryButtonLabel),
        ),
      ];
    }

    if (isLoading) {
      return const [];
    }

    final actions = <Widget>[
      TextButton(
        onPressed: () {
          if (state.canGoBack) {
            bloc.add(const RecordFormPreviousStep());
          } else {
            popSafeDialogContext(context);
          }
        },
        child: Text(
          state.canGoBack ? config.backButtonLabel : config.cancelButtonLabel,
        ),
      ),
    ];

    if (state.isLastStep) {
      actions.add(
        ElevatedButton(
          onPressed: () => bloc.add(const RecordFormSubmit()),
          child: Text(config.submitButtonLabel),
        ),
      );
    } else {
      actions.add(
        ElevatedButton(
          onPressed: state.canGoForward
              ? () => bloc.add(const RecordFormNextStep())
              : null,
          child: Text(config.nextButtonLabel),
        ),
      );
    }

    return actions;
  }
}

class _DefaultLoading extends StatelessWidget {
  const _DefaultLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 160,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _DefaultError extends StatelessWidget {
  const _DefaultError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}