import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../l10n/app_localizations.dart";
import "../services/api_client.dart";
import "../widgets/common_widgets.dart";
import "../widgets/comiverse_logo.dart";

/// Two-step registration: form → OTP email verification.
class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.apiClient,
    required this.onSignedUp,
  });

  final ApiClient apiClient;

  /// Called after email is verified. Receives the verified email so the login
  /// screen can pre-fill it.
  final ValueChanged<String> onSignedUp;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ── step ────────────────────────────────────────────────────────────────────
  _Step _step = _Step.form;

  // ── form controllers ────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;

  // ── otp ─────────────────────────────────────────────────────────────────────
  final _otpCtrl = TextEditingController();
  bool _otpLoading = false;
  String? _otpError;
  bool _resendLoading = false;
  String? _resendSuccess;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── register ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.apiClient.register(
        username: _usernameCtrl.text.trim(),
        fullName: _fullNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _step = _Step.otp);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = context.localizedError(err));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── verify OTP ───────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty || _otpLoading) return;
    setState(() {
      _otpLoading = true;
      _otpError = null;
    });
    try {
      await widget.apiClient.verifyEmail(
        email: _emailCtrl.text.trim(),
        otp: otp,
      );
      if (!mounted) return;
      widget.onSignedUp(_emailCtrl.text.trim());
    } catch (err) {
      if (!mounted) return;
      setState(() => _otpError = context.localizedError(err));
    } finally {
      if (mounted) setState(() => _otpLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendLoading) return;
    setState(() {
      _resendLoading = true;
      _resendSuccess = null;
      _otpError = null;
    });
    try {
      await widget.apiClient.resendVerificationOtp(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() => _resendSuccess = context.tr("A new OTP has been sent to your email."));
    } catch (err) {
      if (!mounted) return;
      setState(() => _otpError = context.localizedError(err));
    } finally {
      if (mounted) setState(() => _resendLoading = false);
    }
  }

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step == _Step.otp) {
              setState(() => _step = _Step.form);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 38, 24, 32),
                  child: _step == _Step.form
                      ? _buildForm(context)
                      : _buildOtp(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── registration form ───────────────────────────────────────────────────────
  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: ComiVerseLogo(height: 38),
        ),
        const SizedBox(height: 28),
        Text(
          context.tr("Create account"),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr("Join ComiVerse and start reading."),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        Form(
          key: _formKey,
          child: Column(
            children: [
              // Username
              TextFormField(
                controller: _usernameCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr("Username"),
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return context.tr("Enter a username");
                  }
                  if (v.trim().length < 3 || v.trim().length > 20) {
                    return context.tr("Username must be 3–20 characters");
                  }
                  if (!RegExp(r"^[a-zA-Z0-9._]+$").hasMatch(v.trim())) {
                    return context.tr("Only letters, numbers, dots and underscores");
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Full name
              TextFormField(
                controller: _fullNameCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr("Full name"),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return context.tr("Enter your full name (at least 2 characters)");
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr("Email"),
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return context.tr("Enter your email");
                  }
                  if (!v.contains("@") || !v.contains(".")) {
                    return context.tr("Enter a valid email address");
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Password
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr("Password"),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return context.tr("Enter a password");
                  }
                  if (v.length < 6) {
                    return context.tr("Password must be at least 6 characters");
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Confirm password
              TextFormField(
                controller: _confirmPasswordCtrl,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr("Confirm password"),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v != _passwordCtrl.text) {
                    return context.tr("Passwords do not match");
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Phone (optional)
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText:
                      "${context.tr("Phone number")} (${context.tr("optional")})",
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!RegExp(r"^(0|\+84)[3|5|7|8|9][0-9]{8}$")
                      .hasMatch(v.trim())) {
                    return context.tr("Invalid phone number format");
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: PrimaryGradientButton(
            label: context.tr("Create account"),
            onPressed: _submit,
            loading: _isLoading,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.tr("Already have an account?"),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr("Sign In")),
            ),
          ],
        ),
      ],
    );
  }

  // ─── OTP verification ────────────────────────────────────────────────────────
  Widget _buildOtp(BuildContext context) {
    final email = _emailCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: ComiVerseLogo(height: 38),
        ),
        const SizedBox(height: 28),
        Text(
          context.tr("Verify your email"),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          "${context.tr("We sent a 6-digit code to")} $email. "
          "${context.tr("Enter it below to activate your account.")}",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 8),
          decoration: InputDecoration(
            hintText: "——————",
            hintStyle: const TextStyle(letterSpacing: 12),
            counterText: "",
            prefixIcon: const Icon(Icons.verified_outlined),
          ),
          onFieldSubmitted: (_) => _verifyOtp(),
        ),
        if (_otpError != null) ...[
          const SizedBox(height: 12),
          Text(
            _otpError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_resendSuccess != null) ...[
          const SizedBox(height: 12),
          Text(
            _resendSuccess!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: PrimaryGradientButton(
            label: context.tr("Verify"),
            onPressed: _verifyOtp,
            loading: _otpLoading,
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _resendLoading ? null : _resendOtp,
          child: _resendLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr("Resend code")),
        ),
      ],
    );
  }
}

enum _Step { form, otp }
