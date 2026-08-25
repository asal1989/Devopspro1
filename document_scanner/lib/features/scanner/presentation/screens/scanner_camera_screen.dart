import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../providers/scan_session_provider.dart';
import '../widgets/detection_frame_painter.dart';

enum FlashMode { off, on, auto }

/// The live scanner camera. In this Phase 1 prototype the camera preview
/// and edge detection are simulated (no `camera`/OpenCV plugin wired up
/// yet), but the interaction model — detect, stabilize, auto-capture,
/// manual capture, flash, gallery import — matches the target product.
class ScannerCameraScreen extends StatefulWidget {
  const ScannerCameraScreen({super.key});

  @override
  State<ScannerCameraScreen> createState() => _ScannerCameraScreenState();
}

class _ScannerCameraScreenState extends State<ScannerCameraScreen> {
  bool _detected = false;
  bool _autoCapture = true;
  bool _capturing = false;
  FlashMode _flash = FlashMode.off;
  bool _frontCamera = false;
  Timer? _detectionTimer;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _startDetectionLoop();
  }

  void _startDetectionLoop() {
    setState(() => _detected = false);
    _detectionTimer?.cancel();
    _detectionTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _detected = true);
      if (_autoCapture) {
        Timer(const Duration(milliseconds: 700), () {
          if (mounted && _detected) _capture();
        });
      }
    });
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    super.dispose();
  }

  Color _simulatedCapture() {
    const palette = [Color(0xFFEFEAE0), Color(0xFFF2ECDF), Color(0xFFEAE6DC)];
    return palette[_random.nextInt(palette.length)];
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    context.read<ScanSessionProvider>().capturePage(_simulatedCapture());
    setState(() => _capturing = false);
    if (!mounted) return;
    context.push(AppRoutes.crop);
  }

  void _cycleFlash() {
    setState(() {
      _flash = FlashMode.values[(_flash.index + 1) % FlashMode.values.length];
    });
  }

  IconData get _flashIcon {
    switch (_flash) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.on:
        return Icons.flash_on_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = context.watch<ScanSessionProvider>().pageCount;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Simulated live preview
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _frontCamera
                        ? [const Color(0xFF232733), const Color(0xFF11131A)]
                        : [const Color(0xFF1B1E27), const Color(0xFF0D0E12)],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.description_outlined, size: 140, color: Colors.white.withOpacity(0.06)),
                ),
              ),
            ),

            // Detection frame
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: MediaQuery.of(context).size.width * 0.78,
                height: MediaQuery.of(context).size.width * 0.78 * 1.35,
                child: CustomPaint(
                  painter: DetectionFramePainter(
                    color: _detected ? const Color(0xFF23A26D) : Colors.white.withOpacity(0.85),
                  ),
                ),
              ),
            ),

            if (_capturing)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 100),
                  child: Container(color: Colors.white.withOpacity(0.85)),
                ),
              ),

            // Top bar
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  _CircleIconButton(icon: Icons.close_rounded, onTap: () => context.pop()),
                  const Spacer(),
                  _CircleIconButton(icon: _flashIcon, onTap: _cycleFlash),
                  const SizedBox(width: AppSpacing.sm),
                  _CircleIconButton(
                    icon: Icons.cameraswitch_rounded,
                    onTap: () => setState(() => _frontCamera = !_frontCamera),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (pageCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Text('$pageCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),

            // Status text
            Align(
              alignment: const Alignment(0, -0.28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(_detected),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Text(
                    _detected ? AppStrings.documentDetected : AppStrings.positionInFrame,
                    style: TextStyle(
                      color: _detected ? const Color(0xFF7BE3B4) : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.lg,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded, size: 16, color: Colors.white.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Text('Auto capture', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                      Switch(
                        value: _autoCapture,
                        onChanged: (v) {
                          setState(() => _autoCapture = v);
                          _startDetectionLoop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CircleIconButton(icon: Icons.photo_library_rounded, onTap: () => context.push(AppRoutes.crop)),
                      GestureDetector(
                        onTap: _capture,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                          ),
                        ),
                      ),
                      pageCount > 0
                          ? TextButton(
                              onPressed: () => context.push(AppRoutes.pages),
                              child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            )
                          : const SizedBox(width: 48),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
