import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:microsoft_viewer/models/font_details.dart';

import '../models/styles.dart';
import 'package:xml/xml.dart' as xml;

///Processor for handling tasks for all types of documents
class CommonProcessor {
  ///Function for processing styles file
  Future<void> processStylesFile(ArchiveFile stylesFile, List<Styles> stylesList, Map<String, String> defaultValues) async {
    stylesList.clear();
    final fileContent = utf8.decode(stylesFile.content);
    final stylesDoc = xml.XmlDocument.parse(fileContent);
    var stylesRoot = stylesDoc.findAllElements("w:styles");
    if (stylesRoot.isNotEmpty) {
      var allStyles = stylesRoot.first.findAllElements("w:style");
      if (allStyles.isNotEmpty) {
        for (var style in allStyles) {
          Styles tempStyles = await compute(getStyles, GetStylesParam(style));
          stylesList.add(tempStyles);
        }
      }
    }
    var rDefault = stylesDoc.findAllElements("w:rPrDefault");
    if (rDefault.isNotEmpty) {
      var fSize = rDefault.first.findAllElements("w:sz");
      if (fSize.isNotEmpty) {
        var tempSize = fSize.first.getAttribute("w:val");
        if (tempSize != null) {
          defaultValues["fontSize"] = tempSize;
        }
      }
    }
    var pDefault = stylesDoc.findAllElements("w:pPrDefault");
    if (pDefault.isNotEmpty) {
      var spacing = pDefault.first.findAllElements("w:spacing");
      if (spacing.isNotEmpty) {
        var tempSpacing = spacing.first.getAttribute("w:line");
        if (tempSpacing != null) {
          defaultValues["lineSpacing"] = tempSpacing;
        }
      }
    }
  }

  ///Function for processing custom fonts
  void processFonts(List<FontDetails> fontDetails, ArchiveFile fontTableFile, ArchiveFile fontTableRelsFile) {
    final fileContent = utf8.decode(fontTableFile.content);
    final fontTableDoc = xml.XmlDocument.parse(fileContent);
    final fonts = fontTableDoc.findAllElements("w:font");
    if (fonts.isNotEmpty) {
      Map<String, Map<String, String>> tempFontMap = {};
      for (var font in fonts) {
        Map<String, String> tempFontDetails = {};
        var fontName = font.getAttribute("w:name");
        if (fontName != null) {
          var embedReg = font.findAllElements("w:embedRegular");
          if (embedReg.isNotEmpty) {
            var embedRegRid = embedReg.first.getAttribute("r:id");
            if (embedRegRid != null) {
              tempFontDetails["embedReg"] = embedRegRid;
            }
            var fontKey = embedReg.first.getAttribute("w:fontKey");
            if (fontKey != null) {
              tempFontDetails["fontKey"] = fontKey;
            }
          }

          if (tempFontDetails.isNotEmpty) {
            tempFontMap[fontName] = tempFontDetails;
          }
        }
      }

      final relFileContent = utf8.decode(fontTableRelsFile.content);
      final fontTableRelDoc = xml.XmlDocument.parse(relFileContent);
      final relationsships = fontTableRelDoc.findAllElements("Relationship");
      if (relationsships.isNotEmpty) {
        Map<String, String> relDetails = {};
        for (var rel in relationsships) {
          var relId = rel.getAttribute("Id");
          if (relId != null) {
            var target = rel.getAttribute("Target");
            if (target != null) {
              relDetails[relId] = target;
            }
          }
        }
        tempFontMap.forEach((key, value) {
          String fileName = "";
          String fontKey = "";
          value.forEach((key2, value2) {
            if (key2 == "embedReg") {
              var tempFileName = relDetails[value2];
              if (tempFileName != null) {
                fileName = tempFileName;
              }
            } else {
              fontKey = value2;
            }
          });
          fontDetails.add(FontDetails(key, fileName, fontKey));
        });
      }
    }
  }
  ///Get details from styles file
  static Styles getStyles(GetStylesParam stylesParam) {
    String name = "";
    String type = "";
    String styleId = "";
    var tempType = stylesParam.style.getAttribute("w:type");
    if (tempType != null) {
      type = tempType;
    }
    var tempStyleId = stylesParam.style.getAttribute("w:styleId");
    if (tempStyleId != null) {
      styleId = tempStyleId;
    }
    var checkName = stylesParam.style.findAllElements("w:name");
    if (checkName.isNotEmpty) {
      var tempName = checkName.first.getAttribute("w:val");
      if (tempName != null) {
        name = tempName;
      }
    }

    Styles tempStyles = Styles(name, type, styleId);
    var checkParaProp = stylesParam.style.findAllElements("w:pPr");
    if (checkParaProp.isNotEmpty) {
      var indProp = checkParaProp.first.findAllElements("w:ind");
      if (indProp.isNotEmpty) {
        var tempFirstLine = indProp.first.getAttribute("w:firstLine");
        if (tempFirstLine != null) {
          tempStyles.firstLineInd = int.parse(tempFirstLine);
        }
        var tempLeftInd = indProp.first.getAttribute("w:left");
        if (tempLeftInd != null) {
          tempStyles.leftInd = int.parse(tempLeftInd);
        }
      }
      var chkKeepNext = checkParaProp.first.findAllElements("w:keepNext");
      if (chkKeepNext.isNotEmpty) {
        tempStyles.keepNext = true;
      }
      var chkKeepLines = checkParaProp.first.findAllElements("w:keepLines");
      if (chkKeepLines.isNotEmpty) {
        tempStyles.keepLines = true;
      }
      var chkPageBreakBefore = checkParaProp.first.findAllElements("w:pageBreakBefore");
      if (chkPageBreakBefore.isNotEmpty) {
        tempStyles.pageBreakBefore = true;
      }
      var chkSpacing = checkParaProp.first.findAllElements("w:spacing");
      if (chkSpacing.isNotEmpty) {
        var tempBefore = chkSpacing.first.getAttribute("w:before");
        if (tempBefore != null) {
          tempStyles.spacingBefore = int.parse(tempBefore);
        }
        var tempAfter = chkSpacing.first.getAttribute("w:after");
        if (tempAfter != null) {
          tempStyles.spacingAfter = int.parse(tempAfter);
        }
      }
      var chkOutlineLvl = checkParaProp.first.findAllElements("w:outlineLvl");
      if (chkOutlineLvl.isNotEmpty) {
        var tempOutlineLvl = chkOutlineLvl.first.getAttribute("w:val");
        if (tempOutlineLvl != null) {
          tempStyles.outlineLvl = int.parse(tempOutlineLvl);
        }
      }
      var chkJc = checkParaProp.first.findAllElements("w:jc");
      if (chkJc.isNotEmpty) {
        var tempJc = chkJc.first.getAttribute("w:val");
        if (tempJc != null) {
          tempStyles.jc = tempJc;
        }
      }
      var chkPBrd = checkParaProp.first.findAllElements("w:pBdr");
      if (chkPBrd.isNotEmpty) {
        Map<String, String> tempParaProp = {};
        var topPro = chkPBrd.first.findAllElements("w:top");
        if (topPro.isNotEmpty) {
          var topVal = topPro.first.getAttribute("w:val");
          if (topVal != null) {
            tempParaProp["top-va"] = topVal;
          }
          var topSz = topPro.first.getAttribute("w:sz");
          if (topSz != null) {
            tempParaProp["top-sz"] = topSz;
          }
          var topColor = topPro.first.getAttribute("w:color");
          if (topColor != null) {
            tempParaProp["top-color"] = topColor;
          }
        }
        var leftPro = chkPBrd.first.findAllElements("w:left");
        if (leftPro.isNotEmpty) {
          var leftVal = leftPro.first.getAttribute("w:val");
          if (leftVal != null) {
            tempParaProp["left-va"] = leftVal;
          }
          var leftSz = leftPro.first.getAttribute("w:sz");
          if (leftSz != null) {
            tempParaProp["left-sz"] = leftSz;
          }
          var leftColor = leftPro.first.getAttribute("w:color");
          if (leftColor != null) {
            tempParaProp["left-color"] = leftColor;
          }
        }
        var bottomPro = chkPBrd.first.findAllElements("w:bottom");
        if (bottomPro.isNotEmpty) {
          var bottomVal = bottomPro.first.getAttribute("w:val");
          if (bottomVal != null) {
            tempParaProp["bottom-va"] = bottomVal;
          }
          var bottomSz = bottomPro.first.getAttribute("w:sz");
          if (bottomSz != null) {
            tempParaProp["bottom-sz"] = bottomSz;
          }
          var bottomColor = bottomPro.first.getAttribute("w:color");
          if (bottomColor != null) {
            tempParaProp["bottom-color"] = bottomColor;
          }
        }
        var rightPro = chkPBrd.first.findAllElements("w:right");
        if (rightPro.isNotEmpty) {
          var rightVal = rightPro.first.getAttribute("w:val");
          if (rightVal != null) {
            tempParaProp["right-va"] = rightVal;
          }
          var rightSz = rightPro.first.getAttribute("w:sz");
          if (rightSz != null) {
            tempParaProp["right-sz"] = rightSz;
          }
          var rightColor = rightPro.first.getAttribute("w:color");
          if (rightColor != null) {
            tempParaProp["right-color"] = rightColor;
          }
        }
        tempStyles.paraGraphBorder = tempParaProp;
      }
    }
    var runProperty = stylesParam.style.findAllElements("w:rPr");
    if (runProperty.isNotEmpty) {
      var boldProperty = runProperty.first.findAllElements("w:b");
      if (boldProperty.isNotEmpty) {
        tempStyles.formats.add("bold");
      }
      var italicProperty = runProperty.first.findAllElements("w:i");
      if (italicProperty.isNotEmpty) {
        tempStyles.formats.add("italic");
      }
      var underlineProperty = runProperty.first.findAllElements("w:u");
      if (underlineProperty.isNotEmpty) {
        if (underlineProperty.first.getAttribute("w:val") == "single") {
          tempStyles.formats.add("single-underline");
        } else if (underlineProperty.first.getAttribute("w:val") == "double") {
          tempStyles.formats.add("double-underline");
        }
      }
      var strikeProperty = runProperty.first.findAllElements("w:strike");
      if (strikeProperty.isNotEmpty) {
        tempStyles.formats.add("strike");
      }
      var scriptProperty = runProperty.first.findAllElements("w:vertAlign");
      if (scriptProperty.isNotEmpty) {
        if (scriptProperty.first.getAttribute("w:val") == "superscript") {
          tempStyles.formats.add("superscript");
        } else if (scriptProperty.first.getAttribute("w:val") == "subscript") {
          tempStyles.formats.add("subscript");
        }
      }
      var colorProperty = runProperty.first.findAllElements("w:color");
      if (colorProperty.isNotEmpty) {
        var tempTextColor = colorProperty.first.getAttribute("w:val");
        if (tempTextColor != null) {
          tempStyles.textColor = tempTextColor;
        }
      }

      var fontSizeProperty = runProperty.first.findAllElements("w:sz");
      if (fontSizeProperty.isNotEmpty) {
        var tempFontSize = fontSizeProperty.first.getAttribute("w:val");
        if (tempFontSize != null) {
          tempStyles.fontSize = int.parse(tempFontSize);
        }
      }
      var fontsProperty = runProperty.first.findAllElements("w:rFonts");
      if (fontsProperty.isNotEmpty) {
        var tempAscii = fontsProperty.first.getAttribute("w:ascii");
        if (tempAscii != null) {
          tempStyles.fonts["ascii"] = tempAscii;
        }
        var temphAnsi = fontsProperty.first.getAttribute("w:hAnsi");
        if (temphAnsi != null) {
          tempStyles.fonts["hAnsi"] = temphAnsi;
        }
      }
    }
    var tableProp = stylesParam.style.findAllElements("w:tblPr");
    if (tableProp.isNotEmpty) {
      var borderProp = tableProp.first.findAllElements("w:tblBorders");
      if (borderProp.isNotEmpty) {
        Map<String, String> tempTableProp = {};
        var topPro = borderProp.first.findAllElements("w:top");
        if (topPro.isNotEmpty) {
          var topVal = topPro.first.getAttribute("w:val");
          if (topVal != null) {
            tempTableProp["top-va"] = topVal;
          }
          var topSz = topPro.first.getAttribute("w:sz");
          if (topSz != null) {
            tempTableProp["top-sz"] = topSz;
          }
          var topColor = topPro.first.getAttribute("w:color");
          if (topColor != null) {
            tempTableProp["top-color"] = topColor;
          }
        }
        var leftPro = borderProp.first.findAllElements("w:left");
        if (leftPro.isNotEmpty) {
          var leftVal = leftPro.first.getAttribute("w:val");
          if (leftVal != null) {
            tempTableProp["left-va"] = leftVal;
          }
          var leftSz = leftPro.first.getAttribute("w:sz");
          if (leftSz != null) {
            tempTableProp["left-sz"] = leftSz;
          }
          var leftColor = leftPro.first.getAttribute("w:color");
          if (leftColor != null) {
            tempTableProp["left-color"] = leftColor;
          }
        }
        var bottomPro = borderProp.first.findAllElements("w:bottom");
        if (bottomPro.isNotEmpty) {
          var bottomVal = bottomPro.first.getAttribute("w:val");
          if (bottomVal != null) {
            tempTableProp["bottom-va"] = bottomVal;
          }
          var bottomSz = bottomPro.first.getAttribute("w:sz");
          if (bottomSz != null) {
            tempTableProp["bottom-sz"] = bottomSz;
          }
          var bottomColor = bottomPro.first.getAttribute("w:color");
          if (bottomColor != null) {
            tempTableProp["bottom-color"] = bottomColor;
          }
        }
        var rightPro = borderProp.first.findAllElements("w:right");
        if (rightPro.isNotEmpty) {
          var rightVal = rightPro.first.getAttribute("w:val");
          if (rightVal != null) {
            tempTableProp["right-va"] = rightVal;
          }
          var rightSz = rightPro.first.getAttribute("w:sz");
          if (rightSz != null) {
            tempTableProp["right-sz"] = rightSz;
          }
          var rightColor = rightPro.first.getAttribute("w:color");
          if (rightColor != null) {
            tempTableProp["right-color"] = rightColor;
          }
        }
        tempStyles.tableBorder = tempTableProp;
      }
    }
    var tblStylePr = stylesParam.style.findAllElements("w:tblStylePr");
    if (tblStylePr.isNotEmpty) {
      for (var tblStyle in tblStylePr) {
        var belongsTo = tblStyle.getAttribute("w:type");
        if (belongsTo != null) {
          RowColStyles rowColStyles = RowColStyles(belongsTo);
          var chckrPr = tblStyle.findAllElements("w:rPr");
          if (chckrPr.isNotEmpty) {
            var chkSz = chckrPr.first.findAllElements("w:sz");
            if (chkSz.isNotEmpty) {
              var tempSz = chkSz.first.getAttribute("val");
              if (tempSz != null) {
                rowColStyles.fontSize = int.parse(tempSz);
              }
            }
            var chkBold = chckrPr.first.findAllElements("w:b");
            if (chkBold.isNotEmpty) {
              rowColStyles.formats.add("bold");
            }
            var chkColor = chckrPr.first.findAllElements("w:color");
            if (chkColor.isNotEmpty) {
              var tempColor = chkColor.first.getAttribute("w:val");
              if (tempColor != null) {
                rowColStyles.textColor = tempColor;
              }
            }
          }
          var chktcPr = tblStyle.findAllElements("w:tcPr");
          if (chktcPr.isNotEmpty) {
            var chktcBorder = chktcPr.first.findAllElements("w:tcBorders");
            if (chktcBorder.isNotEmpty) {
              Map<String, String> tempTcProp = {};
              var topPro = chktcBorder.first.findAllElements("w:top");
              if (topPro.isNotEmpty) {
                var topVal = topPro.first.getAttribute("w:val");
                if (topVal != null) {
                  tempTcProp["top-va"] = topVal;
                }
                var topSz = topPro.first.getAttribute("w:sz");
                if (topSz != null) {
                  tempTcProp["top-sz"] = topSz;
                }
                var topColor = topPro.first.getAttribute("w:color");
                if (topColor != null) {
                  tempTcProp["top-color"] = topColor;
                }
              }
              var leftPro = chktcBorder.first.findAllElements("w:left");
              if (leftPro.isNotEmpty) {
                var leftVal = leftPro.first.getAttribute("w:val");
                if (leftVal != null) {
                  tempTcProp["left-va"] = leftVal;
                }
                var leftSz = leftPro.first.getAttribute("w:sz");
                if (leftSz != null) {
                  tempTcProp["left-sz"] = leftSz;
                }
                var leftColor = leftPro.first.getAttribute("w:color");
                if (leftColor != null) {
                  tempTcProp["left-color"] = leftColor;
                }
              }
              var bottomPro = chktcBorder.first.findAllElements("w:bottom");
              if (bottomPro.isNotEmpty) {
                var bottomVal = bottomPro.first.getAttribute("w:val");
                if (bottomVal != null) {
                  tempTcProp["bottom-va"] = bottomVal;
                }
                var bottomSz = bottomPro.first.getAttribute("w:sz");
                if (bottomSz != null) {
                  tempTcProp["bottom-sz"] = bottomSz;
                }
                var bottomColor = bottomPro.first.getAttribute("w:color");
                if (bottomColor != null) {
                  tempTcProp["bottom-color"] = bottomColor;
                }
              }
              var rightPro = chktcBorder.first.findAllElements("w:right");
              if (rightPro.isNotEmpty) {
                var rightVal = rightPro.first.getAttribute("w:val");
                if (rightVal != null) {
                  tempTcProp["right-va"] = rightVal;
                }
                var rightSz = rightPro.first.getAttribute("w:sz");
                if (rightSz != null) {
                  tempTcProp["right-sz"] = rightSz;
                }
                var rightColor = rightPro.first.getAttribute("w:color");
                if (rightColor != null) {
                  tempTcProp["right-color"] = rightColor;
                }
              }
              rowColStyles.cellBorder = tempTcProp;
            }
            var chkSdClr = chktcPr.first.findAllElements("w:shd");
            if (chkSdClr.isNotEmpty) {
              var tempSdColor = chkSdClr.first.getAttribute("w:fill");
              if (tempSdColor != null) {
                rowColStyles.shadingColor = tempSdColor;
              }
            }
          }

          tempStyles.rowColStyles.add(rowColStyles);
        }
      }
    }
    return tempStyles;
  }
}
///Params to be passed for styles
class GetStylesParam {
  ///Styles element
  xml.XmlElement style;
  ///Constructor
  GetStylesParam(this.style);
}
