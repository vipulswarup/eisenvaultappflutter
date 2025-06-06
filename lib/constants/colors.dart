import 'package:flutter/material.dart';

class EVColors {
  

  // General Purpose Colors
  static const errorRed = Color(0xFFD9534F);
  static const warningOrange = Color(0xFFF0AD4E);
  static const successGreen = Color(0xFF5CB85C);
  static const infoBlue = Color(0xFF5BC0DE);

  // Custom Palette
  static const paletteBackground = Color(0xFFF4EAD2); // #f4ead2
  static const paletteButton = Color(0xFFB24A3B); // #b24a3b
  static const paletteTextDark = Color(0xFF222222); // #222222
  static const paletteAccent = Color(0xFF74B7A0); // #74b7a0

  // Card & List Backgrounds
  static const cardBackground = paletteBackground;
  static const cardShadow = Color(0x0D000000); // 5% black

  // Icon Colors
  static const iconGrey = Color(0xFFBDBDBD); // grey[400]
  static const iconGreyLight = Color(0xFF9E9E9E); // grey[500]
  static const iconAmber = Color(0xFFFFC107); // amber
  static const iconTeal = Color(0xFF009688); // teal

  // Text colors
  static const textDefault = paletteTextDark;
  static const textSecondary = Color(0xFFAAAAAA);
  static const textGrey = Color(0xFF757575); // grey[600]
  static const textLightGrey = Color(0xFF9E9E9E); // grey[500]

  // Highlight for search
  static const searchHighlightBackground = Color(0x330056A6); // 20% primaryBlue
  static const searchHighlightText = Color(0xFF0056A6);

  // Sort Option
  static const sortOptionBackground = paletteBackground;
  static const sortOptionShadow = Color(0x0D000000); // 5% black
  static const sortOptionText = paletteTextDark;
  static const sortOptionIcon = Color(0xFF0056A6);

  // Browse Navigation
  static const browseNavBackground = paletteBackground;
  static const browseNavChevron = Color(0xFFBDBDBD); // grey[400]
  static const browseNavText = paletteButton;
  static const browseNavCurrentText = paletteTextDark;
  static const browseNavSeparator = Color(0xFFAAAAAA);

  // Search Result Item Icons
  static const departmentIconBackground = Color(0xFFE3F2FD); // blue[50]
  static const departmentIconForeground = Color(0xFF1976D2); // blue[700]
  static const folderIconBackground = Color(0xFFFFF8E1); // amber[50]
  static const folderIconForeground = Color(0xFFFFA000); // amber[700]
  static const documentIconBackground = Color(0xFFE0F2F1); // teal[50]
  static const documentIconForeground = Color(0xFF009688); // teal[500]

  // Screen & Background Colors
  static const screenBackground = paletteBackground;

  // TextField Colors
  static const textFieldPrefixIcon = paletteButton;
  static const textFieldFill = Color(0xFFFFFFFF);
  static const textFieldBorder = Color(0xFF8CB3E8);
  static const textFieldErrorBorder = Color(0xFFD9534F);
  static const textFieldLabel = paletteTextDark;
  static const textFieldHint = Color(0xFFAAAAAA);

  // Button Colors
  static const buttonBackground = paletteButton;
  static const buttonForeground = Color(0xFFFFFFFF);
  static const buttonDisabledBackground = Color(0xFFDEB6A2); // lighter brown
  static const buttonDisabledForeground = Color(0xFFCCCCCC);
  static const buttonBorder = paletteButton;
  static const buttonDisabledBorder = Color(0xFFDEB6A2);

  // Error Button Colors
  static const buttonErrorBackground = Color(0xFFD9534F);
  static const buttonErrorForeground = Color(0xFFFFFFFF);
  static const buttonErrorBorder = Color(0xFFB52B27);

  // Alert Message Colors
  static const alertSuccess = Color(0xFF5CB85C);
  static const alertFailure = Color(0xFFD9534F);

  // Status Colors
  static const statusError = Color(0xFFD9534F);
  static const statusErrorBackground = Color(0xFFF2DEDE);
  static const statusWarning = Color(0xFFF0AD4E);
  static const statusWarningBackground = Color(0xFFFCF8E3);
  static const statusSuccess = Color(0xFF5CB85C);
  static const statusSuccessBackground = Color(0xFFDFF0D8);
  static const statusInfo = Color(0xFF5BC0DE);
  static const statusInfoBackground = Color(0xFFD9EDF7);

  // Offline Mode Colors
  static const offlineIndicator = Color(0xFFF0AD4E);
  static const offlineBackground = Color(0xFFFFF3CD);
  static const offlineText = Color(0xFF856404);

  // Online Mode Colors
  static const onlineIndicator = Color(0xFF5CB85C);
  static const onlineBackground = Color(0xFFDFF0D8);
  static const onlineText = Color(0xFF3C763D);

  // RadioListTile Colors
  static const radioActive = paletteButton;
  static const radioInactive = Color(0xFFAAAAAA);

  // AppBar Colors
  static const appBarBackground = paletteButton;
  static const appBarForeground = Color(0xFFFFFFFF);

  // Upload Button Colors
  static const uploadButtonBackground = Color(0xFFF4EAD2);
  static const uploadButtonForeground = paletteButton;

  // List Item Colors
  static const listItemBackground = paletteBackground;
  static const listItemDivider = Color(0xFFEFEFEF);

  // Breadcrumb Navigation Colors
  static const breadcrumbText = paletteTextDark;
  static const breadcrumbCurrentText = paletteButton;
  static const breadcrumbSeparator = Color(0xFFAAAAAA);
}