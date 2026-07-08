import 'package:flutter/material.dart';

import 'models/user_profile.dart';
import 'screens/comics_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';

class ComiVerseApp extends StatefulWidget {
  const ComiVerseApp({super.key});

  @override
  State<ComiVerseApp> createState() => _ComiVerseAppState();
}

class _ComiVerseAppState extends State<ComiVerseApp> {
  final ApiClient _apiClient = ApiClient();
  UserProfile? _user;
  bool _isGuest = false;

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
    return MaterialApp(
      title: 'ComiVerse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFA855F7),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF080511),
        fontFamily: 'Roboto',
      ),
      home: _apiClient.hasToken || _user != null || _isGuest
          ? ComicsScreen(
              apiClient: _apiClient,
              user: _user,
              onSignOut: _handleSignOut,
            )
          : LoginScreen(
              apiClient: _apiClient,
              onSignedIn: _handleSignedIn,
              onContinueAsGuest: _handleGuestMode,
            ),
    );
  }
}
