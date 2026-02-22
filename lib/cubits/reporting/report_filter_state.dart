// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/reporting/filter_config.dart';
import 'package:seafoundry_app/models/reporting/time_range_config.dart';

/// State for report filter management.
sealed class ReportFilterState extends Equatable {
  const ReportFilterState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any filters are configured.
final class ReportFilterInitial extends ReportFilterState {
  const ReportFilterInitial();
}

/// State with active filter configuration.
final class ReportFilterActive extends ReportFilterState {
  const ReportFilterActive({
    required this.timeRange,
    required this.filters,
    this.isDirty = false,
  });

  final TimeRangeConfig timeRange;
  final FilterConfig filters;
  final bool isDirty;

  ReportFilterActive copyWith({
    TimeRangeConfig? timeRange,
    FilterConfig? filters,
    bool? isDirty,
  }) {
    return ReportFilterActive(
      timeRange: timeRange ?? this.timeRange,
      filters: filters ?? this.filters,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  List<Object?> get props => [timeRange, filters, isDirty];
}
