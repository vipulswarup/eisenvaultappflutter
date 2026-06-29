///Class for storing details regarding text in word document.
class MsTextSpan {
  int pSeqNo;
  String text;
  String style;
  int fontSize;
  List<String> formats;
  String textColor;
  String highlightColor;
  String shadingColor;
  Map<String, String> fonts;

  MsTextSpan(this.pSeqNo, this.text, this.style, this.formats, this.fontSize, this.textColor, this.highlightColor, this.fonts, this.shadingColor);
}
