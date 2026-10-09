import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:flutter/material.dart';

/// A colored, scalable Material icon for a department, folder, or file type.
/// The icon is rendered directly on its surface with no backing shape.
class FileTypeIcon extends StatelessWidget {
  final String? fileName;
  final bool isFolder;
  final bool isDepartment;
  final double containerSize;
  final double iconSize;

  const FileTypeIcon({
    super.key,
    this.fileName,
    this.isFolder = false,
    this.isDepartment = false,
    this.containerSize = 40,
    this.iconSize = 26,
  });

  factory FileTypeIcon.forItem(
    BrowseItem item, {
    double containerSize = 40,
    double iconSize = 26,
  }) {
    return FileTypeIcon(
      fileName: item.type == 'folder' || item.isDepartment ? null : item.name,
      isFolder: item.type == 'folder',
      isDepartment: item.isDepartment,
      containerSize: containerSize,
      iconSize: iconSize,
    );
  }

  String get _extension {
    final name = fileName?.toLowerCase() ?? '';
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1);
  }

  (IconData, Color) get _appearance {
    if (isFolder) return (Icons.folder_rounded, EVColors.accentAmberDark);

    switch (_extension) {
      case 'pdf':
        return (Icons.picture_as_pdf_rounded, EVColors.statusRedDark);
      case 'doc':
      case 'docx':
      case 'rtf':
      case 'odt':
        return (Icons.description_rounded, EVColors.accentBlue);
      case 'ppt':
      case 'pptx':
      case 'odp':
        return (Icons.slideshow_rounded, EVColors.accentAmberDark);
      case 'xls':
      case 'xlsx':
      case 'csv':
      case 'tsv':
      case 'ods':
        return (Icons.table_chart_rounded, EVColors.statusGreenDark);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'tif':
      case 'tiff':
      case 'psd':
      case 'cdr':
      case 'dcm':
        return (Icons.image_rounded, EVColors.accentPurple);
      case 'svg':
      case 'ai':
        return (Icons.draw_rounded, EVColors.accentPurple);
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'wmv':
      case 'flv':
      case 'mkv':
      case 'mpeg':
      case '3gp':
      case 'ogv':
      case 'webm':
      case 'ogm':
      case 'm3u8':
        return (Icons.movie_rounded, EVColors.accentPurple);
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'm4a':
      case 'flac':
        return (Icons.music_note_rounded, EVColors.accentTeal);
      case 'zip':
      case 'rar':
      case '7z':
      case '7zip':
      case 'gz':
      case 'tar':
        return (Icons.archive_rounded, EVColors.neutralGrey600);
      case 'json':
      case 'xml':
      case 'html':
      case 'css':
      case 'js':
      case 'ts':
      case 'dart':
      case 'py':
      case 'java':
      case 'c':
      case 'cpp':
      case 'h':
      case 'hpp':
      case 'php':
        return (Icons.code_rounded, EVColors.accentPurple);
      case 'txt':
      case 'md':
        return (Icons.article_rounded, EVColors.neutralGrey600);
      case 'dwg':
      case 'dxf':
        return (Icons.design_services_rounded, EVColors.accentTeal);
      default:
        return (Icons.insert_drive_file_rounded, EVColors.neutralGrey500);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Center(
        child: Icon(
          isDepartment ? Icons.corporate_fare_rounded : _appearance.$1,
          size: iconSize,
          color: isDepartment ? EVColors.accentBlue : _appearance.$2,
        ),
      ),
    );
  }
}
