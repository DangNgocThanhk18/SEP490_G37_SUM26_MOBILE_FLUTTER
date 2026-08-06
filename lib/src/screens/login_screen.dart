import "package:flutter/material.dart";
import "package:google_sign_in/google_sign_in.dart";

import "../l10n/app_localizations.dart";
import "../models/user_profile.dart";
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

  /// Lazily-created GoogleSignIn instance. We only sign in, not silently
  /// restore, so no serverClientId is required for this flow.
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
          _error = context.tr("Could not obtain Google token. Please try again.");
          _isGoogleLoading = false;
        });
        return;
      }

      final result = await widget.apiClient.loginWithGoogle(idToken);
      if (!mounted) return;
      widget.onSignedIn(result.user);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = context.localizedError(err);
      });
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
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
                  context.tr(
                    "Email verified! You can now sign in.",
                  ),
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
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // ── Google button ───────────────────────────────────────
                      _GoogleSignInButton(
                        onPressed: _signInWithGoogle,
                        loading: _isGoogleLoading,
                      ),
                      const SizedBox(height: 16),
                      // ── divider ─────────────────────────────────────────────
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 12),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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

/// Renders the colourful Google "G" logo using a CustomPainter.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw arcs for each color segment
    final segments = [
      // blue
      (_deg(330), _deg(90), const Color(0xFF4285F4)),
      // red
      (_deg(210), _deg(120), const Color(0xFFEA4335)),
      // yellow
      (_deg(150), _deg(60), const Color(0xFFFBBC05)),
      // green
      (_deg(90), _deg(60), const Color(0xFF34A853)),
    ];

    for (final (start, sweep, color) in segments) {
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        paint,
      );
    }

    // White cutout in the center
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.6, paint);

    // Blue right bar of the "G"
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - radius * 0.18,
          radius + 2, radius * 0.36),
      paint,
    );

    // Re-draw white inner circle to clean up
    canvas.drawCircle(center, radius * 0.58, paint..color = Colors.white);

    // "G" body
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.58),
      _deg(-15),
      _deg(205),
      false,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.3,
    );

    // Right part of "G"
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - radius * 0.05,
        center.dy - radius * 0.15,
        radius * 0.6,
        radius * 0.3,
      ),
      paint,
    );
  }

  double _deg(double deg) => deg * 3.14159265358979 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
