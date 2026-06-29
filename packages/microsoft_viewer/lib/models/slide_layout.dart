

class SlideLayout {
  List<dynamic> components = [];
  List<SlideLayoutParagraph> paragraphs = [];

  //List<PresentationPresetShapes> presetShapes=[];
  //List<PresentationCustomDiagram> customDiagrams=[];
  SlideLayout();
}

class SlideLayoutParagraph {
  String type;
  String idx;
  String sz;
  String anchor;
  String schemeClr;
  String? lumMod;
  String? lumOff;
  int defaultSz;
  double? x;
  double? y;
  int? width;
  int? height;

  SlideLayoutParagraph(this.type, this.idx, this.sz, this.anchor, this.schemeClr, this.defaultSz);
}
