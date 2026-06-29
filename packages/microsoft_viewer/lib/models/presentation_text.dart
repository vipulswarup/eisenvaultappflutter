///Class for storing text in presentation
class PresentationText {
  ///Text of the presentation
  String text;

  ///Font size of the text
  double fontSize;

  String? colorScheme;

  String? lumMod;
  String? lumOff;

  bool isBold = false;

  ///Constructor
  PresentationText(this.text, this.fontSize);
}
