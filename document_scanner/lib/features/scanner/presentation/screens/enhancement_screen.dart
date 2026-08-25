import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/entities/scan_page.dart';
import '../providers/scan_session_provider.dart';

/// Enhancement screen with filter presets and manual brightness /
/// contrast / sharpness controls, all previewed live over the captured
/// page. The original capture is never overwritten — only the applied
/// [ScanPage] settings change, so re-processing stays possible later.
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

  @override
  void initState() {
    super.initState();
    final page = context.read<ScanSessionProvider>().activePage;
    _original = page;
    _filter = page?.filter ?? PageFilter.auto;
    _brightness = page?.brightness ?? 0;
    _contrast = page?.contrast ?? 0;
    _sharpness = page?.sharpness ?? 0;
  }

  Color get _previewColor {
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _previewColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6))],
                ),
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
                  onTap: () => setState(() => _filter = filter),
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
                _AdjustmentSlider(label: 'Brightness', value: _brightness, onChanged: (v) => setState(() => _brightness = v)),
                _AdjustmentSlider(label: 'Contrast', value: _contrast, onChanged: (v) => setState(() => _contrast = v)),
                _AdjustmentSlider(label: 'Sharpness', value: _sharpness, onChanged: (v) => setState(() => _sharpness = v)),
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
