import 'package:flutter/material.dart';
import 'package:microsoft_viewer/models/presentation_custom_diagram.dart';

class CustomDiagram extends CustomPainter {
  final PresentationCustomDiagram presentationCustomDiagram;
  final double divisionFactor;
  final Color color;
  double fullWidth = 0;
  double fullHeight = 0;

  CustomDiagram(this.presentationCustomDiagram, this.divisionFactor, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    Path path = createPathFromData();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    double scaleFactor = 1;
    if (fullWidth > fullHeight) {
      scaleFactor = size.width / fullWidth;
    } else {
      scaleFactor = size.height / fullHeight;
    }
    canvas.scale(scaleFactor);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }

  Path createPathFromData() {
    Path path = Path();

    for (int i = 0; i < presentationCustomDiagram.pathList.length; i++) {
      double x = presentationCustomDiagram.pathList[i].points[0].x / divisionFactor;
      double y = presentationCustomDiagram.pathList[i].points[0].y / divisionFactor;
      double x1 = 0;
      double x2 = 0;
      double y1 = 0;
      double y2 = 0;
      if (presentationCustomDiagram.pathList[i].points.length > 2) {
        x1 = presentationCustomDiagram.pathList[i].points[1].x / divisionFactor;
        x2 = presentationCustomDiagram.pathList[i].points[2].x / divisionFactor;
        y1 = presentationCustomDiagram.pathList[i].points[1].y / divisionFactor;
        y2 = presentationCustomDiagram.pathList[i].points[2].y / divisionFactor;
      }
      if (x > fullWidth) {
        fullWidth = x;
      }
      if (y > fullHeight) {
        fullHeight = y;
      }
      if (x1 > fullWidth) {
        fullWidth = x1;
      }
      if (y1 > fullHeight) {
        fullHeight = y1;
      }
      if (x2 > fullWidth) {
        fullWidth = x2;
      }
      if (y2 > fullHeight) {
        fullHeight = y2;
      }
      switch (presentationCustomDiagram.pathList[i].type) {
        case "moveTo":
          path.moveTo(x, y);
          break;
        case "lnTo":
          path.lineTo(x, y);
          break;
        case "cubicBezTo":
          path.cubicTo(x, y, x1, y1, x2, y2);
          break;
      }
    }

    return path;
  }
}
