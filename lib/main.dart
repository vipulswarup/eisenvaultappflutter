import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/offline/offline_database_service.dart';
import 'package:eisenvaultappflutter/services/offline/sync_service.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:eisenvaultappflutter/services/sharing/upload_service.dart';
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

Future<bool> _checkWindowsElevation() async {
  if (!Platform.isWindows) return true;
  
  try {
    // Try to create a file in Program Files to check elevation
    final testFile = File('C:\\Program Files\\eisenvault_test.txt');
    await testFile.writeAsString('test');
    await testFile.delete();
    return true;
  } catch (e) {
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check for elevated permissions on Windows
  if (Platform.isWindows) {
    final hasElevation = await _checkWindowsElevation();
    if (!hasElevation) {
      // Show error dialog and exit
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: AlertDialog(
              title: const Text('Elevated Permissions Required'),
              content: const Text(
                'EisenVault requires elevated permissions to run properly on Windows. '
                'Please run the application as Administrator.\n\n'
                'This is required for secure storage, database operations, and file system access.'
              ),
              actions: [
                TextButton(
                  onPressed: () => exit(0),
                  child: const Text('Exit'),
                ),
              ],
            ),
          ),
        ),
      ));
      return;
    }
  }

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
  final uploadService = UploadService();

  try {
    // Initialize auth state
    await authStateManager.initialize();

    // Initialize upload service
    uploadService.initialize();

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
  if (!kIsWeb) {
    if (Platform.isAndroid || Platform.isIOS) {
      await Permission.photos.request();
      await Permission.videos.request();
      await Permission.audio.request();
    }
  }

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
      child: MyApp(syncService: syncService, uploadService: uploadService),
    ),
  );
}


class MyApp extends StatefulWidget {
  final SyncService syncService;
  final UploadService uploadService;

  const MyApp({super.key, required this.syncService, required this.uploadService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForUploads();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.uploadService.checkForUploadDataWhenAppForeground();
    }
  }

  void _listenForUploads() {
    widget.uploadService.uploadStream.listen((uploadData) {
      _showUploadNotification(uploadData);
    });
  }

  void _showUploadNotification(UploadData uploadData) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Uploaded ${uploadData.fileCount} files to ${uploadData.folder}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

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