// @tier: community
import 'dart:async';

import 'package:meta/meta.dart';

import '../widgets/spreadsheet/spreadsheet_base.dart';

/// Shared pagination helpers for spreadsheets that rely on the SpreadsheetBase pattern.
class PaginationService<T> {
  const PaginationService();

  /// Creates a `PageLoader` backed by a synchronous iterable.
  PageLoader<T> buildListLoader(Iterable<T> Function() source) {
    return ({required int pageSize, PageCursor? startAfter, String? sortField, bool descending = true}) async {
      final items = source().toList(growable: false);
      final startIndex = startAfter is int ? startAfter : 0;
      final pageItems = items.skip(startIndex).take(pageSize).toList();
      final nextIndex = startIndex + pageItems.length;
      final nextCursor = nextIndex < items.length ? nextIndex : null;
      return PageResult<T>(items: pageItems, nextCursor: nextCursor, totalCount: items.length);
    };
  }

  /// Wraps a remote fetcher allowing optional cursor transforms and total count support.
  PageLoader<T> buildAsyncLoader({
    required Future<PaginationFetchResult<T>> Function({
      required int limit,
      Object? cursor,
      bool descending,
      String? sortField,
    })
    fetchPage,
    Object? Function(PageCursor? cursor)? encodeCursor,
    PageCursor? Function(Object? rawCursor)? decodeCursor,
  }) {
    return ({required int pageSize, PageCursor? startAfter, String? sortField, bool descending = true}) async {
      final encoded = encodeCursor?.call(startAfter) ?? startAfter;
      final result = await fetchPage(limit: pageSize, cursor: encoded, descending: descending, sortField: sortField);
      final nextCursor = decodeCursor?.call(result.nextCursor) ?? result.nextCursor;
      return PageResult<T>(items: result.items, nextCursor: nextCursor, totalCount: result.totalCount);
    };
  }
}

@immutable
class PaginationFetchResult<T> {
  const PaginationFetchResult({required this.items, this.nextCursor, this.totalCount});

  final List<T> items;
  final Object? nextCursor;
  final int? totalCount;
}
