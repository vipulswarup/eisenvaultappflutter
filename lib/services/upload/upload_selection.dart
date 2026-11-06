import 'dart:io';
import 'package:path/path.dart' as p;
import '../../models/upload/batch_upload_models.dart';

class UploadSelection {
  final List<UploadFileItem> items;
  final List<String> skipped;
  UploadSelection(this.items, this.skipped);
}

/// Expands native file selections without following symbolic links.
class UploadSelectionScanner {
  Future<UploadSelection> scan(List<String> paths) async {
    final items = <UploadFileItem>[];
    final skipped = <String>[];
    final visited = <String>{};
    Future<void> visit(String path, String parent) async {
      final normalized = p.normalize(p.absolute(path));
      if (!visited.add(normalized)) return;
      try {
        final type = await FileSystemEntity.type(path, followLinks: false);
        final name = p.basename(path);
        if (type == FileSystemEntityType.file) {
          // Confirm read access now, before adding the item to the queue.
          final handle = await File(path).open();
          await handle.close();
          items.add(
            UploadFileItem(
              name: name,
              path: normalized,
              relativeFolderPath: parent,
            ),
          );
        } else if (type == FileSystemEntityType.directory) {
          final children =
              await Directory(path).list(followLinks: false).toList();
          children.sort((a, b) => a.path.compareTo(b.path));
          items.add(
            UploadFileItem(
              name: name,
              path: normalized,
              relativeFolderPath: parent,
              isDirectory: true,
            ),
          );
          final next = parent.isEmpty ? name : '$parent/$name';
          for (final child in children) {
            await visit(child.path, next);
          }
        } else {
          skipped.add(
            '$path: symbolic link, missing file, or unsupported item',
          );
        }
      } on FileSystemException catch (e) {
        skipped.add('$path: ${e.message}');
      }
    }

    for (final path in paths) {
      await visit(path, '');
    }
    return UploadSelection(items, skipped);
  }
}
