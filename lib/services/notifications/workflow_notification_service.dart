import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/account.dart';
import '../auth/auth_state_manager.dart';
import '../../utils/logger.dart';
import 'workflow_notification.dart';
import 'workflow_notification_api.dart';

/// Native display and authenticated inbox integration. OS remote push adapters
/// can call receive(); polling is recovery while the application is running.
class WorkflowNotificationService {
  static const enabled = bool.fromEnvironment('WORKFLOW_NOTIFICATIONS');
  final AuthStateManager auth;
  final Future<void> Function(WorkflowNotification) onOpen;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final http.Client _client = http.Client();
  Timer? _timer;
  bool _disposed = false, _polling = false;
  final Set<String> _inFlight = {};
  final Set<String> _permissionRequested = {};
  Set<String> _knownAccounts = {};

  WorkflowNotificationService({required this.auth, required this.onOpen});

  Future<void> initialize() async {
    if (!enabled) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        windows: WindowsInitializationSettings(
          appName: 'EisenVault',
          appUserModelId: 'EisenVault.EisenVaultDesktop',
          guid: 'b4ef7d09-31bc-4b26-92d0-baa2c49a8a96',
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open task'),
      ),
      onDidReceiveNotificationResponse: (response) => _open(response.payload),
    );
    auth.addListener(_authChanged);
    _authChanged();
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _open(launch?.notificationResponse?.payload);
    }
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => poll());
  }

  void _authChanged() {
    if (_disposed) return;
    final current = auth.allAccounts.map((account) => account.id).toSet();
    if (_knownAccounts.difference(current).isNotEmpty ||
        !auth.isAuthenticated) {
      unawaited(
        _plugin.cancelAll().catchError((Object error) {
          EVLogger.warning('Could not clear workflow notifications');
        }),
      );
    }
    _knownAccounts = current;
    unawaited(poll());
  }

  Account? _account(String id) =>
      auth.allAccounts.where((account) => account.id == id).firstOrNull;

  Future<void> _permissions(Account account) async {
    if (!_permissionRequested.add(account.id)) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Fetch the server's durable inbox, advancing only after successful display.
  Future<void> poll() async {
    if (_disposed || _polling || !auth.isAuthenticated) return;
    _polling = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final account in auth.allAccounts) {
        if (_disposed) return;
        try {
          await _permissions(account);
          final key = 'workflow.notifications.cursor.${account.id}';
          final page = await WorkflowNotificationApi(
            _client,
            account,
          ).inbox(prefs.getString(key));
          if (_disposed || _account(account.id)?.token != account.token) {
            continue;
          }
          for (final event in page.events) {
            await receive(event);
          }
          if (!_disposed && _account(account.id)?.token == account.token) {
            await prefs.setString(key, page.nextCursor);
          }
        } catch (_) {
          // Retain cursor and retry later; never log tokens or payloads.
          EVLogger.warning('Workflow notification inbox unavailable');
        }
      }
    } finally {
      _polling = false;
    }
  }

  /// Entry point for foreground remote push adapters. Duplicate delivery from
  /// inbox recovery and the push provider shares the same persisted event ID.
  Future<void> receive(WorkflowNotification event) async {
    if (_disposed ||
        !enabled ||
        !auth.isAuthenticated ||
        _account(event.accountId) == null) {
      return;
    }
    final key = 'workflow.notifications.seen.${event.accountId}';
    final flightKey = '${event.accountId}:${event.eventId}';
    if (!_inFlight.add(flightKey)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(key) ?? [];
      if (seen.contains(event.eventId) ||
          _disposed ||
          _account(event.accountId) == null) {
        return;
      }
      final digest = sha256.convert(utf8.encode(flightKey)).bytes;
      final id =
          ((digest[0] << 24) |
              (digest[1] << 16) |
              (digest[2] << 8) |
              digest[3]) &
          0x7fffffff;
      await _plugin.show(
        id: id,
        title: 'New workflow task',
        body:
            'A workflow step needs your attention. Open EisenVault to view it.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'workflow_tasks',
            'Workflow tasks',
            channelDescription:
                'Assigned approvals, signatures and other workflow steps',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
          windows: WindowsNotificationDetails(),
          linux: LinuxNotificationDetails(),
        ),
        payload: jsonEncode(event.toJson()),
      );
      if (_disposed ||
          !auth.isAuthenticated ||
          _account(event.accountId) == null) {
        await _plugin.cancel(id: id);
        return;
      }
      seen.add(event.eventId);
      await prefs.setStringList(
        key,
        seen.length > 1000 ? seen.sublist(seen.length - 1000) : seen,
      );
    } finally {
      _inFlight.remove(flightKey);
    }
  }

  Future<void> _open(String? payload) async {
    if (_disposed || payload == null || !auth.isAuthenticated) return;
    try {
      final event = WorkflowNotification.fromJson(
        jsonDecode(payload) as Map<String, dynamic>,
      );
      if (_account(event.accountId) != null) await onOpen(event);
    } catch (_) {
      EVLogger.warning('Could not open workflow notification');
    }
  }

  void dispose() {
    _disposed = true;
    auth.removeListener(_authChanged);
    _timer?.cancel();
    _client.close();
  }
}
