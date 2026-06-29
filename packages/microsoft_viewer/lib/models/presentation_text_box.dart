import 'dart:ui';

import 'package:microsoft_viewer/models/presentation_paragraph.dart';

///Class for storing details of text boxes
class PresentationTextBox {
  ///Offset for textbox
  Offset offset;

  ///Size of the textbox
  Size size;

  //String? align;

  ///List of paragraph in a textbox
  List<PresentationParagraph> presentationParas = [];

  ///Constructor
  PresentationTextBox(this.offset, this.size);
}
