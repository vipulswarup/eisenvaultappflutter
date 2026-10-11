# Camera photo geostamps

Android and iOS camera uploads add a visible bottom-right panel and EXIF GPS
metadata before uploading. The device-wide **Photo upload settings → Geostamp
photos** preference defaults to ON, including upgrades, and is persisted with
SharedPreferences. Turning it off skips all feature location requests and image
processing; it does not strip metadata already present in the original camera
image. Gallery selection, shared files and document scanning are excluded.

## Capture and failure behavior

The camera flow checks location permission and obtains a fresh fix before opening
the system camera, then refreshes it when the camera returns. Only foreground
location is requested. The iOS app declares both location purpose strings because
the location SDK can reference Always authorization APIs; the extra declaration
does not enable background tracking or change the permission requested by the app.
Each measurement has a ten-second timeout, and fixes older
than sixty seconds or invalid coordinates/accuracy are rejected. Reduced accuracy
is accepted and explicitly labeled approximate.

The visible panel includes coordinates, reported accuracy, a full global Plus
Code and **location measurement time in UTC**. This is not a guarantee of exact
shutter-time location: the existing external-camera picker does not expose a
shutter-time location callback. Plus Codes identify an area and do not imply GPS
accuracy or verify the authenticity of a capture. No Google API key, geocoding
request, or network access is needed to compute the code.

If location is denied, disabled, stale, or times out, the user chooses Retry,
Upload without geostamp, or Cancel. Unsupported image formats or processing
failures use the same explicit fallback. The app does not silently upload an
unstamped photo with the preference ON.

Prepared JPEGs preserve image dimensions, bake orientation before stamping, and
are generated in an isolate at quality 95. The source file is never overwritten.
The prepared temporary directory is deleted when the upload/retry flow ends.
Retries reuse the same file without applying another stamp. A successful upload
followed by a failed folder refresh does not trigger another camera upload.

Android persists only camera origin, account/server scope, destination folder,
and whether geostamping was enabled before launching the external camera. On
restart, image_picker lost-data recovery offers upload to the original folder
only for the matching account. Because capture location cannot be verified after
process death, a recovered capture explicitly requires consent to upload without
an added geostamp. Gallery/scanner results are not registered for this recovery.

## Metadata

GPS latitude/longitude use standard unsigned degrees/minutes/seconds RATIONALs
and N/S/E/W references. GPS date/time records the location measurement in UTC;
GPSHPositioningError records the reported horizontal accuracy in metres. Old GPS
fields and stale embedded thumbnails are removed from the prepared copy.
Relevant camera EXIF is preserved; altitude is omitted because this feature does
not currently assess vertical accuracy.

EXIF UserComment uses the ASCII charset prefix and JSON with
`eisenvaultGeostampVersion: 1`, coordinates, accuracy, approximation status,
location measurement time, Plus Code, and a Google Maps coordinate-search URL.
An existing comment is retained as `originalUserCommentBase64` so its original
encoding survives. The output EXIF is read back before the file is uploaded.

## Validation

Automated tests cover standard GPS serialization in all hemispheres, metadata
preservation, orientation, pixel stamping, approximate locations, permission
failures/timeouts, freshness, settings persistence and account-scoped recovery.

Physical Android and iOS checks still required:

- Allow precise and approximate location, deny it, permanently deny it, and disable
  location services. Check Retry/Upload without geostamp/Cancel.
- Turn the preference OFF, restart, and capture: no feature location prompt or added
  EXIF/pixel stamp. Re-enable it and repeat.
- Capture portrait/landscape and large photos, move during a camera session,
  cancel the camera, and take a photo without network access.
- Upload to Angora and Alfresco, download the original, and read its EXIF using an
  independent viewer. Server-generated thumbnails/previews may discard EXIF.
- Cause an upload failure and retry; confirm there is only one visible stamp.
- On Android, simulate process death while the camera is open and verify the
  recovered-photo confirmation, original folder, and account boundary.
- Confirm gallery uploads and JPEG/PDF document scans have unchanged behavior and
  do not request feature location permission or receive a new stamp.
