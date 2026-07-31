import 'package:equatable/equatable.dart';

/// Generic paginated list envelope for `PageResult<T>` (api-docs §1.5).
///
/// ⚠️ The real backend JSON only ever contains **4 fields** — `items`,
/// `total`, `page`, `page_size`. `total_pages` / `has_next` / `has_previous`
/// are `@property`s on the server's Python dataclass and are **not**
/// serialized (api-docs §0.3, confirmed against the actual FastAPI/Pydantic
/// behaviour), even though it would be natural to assume otherwise. This
/// class computes them client-side from `total`/`page`/`page_size` instead
/// of ever trying to read them out of the response body.
///
/// Shared across every paginated list in the app (profiles, projects,
/// positions, applications, roles/permissions/sessions, users,
/// notifications — api-docs §1.5, §10.3) — put it here once rather than
/// re-declaring per feature.
class PageResult<T> extends Equatable {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  const PageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// `ceil(total / page_size)`. `0` when [pageSize] isn't positive, rather
  /// than throwing on a malformed/empty response.
  int get totalPages => pageSize <= 0 ? 0 : (total / pageSize).ceil();

  bool get hasNext => page < totalPages;

  bool get hasPrevious => page > 1;

  bool get isEmpty => items.isEmpty;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromJsonT,
  ) {
    return PageResult<T>(
      items: (json['items'] as List<dynamic>).map(fromJsonT).toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
    );
  }

  /// Maps [items] to a different type while keeping the pagination
  /// metadata untouched — how a repository turns a data-layer
  /// `PageResult<XModel>` into a domain-layer `PageResult<XEntity>`
  /// (mirrors `Either.map`, which the rest of the data layer already uses
  /// for the same model→entity step).
  PageResult<R> map<R>(R Function(T item) convert) {
    return PageResult<R>(
      items: items.map(convert).toList(),
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  List<Object?> get props => [items, total, page, pageSize];
}
