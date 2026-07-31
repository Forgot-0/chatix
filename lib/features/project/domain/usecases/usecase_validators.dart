import 'package:chatix/core/error/failures.dart';

/// Shared client-side guards for the project use cases. Kept here (rather
/// than duplicated per file) since almost every list operation needs the
/// same paging bounds. Each returns an [InputFailure] to surface, or `null`
/// when the input is valid.

/// api-docs §1.5: `page >= 1`, `1 <= page_size <= 100`.
InputFailure? validatePaging(int page, int pageSize) {
  if (page < 1) return const InputFailure(message: 'Page must be 1 or greater');
  if (pageSize < 1 || pageSize > 100) {
    return const InputFailure(message: 'Page size must be between 1 and 100');
  }
  return null;
}

/// A positive integer id (project ids, user ids, role ids are all `> 0`).
InputFailure? validatePositiveId(int id, String label) {
  if (id < 1) return InputFailure(message: '$label must be a positive id');
  return null;
}

/// A non-empty UUID/string id (positions & applications use UUID strings).
InputFailure? validateStringId(String id, String label) {
  if (id.trim().isEmpty) return InputFailure(message: '$label is required');
  return null;
}
