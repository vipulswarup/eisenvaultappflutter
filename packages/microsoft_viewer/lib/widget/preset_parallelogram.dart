import 'package:flutter/material.dart';

class PresetParallelogram extends CustomPainter {
  final int skewValue;
  final Color color;
  final double divisionalFactor;

  PresetParallelogram(this.skewValue, this.color, this.divisionalFactor);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Define the parallelogram vertices
    double width = size.width;
    double height = size.height;

    // Adjust this according to the 'adj' value from XML, interpreting it as skew
    double skew = skewValue / (divisionalFactor * 2); // Arbitrary scale down, adjust as needed

    Path path = Path()
      ..moveTo(0 + skew * height, 0) // Top-left
      ..lineTo(width, 0) // Top-right
      ..lineTo(width - skew * height, height) // Bottom-right
      ..lineTo(0, height) // Bottom-left
      ..close(); // Close the path

    // Draw the parallelogram
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
