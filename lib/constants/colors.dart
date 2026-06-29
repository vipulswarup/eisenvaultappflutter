import 'package:flutter/material.dart';

/// EisenVault ONE web-aligned color theme.
/// Base palette values are defined once; semantic names alias them for UI usage.
class EVColors {
  // Brand palette (from EisenVault ONE web)
  static const paletteBrand = Color(0xFFE74C3C); // logo "ONE", brand accent
  static const palettePrimary = Color(0xFF17A2B8); // primary action buttons (teal)
  static const palettePrimaryDark = Color(0xFF138496);
  static const paletteLink = Color(0xFF00A3C4); // breadcrumbs, links, usernames
  static const paletteBackground = Color(0xFFF4F7F9); // main content area
  static const paletteSurface = Color(0xFFFFFFFF); // cards, header, table rows
  static const paletteSidebar = Color(0xFF2D2F36); // navigation sidebar
  static const paletteTextDark = Color(0xFF212529);

  // Legacy aliases (semantic names used across the app)
  static const paletteButton = palettePrimary;
  static const paletteAccent = palettePrimary;

  // Neutrals
  static const neutralWhite = Color(0xFFFFFFFF);
  static const neutralBlack = Color(0xFF000000);
  static const neutralGreyDivider = Color(0xFFE9ECEF);
  static const neutralGreyShimmer = Color(0xFFE9ECEF);
  static const neutralGreyScroll = Color(0xFFF0F0F0);
  static const neutralGreyHeader = Color(0xFFF8F9FA);
  static const neutralGrey400 = Color(0xFFADB5BD);
  static const neutralGrey500 = Color(0xFF9E9E9E);
  static const neutralGrey600 = Color(0xFF6C757D);
  static const neutralGreyMid = Color(0xFF6C757D);
  static const neutralGreyDisabled = Color(0xFFCED4DA);
  static const sidebarTextInactive = Color(0xFFA0AEC0);
  static const shadowBlack = Color(0x0D000000);
  static const overlayBlack = Color(0x4D000000); // 30% black

  // Status / feedback (Bootstrap-aligned, matching web dashboard)
  static const statusRed = Color(0xFFE74C3C);
  static const statusRedDark = Color(0xFFC0392B);
  static const statusRedBackground = Color(0xFFF8D7DA);
  static const statusGreen = Color(0xFF28A745);
  static const statusGreenDark = Color(0xFF1E7E34);
  static const statusGreenBackground = Color(0xFFD4EDDA);
  static const statusOrange = Color(0xFFF39C12);
  static const statusOrangeBackground = Color(0xFFFFF3CD);
  static const statusOrangeLight = Color(0xFFFFF3CD);
  static const statusOrangeDark = Color(0xFF856404);
  static const statusBlue = Color(0xFF3498DB);
  static const statusBlueDark = Color(0xFF2980B9);
  static const statusBlueBackground = Color(0xFFD1ECF1);
  static const statusBlueHighlight = Color(0x3317A2B8); // 20% palettePrimary

  // Accent / icon tints (dashboard metric cards)
  static const accentAmber = Color(0xFFF39C12);
  static const accentAmberDark = Color(0xFFE67E22);
  static const accentTeal = Color(0xFF1ABC9C);
  static const accentBlue = Color(0xFF3498DB);
  static const accentPurple = Color(0xFF9B59B6);
  static const tintBlue = Color(0xFFE3F2FD);
  static const tintAmber = Color(0xFFFFF8E1);
  static const tintTeal = Color(0xFFE8F8F5);
  static const tintGreen = Color(0xFFD4EDDA);
  static const tintPurple = Color(0xFFF3E5F5);
  static const tintPrimaryDisabled = Color(0xFFA0CFD8);

  // Form
  static const formBorder = Color(0xFFCED4DA);

  // General purpose (semantic aliases)
  static const errorRed = statusRed;
  static const warningOrange = statusOrange;
  static const successGreen = statusGreen;
  static const infoBlue = statusBlue;

  // Card & list backgrounds
  static const cardBackground = paletteSurface;
  static const cardShadow = shadowBlack;

  // Icon colors
  static const iconGrey = neutralGrey400;
  static const iconGreyLight = neutralGrey500;
  static const iconAmber = accentAmber;
  static const iconTeal = accentTeal;

  // Text colors
  static const textDefault = paletteTextDark;
  static const textSecondary = neutralGrey600;
  static const textGrey = neutralGrey600;
  static const textLightGrey = neutralGrey500;

  // Search highlight
  static const searchHighlightBackground = statusBlueHighlight;
  static const searchHighlightText = palettePrimaryDark;

  // Sort option
  static const sortOptionBackground = paletteSurface;
  static const sortOptionShadow = shadowBlack;
  static const sortOptionText = paletteTextDark;
  static const sortOptionIcon = palettePrimary;

  // Browse navigation
  static const browseNavBackground = paletteBackground;
  static const browseNavChevron = neutralGrey400;
  static const browseNavText = paletteLink;
  static const browseNavCurrentText = paletteTextDark;
  static const browseNavSeparator = neutralGreyMid;

  // Search result item icons
  static const departmentIconBackground = tintBlue;
  static const departmentIconForeground = accentBlue;
  static const folderIconBackground = tintAmber;
  static const folderIconForeground = accentAmberDark;
  static const documentIconBackground = tintTeal;
  static const documentIconForeground = accentTeal;

  // Screen & background
  static const screenBackground = paletteBackground;

  // TextField
  static const textFieldPrefixIcon = palettePrimary;
  static const textFieldFill = paletteSurface;
  static const textFieldBorder = formBorder;
  static const textFieldErrorBorder = statusRed;
  static const textFieldLabel = paletteTextDark;
  static const textFieldHint = neutralGrey500;

  // Button
  static const buttonBackground = palettePrimary;
  static const buttonForeground = neutralWhite;
  static const buttonDisabledBackground = tintPrimaryDisabled;
  static const buttonDisabledForeground = neutralGreyDisabled;
  static const buttonBorder = palettePrimary;
  static const buttonDisabledBorder = tintPrimaryDisabled;

  // Error button
  static const buttonErrorBackground = statusRed;
  static const buttonErrorForeground = neutralWhite;
  static const buttonErrorBorder = statusRedDark;

  // Alert messages
  static const alertSuccess = statusGreen;
  static const alertFailure = statusRed;

  // Status (semantic aliases)
  static const statusError = statusRed;
  static const statusErrorBackground = statusRedBackground;
  static const statusWarning = statusOrange;
  static const statusWarningBackground = statusOrangeBackground;
  static const statusSuccess = statusGreen;
  static const statusSuccessBackground = statusGreenBackground;
  static const statusInfo = statusBlue;
  static const statusInfoBackground = statusBlueBackground;

  // Offline mode
  static const offlineIndicator = statusOrange;
  static const offlineBackground = statusOrangeLight;
  static const offlineText = statusOrangeDark;

  // Online mode
  static const onlineIndicator = statusGreen;
  static const onlineBackground = statusGreenBackground;
  static const onlineText = statusGreenDark;

  // RadioListTile
  static const radioActive = palettePrimary;
  static const radioInactive = neutralGreyMid;

  // AppBar (white header, matching web top bar)
  static const appBarBackground = paletteSurface;
  static const appBarForeground = paletteTextDark;
  static const appBarForegroundMuted = neutralGrey600;
  static const appBarBorder = neutralGreyDivider;

  // Sidebar / drawer (dark navigation, matching web sidebar)
  static const sidebarBackground = paletteSidebar;
  static const sidebarForeground = neutralWhite;
  static const sidebarForegroundMuted = sidebarTextInactive;

  // Colored section headers (dialogs, panels)
  static const dialogHeaderBackground = palettePrimary;
  static const dialogHeaderForeground = neutralWhite;

  // Upload button
  static const uploadButtonBackground = paletteSurface;
  static const uploadButtonForeground = palettePrimary;

  // List item
  static const listItemBackground = paletteSurface;
  static const listItemDivider = neutralGreyDivider;

  // Breadcrumb navigation
  static const breadcrumbText = paletteTextDark;
  static const breadcrumbCurrentText = paletteLink;
  static const breadcrumbSeparator = neutralGreyMid;

  // Sharing screen
  static const sharingContainerBackground = paletteSurface;
  static const sharingHeaderBackground = neutralGreyHeader;
  static const sharingFolderItemBackground = paletteSurface;
  static const sharingFolderItemSelectedBackground = tintGreen;
  static const sharingFolderItemSelectedBorder = accentTeal;
  static const sharingScrollIndicatorBackground = neutralGreyScroll;

  // Progress / overlay
  static const progressTrack = Color(0x336C757D); // 20% neutralGrey600
  static const shimmerBackground = neutralGreyShimmer;
}
