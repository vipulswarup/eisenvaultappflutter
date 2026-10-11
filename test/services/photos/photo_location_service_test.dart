import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:eisenvaultappflutter/services/photos/photo_location_service.dart';

class FakeLocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  LocationAccuracyStatus accuracyStatus = LocationAccuracyStatus.precise;
  int requests = 0;
  int measurements = 0;
  LocationSettings? settings;
  DateTime timestamp = DateTime.now();
  bool timeout = false;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requestedPermission;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracyStatus;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    measurements++;
    settings = locationSettings;
    if (timeout) throw TimeoutException('Location timed out');
    return Position(
      latitude: 28.6,
      longitude: 77.2,
      timestamp: timestamp,
      accuracy: 25,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late GeolocatorPlatform original;
  late FakeLocationPlatform platform;
  setUp(() {
    original = GeolocatorPlatform.instance;
    platform = FakeLocationPlatform();
    GeolocatorPlatform.instance = platform;
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  test(
    'foreground permission requested only when denied, with bounded GPS wait',
    () async {
      platform.permission = LocationPermission.denied;
      final fix = await PhotoLocationService().locate();
      expect(platform.requests, 1);
      expect(platform.settings!.timeLimit, const Duration(seconds: 10));
      expect(platform.settings!.accuracy, LocationAccuracy.high);
      expect(fix.latitude, 28.6);
      expect(fix.measuredAt, platform.timestamp);
    },
  );
  test('reduced accuracy is accepted and explicitly marked', () async {
    platform.accuracyStatus = LocationAccuracyStatus.reduced;
    expect((await PhotoLocationService().locate()).approximate, true);
    expect(platform.requests, 0);
  });
  test('disabled services do not request permission or measure', () async {
    platform.enabled = false;
    await expectLater(
      PhotoLocationService().locate(),
      throwsA(isA<PhotoLocationException>()),
    );
    expect(platform.requests, 0);
    expect(platform.measurements, 0);
  });
  test('permanently denied permission is not requested repeatedly', () async {
    platform.permission = LocationPermission.deniedForever;
    await expectLater(
      PhotoLocationService().locate(),
      throwsA(isA<PhotoLocationException>()),
    );
    expect(platform.requests, 0);
    expect(platform.measurements, 0);
  });
  test('denied request does not measure', () async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.denied;
    await expectLater(
      PhotoLocationService().locate(),
      throwsA(isA<PhotoLocationException>()),
    );
    expect(platform.measurements, 0);
  });
  test('stale GPS is rejected', () async {
    platform.timestamp = DateTime.now().subtract(const Duration(minutes: 5));
    await expectLater(
      PhotoLocationService().locate(),
      throwsA(isA<PhotoLocationException>()),
    );
  });
  test(
    'timeout propagates to explicit fallback instead of using cached GPS',
    () async {
      platform.timeout = true;
      await expectLater(
        PhotoLocationService().locate(),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
