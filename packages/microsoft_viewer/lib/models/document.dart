import 'dart:ui';

import 'package:microsoft_viewer/models/word_page.dart';

///Class for storing word related details
class Document {
  ///Name of the document
  String name;

  ///Page size details
  Size pageSize = const Size(0, 0);

  ///Page margin details
  Map<String, double> pageMargin = {};

  ///Default fontSize
  int defaultFontSize = 0;

  /// Default line spacing
  int defaultLineSpacing = 0;

  ///List of pages in a document
  List<WordPage> pages = [];
  ///Constructor
  Document(this.name);
}
