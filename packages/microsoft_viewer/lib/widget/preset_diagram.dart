import 'dart:math';

import 'package:flutter/material.dart';
import 'package:microsoft_viewer/models/presentation_preset_shapes.dart';

class PresetDiagram extends CustomPainter {
  final PresentationPresetShapes presetShapes;
  final double divisionFactor;
  final Color color;

  PresetDiagram(this.presetShapes, this.divisionFactor, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = double.parse(presetShapes.adjValue3!.replaceAll("val ", "")) / 1000;

    Rect rect = Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.height / 2);
    double adj1 = double.parse(presetShapes.adjValue.replaceAll("val ", "")) / divisionFactor;
    double startAngle = adj1 * pi / adj1;
    double adj2 = double.parse(presetShapes.adjValue2!.replaceAll("val ", "")) / divisionFactor;
    double sweepAngle = adj2 * pi / adj2;
    bool useCenter = false;
    canvas.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
