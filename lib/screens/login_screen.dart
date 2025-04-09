import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/login/login_form.dart';
import 'package:eisenvaultappflutter/screens/login/offline_login_ui.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isOfflineMode = false;
  bool _forceOfflineMode = false; // New flag for forced offline mode

  @override
  void initState() {
    super.initState();
    _checkOfflineMode();
  }
  
  Future<void> _checkOfflineMode() async {
    final offlineManager = OfflineManager.createDefault();
    final isOffline = await offlineManager.isOffline();
    if (mounted) {
      setState(() {
        // Only set to offline if not already forced
        if (!_forceOfflineMode) {
          _isOfflineMode = isOffline;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      // Add AppBar with offline toggle
      appBar: AppBar(
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        title: const Text('EisenVault Login'),
        actions: [
          // Add offline mode toggle
          Row(
            children: [
              const Text('Test Offline Mode', 
                style: TextStyle(fontSize: 14),
              ),
              Switch(
                value: _forceOfflineMode,
                activeColor: Colors.orange,
                onChanged: (value) {
                  setState(() {
                    _forceOfflineMode = value;
                    _isOfflineMode = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _isOfflineMode 
          ? OfflineLoginUI(
              onTryOnlineLogin: () {
                setState(() {
                  _forceOfflineMode = false;
                  _isOfflineMode = false;
                });
              },
            )
          : LoginForm(
              onLoginFailed: (e) async {
                // Check if failure might be due to connectivity
                await _checkOfflineMode();
                if (_isOfflineMode && mounted) {
                  setState(() {});
                }
              },
            ),
      ),
    );
  }
}