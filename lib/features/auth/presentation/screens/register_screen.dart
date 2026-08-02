import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/error/failure_messages.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Read live by the "repeat password" validator, not just at submit time,
  // so it can compare against whatever is currently typed in `password`.
  String _currentPassword() =>
      (_formKey.currentState?.fields['password']?.value as String?) ?? '';

  void _register() {
    final isValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();

    final values = _formKey.currentState!.value;
    ref.read(authProvider.notifier).register(
      username: values['username'] as String,
      email: values['email'] as String,
      password: values['password'] as String,
      passwordRepeat: values['password_repeat'] as String,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        AppUtils.showSnackBar(
          context,
          message: friendlyFailureMessage(next.error),
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    });

    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: FormBuilder(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.flutter_dash, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  const Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Register to get started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FormBuilderTextField(
                    name: 'username',
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: '4-100 characters',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: AuthFieldValidators.username,
                  ),
                  const SizedBox(height: 16),
                  FormBuilderTextField(
                    name: 'email',
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: AuthFieldValidators.email,
                  ),
                  const SizedBox(height: 16),
                  FormBuilderTextField(
                    name: 'password',
                    obscureText: !_isPasswordVisible,
                    // Re-validate the "repeat" field live as this one
                    // changes, so a stale "passwords do not match" error
                    // doesn't linger after the person fixes this field.
                    onChanged: (_) => _formKey.currentState?.fields['password_repeat']
                        ?.validate(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: '8+ chars, upper/lower/digit/special',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: AuthFieldValidators.password,
                  ),
                  const SizedBox(height: 16),
                  FormBuilderTextField(
                    name: 'password_repeat',
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Confirm your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: AuthFieldValidators.passwordRepeat(_currentPassword),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Register'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.go(LoginRoute.location);
                        },
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
