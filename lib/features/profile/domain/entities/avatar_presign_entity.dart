import 'package:equatable/equatable.dart';

class AvatarPresignEntity extends Equatable {
  final String url;

  final String fileKey;

  const AvatarPresignEntity({required this.url, required this.fileKey});

  @override
  List<Object?> get props => [url, fileKey];
}
