import 'package:equatable/equatable.dart';

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
