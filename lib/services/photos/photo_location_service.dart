import 'package:geolocator/geolocator.dart';

/// Location of the device near capture, with the actual measurement time.
class PhotoLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime measuredAt;
  final bool approximate;

  const PhotoLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.measuredAt,
    required this.approximate,
  });

  bool isFreshAt(DateTime now) {
    final age = now.toUtc().difference(measuredAt.toUtc());
    return age >= const Duration(seconds: -5) &&
        age <= const Duration(seconds: 60);
  }
}

class PhotoLocationException implements Exception {
  final String message;
  const PhotoLocationException(this.message);
  @override
  String toString() => message;
}

class PhotoLocationService {
  Future<PhotoLocation> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PhotoLocationException('Location services are turned off.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const PhotoLocationException(
        'Location permission is unavailable. You can enable it in your device settings.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    final location = PhotoLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      measuredAt: position.timestamp,
      approximate:
          await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.reduced,
    );
    if (!location.isFreshAt(DateTime.now()) ||
        !location.latitude.isFinite ||
        location.latitude.abs() > 90 ||
        !location.longitude.isFinite ||
        location.longitude.abs() > 180 ||
        !location.accuracy.isFinite ||
        location.accuracy < 0) {
      throw const PhotoLocationException(
        'A fresh location could not be obtained.',
      );
    }
    return location;
  }
}
