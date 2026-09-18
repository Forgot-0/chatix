import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/presentation/providers/email_verification_provider.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// The screen's whole job is to spend three requests an hour carefully
/// (api-docs §3.6), so the cooldown is what these check.
void main() {
  late _MockAuthRepository repository;

  /// The provider is auto-disposing, so a bare `read` would tear it down —
  /// and the countdown with it — between one line of a test and the next.
  /// A standing listener stands in for the screen that would be watching it.
  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    container.listen<EmailVerificationState>(
      emailVerificationProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    return container;
  }

  setUp(() {
    repository = _MockAuthRepository();
    when(
      () => repository.requestEmailVerification(email: any(named: 'email')),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => repository.confirmEmailVerification(token: any(named: 'token')),
    ).thenAnswer((_) async => const Right(null));
  });

  testWidgets('a resend starts a countdown that blocks the next one', (
    tester,
  ) async {
    final container = makeContainer();
    final controller = container.read(emailVerificationProvider.notifier);

    controller.setEmail('ada@example.com');
    await controller.resend();

    expect(
      container.read(emailVerificationProvider).secondsUntilResend,
      EmailVerificationController.resendCooldown.inSeconds,
    );
    expect(container.read(emailVerificationProvider).canResend, isFalse);

    // Tapping again while the countdown runs must not reach the server.
    await controller.resend();
    verify(
      () => repository.requestEmailVerification(email: 'ada@example.com'),
    ).called(1);

    await tester.pump(const Duration(seconds: 1));
    expect(
      container.read(emailVerificationProvider).secondsUntilResend,
      EmailVerificationController.resendCooldown.inSeconds - 1,
    );

    await tester.pump(EmailVerificationController.resendCooldown);
    expect(container.read(emailVerificationProvider).secondsUntilResend, 0);
    expect(container.read(emailVerificationProvider).canResend, isTrue);

    await controller.resend();
    verify(
      () => repository.requestEmailVerification(email: 'ada@example.com'),
    ).called(1);

    await tester.pump(EmailVerificationController.resendCooldown);
    container.dispose();
  });

  testWidgets('a refused resend still costs the cooldown', (tester) async {
    when(
      () => repository.requestEmailVerification(email: any(named: 'email')),
    ).thenAnswer((_) async => const Left(RateLimitFailure()));

    final container = makeContainer();
    final controller = container.read(emailVerificationProvider.notifier);

    controller.setEmail('ada@example.com');
    await controller.resend();

    final state = container.read(emailVerificationProvider);
    expect(state.failure, isA<RateLimitFailure>());
    // The request was made and counted by the server's own limiter, so the
    // button has to wait whatever the answer was.
    expect(state.canResend, isFalse);

    await tester.pump(EmailVerificationController.resendCooldown);
    container.dispose();
  });

  testWidgets('nothing is sent without an address', (tester) async {
    final container = makeContainer();

    await container.read(emailVerificationProvider.notifier).resend();

    verifyNever(
      () => repository.requestEmailVerification(email: any(named: 'email')),
    );
    container.dispose();
  });

  testWidgets('confirming reports success and stops the countdown', (
    tester,
  ) async {
    final container = makeContainer();
    final controller = container.read(emailVerificationProvider.notifier);

    controller.setEmail('ada@example.com');
    await controller.resend();

    final confirmed = await controller.confirm('  code-123  ');

    expect(confirmed, isTrue);
    expect(container.read(emailVerificationProvider).isConfirmed, isTrue);
    // Trimmed before it is sent: a code pasted out of an email brings
    // whitespace with it.
    verify(
      () => repository.confirmEmailVerification(token: 'code-123'),
    ).called(1);

    // Confirmed is terminal — a second attempt must not spend another of the
    // hour's three.
    expect(await controller.confirm('code-123'), isFalse);
    verifyNever(
      () => repository.confirmEmailVerification(token: any(named: 'token')),
    );
    container.dispose();
  });

  testWidgets('a bad code is reported and leaves the screen usable', (
    tester,
  ) async {
    when(
      () => repository.confirmEmailVerification(token: any(named: 'token')),
    ).thenAnswer(
      (_) async => const Left(
        ApiFailure(
          code: 'INVALID_TOKEN',
          message: 'invalid',
          detail: <String, dynamic>{},
          status: 400,
        ),
      ),
    );

    final container = makeContainer();
    final controller = container.read(emailVerificationProvider.notifier);

    expect(await controller.confirm('nope'), isFalse);

    final state = container.read(emailVerificationProvider);
    expect(state.isConfirmed, isFalse);
    expect(state.isConfirming, isFalse);
    expect((state.failure as ApiFailure).code, 'INVALID_TOKEN');

    controller.clearFailure();
    expect(container.read(emailVerificationProvider).failure, isNull);
    container.dispose();
  });

  testWidgets('an empty code is not a request', (tester) async {
    final container = makeContainer();

    expect(
      await container.read(emailVerificationProvider.notifier).confirm('   '),
      isFalse,
    );
    verifyNever(
      () => repository.confirmEmailVerification(token: any(named: 'token')),
    );
    container.dispose();
  });
}
