import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:microsoft_viewer/domain/common_processor.dart';
import 'package:microsoft_viewer/domain/presentation_processor.dart';
import 'package:microsoft_viewer/domain/spreadsheet_processor.dart';
import 'package:microsoft_viewer/domain/word_processor.dart';
import 'package:microsoft_viewer/models/document.dart';
import 'package:microsoft_viewer/models/font_details.dart';
import 'package:microsoft_viewer/models/foot_end_note.dart';
import 'package:microsoft_viewer/models/presentation.dart';
import 'package:microsoft_viewer/models/relationship.dart';
import 'package:microsoft_viewer/models/spreadsheet.dart';
import 'package:microsoft_viewer/models/ss_color_schemes.dart';
import 'package:microsoft_viewer/models/ss_style.dart';
import 'package:microsoft_viewer/models/styles.dart';
import 'package:microsoft_viewer/models/web_images.dart';
import 'package:microsoft_viewer/utils/odttf.dart';
import 'package:microsoft_viewer/widget/progress_indicator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart' as xml;
import 'models/shared_string.dart';

///The main dart file that takes the bytes data passed and then parses the files and displays the information.
class MicrosoftViewer extends StatefulWidget {
  ///Bytes of the file
  final List<int> fileBytes;
  ///Is widget fixed height
  final bool fixedHeight;
  ///Scaling value
  final double scale;
   ///Constructor
   const MicrosoftViewer(this.fileBytes, this.fixedHeight,{this.scale=1.6,super.key});

  @override
  State<StatefulWidget> createState() => MicrosoftViewerState();
}
///Stateful widget of the package
class MicrosoftViewerState extends State<MicrosoftViewer> {
  ZipDecoder? _zipDecoder;
  ///Word directory
  String wordOutputDirectory = "";
  ///Spreadsheet directory
  String spreadSheetOutputDirectory = "";
  ///Presentation directory
  String presentationOutputDirectory = "";
  ///To store file type
  String fileType = "";
  ///To store archive file
  late Archive archive;
  ///List of relationships
  List<Relationship> relationShips = [];
  ///List of strings
  List<SharedString> sharedStrings = [];
  ///Element depth
  int elementDepth = 0;
  ///Sequence number
  int seqNo = 0;
  ///Document object
  Document wordDocument = Document("empty word document");
  ///Presentation object
  Presentation presentation = Presentation("empty presentation document");
  ///Spreadsheet object
  SpreadSheet spreadSheet = SpreadSheet("empty spread sheet");
  ///List of styles
  List<Styles> stylesList = [];
  ///List of word widgets
  List<Widget> wordWidgets = [];
  ///List of presentation widgets
  List<Widget> presentationWidgets = [];
  ///List of fonts
  List<FontDetails> fontList = [];
  ///List of foot notes
  List<FootEndNote> footNotes = [];
  ///List of endNotes
  List<FootEndNote> endNotes = [];
  ///List of spreadsheet styles
  List<SSStyle> spreadSheetStyles = [];
  ///List of spreadsheet widgets
  List<Widget> spreadSheetWidgets = [];
  ///List of spreadsheet color schemes
  List<SSColorSchemes> spreadSheetColorSchemes = [];
  ///List of web images
  List<WebImages> webImages=[];
  ///To show progress bar
  bool showProgressBar = true;
  ///Set when parsing fails so the spinner does not run forever.
  String? parseError;

  @override
  void initState() {
    parseAndShowData();
    super.initState();
  }

  void _finishWithError(String message) {
    if (!mounted) return;
    setState(() {
      showProgressBar = false;
      parseError = message;
    });
  }

  ///Function for parsing and showing data
  Future<void> parseAndShowData() async {
    try {
    _zipDecoder ??= ZipDecoder();
    archive = _zipDecoder!.decodeBytes(widget.fileBytes);
    await setupDirectory();
    if (archive.any((archiveFile) {
      return archiveFile.name == 'word/document.xml';
    })) {
      fileType = "word";
    } else if (archive.any((archiveFile) {
      return archiveFile.name == 'xl/workbook.xml';
    })) {
      setState(() {
        fileType = "spreadsheet";
      });
    } else if (archive.any((archiveFile) {
      return archiveFile.name == 'ppt/presentation.xml';
    })) {
      setState(() {
        fileType = "presentation";
      });
    } else {
      _finishWithError('Unsupported document format');
      return;
    }
    if (fileType == "word") {
      var relFile = archive.singleWhere((archiveFile) {
        return archiveFile.name.endsWith("document.xml.rels");
      });
      getRelationships(relFile);
      var mediaFile = archive.where((archiveFile) {
        return archiveFile.name.startsWith('word/media/');
      });
      webImages=[];
      for (var medFile in mediaFile) {
        if(kIsWeb){
          final String mediaName = medFile.name.split("/").last;
          webImages.add(WebImages(mediaName, medFile.content));
        }else {
          extractMedia(medFile, wordOutputDirectory);
        }
      }
      var stylesFile = archive.singleWhere((archiveFile) {
        return archiveFile.name.endsWith("word/styles.xml");
      });
      Map<String, String> defaultValues = {};
      CommonProcessor().processStylesFile(stylesFile, stylesList, defaultValues);
      if (defaultValues.isNotEmpty) {
        if (defaultValues["fontSize"] != null) {
          wordDocument.defaultFontSize = int.parse(defaultValues["fontSize"]!);
        }
        if (defaultValues["lineSpacing"] != null) {
          wordDocument.defaultLineSpacing = int.parse(defaultValues["lineSpacing"]!);
        }
      }
      var fontTable = archive.singleWhereOrNull((archiveFile) {
        return archiveFile.name.endsWith("word/fontTable.xml");
      });
      if (fontTable != null) {
        var fontTableRel = archive.singleWhereOrNull((archiveFile) {
          return archiveFile.name.endsWith("_rels/fontTable.xml.rels");
        });
        if (fontTableRel != null) {
          CommonProcessor().processFonts(fontList, fontTable, fontTableRel);
          for (int i = 0; i < fontList.length; i++) {
            var fontFile = archive.singleWhereOrNull((archiveFile) {
              return archiveFile.name.endsWith(fontList[i].fileName);
            });
            if (fontFile != null) {
              String? fontKey = fontList[i].fontKey.replaceAll("{", "").replaceAll("}", "");
              await loadFonts(fontFile, fontList[i].name, fontKey);
            }
          }
        }
      }
      var footNoteFile = archive.singleWhereOrNull((archiveFile) {
        return archiveFile.name.endsWith("footnotes.xml");
      });
      var endNoteFile = archive.singleWhereOrNull((archiveFile) {
        return archiveFile.name.endsWith("endnotes.xml");
      });
      WordProcessor().processFootEndNotes(footNoteFile, endNoteFile, footNotes, endNotes);
      var wordFile = archive.singleWhere((archiveFile) {
        return archiveFile.name == 'word/document.xml';
      });
      await WordProcessor().processWordFile(wordFile, elementDepth, relationShips, wordOutputDirectory, stylesList, wordDocument, fileType);
      List<Widget> tempWidgets = await WordProcessor().displayWordFile(fileType, wordDocument, stylesList, footNotes, endNotes,webImages);
      setState(() {
        wordWidgets = tempWidgets;
        showProgressBar = false;
      });
    } else if (fileType == "spreadsheet") {
      var relFile = archive.singleWhere((archiveFile) {
        return archiveFile.name.endsWith("workbook.xml.rels");
      });
      getRelationships(relFile);
      var stylesFile = archive.singleWhereOrNull((archiveFile) {
        return archiveFile.name.endsWith("xl/styles.xml");
      });
      if (stylesFile != null) {
        spreadSheetStyles = [];
        SpreadsheetProcessor().processSpreadSheetStyles(stylesFile, spreadSheetStyles);
      }
      var themRel = relationShips.firstWhereOrNull((rel) {
        return rel.target.startsWith("theme/theme");
      });
      if (themRel != null) {
        var themeFile = archive.singleWhereOrNull((archiveFile) {
          return archiveFile.name.endsWith(themRel.target);
        });
        if (themeFile != null) {
          spreadSheetColorSchemes = [];
          SpreadsheetProcessor().processColorSchemes(themeFile, spreadSheetColorSchemes);
        }
      }

      var shareStringsFile = archive.singleWhere((archiveFile) {
        return archiveFile.name.endsWith("sharedStrings.xml");
      });
      getSharedStrings(shareStringsFile);
      var workbookFile = archive.singleWhere((archiveFile) {
        return archiveFile.name.endsWith("xl/workbook.xml");
      });

      SpreadsheetProcessor().getSpreadSheetDetails(workbookFile, spreadSheet);
      await SpreadsheetProcessor().readAllSheets(spreadSheet, relationShips, archive);
      List<Widget> tempWidgets =
          await SpreadsheetProcessor().displaySpreadSheet(spreadSheet, sharedStrings, spreadSheetStyles, spreadSheetColorSchemes);
      setState(() {
        spreadSheetWidgets = tempWidgets;
        showProgressBar = false;
      });
    } else if (fileType == "presentation") {
      var relFile = archive.singleWhere((archiveFile) {
        return archiveFile.name.endsWith("presentation.xml.rels");
      });
      getRelationships(relFile);
      var mediaFile = archive.where((archiveFile) {
        return archiveFile.name.startsWith('ppt/media/');
      });
      webImages=[];
      for (var medFile in mediaFile) {
        if(kIsWeb){
          final String mediaName = medFile.name.split("/").last;
          webImages.add(WebImages(mediaName, medFile.content));
        }else {
          extractMedia(medFile, presentationOutputDirectory);
        }
      }
      var presentationFile = archive.singleWhere((archiveFile) {
        return archiveFile.name.endsWith("ppt/presentation.xml");
      });
      PresentationProcessor().getPresentationDetails(presentationFile, presentation);
      await PresentationProcessor().readAllSlides(presentation, relationShips, archive, presentationOutputDirectory);
      List<Widget> tempWidgets = await PresentationProcessor().displayPresentation(presentation,webImages);
      setState(() {
        presentationWidgets = tempWidgets;
        showProgressBar = false;
      });
    }
    } catch (e, stackTrace) {
      debugPrint('MicrosoftViewer parse error: $e\n$stackTrace');
      _finishWithError('Could not render this document.');
    }
  }
  ///Function for setting up directory
  Future<void> setupDirectory() async {
    if(kIsWeb){

    }else {
      var applicationSupportDirectory = await getApplicationSupportDirectory();
      wordOutputDirectory = "${applicationSupportDirectory.path}/word/";
      spreadSheetOutputDirectory = "${applicationSupportDirectory.path}/spreadSheet/";
      presentationOutputDirectory = "${applicationSupportDirectory.path}/presentation/";
      var wordDir = Directory(wordOutputDirectory);
      if (wordDir.existsSync()) {
        wordDir.deleteSync(recursive: true);
      }
      wordDir.createSync(recursive: true);
      var xlsDir = Directory(spreadSheetOutputDirectory);
      if (xlsDir.existsSync()) {
        xlsDir.deleteSync(recursive: true);
      }
      xlsDir.createSync(recursive: true);
      var pptDir = Directory(presentationOutputDirectory);
      if (pptDir.existsSync()) {
        pptDir.deleteSync(recursive: true);
      }
      pptDir.createSync(recursive: true);
    }
  }
  ///Function for getting relationships
  void getRelationships(ArchiveFile relFile) {
    final fileContent = utf8.decode(relFile.content);

    final document = xml.XmlDocument.parse(fileContent);
    final relationshipsElement = document.findAllElements("Relationship");
    relationShips = [];
    for (var rel in relationshipsElement) {
      if (rel.getAttribute("Id") != null) {
        relationShips.add(Relationship(rel.getAttribute("Id").toString(), rel.getAttribute("Target").toString()));
      }
    }
  }
  ///Function for getting strings
  void getSharedStrings(ArchiveFile shareStringsFile) {
    final fileContent = utf8.decode(shareStringsFile.content);
    final document = xml.XmlDocument.parse(fileContent);
    sharedStrings = [];
    int index = 0;
    document.findAllElements('si').forEach((node) {
      sharedStrings.add(SharedString(index, node.getElement("t")?.innerText ?? ""));
      index++;
    });
  }
  ///Function for extracting media files
  Future<void> extractMedia(ArchiveFile mediaFile, String dirPath) async {
    final String outputFilePath = dirPath + mediaFile.name.split("/").last;
    final File outFile = File(outputFilePath);
    await outFile.writeAsBytes(mediaFile.content as List<int>);
  }
  ///Function for loading fonts
  Future<void> loadFonts(ArchiveFile fontFile, String fontFamily, String fileName) async {
    ODTTF().deobfuscate(fontFile.content, fileName);
    var fontLoader = FontLoader(fontFamily)..addFont(getBytes(fontFile));
    await fontLoader.load();
  }
  ///Function for getting bytes
  Future<ByteData> getBytes(ArchiveFile fontFile) async {
    return ByteData.view(fontFile.content.buffer);
  }

  @override
  Widget build(BuildContext context) {
    if (parseError != null) {
      return customWidget(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              parseError!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return customWidget(
      LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          children: [
            InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.1,
              maxScale: 1.6,
              child: Container(
                color: Colors.grey,
                height: 700,
                width: 500,
                child: SingleChildScrollView(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: fileType == "word"
                      ? wordWidgets
                      : fileType == "spreadsheet"
                          ? spreadSheetWidgets
                          : presentationWidgets,
                )),
              ),
            ),
            showProgressBar ? ProgressIndicatorView(constraints.maxHeight, constraints.maxWidth) : Container()
          ],
        );
      }),
    );
  }
  ///Custom widget for showing fixed height
  Widget customWidget(Widget child) {
    if (!widget.fixedHeight) {
      return Expanded(child: child);
    } else {
      return Column(
        children: [
          Expanded(child: child),
        ],
      );
    }
  }
}
