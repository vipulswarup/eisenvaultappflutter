import 'package:microsoft_viewer/models/presentation_color_schemes.dart';
import 'package:microsoft_viewer/models/slide_layout.dart';

///Class for storing slide details in pptx.
class Slide {
  int id;
  String rId;
  String fileName;
  String backgroundImagePath = "";
  List<dynamic> components = [];

  //List<PresentationShape> presentationShapes = [];
  //List<PresentationTextBox> presentationTextBoxes = [];
  //List<PresentationCustomDiagram> presentationCustomDiagrams=[];
  List<PresentationColorSchemes> colorSchemes = [];

  //List<PresentationPresetShapes> presetShapes=[];
  Map<String, String> clearMap = {};
  SlideLayout? slideLayout;

  Slide(this.id, this.rId, this.fileName);
}
