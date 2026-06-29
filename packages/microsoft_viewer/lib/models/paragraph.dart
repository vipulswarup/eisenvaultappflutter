import 'package:microsoft_viewer/models/ms_image.dart';
import 'package:microsoft_viewer/models/ms_text_span.dart';

///Class for storing word paragraph details.
class Paragraph {
  int seqNo;
  String style;
  List<MsTextSpan> textSpans = [];
  List<MsImage> images = [];
  Map<String, String> tabDetails = {};
  String? shadingColor;
  Map<String, String>? formats;

  Paragraph(this.seqNo, this.style);
}
