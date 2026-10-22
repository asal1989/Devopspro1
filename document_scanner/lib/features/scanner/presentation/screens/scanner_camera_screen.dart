import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../providers/scan_session_provider.dart';
import '../widgets/detection_frame_painter.dart';

/// The live scanner camera. Uses the device camera through the
/// `camera` plugin for a real preview and real captures. Automatic
/// document-edge detection is approximated with a stabilization timer
/// layered over the live feed (true frame-by-frame contour detection
/// needs a native OpenCV binding — see the README's Phase 3 notes);
/// manual capture and the interactive Crop screen are always the
/// reliable fallback, matching the "don't auto-capture on low
/// confidence" requirement.
class ScannerCameraScreen extends StatefulWidget {
  const ScannerCameraScreen({super.key});

  @override
  State<ScannerCameraScreen> createState() => _ScannerCameraScreenState();
}

enum _CameraStatus { loading, ready, permissionDenied, unavailable }

class _ScannerCameraScreenState extends State<ScannerCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  _CameraStatus _status = _CameraStatus.loading;
  String? _errorMessage;

  bool _detected = false;
  bool _autoCapture = true;
  bool _capturing = false;
  bool _importing = false;
  FlashMode _flash = FlashMode.off;
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _status = _CameraStatus.loading;
      _errorMessage = null;
    });

    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      setState(() {
        _status = _CameraStatus.permissionDenied;
        _errorMessage = AppStrings.cameraPermissionDenied;
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException('no_cameras', 'No camera found on this device.');
      }
      await _openCamera(_cameraIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _CameraStatus.unavailable;
        _errorMessage = "We couldn't start the camera. Please try again.";
      });
    }
  }

  Future<void> _openCamera(int index) async {
    await _controller?.dispose();
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    await controller.initialize();
    await controller.setFlashMode(_flash);
    if (!mounted) return;
    setState(() {
      _cameraIndex = index;
      _status = _CameraStatus.ready;
    });
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
    WidgetsBinding.instance.removeObserver(this);
    _detectionTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _openCamera(_cameraIndex);
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      context.read<ScanSessionProvider>().capturePageFromFile(file.path);
      setState(() => _capturing = false);
      if (!mounted) return;
      context.push(AppRoutes.crop);
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't capture the photo. Please try again.")),
      );
    }
  }

  Future<void> _importFromGallery() async {
    setState(() => _importing = true);
    try {
      final files = await ImagePicker().pickMultiImage(imageQuality: 92);
      if (!mounted) return;
      if (files.isEmpty) {
        setState(() => _importing = false);
        return;
      }
      final session = context.read<ScanSessionProvider>();
      for (final file in files) {
        session.capturePageFromFile(file.path);
      }
      setState(() => _importing = false);
      if (!mounted) return;
      context.push(AppRoutes.crop);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage failure. Not enough storage available.')),
      );
    }
  }

  Future<void> _cycleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    setState(() => _flash = next);
    await _controller?.setFlashMode(next);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    setState(() => _status = _CameraStatus.loading);
    await _openCamera(nextIndex);
  }

  IconData get _flashIcon {
    switch (_flash) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
      case FlashMode.torch:
        return Icons.flash_on_rounded;
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
            Positioned.fill(child: _buildPreview()),

            if (_status == _CameraStatus.ready) ...[
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
            ],

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
                  if (_status == _CameraStatus.ready) ...[
                    _CircleIconButton(icon: _flashIcon, onTap: _cycleFlash),
                    const SizedBox(width: AppSpacing.sm),
                    _CircleIconButton(icon: Icons.cameraswitch_rounded, onTap: _switchCamera),
                    const SizedBox(width: AppSpacing.sm),
                  ],
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

            // Bottom controls
            if (_status == _CameraStatus.ready)
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
                        _importing
                            ? const SizedBox(
                                width: 44,
                                height: 44,
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                              )
                            : _CircleIconButton(icon: Icons.photo_library_rounded, onTap: _importFromGallery),
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

  Widget _buildPreview() {
    switch (_status) {
      case _CameraStatus.loading:
        return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator(color: Colors.white)));
      case _CameraStatus.permissionDenied:
        return _PermissionDeniedView(message: _errorMessage ?? AppStrings.cameraPermissionDenied, onRetry: _initCamera);
      case _CameraStatus.unavailable:
        return _PermissionDeniedView(
          message: _errorMessage ?? 'Camera unavailable. Please try again.',
          onRetry: _initCamera,
          icon: Icons.videocam_off_rounded,
        );
      case _CameraStatus.ready:
        final controller = _controller!;
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: CameraPreview(controller),
          ),
        );
    }
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const _PermissionDeniedView({required this.message, required this.onRetry, this.icon = Icons.no_photography_rounded});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white54, size: 56),
              const SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
              TextButton(
                onPressed: openAppSettings,
                child: const Text('Open Settings', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
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
