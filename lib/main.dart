import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/browse/browse_screen.dart';
// Add imports for web database support
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:eisenvaultappflutter/services/offline/download_manager.dart';
import 'dart:io'; // Required for Platform.isWindows check
import 'package:permission_handler/permission_handler.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for desktop (Windows/Linux)
  if (!kIsWeb) {
    sqfliteFfiInit();

    // Import dart:io to use Platform
    if (Platform.isWindows || Platform.isLinux) {
      databaseFactory = databaseFactoryFfi;
    }
  }

  await OfflineDatabaseService.instance.database;

  final syncService = SyncService();
  final authStateManager = AuthStateManager();

  try {
    // Initialize auth state
    await authStateManager.initialize();

    // If authenticated, initialize sync service
    if (authStateManager.isAuthenticated) {
      syncService.initialize(
        instanceType: authStateManager.instanceType!,
        baseUrl: authStateManager.baseUrl!,
        authToken: authStateManager.currentToken!,
      );
      syncService.startPeriodicSync();
    }
  } catch (e) {
    EVLogger.error('Failed to initialize auth state: $e');
  }

  // Request permissions when app starts
  await Permission.photos.request();
  await Permission.videos.request();
  await Permission.audio.request();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DownloadManager>(
          create: (_) => DownloadManager(),
        ),
        ChangeNotifierProvider<AuthStateManager>(
          create: (_) => authStateManager,
        ),
      ],
      child: MyApp(syncService: syncService),
    ),
  );
}


class MyApp extends StatelessWidget {
  final SyncService syncService;

  const MyApp({super.key, required this.syncService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EisenVault',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: EVColors.screenBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: EVColors.appBarBackground,
          foregroundColor: EVColors.appBarForeground,
          iconTheme: IconThemeData(color: EVColors.appBarForeground),
          titleTextStyle: TextStyle(
            color: EVColors.appBarForeground,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          actionsIconTheme: IconThemeData(color: EVColors.appBarForeground),
        ),
      ),
      home: Consumer<AuthStateManager>(
        builder: (context, authState, _) {
          if (authState.isAuthenticated) {
            return BrowseScreen(
              baseUrl: authState.baseUrl!,
              authToken: authState.currentToken!,
              firstName: authState.firstName ?? 'User',
              instanceType: authState.instanceType!,
              customerHostname: authState.customerHostname ?? '',
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}