import '../utils/local_storage_util.dart';
import '../main.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogoutSuccess;
  const SettingsScreen({super.key, required this.onLogoutSuccess});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _selectedThemeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    checkTokenExp();
    _loadThemePreference();
  }

  void checkTokenExp() async {
    // Check if the token is still valid, if not, redirect to login page;
    final authData = await LocalStorageUtil.getAuthData();
    final tokenExp = authData['tokenExp'];
    if (tokenExp == null) {
      // No expiration info, redirect to login
      Navigator.pushReplacementNamed(context, '/');
      return;
    }
    final expiration = int.tryParse(tokenExp);
    if (expiration == null) {
      Navigator.pushReplacementNamed(context, '/');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now >= expiration) widget.onLogoutSuccess();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    setState(() {
      _selectedThemeMode = ThemeMode.values[themeIndex];
    });
  }

  void _onThemeChanged(ThemeMode? mode) {
    if (mode != null) {
      setState(() {
        _selectedThemeMode = mode;
      });
      MyApp.of(context).setThemeMode(mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Handler',
                fontSize: 45.0,
              ),
            ),
            Icon(
              Icons.settings,
              size: 45.0,
            ),
          ]
      )),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Theme",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          RadioListTile<ThemeMode>(
            title: const Text("System Default"),
            value: ThemeMode.system,
            groupValue: _selectedThemeMode,
            onChanged: _onThemeChanged,
            secondary: const Icon(Icons.phone_android),
          ),
          RadioListTile<ThemeMode>(
            title: const Text("Light Mode"),
            value: ThemeMode.light,
            groupValue: _selectedThemeMode,
            onChanged: _onThemeChanged,
            secondary: const Icon(Icons.light_mode),
          ),
          RadioListTile<ThemeMode>(
            title: const Text("Dark Mode"),
            value: ThemeMode.dark,
            groupValue: _selectedThemeMode,
            onChanged: _onThemeChanged,
            secondary: const Icon(Icons.dark_mode),
          ),
        ],
      ),
    );
  }
}