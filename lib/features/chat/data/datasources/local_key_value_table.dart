/// The chat store's tables live in `core/storage` now, shared with the
/// contact book; this keeps the chat feature's imports where they were.
library;

export 'package:chatix/core/storage/key_value_table.dart'
    show LocalKeyValueTable, MemoryKeyValueTable;
