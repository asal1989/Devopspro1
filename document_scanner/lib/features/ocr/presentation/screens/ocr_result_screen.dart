import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../documents/domain/entities/document.dart';
import '../../domain/entities/ocr_result.dart';

/// Runs (simulated, on-device) text recognition on a document and shows
/// the result in an easy-to-read, editable view.
class OcrResultScreen extends StatefulWidget {
  final ScannedDocument? document;
  const OcrResultScreen({super.key, this.document});

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  OcrLanguage _language = OcrLanguage.english;
  bool _extracting = false;
  bool _editing = false;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.document?.extractedText ?? '');
    if (_textController.text.isEmpty) {
      _runExtraction();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runExtraction() async {
    setState(() => _extracting = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _extracting = false;
      if (_textController.text.isEmpty) {
        _textController.text =
            'This is the recognized text from your scanned document. Tap "Extract Text" to '
            're-run recognition, or edit this text directly before copying, sharing, or '
            'saving it as a .txt file.';
      }
    });
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _textController.text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text copied to clipboard')));
  }

  void _share() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening share sheet…')));
  }

  void _saveAsTxt() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved as TXT')));
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).extension<AppSemanticColors>()?.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Text'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
            tooltip: 'Edit',
            onPressed: () => setState(() => _editing = !_editing),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Text('Language', style: TextStyle(color: secondary)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: OcrLanguage.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final lang = OcrLanguage.values[index];
                        final selected = lang == _language;
                        return ChoiceChip(
                          label: Text(lang.label),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _language = lang);
                            _runExtraction();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _extracting
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: TextField(
                        controller: _textController,
                        readOnly: !_editing,
                        maxLines: null,
                        style: const TextStyle(height: 1.5, fontSize: 15),
                        decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _extracting ? null : _runExtraction,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Extract Text'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Row(
              children: [
                Expanded(child: _MiniAction(icon: Icons.copy_rounded, label: 'Copy', onTap: _copy)),
                Expanded(child: _MiniAction(icon: Icons.share_rounded, label: 'Share', onTap: _share)),
                Expanded(child: _MiniAction(icon: Icons.save_alt_rounded, label: 'Save TXT', onTap: _saveAsTxt)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MiniAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
