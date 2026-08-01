import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:chatix/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/send_message_use_case.dart';

/// Data layer dependency injection providers
/// These providers are responsible for creating and managing data layer instances

// --- Data Source ---
final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSourceImpl();
});

// --- Repository ---
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(chatRemoteDataSourceProvider));
});

// --- Use Cases ---
final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  return SendMessageUseCase(ref.watch(chatRepositoryProvider));
});
