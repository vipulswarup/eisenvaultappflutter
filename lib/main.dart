import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';
import 'package:eisenvaultappflutter/widgets/offline_mode_indicator.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() async {
  // Ensure Flutter is initialized before using platform channels
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize offline database by simply accessing it
  await OfflineDatabaseService.instance.database;
  
  // Create a singleton SyncService that can be accessed throughout the app
  final syncService = SyncService();
  
  // Try to initialize with saved credentials
  final offlineManager = OfflineManager();
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