import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../data/image_processor.dart';
import '../../domain/entities/scan_page.dart';
import '../providers/scan_session_provider.dart';

/// Enhancement screen with filter presets and manual brightness /
/// contrast / sharpness controls, previewed live over the captured
/// page. The original capture is never overwritten — [ImageProcessor]
/// always re-reads [ScanPage.originalImagePath] and only the applied
/// settings on [ScanPage] change, so re-processing stays possible.
class EnhancementScreen extends StatefulWidget {
  const EnhancementScreen({super.key});

  @override
  State<EnhancementScreen> createState() => _EnhancementScreenState();
}

class _EnhancementScreenState extends State<EnhancementScreen> {
  late PageFilter _filter;
  late double _brightness;
  late double _contrast;
  late double _sharpness;
  ScanPage? _original;
  Uint8List? _sourceBytes;
  Uint8List? _previewBytes;
  bool _processing = false;
  bool _failed = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final page = context.read<ScanSessionProvider>().activePage;
    _original = page;
    _filter = page?.filter ?? PageFilter.auto;
    _brightness = page?.brightness ?? 0;
    _contrast = page?.contrast ?? 0;
    _sharpness = page?.sharpness ?? 0;
    _loadSource();
  }

  Future<void> _loadSource() async {
    final path = _original?.originalImagePath;
    if (path == null) return;
    try {
      _sourceBytes = await File(path).readAsBytes();
      _scheduleProcessing();
    } catch (_) {
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleProcessing() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _runProcessing);
  }

  Future<void> _runProcessing() async {
    final source = _sourceBytes;
    if (source == null) return;
    setState(() => _processing = true);
    try {
      final result = await compute(
        processPageInIsolate,
        ProcessPageRequest(
          sourceBytes: source,
          cropCorners: _original?.cropCorners,
          rotationDegrees: _original?.rotationDegrees ?? 0,
          filter: _filter,
          brightness: _brightness,
          contrast: _contrast,
          sharpness: _sharpness,
          jpegQuality: 85,
        ),
      );
      if (!mounted) return;
      setState(() {
        _previewBytes = result;
        _processing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _failed = true;
      });
    }
  }

  Color get _placeholderColor {
    final base = _original?.originalAssetColor ?? const Color(0xFFEFEAE0);
    switch (_filter) {
      case PageFilter.grayscale:
      case PageFilter.blackAndWhite:
        final gray = ((base.red + base.green + base.blue) / 3).round();
        return Color.fromARGB(255, gray, gray, gray);
      case PageFilter.highContrast:
        return Color.lerp(base, Colors.white, 0.15)!;
      case PageFilter.document:
        return Color.lerp(base, Colors.white, 0.3)!;
      case PageFilter.original:
      case PageFilter.color:
      case PageFilter.auto:
        return base;
    }
  }

  void _continue() {
    final session = context.read<ScanSessionProvider>();
    if (_original != null) {
      session.updateActivePage(_original!.copyWith(
        filter: _filter,
        brightness: _brightness,
        contrast: _contrast,
        sharpness: _sharpness,
      ));
    }
    context.push(AppRoutes.pages);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _original?.originalImagePath != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhance'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _filter = PageFilter.auto;
              _brightness = 0;
              _contrast = 0;
              _sharpness = 0;
              _scheduleProcessing();
            }),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: hasImage
                        ? (_previewBytes != null
                            ? Image.memory(_previewBytes!, fit: BoxFit.contain, gaplessPlayback: true)
                            : Container(color: _placeholderColor))
                        : AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _placeholderColor,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                          ),
                  ),
                  if (_processing)
                    const Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  if (_failed)
                    Container(
                      color: Colors.black.withOpacity(0.55),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: const Text(
                        "We couldn't process this image. The original is safe — try again.",
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: PageFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final filter = PageFilter.values[index];
                final selected = filter == _filter;
                return GestureDetector(
                  onTap: () => setState(() {
                    _filter = filter;
                    _scheduleProcessing();
                  }),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _original?.originalAssetColor ?? const Color(0xFFEFEAE0),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(
                            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(filter.label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                _AdjustmentSlider(
                  label: 'Brightness',
                  value: _brightness,
                  onChanged: (v) => setState(() {
                    _brightness = v;
                    _scheduleProcessing();
                  }),
                ),
                _AdjustmentSlider(
                  label: 'Contrast',
                  value: _contrast,
                  onChanged: (v) => setState(() {
                    _contrast = v;
                    _scheduleProcessing();
                  }),
                ),
                _AdjustmentSlider(
                  label: 'Sharpness',
                  value: _sharpness,
                  onChanged: (v) => setState(() {
                    _sharpness = v;
                    _scheduleProcessing();
                  }),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Back')),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(onPressed: _continue, child: const Text('Add More Pages')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _AdjustmentSlider({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
          child: Slider(min: -50, max: 50, value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
