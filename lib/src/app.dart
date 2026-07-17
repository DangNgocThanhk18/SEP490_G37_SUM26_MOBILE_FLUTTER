import 'package:flutter/material.dart';

import 'models/user_profile.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';

class ComiVerseApp extends StatefulWidget {
  const ComiVerseApp({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<ComiVerseApp> createState() => _ComiVerseAppState();
}

class _ComiVerseAppState extends State<ComiVerseApp> {
  late final ApiClient _apiClient;
  UserProfile? _user;
  bool _isGuest = false;
  bool _isRestoringSession = true;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await _apiClient.restoreSession();
    if (!mounted) return;
    setState(() {
      _user = user;
      _isRestoringSession = false;
    });
  }

  void _toggleTheme() {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isCurrentlyDark =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);
    setState(() {
      _themeMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void _handleSignedIn(UserProfile user) {
    setState(() {
      _user = user;
      _isGuest = false;
    });
  }

  void _handleGuestMode() {
    setState(() {
      _user = null;
      _isGuest = true;
    });
  }

  Future<void> _handleSignOut() async {
    await _apiClient.clearSession();
    if (!mounted) return;
    setState(() {
      _user = null;
      _isGuest = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDarkMode =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);
    return MaterialApp(
      title: 'ComiVerse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: _isRestoringSession
          ? const _SessionSplashScreen()
          : _apiClient.hasToken || _user != null || _isGuest
          ? MainShell(
              apiClient: _apiClient,
              user: _user,
              onSignOut: _handleSignOut,
              onToggleTheme: _toggleTheme,
              isDarkMode: isDarkMode,
            )
          : LoginScreen(
              apiClient: _apiClient,
              onSignedIn: _handleSignedIn,
              onContinueAsGuest: _handleGuestMode,
              onToggleTheme: _toggleTheme,
              isDarkMode: isDarkMode,
            ),
    );
  }
}

class _SessionSplashScreen extends StatelessWidget {
  const _SessionSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_rounded, size: 52),
            SizedBox(height: 18),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
