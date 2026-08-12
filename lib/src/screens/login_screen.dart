import "dart:convert";
import "package:flutter/material.dart";
import "package:google_sign_in/google_sign_in.dart";

import "../l10n/app_localizations.dart";
import "../models/user_profile.dart";
import "../models/login_device.dart";
import "../services/api_client.dart";
import "../widgets/common_widgets.dart";
import "../widgets/comiverse_logo.dart";
import "signup_screen.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.apiClient,
    required this.onSignedIn,
    required this.onContinueAsGuest,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  final ApiClient apiClient;
  final ValueChanged<UserProfile> onSignedIn;
  final VoidCallback onContinueAsGuest;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _error;

  /// iOS reads GIDClientID/GIDServerClientID from Runner/Info.plist. Android
  /// reads the equivalent OAuth clients from google-services.json.
  static final _googleSignIn = GoogleSignIn(scopes: ["email", "profile"]);

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── password login ─────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.apiClient.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      widget.onSignedIn(result.user);
    } on LoginDeviceVerificationRequired catch (challenge) {
      final result = await _showDeviceReplacement(challenge);
      if (result != null && mounted) widget.onSignedIn(result.user);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = context.localizedError(err);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ── google login ────────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    if (_isGoogleLoading) return;
    setState(() {
      _isGoogleLoading = true;
      _error = null;
    });
    try {
      // Force the account picker to show by signing out any cached session first
      await _googleSignIn.signOut();
      // Trigger the Google authentication flow
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null || !mounted) {
        // User cancelled
        setState(() => _isGoogleLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        if (!mounted) return;
        setState(() {
          _error = context.tr(
            "Could not obtain Google token. Please try again.",
          );
          _isGoogleLoading = false;
        });
        return;
      }

      final result = await widget.apiClient.loginWithGoogle(idToken);
      if (!mounted) return;
      widget.onSignedIn(result.user);
    } on LoginDeviceVerificationRequired catch (challenge) {
      final result = await _showDeviceReplacement(challenge);
      if (result != null && mounted) widget.onSignedIn(result.user);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = context.localizedError(err);
      });
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<LoginResult?> _showDeviceReplacement(
    LoginDeviceVerificationRequired challenge,
  ) async {
    final otpController = TextEditingController();
    var selectedDeviceId = challenge.devices.firstOrNull?.id;
    var submitting = false;
    String? error;
    final result = await showModalBottomSheet<LoginResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phonelink_lock_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sheetContext.tr("Device limit reached"),
                          style: Theme.of(sheetContext).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sheetContext.tr(
                      "ComiVerse allows up to 3 mobile devices. Select one device to remove, then enter the OTP sent to your email.",
                    ),
                  ),
                  const SizedBox(height: 14),
                  RadioGroup<String>(
                    groupValue: selectedDeviceId,
                    onChanged: submitting
                        ? (_) {}
                        : (value) =>
                              setSheetState(() => selectedDeviceId = value),
                    child: Column(
                      children: [
                        for (final device in challenge.devices)
                          Card(
                            child: RadioListTile<String>(
                              value: device.id,
                              enabled: !submitting,
                              secondary: Icon(
                                device.platform == "ios"
                                    ? Icons.phone_iphone_rounded
                                    : Icons.android_rounded,
                              ),
                              title: Text(device.deviceName),
                              subtitle: Text(
                                device.lastSeenAt == null
                                    ? sheetContext.tr("Previously verified")
                                    : sheetContext.tr(
                                        "Last active {date}",
                                        values: {
                                          "date": _compactDeviceDate(
                                            device.lastSeenAt!,
                                          ),
                                        },
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpController,
                    enabled: !submitting,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: sheetContext.tr("Email OTP"),
                      prefixIcon: const Icon(Icons.password_rounded),
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: submitting
                              ? null
                              : () => Navigator.pop(sheetContext),
                          child: Text(sheetContext.tr("Cancel")),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (selectedDeviceId == null ||
                                      otpController.text.trim().length != 6) {
                                    setSheetState(
                                      () => error = sheetContext.tr(
                                        "Select a device and enter the 6-digit OTP.",
                                      ),
                                    );
                                    return;
                                  }
                                  setSheetState(() {
                                    submitting = true;
                                    error = null;
                                  });
                                  try {
                                    final login = await widget.apiClient
                                        .replaceLoginDevice(
                                          challengeId: challenge.challengeId,
                                          deviceToRemoveId: selectedDeviceId!,
                                          otp: otpController.text.trim(),
                                        );
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext, login);
                                    }
                                  } catch (exception) {
                                    if (!sheetContext.mounted) return;
                                    setSheetState(() {
                                      submitting = false;
                                      error = sheetContext.localizedError(
                                        exception,
                                      );
                                    });
                                  }
                                },
                          child: submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(sheetContext.tr("Verify & Replace")),
                        ),
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
    otpController.dispose();
    return result;
  }

  String _compactDeviceDate(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, "0");
    return "${two(local.day)}/${two(local.month)}/${local.year} "
        "${two(local.hour)}:${two(local.minute)}";
  }

  // ── sign up ─────────────────────────────────────────────────────────────────
  void _goToSignUp() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => SignupScreen(
          apiClient: widget.apiClient,
          onSignedUp: (email) {
            Navigator.of(ctx).pop();
            // Pre-fill the email field with the newly registered email
            setState(() {
              _usernameController.text = email;
              _error = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr("Email verified! You can now sign in."),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: context.tr(
              widget.isDarkMode ? "Use light mode" : "Use dark mode",
            ),
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
        ],
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
                  padding: const EdgeInsets.fromLTRB(24, 38, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: ComiVerseLogo(height: 40),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        context.tr("Welcome back"),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr(
                          "Sign in to sync your ComiVerse account, or continue as guest to read public comics.",
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // ── credentials form ────────────────────────────────────
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: context.tr("Email or username"),
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return context.tr(
                                    "Enter your email or username",
                                  );
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: context.tr("Password"),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return context.tr("Enter your password");
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 52,
                        child: PrimaryGradientButton(
                          label: context.tr("Sign In"),
                          onPressed: _submit,
                          loading: _isLoading,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ── divider ─────────────────────────────────────────────
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              context.tr("or"),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // ── Google button ───────────────────────────────────────
                      _GoogleSignInButton(
                        onPressed: _signInWithGoogle,
                        loading: _isGoogleLoading,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _isLoading ? null : widget.onContinueAsGuest,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(context.tr("Continue as Guest")),
                      ),
                      const SizedBox(height: 20),
                      // ── sign-up link ────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.tr("Don't have an account?"),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: _goToSignUp,
                            child: Text(context.tr("Sign Up")),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A styled Google Sign-In button following Google branding guidelines.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed, this.loading = false});

  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          side: BorderSide(
            color: isDark
                ? Colors.white24
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" logo painted with Canvas
                  const _GoogleLogo(size: 22),
                  const SizedBox(width: 12),
                  Text(
                    context.tr("Continue with Google"),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF3C4043),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 24});
  final double size;

  static const _base64 =
      "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAAEkUlEQVR4nO2Zb0wbZRzHn3taesUtRpOJYbo/DoQM5c/GMgryzxkYxbGBiQsbNBCEFGaIY8zCCuaUMSiQAQMGQWAgcSY2GeuNuzpc8NqNvRoCItE3841Dthj3ToNzbX+mVRBI197Zo2VJv8n3XZ+nn89dn6dPrwj5448/HgcoJIWqgGIoxywU4HuQTfwJSsIKBxBAKgJIQzbIJhZBhX+BE/g6VAUU2ccgXwc0UgWU4tvwNmGBJASCqiQsoMa3QRsQ433wOlk4qPEsvCkQ2llTEUAxnoEaFOIdeA3RCumEzWPwtT2IrHCK0K0f+HkUCMX4B9HBk9b0PTwNFJKJC9+NngcVfrDu8En/toJoFw9+EMnhOPGr1+DLCE40eIeAGn/vPXgsMvyHRIfgrbEMT0IlroUmaQpQaAtQKAjOSN6C05hy7Db21zgbW4pN4sI3kyGQQVh5g5+W9PJZfEChZ+ADydAqkVKR4R1vVIHv8IIvwPNwDr0oeP4aFAJ5+P76wJvl22CcfAQaCUCyC/gSPAV6JEEbLWAmdWAmwdHeAIB0wvmV35DweiQBs2x+WcDeURmACv8Hn0lYoAK9hDZiwCSPXwW/VI4E0En/ObuclPSjjRowybROBZY6FPAAyhGJNmrATF5xKWCSdQiZL1gzC2I0XDthO9rUd9e9gImccynAkRm+EAjWzMIbddcW+Qg8dCMQ6iuB3TW3rHwEHrkWQJt9JbCjehKeaoHtVd+C5x+hm7IwXwns1t60Pd2L+JNRHovYTI642UY7fSVwRDc8z0NAduZJ8A+5Z6Geif/jvF4RiEROy3D+puiPvrG4Eii/0DjqXoALVDiDnx0PBhWthENXs6HDGHtJbIGTnfX97u6Arq/iuHsBQBjMsntL4DYzCfRYOGQbDjvg7c2jlZaL11/bJhZ8W496Z2SNyeoK/vVas4XiKH5P88BENtrhfzdthrNMwjL4ylaPJi9wXIrHjwcpjpIeafxswd3VL2lrm+A9KXCBL98df+GvEjrdKfxSP2YTZjyRoDhKmt/SM+d2/6+egsbuylhBkzcwihlX8CvvRP/X4VuFwvfeiNhe1lX3E5/d51hz75zQ+RE9FvZKPq208pHIp5WWzq/2DlCDKXJ38w6PRW1qZ/b15RmU1pyRHDja2uH2FEp9ekrQl+dyutmY1iweAitFGljFdJdxL6VnIw5cGdsVdJkL2zJgjEq8aNxTV8ckTNpfs3JM1kgOFPZQsLXqO6cC77c3dSNPomPjpvkKeNKiwXLYWX1nFfy7TQM/Ik+j10fINHTqfW9IFH5RCJG1Jgd8ev2Xv53o6hJ0cHxiOG7HczVM4oI3JI7pc0HVemGeGq4MEgV+hYT8LBM/K2RN/J+eYxXTRmPo+v3m7jNGNecaMq2iX3lDprWXjWlG3sgwvSe0gY2beseQ5TF4ztXDjqt++caru5C3MzQWGdvM7L9VZDj4WCh4AZ3xuJGJm/icifb+n3xrowck6WeiC1uN+0a1TOLPajptUWVQWu13yH4IzDVk2tSGtMWqa8nzLex+ts8YU2Afg/zxxx/kaf4GzSVnCicBYF0AAAAASUVORK5CYII=";

  @override
  Widget build(BuildContext context) {
    return Image.memory(base64Decode(_base64), width: size, height: size);
  }
}
