import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../widgets/common_widgets.dart';
import '../widgets/comiverse_logo.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeRequested = false;
  bool _submitting = false;
  bool _resending = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;
  String? _status;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode({bool resend = false}) async {
    if (!_emailFormKey.currentState!.validate() || _submitting || _resending) {
      return;
    }
    setState(() {
      if (resend) {
        _resending = true;
      } else {
        _submitting = true;
      }
      _error = null;
      _status = null;
    });
    try {
      await widget.apiClient.requestPasswordReset(_emailController.text);
      if (!mounted) return;
      setState(() {
        _codeRequested = true;
        _status = context.tr(
          resend
              ? 'A new reset code has been sent if this email exists.'
              : 'If this email exists, a reset code has been sent.',
        );
      });
    } catch (error) {
      if (mounted) setState(() => _error = context.localizedError(error));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _resending = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.apiClient.resetPassword(
        email: _emailController.text,
        otp: _otpController.text,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, _emailController.text.trim());
    } catch (error) {
      if (mounted) setState(() => _error = context.localizedError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Reset password'))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  minHeight: constraints.maxHeight - 56,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: ComiVerseLogo(height: 38),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      context.tr(
                        _codeRequested
                            ? 'Create a new password'
                            : 'Reset password',
                      ),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr(
                        _codeRequested
                            ? 'Enter the 6-digit code from your email and choose a new password.'
                            : 'Enter your account email to receive a recovery code.',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Form(
                      key: _emailFormKey,
                      child: TextFormField(
                        controller: _emailController,
                        enabled: !_codeRequested && !_submitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: (_) => _requestCode(),
                        decoration: InputDecoration(
                          labelText: context.tr('Email address'),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty ||
                              !RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email)) {
                            return context.tr('Enter a valid email address');
                          }
                          return null;
                        },
                      ),
                    ),
                    if (_codeRequested) ...[
                      const SizedBox(height: 18),
                      Form(
                        key: _resetFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              maxLength: 6,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              decoration: InputDecoration(
                                labelText: context.tr('Recovery code'),
                                prefixIcon: const Icon(Icons.password_rounded),
                              ),
                              validator: (value) =>
                                  RegExp(
                                    r'^\d{6}$',
                                  ).hasMatch(value?.trim() ?? '')
                                  ? null
                                  : context.tr(
                                      'Enter the 6-digit recovery code',
                                    ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: context.tr('New password'),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: context.tr('Show or hide password'),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) => (value?.length ?? 0) < 6
                                  ? context.tr(
                                      'New password must have at least 6 characters.',
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmation,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _resetPassword(),
                              decoration: InputDecoration(
                                labelText: context.tr('Confirm new password'),
                                prefixIcon: const Icon(
                                  Icons.lock_reset_rounded,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: context.tr('Show or hide password'),
                                  onPressed: () => setState(
                                    () => _obscureConfirmation =
                                        !_obscureConfirmation,
                                  ),
                                  icon: Icon(
                                    _obscureConfirmation
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value != _passwordController.text
                                  ? context.tr('Passwords do not match')
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_status != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _status!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: PrimaryGradientButton(
                        label: context.tr(
                          _codeRequested
                              ? 'Reset password'
                              : 'Send recovery code',
                        ),
                        onPressed: _codeRequested
                            ? _resetPassword
                            : _requestCode,
                        loading: _submitting,
                      ),
                    ),
                    if (_codeRequested) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _resending
                            ? null
                            : () => _requestCode(resend: true),
                        icon: _resending
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(context.tr('Resend recovery code')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
