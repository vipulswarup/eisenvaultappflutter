import 'dart:async';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/screens/login/login_form.dart';
import 'package:eisenvaultappflutter/screens/login/offline_login_ui.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isOfflineMode = false;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  late OfflineManager _offlineManager;
  bool _isCheckingConnectivity = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initOfflineManager();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  Future<void> _initOfflineManager() async {
    _offlineManager = await OfflineManager.createDefault();
  }

  Future<void> _checkConnectivity() async {
    if (_isCheckingConnectivity) return;
    
    try {
      _isCheckingConnectivity = true;
      EVLogger.debug('Starting connectivity check');
      final result = await _connectivity.checkConnectivity();
      EVLogger.debug('Connectivity check result', {'result': result.toString()});
      _updateConnectionStatus(result);
    } catch (e) {
      EVLogger.error('Error checking connectivity', e);
    } finally {
      _isCheckingConnectivity = false;
    }
  }

  Future<void> _setupConnectivityListener() async {
    // Cancel any existing subscription
    _connectivitySubscription?.cancel();
    
    EVLogger.debug('Setting up connectivity listener');
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      EVLogger.debug('Connectivity changed', {'result': result.toString()});
      
      // Debounce connectivity changes to prevent rapid state updates
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 1), () {
        _updateConnectionStatus(result);
      });
    });
    EVLogger.debug('Connectivity listener setup complete');
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    if (!mounted) return;
    
    EVLogger.debug('Updating connection status', {'result': result.toString()});
    
    // Consider both ConnectivityResult.none and ConnectivityResult.other as offline states
    final isNowOffline = result == ConnectivityResult.none || result == ConnectivityResult.other;
    
    if (isNowOffline) {
      EVLogger.debug('Device is offline - switching to offline mode');
      if (mounted) {
        setState(() {
          _isOfflineMode = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are offline. Switching to offline mode.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      EVLogger.debug('Device is online - switching to online mode');
      if (mounted) {
        setState(() {
          _isOfflineMode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EVColors.screenBackground,
      appBar: AppBar(
        backgroundColor: EVColors.appBarBackground,
        foregroundColor: EVColors.appBarForeground,
        title: const Text('EisenVault Login'),
      ),
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
                await _checkConnectivity();
              },
            ),
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}