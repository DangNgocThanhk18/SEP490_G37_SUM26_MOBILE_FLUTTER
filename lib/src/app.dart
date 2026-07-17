import 'package:flutter/material.dart';

import 'models/user_profile.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';

class ComiVerseApp extends StatefulWidget {
  const ComiVerseApp({super.key});

  @override
  State<ComiVerseApp> createState() => _ComiVerseAppState();
}

class _ComiVerseAppState extends State<ComiVerseApp> {
  final ApiClient _apiClient = ApiClient();
  UserProfile? _user;
  bool _isGuest = false;
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isCurrentlyDark = _themeMode == ThemeMode.dark ||
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

  void _handleSignOut() {
    _apiClient.clearSession();
    setState(() {
      _user = null;
      _isGuest = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDarkMode = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);
    return MaterialApp(
      title: 'ComiVerse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: _apiClient.hasToken || _user != null || _isGuest
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
