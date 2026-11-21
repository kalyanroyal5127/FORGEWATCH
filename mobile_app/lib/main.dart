import 'package:flutter/material.dart';
import 'screens/dashboard_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'theme.dart';

void main() => runApp(const ForgeWatchApp());

class ForgeWatchApp extends StatefulWidget {
  const ForgeWatchApp({super.key});
  @override
  State<ForgeWatchApp> createState() => _ForgeWatchAppState();
}

class _ForgeWatchAppState extends State<ForgeWatchApp> {
  ApiClient? _api;
  AuthUser? _user;

  void _authenticated(ApiClient api, AuthUser user) => setState(() {
        _api = api;
        _user = user;
      });
  void _signedOut() => setState(() {
        _api = null;
        _user = null;
      });

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Machine Learning-Based Fault Detection and Prediction System',
        debugShowCheckedModeBanner: false,
        theme: ForgeTheme.dark,
        home: _api == null || _user == null
            ? LoginScreen(onAuthenticated: _authenticated)
            : DashboardShell(api: _api!, user: _user!, onSignedOut: _signedOut),
      );
}
