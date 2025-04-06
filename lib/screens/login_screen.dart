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

  @override
  void initState() {
    super.initState();
    _checkOfflineMode();
  }
  
  Future<void> _checkOfflineMode() async {
    final offlineManager = OfflineManager();
    final isOffline = await offlineManager.isOffline();
    if (mounted) {
      setState(() {
        _isOfflineMode = isOffline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      body: SafeArea(
        child: _isOfflineMode 
          ? OfflineLoginUI(
              onTryOnlineLogin: () {
                setState(() {
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
