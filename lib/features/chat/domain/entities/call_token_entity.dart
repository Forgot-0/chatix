import 'package:equatable/equatable.dart';

class CallTokenEntity extends Equatable {
  final String token;

  final String slug;

  final String livekitUrl;

  const CallTokenEntity({
    required this.token,
    required this.slug,
    required this.livekitUrl,
  });

  @override
  List<Object?> get props => [token, slug, livekitUrl];
}
