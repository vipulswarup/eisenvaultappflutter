import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eisenvaultappflutter/services/photos/photo_geostamp_service.dart';
import 'package:eisenvaultappflutter/services/photos/photo_location_service.dart';
import 'package:eisenvaultappflutter/services/photos/photo_upload_settings.dart';

void main() {
  final time = DateTime.utc(2026, 10, 10, 9, 2, 3, 456);
  PhotoLocation fix(double lat, double lon, {bool approximate = false}) =>
      PhotoLocation(
        latitude: lat,
        longitude: lon,
        accuracy: 18.25,
        measuredAt: time,
        approximate: approximate,
      );
  double decimal(img.IfdValue? value) =>
      value!.toDouble(0) + value.toDouble(1) / 60 + value.toDouble(2) / 3600;

  test('GPS round-trip uses standard rationals in all hemispheres', () {
    for (final point in [
      fix(28.6139, 77.209),
      fix(-33.8688, -151.2093),
      fix(0, 0),
    ]) {
      final source = img.Image(width: 900, height: 600);
      img.fill(source, color: img.ColorRgb8(100, 120, 140));
      source.exif.imageIfd.make = 'Test camera';
      source.exif.exifIfd[0x9003] = img.IfdValueAscii('2026:10:10 14:32:00');
      source.exif.exifIfd[0x9286] = img.IfdValueUndefined.list(
        utf8.encode('Original café'),
      );
      final original = img.encodeJpg(source);
      final stamped = stampPhoto(original, point);
      final exif = img.decodeJpgExif(stamped)!;
      final gps = exif.gpsIfd;
      expect(gps[2]!.type, img.IfdValueType.rational);
      expect(gps[2]!.length, 3);
      expect(decimal(gps[2]), closeTo(point.latitude.abs(), 1e-8));
      expect(decimal(gps[4]), closeTo(point.longitude.abs(), 1e-8));
      expect(gps.gpsLatitudeRef, point.latitude < 0 ? 'S' : 'N');
      expect(gps.gpsLongitudeRef, point.longitude < 0 ? 'W' : 'E');
      expect(gps.gpsDate, '2026:10:10');
      expect(gps[7]!.toDouble(2), closeTo(3.456, 0.0001));
      expect(gps[0x1f]!.toDouble(), 18.25);
      expect(exif.imageIfd.make, 'Test camera');
      expect(exif.exifIfd[0x9003]!.toString(), '2026:10:10 14:32:00');
      final comment = exif.exifIfd[0x9286]!.toData();
      expect(ascii.decode(comment.sublist(0, 5)), 'ASCII');
      final json = jsonDecode(ascii.decode(comment.sublist(8))) as Map;
      expect(json['latitude'], point.latitude);
      expect(
        utf8.decode(base64Decode(json['originalUserCommentBase64'] as String)),
        'Original café',
      );
      expect(json['plusCode'], contains('+'));
      expect(
        json['mapsUrl'],
        contains('query=${point.latitude},${point.longitude}'),
      );
      final decoded = img.decodeJpg(stamped)!;
      expect(decoded.width, 900);
      // The bottom-right panel is burned into pixels; upper-left stays intact.
      expect(decoded.getPixel(20, 20).r, closeTo(100, 3));
      expect(decoded.getPixel(875, 575).r, lessThan(80));
      expect(img.decodeJpgExif(original)!.gpsIfd.isEmpty, isTrue);
    }
  });

  test('orientation is baked before bottom-right stamp', () {
    final source = img.Image(width: 600, height: 900);
    source.exif.imageIfd.orientation = 6;
    final stamped = stampPhoto(img.encodeJpg(source), fix(1, 2));
    final decoded = img.decodeJpg(stamped)!;
    expect(decoded.width, 900);
    expect(decoded.height, 600);
    final exif = img.decodeJpgExif(stamped)!;
    expect(exif.imageIfd.orientation, 1);
    expect(exif.exifIfd[0xa002]!.toInt(), 900);
    expect(exif.exifIfd[0xa003]!.toInt(), 600);
  });

  test('approximate accuracy and measurement time are recorded', () {
    final result = stampPhoto(
      img.encodeJpg(img.Image(width: 300, height: 200)),
      fix(1, 2, approximate: true),
    );
    final json =
        jsonDecode(
              ascii.decode(
                img.decodeJpgExif(result)!.exifIfd[0x9286]!.toData().sublist(8),
              ),
            )
            as Map;
    expect(json['approximate'], true);
    expect(json['locationMeasuredAt'], time.toIso8601String());
  });

  test('invalid image fails rather than uploading unstamped silently', () {
    expect(
      () => stampPhoto(Uint8List.fromList([1, 2, 3]), fix(1, 2)),
      throwsFormatException,
    );
  });

  test('freshness excludes old and future measurements', () {
    final point = fix(1, 2);
    expect(point.isFreshAt(time.add(const Duration(seconds: 60))), true);
    expect(point.isFreshAt(time.add(const Duration(seconds: 61))), false);
    expect(point.isFreshAt(time.subtract(const Duration(seconds: 6))), false);
  });

  test('setting defaults ON and persists opt-out across instances', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await PhotoUploadSettings().isGeostampEnabled(), true);
    await PhotoUploadSettings().setGeostampEnabled(false);
    expect(await PhotoUploadSettings().isGeostampEnabled(), false);
    await PhotoUploadSettings().setGeostampEnabled(true);
    expect(await PhotoUploadSettings().isGeostampEnabled(), true);
  });
}
