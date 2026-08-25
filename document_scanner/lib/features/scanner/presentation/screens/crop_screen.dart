import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../providers/scan_session_provider.dart';

/// Interactive crop screen: drag each corner, move the whole crop area,
/// rotate, reset, or re-run auto detection.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  // Corner positions as fractions (0..1) of the image box, in order:
  // top-left, top-right, bottom-right, bottom-left.
  List<Offset> _corners = const [
    Offset(0.08, 0.06),
    Offset(0.92, 0.06),
    Offset(0.92, 0.94),
    Offset(0.08, 0.94),
  ];
  int _rotation = 0;

  static const _defaultCorners = [
    Offset(0.08, 0.06),
    Offset(0.92, 0.06),
    Offset(0.92, 0.94),
    Offset(0.08, 0.94),
  ];

  static const _autoDetectCorners = [
    Offset(0.03, 0.02),
    Offset(0.97, 0.04),
    Offset(0.95, 0.98),
    Offset(0.05, 0.96),
  ];

  void _reset() => setState(() => _corners = List.of(_defaultCorners));

  void _autoDetect() => setState(() => _corners = List.of(_autoDetectCorners));

  void _rotate() => setState(() => _rotation = (_rotation + 90) % 360);

  void _apply(BuildContext context) {
    final session = context.read<ScanSessionProvider>();
    final active = session.activePage;
    if (active != null) {
      session.updateActivePage(active.copyWith(rotationDegrees: _rotation));
    }
    context.push(AppRoutes.enhance);
  }

  @override
  Widget build(BuildContext context) {
    final page = context.watch<ScanSessionProvider>().activePage;
    final docColor = page?.originalAssetColor ?? const Color(0xFFEFEAE0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.72,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedRotation(
                            turns: _rotation / 360,
                            duration: const Duration(milliseconds: 200),
                            child: Container(color: docColor),
                          ),
                        ),
                        CustomPaint(
                          size: size,
                          painter: _CropOverlayPainter(corners: _corners),
                        ),
                        for (var i = 0; i < _corners.length; i++)
                          _CornerHandle(
                            position: _corners[i],
                            size: size,
                            onDrag: (delta) {
                              setState(() {
                                final updated = _corners[i] +
                                    Offset(delta.dx / size.width, delta.dy / size.height);
                                _corners = List.of(_corners)
                                  ..[i] = Offset(
                                    updated.dx.clamp(0.0, 1.0),
                                    updated.dy.clamp(0.0, 1.0),
                                  );
                              });
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ToolButton(icon: Icons.rotate_90_degrees_ccw_rounded, label: 'Rotate', onTap: _rotate),
                _ToolButton(icon: Icons.crop_free_rounded, label: 'Auto detect', onTap: _autoDetect),
                _ToolButton(icon: Icons.restart_alt_rounded, label: 'Reset', onTap: _reset),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                    onPressed: () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _apply(context),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _CornerHandle extends StatelessWidget {
  final Offset position;
  final Size size;
  final void Function(Offset delta) onDrag;

  const _CornerHandle({required this.position, required this.size, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    const handleSize = 28.0;
    return Positioned(
      left: position.dx * size.width - handleSize / 2,
      top: position.dy * size.height - handleSize / 2,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: BoxDecoration(
            color: const Color(0xFF2F6FED),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final List<Offset> corners;
  _CropOverlayPainter({required this.corners});

  @override
  void paint(Canvas canvas, Size size) {
    final points = corners.map((c) => Offset(c.dx * size.width, c.dy * size.height)).toList();
    final path = Path()..addPolygon(points, true);

    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final fullPath = Path()..addRect(Offset.zero & size);
    canvas.drawPath(Path.combine(PathOperation.difference, fullPath, path), overlayPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF2F6FED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) => oldDelegate.corners != corners;
}
