import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';
import 'package:eisenvaultappflutter/widgets/offline_mode_indicator.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
// Add imports for web database support
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  // Ensure Flutter is initialized before using platform channels
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database factory for web
  if (kIsWeb) {
    // Initialize for web
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize offline database by simply accessing it
  await OfflineDatabaseService.instance.database;
  
  // Create a singleton SyncService that can be accessed throughout the app
  final syncService = SyncService();
  
  // Try to initialize with saved credentials
  try {
    final offlineManager = await OfflineManager.createDefault();
    final credentials = await offlineManager.getSavedCredentials();
    if (credentials != null) {
      syncService.initialize(
        instanceType: credentials['instanceType']!,
        baseUrl: credentials['baseUrl']!,
        authToken: credentials['authToken']!,
      );
      
      // Start periodic sync
      syncService.startPeriodicSync();
    }
  } catch (e) {
    // If there are no saved credentials, just continue without offline support
    print('No saved credentials for offline support: $e');
  }
  
  runApp(MyApp(syncService: syncService));
}
class MyApp extends StatelessWidget {
  final SyncService syncService;
  
  const MyApp({
    super.key, 
    required this.syncService
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EisenVault DMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: EVColors.screenBackground,
        fontFamily: 'SF Pro Display',
        primaryColor: EVColors.primaryBlue,
      ),
      // Wrap home screen with offline mode indicator
      home: OfflineModeIndicator(
        syncService: syncService,  // Pass to indicator if needed
        child: const LoginScreen(),
      ),
    );
  }
}