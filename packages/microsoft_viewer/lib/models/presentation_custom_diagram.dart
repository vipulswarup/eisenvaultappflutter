class PresentationCustomDiagram {
  List<PathAction> pathList = [];
  double x;
  double y;
  int width;
  int height;
  String? clrScheme;
  String? lumMod;
  String? lumOff;
  String? srgbClr;
  int? rotate;
  String? flipH;
  String? flipV;

  PresentationCustomDiagram(this.x, this.y, this.width, this.height);
}

class PathAction {
  List<Points> points;
  String type;

  PathAction(this.points, this.type);
}

class Points {
  double x;
  double y;

  Points(this.x, this.y);
}
