import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eisenvaultappflutter/screens/settings/photo_upload_settings_screen.dart';
import 'package:eisenvaultappflutter/services/photos/photo_upload_settings.dart';
import 'package:eisenvaultappflutter/services/photos/pending_camera_capture.dart';

void main() {
  testWidgets('settings starts ON and saves OFF', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: PhotoUploadSettingsScreen()),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      true,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
    expect(await PhotoUploadSettings().isGeostampEnabled(), false);
  });
  test(
    'camera recovery preserves original folder and cannot cross accounts',
    () async {
      SharedPreferences.setMockInitialValues({});
      await const PendingCameraCapture(
        scope: 'server|alice',
        folderId: 'folder-a',
        geostampEnabled: true,
      ).save();
      expect(await PendingCameraCapture.read('server|bob'), isNull);
      final pending = await PendingCameraCapture.read('server|alice');
      expect(pending!.folderId, 'folder-a');
      expect(pending.geostampEnabled, true);
      await PendingCameraCapture.clear();
      expect(await PendingCameraCapture.read('server|alice'), isNull);
    },
  );
}
