import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:microsoft_viewer/models/document.dart';
import 'package:microsoft_viewer/models/foot_end_note.dart';
import 'package:microsoft_viewer/models/relationship.dart';
import 'package:microsoft_viewer/models/web_images.dart';
import 'package:xml/xml.dart' as xml;

import '../models/ms_image.dart';
import '../models/ms_table.dart';
import '../models/ms_text_span.dart';
import '../models/paragraph.dart';
import '../models/styles.dart';
import '../models/word_page.dart';

///Class for processing .docx files
class WordProcessor {
  ///Function for processing footnotes and endnotes
  void processFootEndNotes(ArchiveFile? footNoteFile, ArchiveFile? endNoteFile, List<FootEndNote> footNotes, List<FootEndNote> endNotes) {
    if (footNoteFile != null) {
      final fileContent = utf8.decode(footNoteFile.content);
      final document = xml.XmlDocument.parse(fileContent);
      var footNts = document.findAllElements("w:footnote");
      if (footNts.isNotEmpty) {
        for (var footNt in footNts) {
          String id = "";
          String pStyle = "";
          String rStyle = "";
          String text = "";
          var tempId = footNt.getAttribute("w:id");
          if (tempId != null) {
            id = tempId;
          }
          var chkPStyle = footNt.findAllElements("w:pStyle");
          if (chkPStyle.isNotEmpty) {
            var tempPStyle = chkPStyle.first.getAttribute("w:val");
            if (tempPStyle != null) {
              pStyle = tempPStyle;
            }
          }
          var chkrStyle = footNt.findAllElements("w:rStyle");
          if (chkrStyle.isNotEmpty) {
            var tempRStyle = chkrStyle.first.getAttribute("w:val");
            if (tempRStyle != null) {
              rStyle = tempRStyle;
            }
          }
          var chkText = footNt.findAllElements("w:t");
          if (chkText.isNotEmpty) {
            var tempText = chkText.first.innerText;
            if (tempText.isNotEmpty) {
              text = tempText;
            }
          }
          footNotes.add(FootEndNote(id, pStyle, rStyle, text));
        }
      }
    }
    if (endNoteFile != null) {
      final fileContent = utf8.decode(endNoteFile.content);
      final document = xml.XmlDocument.parse(fileContent);
      var endNts = document.findAllElements("w:endnote");
      if (endNts.isNotEmpty) {
        for (var endNt in endNts) {
          String id = "";
          String pStyle = "";
          String rStyle = "";
          String text = "";
          var tempId = endNt.getAttribute("w:id");
          if (tempId != null) {
            id = tempId;
          }
          var chkPStyle = endNt.findAllElements("w:pStyle");
          if (chkPStyle.isNotEmpty) {
            var tempPStyle = chkPStyle.first.getAttribute("w:val");
            if (tempPStyle != null) {
              pStyle = tempPStyle;
            }
          }
          var chkrStyle = endNt.findAllElements("w:rStyle");
          if (chkrStyle.isNotEmpty) {
            var tempRStyle = chkrStyle.first.getAttribute("w:val");
            if (tempRStyle != null) {
              rStyle = tempRStyle;
            }
          }
          var chkText = endNt.findAllElements("w:t");
          if (chkText.isNotEmpty) {
            var tempText = chkText.first.innerText;
            if (tempText.isNotEmpty) {
              text = tempText;
            }
          }
          endNotes.add(FootEndNote(id, pStyle, rStyle, text));
        }
      }
    }
  }

  ///Function for processing .docx file
  Future<void> processWordFile(ArchiveFile wordFile, int elementDepth, List<Relationship> relationShips, String wordOutputDirectory,
      List<Styles> stylesList, Document wordDocument, String fileType) async {
    final fileContent = utf8.decode(wordFile.content);
    final document = xml.XmlDocument.parse(fileContent);
    var chkBody = document.findAllElements("w:body");
    if (chkBody.isNotEmpty) {
      for (var childElements in chkBody.first.childElements) {
        await processWordElements(childElements, elementDepth, relationShips, wordOutputDirectory, stylesList, wordDocument, fileType);
      }
    }
  }

  ///Function for processing word elements
  Future<void> processWordElements(xml.XmlElement wordElements, int elementDepth, List<Relationship> relationShips, String wordOutputDirectory,
      List<Styles> stylesList, Document wordDocument, String fileType) async {
    if (wordElements.name.local == "tbl") {
      MsTable table = await compute(processWordTable, ProcessWordTableParams(wordElements));
      if (wordDocument.pages.isEmpty) {
        wordDocument.pages.add(WordPage(1));
      }
      wordDocument.pages.last.components.add(table);
      //processWordTable(wordElements, elementDepth, wordDocument);
    } else if (wordElements.name.local == "p") {
      List<WordPage> pages =
          await compute(processParagraph, ProcessParagraphParams(wordElements, relationShips, wordOutputDirectory, stylesList, wordDocument));

      wordDocument.pages = pages;
    } else if (wordElements.name.local == "sectPr") {
      processSectionDetails(wordElements, wordDocument);
    }
  }

  ///Function for processing paragraph
  static List<WordPage> processParagraph(ProcessParagraphParams params) {
    List<WordPage> pages = params.wordDocument.pages;
    var pStyle = "";
    var chkPProperties = params.paragraphElement.findAllElements("w:pPr");
    int seqNo = 0;
    Map<String, String> tabs = {};
    String paraShadingColor = "";
    Map<String, String> paraFormat = {};
    if (chkPProperties.isNotEmpty) {
      var chkPStyle = chkPProperties.first.findAllElements("w:pStyle");
      if (chkPStyle.isNotEmpty) {
        var tempPStyle = chkPStyle.first.getAttribute("w:val");
        if (tempPStyle != null) {
          pStyle = tempPStyle;
        }
      }
      var chkTabs = chkPProperties.first.findAllElements("w:tab");
      if (chkTabs.isNotEmpty) {
        var tempVal = chkTabs.first.getAttribute("w:val");
        if (tempVal != null) {
          tabs["val"] = tempVal;
        }
        var tempLeader = chkTabs.first.getAttribute("w:leader");
        if (tempLeader != null) {
          tabs["leader"] = tempLeader;
        }
      }
      var shadingColorProperty = chkPProperties.first.findAllElements("w:shd");
      if (shadingColorProperty.isNotEmpty) {
        var tempShadingColor = shadingColorProperty.first.getAttribute("w:fill");
        if (tempShadingColor != null) {
          paraShadingColor = tempShadingColor;
        }
      }
      var justifyProp = chkPProperties.first.findAllElements("w:jc");
      if (justifyProp.isNotEmpty) {
        var tempJc = justifyProp.first.getAttribute("w:val");
        if (tempJc != null) {
          paraFormat["jc"] = tempJc;
        }
      }
    }
    Paragraph paragraph = Paragraph(seqNo, pStyle);
    if (tabs.isNotEmpty) {
      paragraph.tabDetails = tabs;
    }
    if (paraShadingColor.isNotEmpty) {
      paragraph.shadingColor = paraShadingColor;
    }
    if (paraFormat.isNotEmpty) {
      paragraph.formats = paraFormat;
    }
    seqNo++;
    int pSeqNo = 0;
    var runElements = params.paragraphElement.findAllElements("w:r");
    if (runElements.isNotEmpty) {
      for (var run in runElements) {
        List<String> formats = [];
        String tStyle = "";
        int fontSize = 0;
        String textColor = "";
        String highlightColor = "";
        String shadingColor = "";
        Map<String, String> fonts = {};
        var runProperty = run.findAllElements("w:rPr");
        if (runProperty.isNotEmpty) {
          var boldProperty = runProperty.first.findAllElements("w:b");
          if (boldProperty.isNotEmpty) {
            formats.add("bold");
          }
          var italicProperty = runProperty.first.findAllElements("w:i");
          if (italicProperty.isNotEmpty) {
            formats.add("italic");
          }
          var underlineProperty = runProperty.first.findAllElements("w:u");
          if (underlineProperty.isNotEmpty) {
            if (underlineProperty.first.getAttribute("w:val") == "single") {
              formats.add("single-underline");
            } else if (underlineProperty.first.getAttribute("w:val") == "double") {
              formats.add("double-underline");
            }
          }
          var strikeProperty = runProperty.first.findAllElements("w:strike");
          if (strikeProperty.isNotEmpty) {
            formats.add("strike");
          }
          var scriptProperty = runProperty.first.findAllElements("w:vertAlign");
          if (scriptProperty.isNotEmpty) {
            if (scriptProperty.first.getAttribute("w:val") == "superscript") {
              formats.add("superscript");
            } else if (scriptProperty.first.getAttribute("w:val") == "subscript") {
              formats.add("subscript");
            }
          }
          var colorProperty = runProperty.first.findAllElements("w:color");
          if (colorProperty.isNotEmpty) {
            var tempTextColor = colorProperty.first.getAttribute("w:val");
            if (tempTextColor != null) {
              textColor = tempTextColor;
            }
          }
          var shadingColorProperty = runProperty.first.findAllElements("w:shd");
          if (shadingColorProperty.isNotEmpty) {
            var tempShadingColor = shadingColorProperty.first.getAttribute("w:fill");
            if (tempShadingColor != null) {
              shadingColor = tempShadingColor;
            }
          }
          var highlightColorProperty = runProperty.first.findAllElements("w:highlight");
          if (highlightColorProperty.isNotEmpty) {
            var tempHighlightColor = highlightColorProperty.first.getAttribute("w:val");
            if (tempHighlightColor != null) {
              highlightColor = tempHighlightColor;
            }
          }
          var styleProperty = runProperty.first.findAllElements("w:rStyle");
          if (styleProperty.isNotEmpty) {
            var tempStyle = styleProperty.first.getAttribute("w:val");
            if (tempStyle != null) {
              tStyle = tempStyle;
            }
          }
          var fontSizeProperty = runProperty.first.findAllElements("w:sz");
          if (fontSizeProperty.isNotEmpty) {
            var tempFontSize = fontSizeProperty.first.getAttribute("w:val");
            if (tempFontSize != null) {
              fontSize = int.parse(tempFontSize);
            }
          }
          var fontsProperty = runProperty.first.findAllElements("w:rFonts");
          if (fontsProperty.isNotEmpty) {
            var tempAscii = fontsProperty.first.getAttribute("w:ascii");
            if (tempAscii != null) {
              fonts["ascii"] = tempAscii;
            }
            var temphAnsi = fontsProperty.first.getAttribute("w:hAnsi");
            if (temphAnsi != null) {
              fonts["hAnsi"] = temphAnsi;
            }
          }
        }
        var textElements = run.findAllElements("w:t");
        if (textElements.isNotEmpty) {
          if (paragraph.tabDetails.isNotEmpty) {
            for (int i = 0; i < textElements.length; i++) {
              if (pSeqNo > 0) {
                paragraph.textSpans.add(MsTextSpan(
                    pSeqNo, textElements.elementAt(i).innerText, tStyle, formats, fontSize, textColor, highlightColor, fonts, shadingColor));
                pSeqNo++;
              } else {
                String innerTex = textElements.elementAt(i).innerText;
                if (paragraph.tabDetails["leader"] == "dot") {
                  if (paragraph.tabDetails["val"] == "left") {
                    innerTex = "......................$innerTex";
                  } else {
                    innerTex = "$innerTex......................";
                  }
                } else if (paragraph.tabDetails["leader"] == "hyphen") {
                  if (paragraph.tabDetails["val"] == "left") {
                    innerTex = "--------------------$innerTex";
                  } else {
                    innerTex = "$innerTex--------------------";
                  }
                } else if (paragraph.tabDetails["leader"] == "space") {
                  if (paragraph.tabDetails["val"] == "left") {
                    innerTex = "                      $innerTex";
                  } else {
                    innerTex = "$innerTex                   ";
                  }
                }
                paragraph.textSpans.add(MsTextSpan(pSeqNo, innerTex, tStyle, formats, fontSize, textColor, highlightColor, fonts, shadingColor));
                pSeqNo++;
              }
            }
          } else {
            for (var textE in textElements) {
              paragraph.textSpans.add(MsTextSpan(pSeqNo, textE.innerText, tStyle, formats, fontSize, textColor, highlightColor, fonts, shadingColor));
              pSeqNo++;
            }
          }
        }
        var drawingElements = run.findAllElements("w:drawing");
        if (drawingElements.isNotEmpty) {
          for (var draw in drawingElements) {
            var imageBlip = draw.findAllElements("a:blip");
            if (imageBlip.isNotEmpty) {
              String imagePath = "";
              String imageType = "";
              int imgCX = 0;
              int imgCY = 0;
              var imageRid = imageBlip.first.getAttribute("r:embed");
              var imageRelation = params.relationShips.firstWhere((rel) {
                return rel.id == imageRid;
              });
              String imageName = imageRelation.target.split("/").last;
              if(kIsWeb){
                imagePath=imageName;
              }else {
                imagePath = "${params.wordOutputDirectory}/$imageName";
              }
              var imageInline = draw.findAllElements("wp:inline");
              if (imageInline.isNotEmpty) {
                imageType = "inline";
                var imageExtent = imageInline.first.findAllElements("wp:extent");
                if (imageExtent.isNotEmpty) {
                  var tempImageCX = imageExtent.first.getAttribute("cx");
                  if (tempImageCX != null) {
                    imgCX = int.parse(tempImageCX);
                  }
                  var tempImageCY = imageExtent.first.getAttribute("cy");
                  if (tempImageCY != null) {
                    imgCY = int.parse(tempImageCY);
                  }
                }
              }
              var imageAnchor = draw.findAllElements("wp:anchor");
              if (imageAnchor.isNotEmpty) {
                imageType = "anchor";
                var imageExtent = imageAnchor.first.findAllElements("wp:extent");
                if (imageExtent.isNotEmpty) {
                  var tempImageCX = imageExtent.first.getAttribute("cx");
                  if (tempImageCX != null) {
                    imgCX = int.parse(tempImageCX);
                  }
                  var tempImageCY = imageExtent.first.getAttribute("cy");
                  if (tempImageCY != null) {
                    imgCY = int.parse(tempImageCY);
                  }
                }
              }
              paragraph.images.add(MsImage(pSeqNo, imagePath, imageType, imgCX, imgCY));
              pSeqNo++;
            }
          }
        }
        var chkFootNotes = run.findAllElements("w:footnoteReference");
        if (chkFootNotes.isNotEmpty) {
          for (var footNt in chkFootNotes) {
            var footNtId = footNt.getAttribute("w:id");
            if (footNtId != null) {
              int noteId = 0;
              if (params.wordDocument.pages.isNotEmpty) {
                noteId = params.wordDocument.pages.last.footNotes.length + params.wordDocument.pages.last.endNotes.length;
              }
              paragraph.textSpans
                  .add(MsTextSpan(pSeqNo, (noteId + 1).toString(), tStyle, formats, fontSize, textColor, highlightColor, fonts, shadingColor));
              pSeqNo++;
              Map<String, String> footNoteDetails = {};
              footNoteDetails["id"] = footNtId;
              footNoteDetails["refNo"] = (noteId + 1).toString();
              footNoteDetails["style"] = tStyle;
              if (pages.isEmpty) {
                WordPage wordPage = WordPage(pages.length + 1);
                pages.add(wordPage);
              }
              pages.last.footNotes.add(footNoteDetails);
            }
          }
        }
        var chkEndNotes = run.findAllElements("w:endnoteReference");
        if (chkEndNotes.isNotEmpty) {
          for (var endNt in chkEndNotes) {
            var endNtId = endNt.getAttribute("w:id");
            if (endNtId != null) {
              paragraph.textSpans.add(MsTextSpan(
                  pSeqNo,
                  (params.wordDocument.pages.last.endNotes.length + params.wordDocument.pages.last.footNotes.length + 1).toString(),
                  tStyle,
                  formats,
                  fontSize,
                  textColor,
                  highlightColor,
                  fonts,
                  shadingColor));
              pSeqNo++;
              Map<String, String> endNoteDetails = {};
              endNoteDetails["id"] = endNtId;
              endNoteDetails["refNo"] =
                  (params.wordDocument.pages.last.footNotes.length + params.wordDocument.pages.last.endNotes.length + 1).toString();
              endNoteDetails["style"] = tStyle;
              if (pages.isEmpty) {
                WordPage wordPage = WordPage(pages.length + 1);
                pages.add(wordPage);
              }
              pages.last.endNotes.add(endNoteDetails);
            }
          }
        }
      }
    }
    bool newPage = false;
    for (var style in params.stylesList) {
      if (style.styleId == paragraph.style) {
        if (style.pageBreakBefore != null && style.pageBreakBefore == true) {
          newPage = true;
        }
      }
    }
    if (newPage || pages.isEmpty) {
      WordPage wordPage = WordPage(pages.length + 1);
      pages.add(wordPage);
    }
    pages.last.components.add(paragraph);
    return pages;
  }

  ///Function for processing table in word
  MsTable processWordTable(ProcessWordTableParams params) {
    String tblStyle = "";
    String rightFromText = "";
    String bottomFromText = "";
    String vertAnchor = "";
    String tblpY = "";
    String tblWidth = "";
    String tblWType = "";
    String tblLook = "";
    int seqNo = 0;
    var chkTblStyle = params.tableElement.findAllElements("w:tblStyle");
    if (chkTblStyle.isNotEmpty) {
      var tempTblStyle = chkTblStyle.first.getAttribute("w:val");
      if (tempTblStyle != null) {
        tblStyle = tempTblStyle;
      }
    }
    var chkTblPr = params.tableElement.findAllElements("w:tblpPr");
    if (chkTblPr.isNotEmpty) {
      var tempRightFromText = chkTblPr.first.getAttribute("w:rightFromText");
      if (tempRightFromText != null) {
        rightFromText = tempRightFromText;
      }
      var tempBottomFromText = chkTblPr.first.getAttribute("w:bottomFromText");
      if (tempBottomFromText != null) {
        bottomFromText = tempBottomFromText;
      }
      var tempVertAnchor = chkTblPr.first.getAttribute("w:vertAnchor");
      if (tempVertAnchor != null) {
        vertAnchor = tempVertAnchor;
      }
      var tempTblpY = chkTblPr.first.getAttribute("w:tblpY");
      if (tempTblpY != null) {
        tblpY = tempTblpY;
      }
    }
    var chkTblW = params.tableElement.findAllElements("w:tblW");
    if (chkTblW.isNotEmpty) {
      var tempTblW = chkTblW.first.getAttribute("w:w");
      if (tempTblW != null) {
        tblWidth = tempTblW;
      }
      var tempWType = chkTblW.first.getAttribute("w:type");
      if (tempWType != null) {
        tblWType = tempWType;
      }
    }
    MsTable table = MsTable(seqNo, tblStyle, rightFromText, bottomFromText, vertAnchor, tblpY, tblWidth, tblWType, tblLook);
    seqNo++;
    final rows = params.tableElement.findAllElements('w:tr');

    for (var row in rows) {
      bool isFirstRow = false;
      bool isLastRow = false;
      bool isFirstCol = false;
      bool isLastCol = false;
      final chkCnfStyle = row.findAllElements("w:cnfStyle");
      if (chkCnfStyle.isNotEmpty) {
        var cnfStyleVal = chkCnfStyle.first.getAttribute("w:val");
        if (cnfStyleVal != null && cnfStyleVal.startsWith("1")) {
          isFirstRow = true;
        }
        if (cnfStyleVal != null && cnfStyleVal.substring(1, 2) == "1") {
          isLastRow = true;
        }
        if (cnfStyleVal != null && cnfStyleVal.substring(2, 3) == "1") {
          isFirstCol = true;
        }
        if (cnfStyleVal != null && cnfStyleVal.substring(3, 4) == "1") {
          isLastCol = true;
        }
      }
      MsTableRow tableRow = MsTableRow(isFirstRow, isLastRow, isFirstCol, isLastCol);
      var chkGridSpan = row.findAllElements("w:gridSpan");
      if (chkGridSpan.isNotEmpty) {
        var tempGridSpan = chkGridSpan.first.getAttribute("w:val");
        if (tempGridSpan != null) {
          tableRow.gridSpan = int.parse(tempGridSpan);
        }
      }
      final cells = row.findAllElements('w:tc');
      if (table.colNums != cells.length && table.colNums < cells.length) {
        table.colNums = cells.length;
      }

      for (var cell in cells) {
        int cellWidth = 0;
        final cellWidthElement = cell.findAllElements("w:tcW");
        if (cellWidthElement.isNotEmpty) {
          var tempCellWidth = cellWidthElement.first.getAttribute("w:w");
          if (tempCellWidth != null) {
            cellWidth = int.parse(tempCellWidth);
          }
        }
        final cellData = cell.findAllElements('w:t');
        String colText = "";
        for (var cellText in cellData) {
          colText += cellText.innerText;
        }
        MsTableCell tableCell = MsTableCell(colText, cellWidth);
        tableRow.cells.add(tableCell);
      }
      table.rows.add(tableRow);
    }
    return table;
  }

  ///Function for displaying .docx file
  Future<List<Widget>> displayWordFile(
      String fileType, Document wordDocument, List<Styles> stylesList, List<FootEndNote> footNotes, List<FootEndNote> endNotes,List<WebImages> webImages) async {
    List<Widget> tempList = [];
    if (fileType == "word") {
      for (int i = 0; i < wordDocument.pages.length; i++) {
        List<Widget> pageWidgets = [];
        for (int j = 0; j < wordDocument.pages[i].components.length; j++) {
          List<Widget> tempPageWidgets =
              await compute(getComponents, GetComponentsParams(wordDocument.pages[i].components[j], stylesList, pageWidgets, wordDocument,webImages));
          pageWidgets.addAll(tempPageWidgets);
        }
        if (wordDocument.pages[i].footNotes.isNotEmpty) {
          for (var footNt in wordDocument.pages[i].footNotes) {
            var chkFootNot = footNotes.firstWhereOrNull((ftNt) {
              return ftNt.id == footNt["id"];
            });
            if (chkFootNot != null) {
              pageWidgets.add(getFootEndNote(chkFootNot, stylesList, footNt["refNo"]!));
            }
          }
        }
        if (wordDocument.pages[i].endNotes.isNotEmpty) {
          for (var endNt in wordDocument.pages[i].endNotes) {
            var chkEndNt = endNotes.firstWhereOrNull((edNt) {
              return edNt.id == endNt["id"];
            });
            if (chkEndNt != null) {
              pageWidgets.add(getFootEndNote(chkEndNt, stylesList, endNt["refNo"]!));
            }
          }
        }
        tempList.add(Container(
          color: Colors.white,
          constraints: BoxConstraints(minHeight: wordDocument.pageSize.height, minWidth: wordDocument.pageSize.width),
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: EdgeInsets.only(
                left: wordDocument.pageMargin["leftMar"] ?? 0,
                right: wordDocument.pageMargin["rightMar"] ?? 0,
                top: wordDocument.pageMargin["topMar"] ?? 0,
                bottom: wordDocument.pageMargin["bottomMar"] ?? 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: pageWidgets,
            ),
          ),
        ));
      }
    }
    return tempList;
  }

  ///Function for processing text spans
  static InlineSpan getTextSpan(MsTextSpan textSpan, List<Styles> stylesList) {
    TextStyle textStyle = const TextStyle(inherit: false);
    String tempSpanText = textSpan.text;

    if (textSpan.fontSize != 0) {
      textStyle = textStyle.copyWith(fontSize: textSpan.fontSize.toDouble() / 2);
    }
    if (textSpan.formats.contains("italic")) {
      textStyle = textStyle.copyWith(fontStyle: FontStyle.italic);
    }
    if (textSpan.formats.contains("bold")) {
      textStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
    }
    if (textSpan.formats.contains("single-underline")) {
      textStyle = textStyle.copyWith(decoration: TextDecoration.underline);
    }
    if (textSpan.formats.contains("double-underline")) {
      textStyle = textStyle.copyWith(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.double);
    }
    if (textSpan.formats.contains("strike")) {
      textStyle = textStyle.copyWith(decoration: TextDecoration.lineThrough);
    }
    if (textSpan.textColor.isNotEmpty && textSpan.textColor != "auto") {
      Color selectedColor = Color(int.parse("FF${textSpan.textColor}", radix: 16));

      textStyle = textStyle.copyWith(color: selectedColor);
    }
    if (textSpan.fonts.isNotEmpty) {
      textStyle = textStyle.copyWith(fontFamily: textSpan.fonts["ascii"]);
    }
    if (textSpan.highlightColor.isNotEmpty) {
      textStyle = textStyle.copyWith(backgroundColor: getColorFromName(textSpan.highlightColor));
    }
    if (textSpan.shadingColor.isNotEmpty) {
      Color shadingColor = Color(int.parse("FF${textSpan.shadingColor}", radix: 16));
      textStyle = textStyle.copyWith(backgroundColor: shadingColor);
    }

    if (textSpan.style.isNotEmpty) {
      Styles? textStyles = stylesList.firstWhereOrNull((style) {
        return style.styleId == textSpan.style;
      });
      if (textStyles != null) {
        if (textStyles.fontSize != 0) {
          textStyle = textStyle.copyWith(fontSize: textStyles.fontSize.toDouble() / 2);
        }
        if (textStyles.formats.contains("italic")) {
          textStyle = textStyle.copyWith(fontStyle: FontStyle.italic);
        }
        if (textStyles.formats.contains("bold")) {
          textStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
        }
        if (textStyles.formats.contains("single-underline")) {
          textStyle = textStyle.copyWith(decoration: TextDecoration.underline);
        }
        if (textStyles.formats.contains("double-underline")) {
          textStyle = textStyle.copyWith(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.double);
        }
        if (textStyles.formats.contains("strike")) {
          textStyle = textStyle.copyWith(decoration: TextDecoration.lineThrough);
        }
        if (textStyles.formats.contains("subscript")) {
          textSpan.formats.add("subscript");
        }
        if (textStyles.formats.contains("superscript")) {
          textSpan.formats.add("superscript");
        }
        if (textStyles.textColor != null && textStyles.textColor != "auto") {
          Color selectedColor = Color(int.parse("FF${textStyles.textColor!}", radix: 16));

          textStyle = textStyle.copyWith(color: selectedColor);
        } else {
          textStyle = textStyle.copyWith(color: Colors.black);
        }
        if (textStyles.fonts.isNotEmpty) {
          textStyle = textStyle.copyWith(fontFamily: textStyles.fonts["ascii"]);
        }
      }
    }
    if (textSpan.formats.contains("subscript") || textSpan.formats.contains("superscript")) {
      double fontSize = textStyle.fontSize ?? 22;
      textStyle = textStyle.copyWith(fontSize: fontSize / 3).copyWith(color: Colors.grey);
      if (textSpan.formats.contains("subscript")) {
        return WidgetSpan(
          child: Transform.translate(
            offset: const Offset(0.0, 1.0),
            child: Text(
              tempSpanText,
              style: textStyle,
            ),
          ),
        );
      } else {
        return WidgetSpan(
          child: Transform.translate(
            offset: const Offset(0.0, -3.0),
            child: Text(
              tempSpanText,
              style: textStyle,
            ),
          ),
        );
      }
    } else {
      return TextSpan(text: tempSpanText, style: textStyle);
    }
  }

  ///Function for processing rich text
  static List<Widget> getRichText(Paragraph paragraph, List<InlineSpan> paragraphWidget, List<Styles> stylesList, Document wordDocument) {
    TextStyle textStyle = const TextStyle();
    String jc = "";
    String indentText = "";
    List<Widget> pageWidgets = [];
    int spaceBefore = 0;
    int spaceAfter = 0;
    Map<String, String> paraBorder = {};
    if (paragraph.style.isNotEmpty) {
      Styles? paraStyles = stylesList.firstWhereOrNull((style) {
        return style.styleId == paragraph.style;
      });
      if (paraStyles != null) {
        if (paraStyles.fontSize != 0) {
          textStyle = textStyle.copyWith(fontSize: paraStyles.fontSize.toDouble() / 2);
        }
        if (paraStyles.formats.contains("italic")) {
          textStyle = textStyle.copyWith(fontStyle: FontStyle.italic);
        }
        if (paraStyles.formats.contains("bold")) {
          textStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
        }
        if (paraStyles.formats.contains("single-underline")) {
          textStyle = textStyle.copyWith(decoration: TextDecoration.underline);
        }
        if (paraStyles.formats.contains("double-underline")) {
          textStyle = textStyle.copyWith(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.double);
        }
        if (paraStyles.formats.contains("strike")) {
          textStyle = textStyle.copyWith(decoration: TextDecoration.lineThrough);
        }
        if (paraStyles.formats.contains("subscript")) {
          textStyle = textStyle.copyWith(fontFeatures: [const FontFeature.subscripts()]);
        }
        if (paraStyles.textColor != null && paraStyles.textColor != "auto") {
          Color selectedColor = Color(int.parse("FF${paraStyles.textColor!}", radix: 16));

          textStyle = textStyle.copyWith(color: selectedColor);
        } else {
          textStyle = textStyle.copyWith(color: Colors.black);
        }
        if (paraStyles.fonts.isNotEmpty) {
          textStyle = textStyle.copyWith(fontFamily: paraStyles.fonts["ascii"]);
        }
        if (paraStyles.jc != null && paraStyles.jc!.isNotEmpty) {
          jc = paraStyles.jc!;
        }

        if (paraStyles.firstLineInd != 0) {
          for (int i = 0; i < paraStyles.firstLineInd / 100; i++) {
            indentText += " ";
          }
        }
        if (paraStyles.leftInd != 0) {
          for (int i = 0; i < paraStyles.leftInd / 100; i++) {
            indentText += " ";
          }
        }
        if (paraStyles.spacingBefore != 0) {
          spaceBefore = paraStyles.spacingBefore;
        }
        if (paraStyles.spacingAfter != 0) {
          spaceAfter = paraStyles.spacingAfter;
        }
        if (paraStyles.styleId == "ListParagraph") {
          indentText = "\u2022 $indentText";
        }
        if (paraStyles.paraGraphBorder.isNotEmpty) {
          paraBorder = paraStyles.paraGraphBorder;
        }
        if (paraStyles.jc != null && paraStyles.jc!.isNotEmpty) {
          jc = paraStyles.jc!;
        }
      }
    } else {
      textStyle = textStyle.copyWith(color: Colors.black);
    }
    if (paragraph.style.isEmpty) {
      if (wordDocument.defaultLineSpacing != 0) {
        for (int i = 0; i < wordDocument.defaultLineSpacing / 100; i++) {
          indentText += " ";
        }
      }
      if (wordDocument.defaultFontSize != 0) {
        textStyle = textStyle.copyWith(fontSize: wordDocument.defaultFontSize / 2);
      }
    }
    if (paragraph.shadingColor != null && paragraph.shadingColor != "auto") {
      Color paraBgColor = Color(int.parse("FF${paragraph.shadingColor!}", radix: 16));
      textStyle = textStyle.copyWith(backgroundColor: paraBgColor);
    }
    if (paragraph.formats != null && paragraph.formats!.isNotEmpty) {
      if (paragraph.formats!["jc"] != null) {
        jc = paragraph.formats!["jc"]!;
      }
    }

    RichText richText = RichText(
      softWrap: true,
      text: TextSpan(text: indentText, style: textStyle, children: paragraphWidget),
      textAlign: jc == "right"
          ? TextAlign.end
          : jc == "center"
              ? TextAlign.center
              : TextAlign.start,
    );

    if (spaceBefore != 0) {
      pageWidgets.add(SizedBox(
        height: spaceBefore.toDouble() / 10,
      ));
    }
    Widget alignmentWidget = Container(
      child: richText,
    );
    if (jc == "center") {
      alignmentWidget = Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [richText],
      );
    } else if (jc == "right") {
      alignmentWidget = Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [Expanded(child: richText)],
      );
    }
    if (paraBorder.isNotEmpty) {
      pageWidgets.add(borderContainer(paraBorder, alignmentWidget));
    } else {
      pageWidgets.add(alignmentWidget);
    }
    if (spaceAfter != 0) {
      pageWidgets.add(SizedBox(
        height: spaceAfter.toDouble() / 10,
      ));
    }
    return pageWidgets;
  }

  ///Function for adding borders in containers
  static Container borderContainer(Map<String, String> borderDetails, Widget child) {
    BorderSide topBorder = const BorderSide(width: 0);
    BorderSide leftBorder = const BorderSide(width: 0);
    BorderSide bottomBorder = const BorderSide(width: 0);
    BorderSide rightBorder = const BorderSide(width: 0);
    if (borderDetails.isNotEmpty) {
      if (borderDetails["top-val"] != null) {
        topBorder = topBorder.copyWith(style: BorderStyle.solid);
      }
      if (borderDetails["top-sz"] != null) {
        topBorder = topBorder.copyWith(width: double.parse(borderDetails["top-sz"].toString()) / 2);
      }
      if (borderDetails["top-color"] != null && borderDetails["top-color"] != "auto") {
        topBorder = topBorder.copyWith(color: Color(int.parse("FF${borderDetails["top-color"]}", radix: 16)));
      }

      if (borderDetails["left-val"] != null) {
        leftBorder = leftBorder.copyWith(style: BorderStyle.solid);
      }
      if (borderDetails["left-sz"] != null) {
        leftBorder = leftBorder.copyWith(width: double.parse(borderDetails["left-sz"].toString()) / 2);
      }
      if (borderDetails["left-color"] != null) {
        leftBorder = leftBorder.copyWith(color: Color(int.parse("FF${borderDetails["left-color"]}", radix: 16)));
      }

      if (borderDetails["bottom-val"] != null) {
        bottomBorder = bottomBorder.copyWith(style: BorderStyle.solid);
      }
      if (borderDetails["bottom-sz"] != null) {
        bottomBorder = bottomBorder.copyWith(width: double.parse(borderDetails["bottom-sz"].toString()) / 2);
      }
      if (borderDetails["bottom-color"] != null && borderDetails["bottom-color"] != "auto") {
        bottomBorder = bottomBorder.copyWith(color: Color(int.parse("FF${borderDetails["bottom-color"]}", radix: 16)));
      }

      if (borderDetails["right-val"] != null) {
        rightBorder = rightBorder.copyWith(style: BorderStyle.solid);
      }
      if (borderDetails["right-sz"] != null) {
        rightBorder = rightBorder.copyWith(width: double.parse(borderDetails["right-sz"].toString()) / 2);
      }
      if (borderDetails["right-color"] != null && borderDetails["right-color"] != "auto") {
        rightBorder = rightBorder.copyWith(color: Color(int.parse("FF${borderDetails["right-color"]}", radix: 16)));
      }
    }
    return Container(
      decoration: BoxDecoration(
          border: Border(
        top: topBorder.width != 0 ? topBorder : BorderSide.none,
        right: rightBorder.width != 0 ? rightBorder : BorderSide.none,
        bottom: bottomBorder.width != 0 ? bottomBorder : BorderSide.none,
        left: leftBorder.width != 0 ? leftBorder : BorderSide.none,
      )),
      child: child,
    );
  }

  ///Function for processing section details
  void processSectionDetails(xml.XmlElement sectionElement, Document wordDocument) {
    var chckPgSz = sectionElement.findAllElements("w:pgSz");
    if (chckPgSz.isNotEmpty) {
      double tmpWidth = 0;
      double tmpHeight = 0;
      var pgWidth = chckPgSz.first.getAttribute("w:w");
      if (pgWidth != null) {
        tmpWidth = (int.parse(pgWidth) / 1440) * 38;
      }
      var pgHeight = chckPgSz.first.getAttribute("w:h");
      if (pgHeight != null) {
        tmpHeight = (int.parse(pgHeight) / 1440) * 38;
      }
      wordDocument.pageSize = Size(tmpWidth, tmpHeight);
    }
    var chckPgMar = sectionElement.findAllElements("w:pgMar");
    if (chckPgMar.isNotEmpty) {
      Map<String, double> tempMar = {};
      var tMar = chckPgMar.first.getAttribute("w:top");
      if (tMar != null) {
        tempMar["topMar"] = (int.parse(tMar) / 1440) * 38;
      }
      var bMar = chckPgMar.first.getAttribute("w:bottom");
      if (bMar != null) {
        tempMar["bottomMar"] = (int.parse(bMar) / 1440) * 38;
      }
      var rMar = chckPgMar.first.getAttribute("w:right");
      if (rMar != null) {
        tempMar["rightMar"] = (int.parse(rMar) / 1440) * 38;
      }
      var lMar = chckPgMar.first.getAttribute("w:left");
      if (lMar != null) {
        tempMar["leftMar"] = (int.parse(lMar) / 1440) * 38;
      }
      var hMar = chckPgMar.first.getAttribute("w:header");
      if (hMar != null) {
        tempMar["headerMar"] = (int.parse(hMar) / 1440) * 38;
      }
      var fMar = chckPgMar.first.getAttribute("w:footer");
      if (fMar != null) {
        tempMar["footerMar"] = (int.parse(fMar) / 1440) * 38;
      }
      var gMar = chckPgMar.first.getAttribute("w:gutter");
      if (gMar != null) {
        tempMar["w:gutter"] = (int.parse(gMar) / 1440) * 38;
      }
      wordDocument.pageMargin = tempMar;
    }
  }

  ///Function for getting color from name
  static Color getColorFromName(String name) {
    switch (name.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'yellow':
        return Colors.yellow;
      // Add more colors as needed
      default:
        return Colors.white; // Return null or a default color
    }
  }

  ///Function for getting table styles
  static String getTableStyle(MsTable msTable, List<Styles> stylesList) {
    String tableStyleHtml = "";
    if (msTable.tblStyle.isNotEmpty) {
      Styles? tableStyles = stylesList.firstWhereOrNull((style) {
        return style.styleId == msTable.tblStyle;
      });
      if (tableStyles != null) {
        if (tableStyles.tableBorder.isNotEmpty) {
          String topColor = "";
          String topBrStyle = "solid";
          String topSz = "";
          if (tableStyles.tableBorder["top-val"] != null) {
            topBrStyle = "solid";
          }
          if (tableStyles.tableBorder["top-sz"] != null) {
            topSz = (int.parse(tableStyles.tableBorder["top-sz"]!) / 2).toString();
          }
          if (tableStyles.tableBorder["top-color"] != null && tableStyles.tableBorder["top-color"] != "auto") {
            topColor = "#${tableStyles.tableBorder["top-color"]!}";
          }
          tableStyleHtml = "${tableStyleHtml}border-top: ${topSz}px $topBrStyle $topColor; ";
          String leftColor = "";
          String leftBrStyle = "solid";
          String leftSz = "";
          if (tableStyles.tableBorder["left-val"] != null) {
            leftBrStyle = "solid";
          }
          if (tableStyles.tableBorder["left-sz"] != null) {
            leftSz = (int.parse(tableStyles.tableBorder["left-sz"]!) / 2).toString();
          }
          if (tableStyles.tableBorder["left-color"] != null) {
            leftColor = "#${tableStyles.tableBorder["left-color"]}";
          }
          tableStyleHtml = "${tableStyleHtml}border-left: ${leftSz}px $leftBrStyle $leftColor; ";
          String bottomColor = "";
          String bottomBrStyle = "solid";
          String bottomSz = "";
          if (tableStyles.tableBorder["bottom-val"] != null) {
            bottomBrStyle = "solid";
          }
          if (tableStyles.tableBorder["bottom-sz"] != null) {
            bottomSz = (int.parse(tableStyles.tableBorder["bottom-sz"]!) / 2).toString();
          }
          if (tableStyles.tableBorder["bottom-color"] != null && tableStyles.tableBorder["bottom-color"] != "auto") {
            bottomColor = "#${tableStyles.tableBorder["bottom-color"]}";
          }
          tableStyleHtml = "${tableStyleHtml}border-bottom: ${bottomSz}px $bottomBrStyle $bottomColor; ";
          String rightColor = "";
          String rightBrStyle = "solid";
          String rightSz = "";
          if (tableStyles.tableBorder["right-val"] != null) {
            rightBrStyle = "solid";
          }
          if (tableStyles.tableBorder["right-sz"] != null) {
            rightSz = (int.parse(tableStyles.tableBorder["right-sz"]!) / 2).toString();
          }
          if (tableStyles.tableBorder["right-color"] != null && tableStyles.tableBorder["right-color"] != "auto") {
            rightColor = "#${tableStyles.tableBorder["right-color"]}";
          }
          tableStyleHtml = "${tableStyleHtml}border-right: ${rightSz}px $rightBrStyle $rightColor; ";
        }
      }
    }
    return tableStyleHtml;
  }

  ///Function for getting row styles
  static String getRowStyle(MsTable table, List<Styles> stylesList, bool isFirstRow, bool isLastRow) {
    String tableStyle = "";

    return tableStyle;
  }
  ///Function for getting cell styles
  static String getCellStyle(MsTable msTable, List<Styles> stylesList, bool isFirstRow, bool isLastRow, bool isFirstCol, bool isLastCol) {
    String tableStyleHtml = "";
    if (msTable.tblStyle.isNotEmpty) {
      Styles? tableStyles = stylesList.firstWhereOrNull((style) {
        return style.styleId == msTable.tblStyle;
      });
      if (tableStyles != null) {
        if (tableStyles.rowColStyles.isNotEmpty) {
          RowColStyles rowColStyles = RowColStyles("");
          if (isFirstRow) {
            var tempStyles = tableStyles.rowColStyles.firstWhereOrNull((style) {
              return style.applicableTo == "firstRow";
            });
            if (tempStyles != null) {
              rowColStyles = tempStyles;
            }
          } else if (isLastRow) {
            var tempStyles = tableStyles.rowColStyles.firstWhereOrNull((style) {
              return style.applicableTo == "lastRow";
            });
            if (tempStyles != null) {
              rowColStyles = tempStyles;
            }
          }
          if (rowColStyles.applicableTo.isNotEmpty) {
            String topColor = "";
            String topBrStyle = "solid";
            String topSz = "";
            if (rowColStyles.cellBorder["top-val"] != null) {
              topBrStyle = "solid";
            }
            if (rowColStyles.cellBorder["top-sz"] != null) {
              topSz = (int.parse(rowColStyles.cellBorder["top-sz"]!) / 2).toString();
            }
            if (rowColStyles.cellBorder["top-color"] != null && tableStyles.tableBorder["top-color"] != "auto") {
              topColor = "#${rowColStyles.cellBorder["top-color"]!}";
            }
            tableStyleHtml = "${tableStyleHtml}border-top: ${topSz}px $topBrStyle $topColor; ";
            String leftColor = "";
            String leftBrStyle = "solid";
            String leftSz = "";
            if (rowColStyles.cellBorder["left-val"] != null) {
              leftBrStyle = "solid";
            }
            if (rowColStyles.cellBorder["left-sz"] != null) {
              leftSz = (int.parse(rowColStyles.cellBorder["left-sz"]!) / 2).toString();
            }
            if (rowColStyles.cellBorder["left-color"] != null) {
              leftColor = "#${rowColStyles.cellBorder["left-color"]}";
            }
            tableStyleHtml = "${tableStyleHtml}border-left: ${leftSz}px $leftBrStyle $leftColor; ";
            String bottomColor = "";
            String bottomBrStyle = "solid";
            String bottomSz = "";
            if (rowColStyles.cellBorder["bottom-val"] != null) {
              bottomBrStyle = "solid";
            }
            if (rowColStyles.cellBorder["bottom-sz"] != null) {
              bottomSz = (int.parse(rowColStyles.cellBorder["bottom-sz"]!) / 2).toString();
            }
            if (rowColStyles.cellBorder["bottom-color"] != null && tableStyles.tableBorder["bottom-color"] != "auto") {
              bottomColor = "#${rowColStyles.cellBorder["bottom-color"]}";
            }
            tableStyleHtml = "${tableStyleHtml}border-bottom: ${bottomSz}px $bottomBrStyle $bottomColor; ";
            String rightColor = "";
            String rightBrStyle = "solid";
            String rightSz = "";
            if (rowColStyles.cellBorder["right-val"] != null) {
              rightBrStyle = "solid";
            }
            if (rowColStyles.cellBorder["right-sz"] != null) {
              rightSz = (int.parse(rowColStyles.cellBorder["right-sz"]!) / 2).toString();
            }
            if (rowColStyles.cellBorder["right-color"] != null && tableStyles.tableBorder["right-color"] != "auto") {
              rightColor = "#${rowColStyles.cellBorder["right-color"]}";
            }
            tableStyleHtml = "${tableStyleHtml}border-right: ${rightSz}px $rightBrStyle $rightColor; ";
            if (rowColStyles.shadingColor != null) {
              tableStyleHtml = "$tableStyleHtml background-color: #${rowColStyles.shadingColor};";
            }
            if (rowColStyles.textColor != null) {
              tableStyleHtml = "$tableStyleHtml color: #${rowColStyles.textColor};";
            }
          }
        }
      }
    }
    return tableStyleHtml;
  }

  ///Function for getting Foot and End notes
  RichText getFootEndNote(FootEndNote footEndNote, List<Styles> stylesList, String refNo) {
    TextStyle textStyle = const TextStyle(inherit: false);
    String tempSpanText = "$refNo ${footEndNote.text}";
    bool superScript = false;
    bool subScript = false;
    if (footEndNote.pStyle.isNotEmpty) {
      Styles? textStyles = stylesList.firstWhereOrNull((style) {
        return style.styleId == footEndNote.pStyle;
      });
      if (textStyles != null) {
        if (textStyles.fontSize != 0) {
          textStyle = textStyle.copyWith(fontSize: textStyles.fontSize.toDouble() / 2);
        }
        if (textStyles.formats.contains("italic")) {
          textStyle = textStyle.copyWith(fontStyle: FontStyle.italic);
        }
        if (textStyles.formats.contains("bold")) {
          textStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
        }
        if (textStyles.formats.contains("single-underline")) {
          textStyle = textStyle.copyWith(decoration: TextDecoration.underline);
        }
        if (textStyles.formats.contains("double-underline")) {
          textStyle = textStyle.copyWith(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.double);
        }
        if (textStyles.formats.contains("strike")) {
          textStyle = textStyle.copyWith(decoration: TextDecoration.lineThrough);
        }
        if (textStyles.formats.contains("subscript")) {
          subScript = true;
        }
        if (textStyles.formats.contains("superscript")) {
          superScript = true;
        }
        if (textStyles.textColor != null && textStyles.textColor != "auto") {
          Color selectedColor = Color(int.parse("FF${textStyles.textColor!}", radix: 16));

          textStyle = textStyle.copyWith(color: selectedColor);
        } else {
          textStyle = textStyle.copyWith(color: Colors.black);
        }
        if (textStyles.fonts.isNotEmpty) {
          textStyle = textStyle.copyWith(fontFamily: textStyles.fonts["ascii"]);
        }
      }
    }
    if (subScript || superScript) {
      double fontSize = textStyle.fontSize ?? 22;
      textStyle = textStyle.copyWith(fontSize: fontSize / 3).copyWith(color: Colors.grey);
      if (subScript) {
        return RichText(
            text: WidgetSpan(
          child: Transform.translate(
            offset: const Offset(0.0, 1.0),
            child: Text(
              tempSpanText,
              style: textStyle,
            ),
          ),
        ));
      } else {
        return RichText(
            text: WidgetSpan(
          child: Transform.translate(
            offset: const Offset(0.0, -3.0),
            child: Text(
              tempSpanText,
              style: textStyle,
            ),
          ),
        ));
      }
    } else {
      return RichText(text: TextSpan(text: tempSpanText, style: textStyle));
    }
  }
  ///Function for getting components
  static List<Widget> getComponents(GetComponentsParams params) {
    List<Widget> pageWidgets = [];
    if (params.component.runtimeType.toString() == "Paragraph") {
      List<MsTextSpan> textSpans = params.component.textSpans;
      List<MsImage> images = params.component.images;
      List<InlineSpan> paragraphWidget = [];
      for (int k = 0; k < (textSpans.length + images.length); k++) {
        MsTextSpan? textSpan = textSpans.firstWhereOrNull((span) {
          return span.pSeqNo == k;
        });
        MsImage? image = images.firstWhereOrNull((img) {
          return img.pSeqNo == k;
        });
        if (textSpan != null) {
          paragraphWidget.add(getTextSpan(textSpan, params.stylesList));
        }
        if (image != null) {
          if(kIsWeb){
            WebImages? webImage=params.webImages.firstWhereOrNull((img){
              return img.name == image.imagePath;
            });
            if(webImage!=null) {
              paragraphWidget.add(WidgetSpan(
                  child: Image.memory(
                    webImage.bytes,
                    width: image.cx / 12700,
                    height: image.cy / 12700,
                  )));
            }
          }else {
            paragraphWidget.add(WidgetSpan(
                child: Image.file(
                  File(image.imagePath),
                  width: image.cx / 12700,
                  height: image.cy / 12700,
                )));
          }
        }
      }
      pageWidgets.addAll(getRichText(params.component, paragraphWidget, params.stylesList, params.wordDocument));
    } else if (params.component.runtimeType.toString() == "MsTable") {
      MsTable msTable = params.component;

      String tableStyle = getTableStyle(msTable, params.stylesList);
      String htmlString = "<html><body>";

      htmlString = "$htmlString<table style='$tableStyle ; border-collapse: collapse;'>";
      for (int k = 0; k < msTable.rows.length; k++) {
        String rowStyle = getRowStyle(msTable, params.stylesList, msTable.rows[k].isFirstRow, msTable.rows[k].isLastRow);
        htmlString = "$htmlString<tr style='$rowStyle ; border-collapse: collapse;'>";
        String colSpan = "0";
        if (msTable.rows[k].gridSpan != null) {
          colSpan = msTable.rows[k].gridSpan.toString();
        }
        for (int l = 0; l < msTable.rows[k].cells.length; l++) {
          String cellStyle = getCellStyle(msTable, params.stylesList, msTable.rows[k].isFirstRow, msTable.rows[k].isLastRow,
              msTable.rows[k].isFirstCol, msTable.rows[k].isLastCol);
          htmlString = "$htmlString<td style='$cellStyle ; border-collapse: collapse;padding: 5px;' colSpan=$colSpan>";
          htmlString = htmlString + msTable.rows[k].cells[l].cellText;
          htmlString = "$htmlString</td>";
        }

        htmlString = "$htmlString</tr>";
      }

      htmlString = "$htmlString</table>";

      htmlString = '$htmlString</body></html>';
      pageWidgets.add(HtmlWidget(htmlString));
    }
    return pageWidgets;
  }
}
///To pass the parameters
class ProcessParagraphParams {
  ///Xml element
  xml.XmlElement paragraphElement;
  ///List of relationships
  List<Relationship> relationShips;
  ///Path details
  String wordOutputDirectory;
  ///List of styles
  List<Styles> stylesList;
  ///Document object
  Document wordDocument;
  ///Constructor
  ProcessParagraphParams(this.paragraphElement, this.relationShips, this.wordOutputDirectory, this.stylesList, this.wordDocument);
}
///To pass component parameters
class GetComponentsParams {
  ///component object
  dynamic component;
  ///List of styles
  List<Styles> stylesList;
  ///List of pages
  List<Widget> pageWidgets;
  ///Document object
  Document wordDocument;
  ///List of web images
  List<WebImages> webImages;
  ///Constructor
  GetComponentsParams(this.component, this.stylesList, this.pageWidgets, this.wordDocument,this.webImages);
}

///To pass table parameters
class ProcessWordTableParams {
  ///Table element
  xml.XmlElement tableElement;
  ///Constructor
  ProcessWordTableParams(this.tableElement);
}
