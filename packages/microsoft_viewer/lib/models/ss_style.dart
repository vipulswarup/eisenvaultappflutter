class SSStyle {
  String id;
  NumFormat numFormat;
  SSFont ssFont;
  SSFill ssFill;
  SSBorder border;
  String alignmentVer;
  String alignmentHorizontal;
  String alignmentWrapText;

  SSStyle(this.id, this.numFormat, this.ssFont, this.ssFill, this.border, this.alignmentVer, this.alignmentHorizontal, this.alignmentWrapText);
}

class NumFormat {
  String id;
  String format;

  NumFormat(this.id, this.format);
}

class SSFont {
  String id;
  String name;
  int size;
  String colorTheme;
  String colorTint;

  SSFont(this.id, this.name, this.size, this.colorTheme, this.colorTint);
}

class SSFill {
  String id;
  String patternType;
  String fgClrTheme;
  String fgClrTint;
  String bgClrIndex;

  SSFill(this.id, this.patternType, this.fgClrTheme, this.fgClrTint, this.bgClrIndex);
}

class SSBorder {
  String id;
  String leftStyle;
  String leftClrTheme;
  String leftClrTint;
  String rightStyle;
  String rightClrTheme;
  String rightClrTint;
  String topStyle;
  String topClrTheme;
  String topClrTint;
  String bottomStyle;
  String bottomClrTheme;
  String bottomClrTint;

  SSBorder(this.id, this.leftStyle, this.leftClrTheme, this.leftClrTint, this.rightStyle, this.rightClrTheme, this.rightClrTint, this.topStyle,
      this.topClrTheme, this.topClrTint, this.bottomStyle, this.bottomClrTheme, this.bottomClrTint);
}
