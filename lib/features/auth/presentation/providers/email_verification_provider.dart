import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';

/// What the "check your mail" screen is doing right now.
class EmailVerificationState extends Equatable {
  const EmailVerificationState({
    this.email,
    this.secondsUntilResend = 0,
    this.isSending = false,
    this.isConfirming = false,
    this.isConfirmed = false,
    this.lastSentAt,
    this.failure,
  });

  /// The address the code went to, where the screen was told one.
  final String? email;

  /// Counts down to zero, at which point the resend button comes back.
  final int secondsUntilResend;

  final bool isSending;
  final bool isConfirming;

  /// The screen's terminal state: the address is confirmed and sign-in will
  /// no longer be refused with `EMAIL_NOT_CONFIRMED`.
  final bool isConfirmed;

  final DateTime? lastSentAt;

  final Failure? failure;

  bool get canResend =>
      secondsUntilResend == 0 && !isSending && (email?.isNotEmpty ?? false);

  bool get isBusy => isSending || isConfirming;

  EmailVerificationState copyWith({
    String? email,
    int? secondsUntilResend,
    bool? isSending,
    bool? isConfirming,
    bool? isConfirmed,
    DateTime? lastSentAt,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return EmailVerificationState(
      email: email ?? this.email,
      secondsUntilResend: secondsUntilResend ?? this.secondsUntilResend,
      isSending: isSending ?? this.isSending,
      isConfirming: isConfirming ?? this.isConfirming,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      lastSentAt: lastSentAt ?? this.lastSentAt,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    email,
    secondsUntilResend,
    isSending,
    isConfirming,
    isConfirmed,
    lastSentAt,
    failure,
  ];
}

/// Drives `POST /auth/verifications/email/` and its `verify/` sibling.
///
/// The cooldown is the point of this class. Both endpoints are capped at
/// **3 requests per hour** (api-docs §3.6), and a 429 there comes back as a
/// bare `{"detail": ...}` with no error code to read — so a screen that lets
/// anyone tap "send again" freely burns the hour's budget in seconds and
/// then cannot explain itself. A local countdown keeps the third attempt for
/// when it is worth something.
class EmailVerificationController extends Notifier<EmailVerificationState> {
  Timer? _ticker;

  /// Long enough that three taps cannot cost an hour of sending, short
  /// enough that a letter which genuinely did not arrive can be chased.
  static const Duration resendCooldown = Duration(seconds: 60);

  @override
  EmailVerificationState build() {
    ref.onDispose(_stopTicker);
    return const EmailVerificationState();
  }

  void setEmail(String? email) {
    final trimmed = email?.trim();
    if (trimmed == state.email) return;
    state = EmailVerificationState(email: trimmed);
  }

  /// Asks for a new letter, then starts the countdown whatever the answer
  /// was — a refusal still cost a request against the hourly budget.
  Future<void> resend() async {
    final email = state.email;
    if (email == null || email.isEmpty || !state.canResend) return;

    state = state.copyWith(isSending: true, clearFailure: true);

    final result = await ref
        .read(requestEmailVerificationUseCaseProvider)
        .execute(email: email);

    state = result.fold(
      (failure) => state.copyWith(isSending: false, failure: failure),
      (_) => state.copyWith(
        isSending: false,
        lastSentAt: DateTime.now(),
        clearFailure: true,
      ),
    );

    _startCooldown();
  }

  /// Confirms [token]. Returns true when the address is now confirmed.
  Future<bool> confirm(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty || state.isConfirming || state.isConfirmed) {
      return false;
    }

    state = state.copyWith(isConfirming: true, clearFailure: true);

    final result = await ref
        .read(confirmEmailVerificationUseCaseProvider)
        .execute(token: trimmed);

    return result.fold(
      (failure) {
        state = state.copyWith(isConfirming: false, failure: failure);
        return false;
      },
      (_) {
        _stopTicker();
        state = state.copyWith(
          isConfirming: false,
          isConfirmed: true,
          clearFailure: true,
        );
        return true;
      },
    );
  }

  void clearFailure() {
    if (state.failure == null) return;
    state = state.copyWith(clearFailure: true);
  }

  /// Starts the countdown. Exposed for the screen's first build, which puts
  /// the cooldown up straight after a registration has already sent one.
  void startCooldown() => _startCooldown();

  void _startCooldown() {
    _stopTicker();
    state = state.copyWith(secondsUntilResend: resendCooldown.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.secondsUntilResend - 1;
      if (remaining <= 0) {
        _stopTicker();
        state = state.copyWith(secondsUntilResend: 0);
        return;
      }
      state = state.copyWith(secondsUntilResend: remaining);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}

final emailVerificationProvider =
    NotifierProvider<EmailVerificationController, EmailVerificationState>(
      EmailVerificationController.new,
      isAutoDispose: true,
    );
