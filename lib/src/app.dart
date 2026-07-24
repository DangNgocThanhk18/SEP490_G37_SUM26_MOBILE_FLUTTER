import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'models/user_profile.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_client.dart';
import 'services/app_preferences.dart';
import 'theme/app_theme.dart';

class ComiVerseApp extends StatefulWidget {
  const ComiVerseApp({super.key, this.apiClient, this.preferences});

  final ApiClient? apiClient;
  final AppPreferences? preferences;

  @override
  State<ComiVerseApp> createState() => _ComiVerseAppState();
}

class _ComiVerseAppState extends State<ComiVerseApp> {
  late final ApiClient _apiClient;
  late final AppPreferences _preferences;
  UserProfile? _user;
  bool _isGuest = false;
  bool _isRestoringSession = true;
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _preferences = widget.preferences ?? const SecureAppPreferences();
    _restoreAppState();
  }

  Future<void> _restoreAppState() async {
    final userFuture = _apiClient.restoreSession();
    final languageFuture = _readLanguageCode();
    final user = await userFuture;
    final languageCode = await languageFuture;
    if (!mounted) return;
    setState(() {
      _user = user;
      if (languageCode == 'vi' || languageCode == 'en') {
        _locale = Locale(languageCode!);
        _apiClient.setLanguage(languageCode);
      }
      _isRestoringSession = false;
    });
  }

  Future<String?> _readLanguageCode() async {
    try {
      return await _preferences.readLanguageCode();
    } catch (_) {
      return null;
    }
  }

  void _changeLocale(Locale locale) {
    if (_locale.languageCode == locale.languageCode) return;
    _apiClient.setLanguage(locale.languageCode);
    setState(() => _locale = Locale(locale.languageCode));
    unawaited(_writeLanguageCode(locale.languageCode));
  }

  Future<void> _writeLanguageCode(String languageCode) async {
    try {
      await _preferences.writeLanguageCode(languageCode);
    } catch (_) {
      // A storage failure must not prevent an immediate language change.
    }
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
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _isRestoringSession
          ? const _SessionSplashScreen()
          : _apiClient.hasToken || _user != null || _isGuest
          ? MainShell(
              apiClient: _apiClient,
              user: _user,
              onSignOut: _handleSignOut,
              onToggleTheme: _toggleTheme,
              isDarkMode: isDarkMode,
              locale: _locale,
              onLocaleChanged: _changeLocale,
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
