import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/utils/file_type_utils.dart';
import 'package:flutter/material.dart';

class FileTypeIcon extends StatelessWidget {
  final String? fileName;
  final bool isFolder;
  final bool isDepartment;
  final double containerSize;
  final double iconSize;
  final bool showBackground;

  const FileTypeIcon({
    super.key,
    this.fileName,
    this.isFolder = false,
    this.isDepartment = false,
    this.containerSize = 40,
    this.iconSize = 24,
    this.showBackground = true,
  });

  factory FileTypeIcon.forItem(
    BrowseItem item, {
    double containerSize = 40,
    double iconSize = 24,
    bool showBackground = true,
  }) {
    return FileTypeIcon(
      fileName: item.type == 'folder' || item.isDepartment ? null : item.name,
      isFolder: item.type == 'folder',
      isDepartment: item.isDepartment,
      containerSize: containerSize,
      iconSize: iconSize,
      showBackground: showBackground,
    );
  }

  String get _assetPath {
    if (isDepartment) {
      return FileTypeUtils.departmentIconAsset;
    }
    if (isFolder) {
      return FileTypeUtils.folderIconAsset;
    }
    return FileTypeUtils.getFileIconAsset(fileName ?? '');
  }

  Color? get _backgroundColor {
    if (!showBackground) {
      return null;
    }
    if (isDepartment) {
      return EVColors.paletteAccent.withOpacity(0.1);
    }
    if (isFolder) {
      return EVColors.folderIconBackground;
    }
    return EVColors.documentIconBackground;
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _assetPath,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
    );

    if (!showBackground) {
      return image;
    }

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: image),
    );
  }
}
