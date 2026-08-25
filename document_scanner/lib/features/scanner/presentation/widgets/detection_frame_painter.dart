import 'package:flutter/material.dart';

/// Draws an animated corner-bracket outline representing detected
/// document edges, the way Adobe Scan-style scanners highlight a page.
class DetectionFramePainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;

  DetectionFramePainter({required this.color, this.cornerLength = 28, this.strokeWidth = 4});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final rect = Offset.zero & size;
    final corners = [
      [rect.topLeft, Offset(cornerLength, 0), Offset(0, cornerLength)],
      [rect.topRight, Offset(-cornerLength, 0), Offset(0, cornerLength)],
      [rect.bottomLeft, Offset(cornerLength, 0), Offset(0, -cornerLength)],
      [rect.bottomRight, Offset(-cornerLength, 0), Offset(0, -cornerLength)],
    ];

    for (final corner in corners) {
      final origin = corner[0];
      final dx = corner[1];
      final dy = corner[2];
      canvas.drawLine(origin, origin + dx, paint);
      canvas.drawLine(origin, origin + dy, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DetectionFramePainter oldDelegate) => oldDelegate.color != color;
}
