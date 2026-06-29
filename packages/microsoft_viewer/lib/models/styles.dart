///Class for storing styles information.
class Styles {
  String name;
  String type;
  String styleId;
  int firstLineInd = 0;
  int leftInd = 0;
  Map<String, String> fonts = {};
  int fontSize = 0;
  bool? keepNext;
  bool? keepLines;
  bool? pageBreakBefore;
  int spacingBefore = 0;
  int spacingAfter = 0;
  int outlineLvl = 0;
  Map<String, String> tableBorder = {};
  Map<String, String> paraGraphBorder = {};
  List<String> formats = [];
  String? textColor;
  String? jc;
  List<RowColStyles> rowColStyles = [];

  Styles(this.name, this.type, this.styleId);
}

class RowColStyles {
  String applicableTo;
  int spacingBefore = 0;
  int spacingAfter = 0;
  int fontSize = 0;
  List<String> formats = [];
  String? textColor;
  String? cellFillColor;
  Map<String, String> cellBorder = {};
  Map<String, String> fonts = {};
  String? shadingColor;

  RowColStyles(this.applicableTo);
}
