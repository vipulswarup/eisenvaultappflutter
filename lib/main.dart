import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:eisenvaultappflutter/widgets/offline_mode_indicator.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
// Add imports for web database support
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfi;
  }

  await OfflineDatabaseService.instance.database;

  final syncService = SyncService();

  try {
    final offlineManager = await OfflineManager.createDefault();
    final credentials = await offlineManager.getSavedCredentials();
    if (credentials != null) {
      syncService.initialize(
        instanceType: credentials['instanceType']!,
        baseUrl: credentials['baseUrl']!,
        authToken: credentials['authToken']!,
      );
      syncService.startPeriodicSync();
    }
  } catch (e) {
    EVLogger.error('No saved credentials for offline support: $e');
  }

  runApp(MyApp(syncService: syncService));
}

class MyApp extends StatelessWidget {
  final SyncService syncService;

  const MyApp({
    super.key,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EisenVault DMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: EVColors.screenBackground,
        fontFamily: 'SF Pro Display',
        primaryColor: EVColors.buttonBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: EVColors.appBarBackground,
          foregroundColor: EVColors.appBarForeground,
        ),
      ),
      home: OfflineModeIndicator(
        syncService: syncService,
        child: const LoginScreen(),
      ),
    );
  }
}