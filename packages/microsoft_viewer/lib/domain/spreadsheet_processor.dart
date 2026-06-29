import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:microsoft_viewer/data/indexed_color.dart';
import 'package:microsoft_viewer/models/relationship.dart';
import 'package:microsoft_viewer/models/shared_string.dart';
import 'package:microsoft_viewer/models/spreadsheet.dart';
import 'package:microsoft_viewer/models/ss_color_schemes.dart';
import 'package:microsoft_viewer/models/ss_style.dart';
import 'package:xml/xml.dart' as xml;
import 'package:intl/intl.dart';

import '../models/ms_ss_table.dart';
import '../models/sheet.dart';
import '../data/alphabets.dart';

///Class for processing .xlsx files
class SpreadsheetProcessor {
  ///Function for processing spread sheet styles
  void processSpreadSheetStyles(ArchiveFile stylesFile, List<SSStyle> spreadSheetStyles) {
    final fileContent = utf8.decode(stylesFile.content);
    final ssStylesDoc = xml.XmlDocument.parse(fileContent);
    var styleRoot = ssStylesDoc.findAllElements("styleSheet");
    List<NumFormat> numFormats = [];
    List<SSFont> fonts = [];
    List<SSFill> fills = [];
    List<SSBorder> borders = [];
    if (styleRoot.isNotEmpty) {
      var chkNumFormats = styleRoot.first.findAllElements("numFmts");
      if (chkNumFormats.isNotEmpty) {
        var tempNumFormats = chkNumFormats.first.findAllElements("numFmt");
        if (tempNumFormats.isNotEmpty) {
          for (var numFmt in tempNumFormats) {
            var numId = numFmt.getAttribute("numFmtId");
            var fmtCode = numFmt.getAttribute("formatCode");
            if (numId != null && fmtCode != null) {
              numFormats.add(NumFormat(numId, fmtCode));
            }
          }
        }
      }
      var chkFonts = styleRoot.first.findAllElements("fonts");
      if (chkFonts.isNotEmpty) {
        var tempFonts = chkFonts.first.findAllElements("font");
        if (tempFonts.isNotEmpty) {
          for (var font in tempFonts) {
            int sz = 0;
            String clrTheme = "";
            String clrTint = "";
            String name = "";
            var chkSz = font.findAllElements("sz");
            if (chkSz.isNotEmpty) {
              var tempSz = chkSz.first.getAttribute("val");
              if (tempSz != null) {
                sz = int.parse(tempSz);
              }
            }
            var chkClrTheme = font.findAllElements("color");
            if (chkClrTheme.isNotEmpty) {
              var tempColor = chkClrTheme.first.getAttribute("theme");
              if (tempColor != null) {
                clrTheme = tempColor;
              }
              var tempClrTint = chkClrTheme.first.getAttribute("tint");
              if (tempClrTint != null) {
                clrTint = tempClrTint;
              }
            }
            var chkName = font.findAllElements("name");
            if (chkName.isNotEmpty) {
              var tempName = chkName.first.getAttribute("val");
              if (tempName != null) {
                name = tempName;
              }
            }
            fonts.add(SSFont(fonts.length.toString(), name, sz, clrTheme, clrTint));
          }
        }
      }
      var chkFills = styleRoot.first.findAllElements("fills");
      if (chkFills.isNotEmpty) {
        var tempFills = chkFills.first.findAllElements("fill");
        if (tempFills.isNotEmpty) {
          for (var fill in tempFills) {
            String type = "";
            String clrTheme = "";
            String clrTint = "";
            String clrIndex = "";
            var chkPattern = fill.findAllElements("patternFill");
            if (chkPattern.isNotEmpty) {
              var tempType = chkPattern.first.getAttribute("patternType");
              if (tempType != null) {
                type = tempType;
              }
              var chkFgClr = chkPattern.first.findAllElements("fgColor");
              if (chkFgClr.isNotEmpty) {
                var tempTheme = chkFgClr.first.getAttribute("theme");
                if (tempTheme != null) {
                  clrTheme = tempTheme;
                }
                var tempTint = chkFgClr.first.getAttribute("tint");
                if (tempTint != null) {
                  clrTint = tempTint;
                }
              }
              var chkBgClr = chkPattern.first.findAllElements("bgColor");
              if (chkBgClr.isNotEmpty) {
                var tempIndex = chkBgClr.first.getAttribute("indexed");
                if (tempIndex != null) {
                  clrIndex = tempIndex;
                }
              }
            }
            fills.add(SSFill(fills.length.toString(), type, clrTheme, clrTint, clrIndex));
          }
        }
      }
      var chkBorder = styleRoot.first.findAllElements("borders");
      if (chkBorder.isNotEmpty) {
        var allBorder = chkBorder.first.findAllElements("border");
        if (allBorder.isNotEmpty) {
          for (var border in allBorder) {
            String leftStyle = "";
            String leftClrTheme = "";
            String leftClrTint = "";
            String rightStyle = "";
            String rightClrTheme = "";
            String rightClrTint = "";
            String topStyle = "";
            String topClrTheme = "";
            String topClrTint = "";
            String bottomStyle = "";
            String bottomClrTheme = "";
            String bottomClrTint = "";
            var chkLeft = border.findAllElements("left");
            if (chkLeft.isNotEmpty) {
              var tempStyle = chkLeft.first.getAttribute("style");
              if (tempStyle != null) {
                leftStyle = tempStyle;
              }
              var chkClr = chkLeft.first.findAllElements("color");
              if (chkClr.isNotEmpty) {
                var tempTheme = chkClr.first.getAttribute("theme");
                if (tempTheme != null) {
                  leftClrTheme = tempTheme;
                }
                var tempTint = chkClr.first.getAttribute("tint");
                if (tempTint != null) {
                  leftClrTint = tempTint;
                }
              }
            }
            var chkRight = border.findAllElements("right");
            if (chkRight.isNotEmpty) {
              var tempStyle = chkRight.first.getAttribute("style");
              if (tempStyle != null) {
                rightStyle = tempStyle;
              }
              var chkClr = chkRight.first.findAllElements("color");
              if (chkClr.isNotEmpty) {
                var tempTheme = chkClr.first.getAttribute("theme");
                if (tempTheme != null) {
                  rightClrTheme = tempTheme;
                }
                var tempTint = chkClr.first.getAttribute("tint");
                if (tempTint != null) {
                  rightClrTint = tempTint;
                }
              }
            }
            var chkTop = border.findAllElements("top");
            if (chkTop.isNotEmpty) {
              var tempStyle = chkTop.first.getAttribute("style");
              if (tempStyle != null) {
                topStyle = tempStyle;
              }
              var chkClr = chkTop.first.findAllElements("color");
              if (chkClr.isNotEmpty) {
                var tempTheme = chkClr.first.getAttribute("theme");
                if (tempTheme != null) {
                  topClrTheme = tempTheme;
                }
                var tempTint = chkClr.first.getAttribute("tint");
                if (tempTint != null) {
                  topClrTint = tempTint;
                }
              }
            }
            var chkBottom = border.findAllElements("left");
            if (chkBottom.isNotEmpty) {
              var tempStyle = chkBottom.first.getAttribute("style");
              if (tempStyle != null) {
                bottomStyle = tempStyle;
              }
              var chkClr = chkBottom.first.findAllElements("color");
              if (chkClr.isNotEmpty) {
                var tempTheme = chkClr.first.getAttribute("theme");
                if (tempTheme != null) {
                  bottomClrTheme = tempTheme;
                }
                var tempTint = chkClr.first.getAttribute("tint");
                if (tempTint != null) {
                  bottomClrTint = tempTint;
                }
              }
            }

            borders.add(SSBorder(borders.length.toString(), leftStyle, leftClrTheme, leftClrTint, rightStyle, rightClrTheme, rightClrTint, topStyle,
                topClrTheme, topClrTint, bottomStyle, bottomClrTheme, bottomClrTint));
          }
        }
      }

      var chkCellXfs = styleRoot.first.findAllElements("cellXfs");
      if (chkCellXfs.isNotEmpty) {
        var xfs = chkCellXfs.first.findAllElements("xf");
        if (xfs.isNotEmpty) {
          for (var xf in xfs) {
            NumFormat numFormat = NumFormat("", "");
            SSFont ssFont = SSFont("", "", 0, "", "");
            SSFill ssFill = SSFill("", "", "", "", "");
            SSBorder border = SSBorder("", "", "", "", "", "", "", "", "", "", "", "", "");
            String alignmentVer = "", alignmentHorizontal = "", alignmentWrapText = "";
            var tempNumId = xf.getAttribute("numFmtId");
            if (tempNumId != null) {
              var tempNumFmt = numFormats.firstWhereOrNull((numFmt) {
                return numFmt.id == tempNumId;
              });
              if (tempNumFmt != null) {
                numFormat = tempNumFmt;
              }
            }
            var tempFontId = xf.getAttribute("fontId");
            if (tempFontId != null) {
              var tempFont = fonts.firstWhereOrNull((fnt) {
                return fnt.id == tempFontId;
              });
              if (tempFont != null) {
                ssFont = tempFont;
              }
            }
            var tempFillId = xf.getAttribute("fillId");
            if (tempFillId != null) {
              var tempFill = fills.firstWhereOrNull((fill) {
                return fill.id == tempFillId;
              });
              if (tempFill != null) {
                ssFill = tempFill;
              }
            }
            var tempBorderId = xf.getAttribute("borderId");
            if (tempBorderId != null) {
              var tempBorder = borders.firstWhereOrNull((brd) {
                return brd.id == tempBorderId;
              });
              if (tempBorder != null) {
                border = tempBorder;
              }
            }
            var chkAlignment = xf.findAllElements("alignment");
            if (chkAlignment.isNotEmpty) {
              var tempHorizontal = chkAlignment.first.getAttribute("horizontal");
              if (tempHorizontal != null) {
                alignmentHorizontal = tempHorizontal;
              }
              var tempVertical = chkAlignment.first.getAttribute("vertical");
              if (tempVertical != null) {
                alignmentVer = tempVertical;
              }
              var tempWrapText = chkAlignment.first.getAttribute("wrapText");
              if (tempWrapText != null) {
                alignmentWrapText = tempWrapText;
              }
            }
            spreadSheetStyles.add(SSStyle(
                spreadSheetStyles.length.toString(), numFormat, ssFont, ssFill, border, alignmentVer, alignmentHorizontal, alignmentWrapText));
          }
        }
      }
    }
  }
  ///Function for processing colors
  void processColorSchemes(ArchiveFile themeFile, List<SSColorSchemes> colorSchemes) {
    final fileContent = utf8.decode(themeFile.content);
    final themeDoc = xml.XmlDocument.parse(fileContent);
    var colorSchemeRoot = themeDoc.findAllElements("a:clrScheme");
    if (colorSchemeRoot.isNotEmpty) {
      for (var clrSch in colorSchemeRoot.first.childElements) {
        String name = "", sysClrName = "", sysClrLast = "", srgbClr = "";
        name = clrSch.name.local;
        var chkSysClr = clrSch.findAllElements("a:sysClr");
        if (chkSysClr.isNotEmpty) {
          var tempClrName = chkSysClr.first.getAttribute("val");
          if (tempClrName != null) {
            sysClrName = tempClrName;
          }
          var tempClrLast = chkSysClr.first.getAttribute("lastClr");
          if (tempClrLast != null) {
            sysClrLast = tempClrLast;
          }
        }
        var chksrgbClr = clrSch.findAllElements("a:srgbClr");
        if (chksrgbClr.isNotEmpty) {
          var tempSrgbClr = chksrgbClr.first.getAttribute("val");
          if (tempSrgbClr != null) {
            srgbClr = tempSrgbClr;
          }
        }
        colorSchemes.add(SSColorSchemes(colorSchemes.length.toString(), name, sysClrName, sysClrLast, srgbClr));
      }
    }
  }

  ///Function for getting spreadsheet details
  void getSpreadSheetDetails(ArchiveFile workbookFile, SpreadSheet spreadSheet) {
    final fileContent = utf8.decode(workbookFile.content);
    final workbookDoc = xml.XmlDocument.parse(fileContent);
    var sheetsRoot = workbookDoc.findAllElements("sheets");
    if (sheetsRoot.isNotEmpty) {
      var allSheets = sheetsRoot.first.findAllElements("sheet");
      if (allSheets.isNotEmpty) {
        for (var sheets in allSheets) {
          String sName = "";
          String sId = "";
          String rId = "";
          var tempName = sheets.getAttribute("name");
          if (tempName != null) {
            sName = tempName;
          }
          var tempId = sheets.getAttribute("sheetId");
          if (tempId != null) {
            sId = tempId;
          }
          var tempRId = sheets.getAttribute("r:id");
          if (tempRId != null) {
            rId = tempRId;
          }
          spreadSheet.sheets.add(Sheet(sName, sId, rId));
        }
      }
    }
  }

  ///Function for reading all details of the sheets
  Future<void> readAllSheets(SpreadSheet spreadSheet, List<Relationship> relationShips, Archive archive) async {
    for (int i = 0; i < spreadSheet.sheets.length; i++) {
      var sheetRelation = relationShips.firstWhereOrNull((rel) {
        return rel.id == spreadSheet.sheets[i].rId;
      });
      if (sheetRelation != null) {
        var sheetFile = archive.singleWhere((archiveFile) {
          return archiveFile.name.endsWith(sheetRelation.target);
        });
        if (sheetFile.isFile) {
          final fileContent = utf8.decode(sheetFile.content);
          final workbookDoc = xml.XmlDocument.parse(fileContent);
          List<Map<String, String>> mergeCells = [];
          List<String> mergedCells = [];
          var chkMergeCells = workbookDoc.findAllElements("mergeCells");
          if (chkMergeCells.isNotEmpty) {
            var tempMergeCells = chkMergeCells.first.findAllElements("mergeCell");
            if (tempMergeCells.isNotEmpty) {
              for (var mergeCell in tempMergeCells) {
                var ref = mergeCell.getAttribute("ref");
                if (ref != null) {
                  var fromTo = ref.split(":");
                  if (fromTo.length > 1) {
                    mergeCells.add({"from": fromTo[0], "to": fromTo[1]});
                    mergedCells.addAll(getAllMergedCells(fromTo[0], fromTo[1]));
                  }
                }
              }
            }
          }

          MsSsTable table = MsSsTable();
          var cols = workbookDoc.findAllElements("cols");
          if (cols.isNotEmpty) {
            var col = cols.first.findAllElements("col");
            if (col.isNotEmpty) {
              List<MsSsCol> colList = [];
              for (var tempCol in col) {
                int min = 0;
                int max = 0;
                double width = 0;
                int customWidth = 0;
                var tempMin = tempCol.getAttribute("min");
                if (tempMin != null) {
                  min = int.parse(tempMin);
                }
                var tempMax = tempCol.getAttribute("max");
                if (tempMax != null) {
                  max = int.parse(tempMax);
                }
                var tempWidth = tempCol.getAttribute("width");
                if (tempWidth != null) {
                  width = double.parse(tempWidth);
                }
                var tempCustWidth = tempCol.getAttribute("customWidth");
                if (tempCustWidth != null) {
                  customWidth = int.parse(tempCustWidth);
                }
                colList.add(MsSsCol(min, max, width, customWidth));
              }
              table.cols.addAll(colList);
            }
          }
          var sheetData = workbookDoc.findAllElements("sheetData");
          if (sheetData.isNotEmpty) {
            var rows = sheetData.first.findAllElements("row");
            List<MsSsRow> rowList = [];
            if (rows.isNotEmpty) {
              for (var row in rows) {
                var msSsRow = await compute(getRows, GetRowsParams(row, mergeCells, mergedCells));
                rowList.add(msSsRow);
              }
            }

            table.rows.addAll(rowList);
          }
          spreadSheet.sheets[i].tables.add(table);
        }
      }
    }
  }

  ///Function for getting cell number
  static int getCellColNo(String colNoStr, int rowId) {
    int colNo = 0;
    String colNoOnlyStr = colNoStr.replaceAll(rowId.toString(), "");

    for (int i = 0; i < colNoOnlyStr.length; i++) {
      if (i == colNoOnlyStr.length - 1) {
        colNo = colNo + Alphabet.alphabets.indexOf(colNoOnlyStr[i]) + 1;
      } else {
        colNo = colNo + ((Alphabet.alphabets.indexOf(colNoOnlyStr[i]) + 1) * 26);
      }
    }

    return colNo;
  }

  ///Function for displaying spreadsheets
  Future<List<Widget>> displaySpreadSheet(
      SpreadSheet spreadSheet, List<SharedString> sharedStrings, List<SSStyle> spreadSheetStyles, List<SSColorSchemes> colorSchemes) async {
    List<Widget> tempList = [];
    List<Widget> sheetWidgets = [];
    for (int i = 0; i < spreadSheet.sheets.length; i++) {
      sheetWidgets.add(Text(spreadSheet.sheets[i].name));
      String htmlString = await compute(getHtml, GetHtmlParams(spreadSheet.sheets[i], sharedStrings, spreadSheetStyles, colorSchemes));
      sheetWidgets.add(
        Container(color: Colors.white, width: 500, margin: const EdgeInsets.all(8), child: SingleChildScrollView(child: HtmlWidget(htmlString))),
      );
    }

    tempList.add(Container(
      color: Colors.grey,
      width: 500,
      margin: const EdgeInsets.all(8),
      child: Column(
        children: sheetWidgets,
      ),
    ));
    return tempList;
  }

  ///Function for getting cell values
  static String getCellValue(MsSsCell cell, List<SharedString> sharedStrings) {
    String value = "";
    switch (cell.type) {
      // sharedString
      case 's':
        var sharedString = sharedStrings.firstWhereOrNull((sharedString) {
          return sharedString.index == int.parse(cell.value);
        });
        if (sharedString != null) {
          value = sharedString.text;
        }
        break;
      // boolean
      case 'b':
        value = cell.value == '1' ? "true" : "false";
        break;
      // error
      case 'e':
      // formula
      case 'str':
        value = cell.value;
        break;
      // inline string
      case 'inlineStr':
        value = cell.value;
        break;
      // number
      case 'n':
      default:
        value = cell.value;
    }
    return value;
  }

  ///Function for getting the html values
  static String getHtml(GetHtmlParams getHtmlParams) {
    String htmlString = "<html><body>";
    for (int j = 0; j < getHtmlParams.sheet.tables.length; j++) {
      htmlString = "$htmlString<table >";

      for (int k = 0; k < getHtmlParams.sheet.tables[j].rows.length; k++) {
        String rowStyle = getRowStyle(getHtmlParams.sheet.tables[j].rows[k], getHtmlParams.spreadSheetStyles, getHtmlParams.colorSchemes);
        htmlString = "$htmlString<tr $rowStyle height=${getHtmlParams.sheet.tables[j].rows[k].height}px >";
        String colSpan = "0";
        bool rowStarted = false;
        for (int l = 0; l < getHtmlParams.sheet.tables[j].rows[k].cells.length; l++) {
          colSpan = getHtmlParams.sheet.tables[j].rows[k].cells[l].colSpan.toString();
          if (colSpan == "0") {}
          if (!rowStarted && getHtmlParams.sheet.tables[j].rows[k].cells[l].colNo != 1) {
            for (int blankI = 1; blankI < getHtmlParams.sheet.tables[j].rows[k].cells[l].colNo; blankI++) {
              htmlString = "$htmlString<td><p> </p> </td>";
            }
          }
          String cellStyle = getCellStyle(getHtmlParams.sheet.tables[j].rows[k].cells[l], getHtmlParams.spreadSheetStyles, getHtmlParams.colorSchemes,
              getHtmlParams.sheet.tables[j].cols);
          htmlString = "$htmlString<td $cellStyle colSpan=$colSpan>";
          htmlString = htmlString +
              formatCellValue(getCellValue(getHtmlParams.sheet.tables[j].rows[k].cells[l], getHtmlParams.sharedString),
                  getHtmlParams.sheet.tables[j].rows[k].cells[l], getHtmlParams.spreadSheetStyles);
          htmlString = "$htmlString</td>";
          rowStarted = true;
        }
        if (getHtmlParams.sheet.tables[j].rows[k].cells.isEmpty) {
          htmlString = "$htmlString<td><p> </p> </td>";
        }

        htmlString = "$htmlString</tr>";
      }

      htmlString = "$htmlString</table>";
    }

    htmlString = '$htmlString</body></html>';
    return htmlString;
  }
  ///Function for getting cell style
  static String getCellStyle(MsSsCell cell, List<SSStyle> spreadSheetStyles, List<SSColorSchemes> colorSchemes, List<MsSsCol> colDetails) {
    String styles = "";
    String stylesInner = "";
    if (cell.style != null) {
      var cellStyle = spreadSheetStyles.firstWhereOrNull((style) {
        return style.id == cell.style;
      });
      if (cellStyle != null) {
        if (cellStyle.alignmentHorizontal.isNotEmpty) {
          styles = "$styles align:'${cellStyle.alignmentHorizontal}';";
        }
        if (cellStyle.alignmentVer.isNotEmpty) {
          styles = "$styles vertical-align:'${cellStyle.alignmentVer}';";
        }
        if (cellStyle.alignmentWrapText.isNotEmpty && cellStyle.alignmentWrapText == "1") {
          styles = "$styles word-wrap: break-word;";
        }
        if (cellStyle.ssFont.id.isNotEmpty) {
          if (cellStyle.ssFont.size != 0) {
            stylesInner = "$stylesInner font-size: ${cellStyle.ssFont.size}px;";
          }
          if (cellStyle.ssFont.name.isNotEmpty) {
            stylesInner = "$stylesInner font-family: '${cellStyle.ssFont.name}';";
          }
        }
        if (cellStyle.ssFill.id.isNotEmpty) {
          if (cellStyle.ssFill.bgClrIndex.isNotEmpty) {
            String bgColor = "#a5c6fa";
            if (int.parse(cellStyle.ssFill.bgClrIndex) < 64) {
              bgColor = IndexedColor().colors[int.parse(cellStyle.ssFill.bgClrIndex)];
            } else if (cellStyle.ssFill.bgClrIndex == "64") {
              var clrScheme = colorSchemes.firstWhereOrNull((clrSch) {
                return clrSch.id == cellStyle.ssFill.fgClrTheme;
              });

              if (clrScheme != null) {
                if (clrScheme.sysClrLast.isNotEmpty) {
                  bgColor = "#${clrScheme.sysClrLast}";
                } else if (clrScheme.srgbClr.isNotEmpty) {
                  bgColor = "#${clrScheme.srgbClr}";
                }
              }
            }
            stylesInner = "$stylesInner background-color: $bgColor;";
          }
        }
        if (cellStyle.border.id.isNotEmpty) {
          if (cellStyle.border.bottomStyle.isNotEmpty) {
            stylesInner = "$stylesInner border-bottom: 1px solid black;";
          }
          if (cellStyle.border.topStyle.isNotEmpty) {
            stylesInner = "$stylesInner border-top: 1px solid black;";
          }
          if (cellStyle.border.leftStyle.isNotEmpty) {
            stylesInner = "$stylesInner border-left: 1px solid black;";
          }
          if (cellStyle.border.rightStyle.isNotEmpty) {
            stylesInner = "$stylesInner border-right: 1px solid black;";
          }
        }
      }
    }
    if (colDetails.isNotEmpty) {
      var colDet = colDetails.firstWhereOrNull((col) {
        return col.min <= cell.colNo && col.max >= cell.colNo;
      });
      if (colDet != null) {
        stylesInner = "$stylesInner width:${colDet.width.toInt() * 16}px;";
      }
    }
    if (stylesInner.isNotEmpty) {
      stylesInner = "$stylesInner border-collapse: collapse;";
      styles = "$styles style=\"$stylesInner\"";
    }
    return styles;
  }
  ///Function for getting row style
  static String getRowStyle(MsSsRow row, List<SSStyle> spreadSheetStyles, List<SSColorSchemes> colorSchemes) {
    String styles = "";
    String stylesInner = "";
    if (row.style != null) {
      var rowStyle = spreadSheetStyles.firstWhereOrNull((style) {
        return style.id == row.style;
      });
      if (rowStyle != null) {
        if (rowStyle.alignmentHorizontal.isNotEmpty) {
          styles = "$styles align:'${rowStyle.alignmentHorizontal}';";
        }
        if (rowStyle.alignmentVer.isNotEmpty) {
          styles = "$styles vertical-align:'${rowStyle.alignmentVer}';";
        }
        if (rowStyle.alignmentWrapText.isNotEmpty && rowStyle.alignmentWrapText == "1") {
          styles = "$styles word-wrap: break-word;";
        }
        if (rowStyle.ssFont.id.isNotEmpty) {
          if (rowStyle.ssFont.size != 0) {
            stylesInner = "$stylesInner font-size: ${rowStyle.ssFont.size}px;";
          }
          if (rowStyle.ssFont.name.isNotEmpty) {
            stylesInner = "$stylesInner font-family: '${rowStyle.ssFont.name}';";
          }
        }
        if (rowStyle.ssFill.id.isNotEmpty) {
          if (rowStyle.ssFill.bgClrIndex.isNotEmpty) {
            String bgColor = "#a5c6fa";
            if (int.parse(rowStyle.ssFill.bgClrIndex) < 64) {
              bgColor = IndexedColor().colors[int.parse(rowStyle.ssFill.bgClrIndex)];
            } else if (rowStyle.ssFill.bgClrIndex == "64") {
              var clrScheme = colorSchemes.firstWhereOrNull((clrSch) {
                return clrSch.id == rowStyle.ssFill.fgClrTheme;
              });

              if (clrScheme != null) {
                if (clrScheme.sysClrLast.isNotEmpty) {
                  bgColor = "#${clrScheme.sysClrLast}";
                } else if (clrScheme.srgbClr.isNotEmpty) {
                  bgColor = "#${clrScheme.srgbClr}";
                }
              }
            }
            stylesInner = "$stylesInner background-color: $bgColor;";
          }
        }
        if (rowStyle.border.id.isNotEmpty) {
          if (rowStyle.border.bottomStyle.isNotEmpty) {
            stylesInner = "$stylesInner border-bottom: 1px solid black;";
          }
          if (rowStyle.border.topStyle.isNotEmpty) {
            stylesInner = "$stylesInner border-top: 1px solid black;";
          }
          if (rowStyle.border.leftStyle.isNotEmpty) {
            stylesInner = "$stylesInner border-left: 1px solid black;";
          }
          if (rowStyle.border.rightStyle.isNotEmpty) {
            stylesInner = "$stylesInner border-right: 1px solid black;";
          }
        }
      }
    }

    if (stylesInner.isNotEmpty) {
      stylesInner = "$stylesInner border-collapse: collapse;";
      styles = "$styles style=\"$stylesInner\"";
    }
    return styles;
  }
  ///Function for formating cell value
  static String formatCellValue(String value, MsSsCell cell, List<SSStyle> spreadSheetStyles) {
    String retValue = value;
    if (cell.style != null) {
      var cellStyle = spreadSheetStyles.firstWhereOrNull((style) {
        return style.id == cell.style;
      });
      if (cellStyle != null) {
        if (cellStyle.numFormat.id.isNotEmpty) {
          switch (cellStyle.numFormat.format) {
            case 'd':
              if (int.tryParse(value) != null) {
                DateTime baseDate = DateTime(1900, 1, 1);
                DateTime dartDate;
                if (int.parse(value) <= 60) {
                  // up to Feb 29 1900
                  dartDate = baseDate.add(Duration(days: int.parse(value) - 2)); // Subtract 2 (account for Jan 1, 1900 being 2)
                } else {
                  dartDate = baseDate.add(Duration(days: int.parse(value) - 2)); // subtract 2
                }
                retValue = DateFormat('d').format(dartDate);
              }

            case 'dd': // day of the month as a zero-padded decimal number
              if (int.tryParse(value) != null) {
                DateTime baseDate = DateTime(1900, 1, 1);
                DateTime dartDate;
                if (int.parse(value) <= 60) {
                  // up to Feb 29 1900
                  dartDate = baseDate.add(Duration(days: int.parse(value) - 2)); // Subtract 2 (account for Jan 1, 1900 being 2)
                } else {
                  dartDate = baseDate.add(Duration(days: int.parse(value) - 2)); // subtract 2
                }
                retValue = DateFormat('dd').format(dartDate);
              }

            case 'ddd': // abbreviated weekday as text
              if (int.tryParse(value) != null) {
                DateTime baseDate = DateTime(1900, 1, 1);
                DateTime dartDate;
                if (int.parse(value) <= 60) {
                  // up to Feb 29 1900
                  dartDate = baseDate.add(Duration(days: int.parse(value) - 2)); // Subtract 2 (account for Jan 1, 1900 being 2)
                } else {
                  dartDate = baseDate.add(Duration(days: int.parse(value) - 2)); // subtract 2
                }
                retValue = DateFormat('EEE').format(dartDate);
              }

            case 'MMMM': // month as text
              if (int.tryParse(value) != null) {
                DateTime baseDate = DateTime(1900, 1, 1);
                DateTime dartDate;
                if (int.parse(value) <= 60) {
                  // up to Feb 29 1900
                  dartDate = baseDate.add(Duration(days: int.parse(value) - 2)); // Subtract 2 (account for Jan 1, 1900 being 2)
                } else {
                  dartDate = baseDate.add(Duration(days: int.parse(value) - 2)); // subtract 2
                }
                retValue = DateFormat('MMMM').format(dartDate);
              }

            case 'dd/MMM/YYYY': // day/month/year
              if (int.tryParse(value) != null) {
                DateTime baseDate = DateTime(1900, 1, 1);
                DateTime dartDate;
                if (int.parse(value) <= 60) {
                  // up to Feb 29 1900
                  dartDate = baseDate.add(Duration(days: int.parse(value) - 2)); // Subtract 2 (account for Jan 1, 1900 being 2)
                } else {
                  dartDate = baseDate.add(Duration(days: int.parse(value) - 2)); // subtract 2
                }
                retValue = DateFormat('dd/MMM/yyyy').format(dartDate);
              }

            default:
              retValue = value; // or throw an exception
          }
        }
      }
    }
    return retValue;
  }
  ///Function for getting col span
  static int getColSpan(Map<String, String> mergeCell) {
    String from = mergeCell["from"]?.replaceAll(RegExp(r"\d"), "") ?? "";
    String to = mergeCell["to"]?.replaceAll(RegExp(r"\d"), "") ?? "";
    int fromIndex = 0;
    int toIndex = 0;
    for (int i = 0; i < from.length; i++) {
      if (i == from.length - 1) {
        fromIndex = fromIndex + Alphabet.alphabets.indexOf(from[i]);
      } else {
        fromIndex = fromIndex + ((Alphabet.alphabets.indexOf(from[i]) + 1) * 26);
      }
    }
    for (int i = 0; i < to.length; i++) {
      if (i == to.length - 1) {
        toIndex = toIndex + Alphabet.alphabets.indexOf(to[i]) + 1;
      } else {
        toIndex = toIndex + ((Alphabet.alphabets.indexOf(to[i]) + 1) * 26);
      }
    }

    return toIndex - fromIndex;
  }
  ///Function for getting all merged cells
  List<String> getAllMergedCells(String fromCol, String toCol) {
    List<String> mergedCells = [];
    String from = fromCol.replaceAll(RegExp(r"\d"), "");
    String to = toCol.replaceAll(RegExp(r"\d"), "");
    String latestCol = "";
    String rowNum = fromCol.replaceAll(from, "");
    int cycleCount = 0;

    String fromLastChar = from.substring(from.length - 1);
    String fromPrevChar = "";
    if (from.length > 1) {
      fromPrevChar = from.substring(0, from.length - 1);
    }
    int indexOfLastChar = Alphabet.alphabets.indexOf(fromLastChar);
    while (latestCol != to) {
      for (int i = indexOfLastChar + 1; i < Alphabet.alphabets.length; i++) {
        latestCol = fromPrevChar + Alphabet.alphabets[i];
        mergedCells.add(latestCol + rowNum);
        if (latestCol == to) {
          break;
        }
      }
      if (latestCol != to) {
        if (fromPrevChar.isNotEmpty) {
          if (fromPrevChar.substring(fromPrevChar.length - 1) != Alphabet.alphabets.last) {
            fromPrevChar = fromPrevChar.substring(0, fromPrevChar.length - 1) +
                Alphabet.alphabets.elementAt(Alphabet.alphabets.indexOf(fromPrevChar.substring(fromPrevChar.length - 1)) + 1);
          }
        } else {
          fromPrevChar = Alphabet.alphabets.first;
          indexOfLastChar = -1;
        }
      }
      cycleCount++;
      if (cycleCount == 10) {
        break;
      }
    }
    return mergedCells;
  }
  ///Function for getting rows
  static MsSsRow getRows(GetRowsParams rowParams) {
    int rowId = 0;
    String spans = "";
    double height = 0;
    var tempRowId = rowParams.row.getAttribute("r");
    if (tempRowId != null) {
      rowId = int.parse(tempRowId);
    }
    var tempSpans = rowParams.row.getAttribute("spans");
    if (tempSpans != null) {
      spans = tempSpans;
    }
    var tempHeight = rowParams.row.getAttribute("ht");
    if (tempHeight != null) {
      height = double.parse(tempHeight);
    }
    MsSsRow msSsRow = MsSsRow(rowId, spans, height);
    var styleParam = rowParams.row.getAttribute("s");
    if (styleParam != null) {
      msSsRow.style = styleParam;
    }
    var cells = rowParams.row.findAllElements("c");
    if (cells.isNotEmpty) {
      List<MsSsCell> msCells = [];
      for (var cell in cells) {
        int colNo = 0;
        String type = "";
        String value = "";
        int colSpan = 0;
        var tempColNo = cell.getAttribute("r");
        if (tempColNo != null) {
          if (rowParams.mergedCells.contains(tempColNo)) {
            continue;
          }
          colNo = getCellColNo(tempColNo, rowId);
          if (rowParams.mergeCells.isNotEmpty) {
            var mergeCell = rowParams.mergeCells.firstWhereOrNull((mCell) {
              return mCell["from"] == tempColNo;
            });
            if (mergeCell != null) {
              colSpan = getColSpan(mergeCell);
            }
          }
        }
        var tempType = cell.getAttribute("t");
        if (tempType != null) {
          type = tempType;
        }
        var tempValue = cell.findAllElements("v");
        if (tempValue.isNotEmpty) {
          value = tempValue.first.innerText;
        }

        MsSsCell msSsCell = MsSsCell(colNo, type, value, colSpan);
        var tempStyle = cell.getAttribute("s");
        if (tempStyle != null) {
          msSsCell.style = tempStyle;
        }
        msCells.add(msSsCell);
      }
      msSsRow.cells.addAll(msCells);
    }
    return msSsRow;
  }
}

///class for passing parameters
class GetHtmlParams {
  ///Sheet object
  Sheet sheet;
  ///List of strings
  List<SharedString> sharedString;
  ///List of styles
  List<SSStyle> spreadSheetStyles;
  ///list of color schemes
  List<SSColorSchemes> colorSchemes;
  ///Constructor
  GetHtmlParams(this.sheet, this.sharedString, this.spreadSheetStyles, this.colorSchemes);
}
///To pass the row parameters
class GetRowsParams {
  ///Xml element
  xml.XmlElement row;
  ///Merged cell details
  List<Map<String, String>> mergeCells;
  ///List of merged cells
  List<String> mergedCells;
  ///Constructor
  GetRowsParams(this.row, this.mergeCells, this.mergedCells);
}
