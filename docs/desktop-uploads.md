# Desktop file and folder uploads

## Selecting and reviewing local items

On Windows, macOS, and Linux, open **Upload Documents** in a destination folder.
Drag files or folders onto the screen, use **Select Files**, or use **Select Folder**.
Selections are added to a review queue; they are not uploaded immediately.
The queue shows each relative destination path. Removing a folder also removes
its queued descendants. Adding the same destination twice does not duplicate it.
Conflicting local destinations and unreadable or unsupported items are reported.
Symbolic links are skipped to avoid following links outside a selected folder or
recursing through cycles. Files are read from their selected locations at upload
time, so keep them available until the upload finishes.

## Sending content to the repository

Choose **Upload All Items** to create folders and upload files beneath the current
repository folder. Nested structure and empty folders are preserved. Progress is
shown for the batch and individual queue entries. Successful items leave the
queue. Return to browsing to refresh the destination listing.

Folder creation supports Classic/Alfresco and Angora repositories. An existing
server folder name conflict is reported; the app does not silently merge into it.
Classic's existing document upload policy can rename colliding file names.

## Recovering failed items

Failed items remain in the queue with their errors. **Retry Failed Items** retries
those items only. Folder IDs already created during the current upload-screen
session are reused. Leaving the screen ends that session; reopening it does not
retain the queue or folder cache. This feature does not provide offline uploads
or resumable upload sessions across app restarts.

## Platform access and verification

The macOS release build enables user-selected file read/write access. For native
drops, security-scoped access is held until the upload screen closes. Windows
uses native file paths. Selection and uploads disable queue changes while they
are running.

`test/services/upload/folder_upload_test.dart` covers local scanning, both folder
creation APIs, conflicts, and retry behavior. `integration_test/desktop_upload_test.dart`
checks the upload screen against a local HTTP fixture, including multipart file
content, destination IDs, and a failed upload followed by retry. Set
`UPLOAD_NATIVE_SMOKE=true` and `UPLOAD_FIXTURE_DIR` to a fixture directory to
exercise a real file picker and native Finder/File Explorer drop during the test.
This fixture contains `picked.txt`, `Reports/sub/report.txt`, and `Reports/empty`.
Live repository integration requires separate server credentials.

## Scanning (desktop)

The **Scan** button beside the file and folder pickers scans to a multi-page PDF
under the app temp directory (`scan-YYYYMMDD-HHMMSS.pdf`) and adds it to the
upload queue. The user still presses Upload.

Implemented in `packages/ev_scanner` (`listDevices`, `scan`, `cancel`; `ScanRequest`
holds device, source, colour, DPI, page size). Pages are returned before PDF
assembly, so `EvScanner(processors: [...])` can later insert deskew, blank-page
removal or barcode separation.

| OS | Backend | Status |
|----|---------|--------|
| Linux | system `scanimage` (SANE) run as a separate process; package must depend on `sane` and `sane-airscan` | `scanimage` flags and parsing verified against an HP Smart Tank over wifi (airscan/eSCL) from an Ubuntu VM; Dart backend itself not run on Linux |
| Windows | TWAIN 2 (`TWAINDSM.dll`, x64 only, bundled), WIA 2.0 fallback | full Flutter plugin scanned an HP over wifi through WIA (ARM64 Windows 11 VM); TWAIN path not exercised on a device |
| macOS | ImageCaptureCore, `com.apple.security.device.usb` entitlement | sandboxed app listed and scanned an HP over wifi (`tool/scan_probe.dart`); USB not tried |

The app installs no drivers. A scanner with no TWAIN/WIA driver (Windows), no Image
Capture support (macOS) or no SANE backend (Linux) will not appear; high-speed
production scanners are the usual Linux miss.
