import 'package:eisenvaultappflutter/screens/browse/widgets/browse_drawer.dart';
import 'package:eisenvaultappflutter/services/offline/offline_manager.dart';
import 'package:eisenvaultappflutter/services/auth/auth_state_manager.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_app_bar.dart';
import 'package:eisenvaultappflutter/screens/browse/widgets/browse_list_item.dart';
import 'package:eisenvaultappflutter/screens/login/login_form.dart';
import 'package:eisenvaultappflutter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineManagerFake extends Fake implements OfflineManager {}

void main() {
  for (final persistent in [true, false]) {
    testWidgets('Navigation preserves workspace when persistent=$persistent', (
      tester,
    ) async {
      PackageInfo.setMockInitialValues(
        appName: 'EisenVault',
        packageName: 'ev',
        version: '1.4.2',
        buildNumber: '142',
        buildSignature: '',
      );
      final navigator = GlobalKey<NavigatorState>();
      final scaffold = GlobalKey<ScaffoldState>();
      var signOutRequested = false;
      final drawer = BrowseDrawer(
        firstName: 'Alex',
        baseUrl: 'https://example.com',
        authToken: '',
        instanceType: 'angora',
        customerHostname: '',
        offlineManager: _OfflineManagerFake(),
        persistent: persistent,
        onLogoutTap: () => signOutRequested = true,
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: AuthStateManager(),
          child: MaterialApp(
            navigatorKey: navigator,
            theme: AppTheme.light,
            initialRoute: '/workspace',
            routes: {
              '/': (_) => const Scaffold(body: Text('Previous page')),
              '/workspace':
                  (_) => Scaffold(
                    key: scaffold,
                    drawer: persistent ? null : drawer,
                    body:
                        persistent
                            ? SizedBox(width: 280, child: drawer)
                            : const Text('Workspace'),
                  ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!persistent) {
        scaffold.currentState!.openDrawer();
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.text('Logout'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      expect(signOutRequested, isTrue);
      expect(navigator.currentState!.canPop(), isTrue);
      expect(find.text('Previous page'), findsNothing);
      if (!persistent) expect(scaffold.currentState!.isDrawerOpen, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(768, 1024),
    const Size(1440, 900),
    const Size(900, 400),
  ]) {
    testWidgets('Sign in adapts to $size and remains usable with keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: LoginForm(onLoginFailed: (_) {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Your documents.\nOne organised space.'),
        size.width >= 900 ? findsOneWidget : findsNothing,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'alex',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter Server URL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Compact toolbar exposes selection and filtering through overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = false;
      var filtered = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            appBar: BrowseAppBar(
              onSelectionModeToggle: () => selected = true,
              onFilterSortTap: () => filtered = true,
            ),
            body: const SizedBox(),
          ),
        ),
      );
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select items'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filter and sort'));
      await tester.pumpAndSettle();
      expect(filtered, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Document row handles long names, selection and large text on phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var checked = false;
      var actions = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
          home: Scaffold(
            appBar: const BrowseAppBar(),
            body: BrowseListItem(
              item: const BrowseItem(
                id: '1',
                name:
                    'A very long department folder name for responsive testing',
                type: 'folder',
              ),
              showSelectionCheckbox: true,
              onTap: () {},
              onLongPress: () => actions = true,
              onSelectionChanged: (value) => checked = value,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(Checkbox));
      expect(checked, isTrue);
      await tester.tap(find.byTooltip('Document actions'));
      expect(actions, isTrue);
    },
  );
}
