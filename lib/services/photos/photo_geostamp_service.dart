import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:open_location_code/open_location_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'photo_location_service.dart';

/// Produces a separate JPEG; original pixels/files are never overwritten.
class PhotoGeostampService {
  Future<File> prepare(String sourcePath, PhotoLocation location) async {
    final directory =
        await Directory(
          p.join(
            (await getTemporaryDirectory()).path,
            'geostamp_${DateTime.now().microsecondsSinceEpoch}',
          ),
        ).create();
    final output = File(
      p.join(
        directory.path,
        '${p.basenameWithoutExtension(sourcePath)}_geostamped.jpg',
      ),
    );
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final encoded = await compute(
        (Uint8List data) => stampPhoto(data, location),
        bytes,
      );
      await output.writeAsBytes(encoded, flush: true);
      return output;
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }
}

/// Pure processing entry point, used in an isolate and metadata round-trip tests.
Uint8List stampPhoto(Uint8List bytes, PhotoLocation location) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const FormatException('This photo format cannot be geostamped.');
  }
  if (decoded == null) {
    throw const FormatException('This photo format cannot be geostamped.');
  }
  final image = img.bakeOrientation(decoded);
  image.exif.imageIfd.orientation = 1;
  image.exif.imageIfd[0x0100] = img.IfdValueLong(image.width);
  image.exif.imageIfd[0x0101] = img.IfdValueLong(image.height);
  image.exif.exifIfd[0xa002] = img.IfdValueLong(image.width);
  image.exif.exifIfd[0xa003] = img.IfdValueLong(image.height);
  // Embedded thumbnails would otherwise show an unstamped, unrotated image.
  image.exif.thumbnailData = null;
  image.exif.directories.remove('ifd1');
  final code =
      PlusCode.encode(LatLng(location.latitude, location.longitude)).toString();
  final utc = location.measuredAt.toUtc();
  final lines = [
    '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
    '${location.approximate ? 'Approximate' : 'Accuracy'}: +/-${location.accuracy.ceil()} m',
    'Plus Code: $code',
    'Location: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(utc)} UTC',
  ];
  final font = img.arial24;
  int textWidth(String text) => text.codeUnits.fold(
    0,
    (width, c) => width + (font.characters[c]?.xAdvance ?? 0),
  );
  final panel = img.Image(
    width: lines.map(textWidth).reduce(math.max) + 28,
    height: lines.length * 34 + 20,
    numChannels: 4,
  );
  img.fill(panel, color: img.ColorRgba8(0, 0, 0, 180));
  for (var i = 0; i < lines.length; i++) {
    img.drawString(
      panel,
      lines[i],
      font: font,
      x: 14,
      y: 10 + i * 34,
      color: img.ColorRgb8(255, 255, 255),
    );
  }
  final margin = math.max(
    2,
    (math.min(image.width, image.height) * .02).round(),
  );
  final width = math.max(
    1,
    math.min(
      (math.min(image.width, image.height) * .38).round(),
      ((image.height - margin * 2) * panel.width / panel.height).floor(),
    ),
  );
  final scaled = img.copyResize(
    panel,
    width: width,
    interpolation: img.Interpolation.linear,
  );
  img.compositeImage(
    image,
    scaled,
    dstX: math.max(0, image.width - scaled.width - margin),
    dstY: math.max(0, image.height - scaled.height - margin),
  );

  // EXIF GPS uses unsigned D/M/S rationals, NOT decimal DOUBLE values.
  // Obtain the library's rational value through its public EXIF API.
  rational(int numerator, int denominator) =>
      img.IfdValueRational(numerator, denominator).toRational();
  img.IfdValueRational coordinate(double value) {
    final absolute = value.abs();
    final degrees = absolute.floor();
    final minutes = ((absolute - degrees) * 60).floor();
    final seconds = (absolute - degrees - minutes / 60) * 3600;
    return img.IfdValueRational.list([
      rational(degrees, 1),
      rational(minutes, 1),
      rational((seconds * 1000000).round(), 1000000),
    ]);
  }

  final gps = image.exif.gpsIfd;
  // Replace stale camera GPS tags rather than mixing different measurements.
  gps.data.clear();
  gps[0x0000] = img.IfdByteValue.list(Uint8List.fromList([2, 3, 0, 0]));
  gps.gpsLatitudeRef = location.latitude < 0 ? 'S' : 'N';
  gps[0x0002] = coordinate(location.latitude);
  gps.gpsLongitudeRef = location.longitude < 0 ? 'W' : 'E';
  gps[0x0004] = coordinate(location.longitude);
  gps[0x0007] = img.IfdValueRational.list([
    rational(utc.hour, 1),
    rational(utc.minute, 1),
    rational(utc.second * 1000 + utc.millisecond, 1000),
  ]);
  gps.gpsDate = DateFormat('yyyy:MM:dd').format(utc);
  gps[0x001f] = img.IfdValueRational((location.accuracy * 1000).round(), 1000);
  final existingComment = image.exif.exifIfd[0x9286]?.toData();
  final metadata = jsonEncode({
    'eisenvaultGeostampVersion': 1,
    'latitude': location.latitude,
    'longitude': location.longitude,
    'accuracyMeters': location.accuracy,
    'approximate': location.approximate,
    'locationMeasuredAt': utc.toIso8601String(),
    'plusCode': code,
    'mapsUrl':
        'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
    if (existingComment != null && existingComment.isNotEmpty)
      'originalUserCommentBase64': base64Encode(existingComment),
  });
  image.exif.exifIfd[0x9286] = img.IfdValueUndefined.list([
    ...ascii.encode('ASCII'),
    0,
    0,
    0,
    ...ascii.encode(
      metadata.codeUnits
          .map(
            (c) =>
                c < 128
                    ? String.fromCharCode(c)
                    : '\\u${c.toRadixString(16).padLeft(4, '0')}',
          )
          .join(),
    ),
  ]);
  final result = img.encodeJpg(image, quality: 95);
  final check = img.decodeJpgExif(result);
  if (check?.gpsIfd[0x0002]?.length != 3 ||
      check?.gpsIfd[0x0004]?.length != 3 ||
      check?.exifIfd[0x9286] == null) {
    throw const FormatException('Could not verify photo location metadata.');
  }
  return result;
}
