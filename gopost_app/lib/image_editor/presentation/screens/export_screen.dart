import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:path_provider/path_provider.dart';

/// Full-screen export dialog for the GoPost image editor.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportFormat _format = ExportFormat.jpeg;
  int _quality = 85;
  ExportResolution _resolution = ExportResolution.original;
  double _dpi = 72;
  int _customWidth = 0;
  int _customHeight = 0;
  bool _exporting = false;
  double _progress = 0;
  bool _complete = false;
  String? _exportedPath;
  int _estimatedSize = 0;
  String? _exportError;

  bool get _showQualitySlider =>
      _format == ExportFormat.jpeg || _format == ExportFormat.webp;

  ExportConfig get _exportConfig => ExportConfig(
        format: _format,
        quality: _quality,
        resolution: _resolution,
        customWidth: _customWidth,
        customHeight: _customHeight,
        dpi: _dpi,
      );

  Future<void> _startExport() async {
    final canvasState = ref.read(canvasProvider);
    final canvasId = canvasState.canvas?.canvasId;
    if (canvasId == null) {
      setState(() {
        _exportError = 'No canvas to export';
      });
      return;
    }

    setState(() {
      _exporting = true;
      _progress = 0;
      _complete = false;
      _exportedPath = null;
      _exportError = null;
    });

    try {
      final exportRepo = ref.read(exportRepositoryProvider);
      final dir = await getApplicationDocumentsDirectory();
      final ext = _format.name;
      final path = '${dir.path}/gopost_export_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final result = await exportRepo.exportImage(
        canvasId,
        _exportConfig,
        path,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (!mounted) return;
      setState(() {
        _exporting = false;
        _progress = 1.0;
        _complete = true;
        _exportedPath = result.filePath;
        _estimatedSize = result.fileSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _progress = 0;
        _exportError = e.toString();
      });
    }
  }

  void _cancelExport() {
    setState(() {
      _exporting = false;
      _progress = 0;
    });
  }

  int _estimateFileSize() {
    final base = _format == ExportFormat.png ? 2048 : 512;
    final qualityFactor = _showQualitySlider ? (_quality / 100) : 1.0;
    return (base * qualityFactor).round() * 1024;
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '~${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '~${(bytes / 1024).round()} KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.editorBackground,
      appBar: AppBar(
        backgroundColor: AppColors.editorSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: AppColors.textPrimaryDark,
        ),
        title: const Text(
          'Export Image',
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _complete ? _buildSuccessView() : _buildExportForm(),
    );
  }

  Widget _buildExportForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFormatPicker(),
          const SizedBox(height: AppSpacing.xl),
          if (_showQualitySlider) ...[
            _buildQualitySlider(),
            const SizedBox(height: AppSpacing.lg),
          ],
          _buildResolutionDropdown(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _formatFileSize(_estimatedSize > 0 ? _estimatedSize : _estimateFileSize()),
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildDpiSelector(),
          if (_exportError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _exportError!,
              style: const TextStyle(
                color: AppColors.semanticError,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          if (_exporting) ...[
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.neutralSurfaceVariantDark,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _cancelExport,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.semanticError,
              ),
              child: const Text('Cancel'),
            ),
          ] else
            FilledButton(
              onPressed: _startExport,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
              ),
              child: const Text('Export'),
            ),
        ],
      ),
    );
  }

  Widget _buildFormatPicker() {
    return Row(
      children: [
        Expanded(
          child: _FormatCard(
            label: 'JPEG',
            isSelected: _format == ExportFormat.jpeg,
            onTap: () => setState(() => _format = ExportFormat.jpeg),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _FormatCard(
            label: 'PNG',
            isSelected: _format == ExportFormat.png,
            onTap: () => setState(() => _format = ExportFormat.png),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _FormatCard(
            label: 'WebP',
            isSelected: _format == ExportFormat.webp,
            onTap: () => setState(() => _format = ExportFormat.webp),
          ),
        ),
      ],
    );
  }

  Widget _buildQualitySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quality',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 14,
              ),
            ),
            Text(
              '$_quality%',
              style: const TextStyle(
                color: AppColors.brandPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.brandPrimary,
            inactiveTrackColor: AppColors.neutralSurfaceVariantDark,
            thumbColor: AppColors.brandPrimary,
          ),
          child: Slider(
            value: _quality.toDouble(),
            min: 1,
            max: 100,
            onChanged: (v) => setState(() => _quality = v.round()),
          ),
        ),
      ],
    );
  }

  Widget _buildResolutionDropdown() {
    const options = [
      (ExportResolution.original, 'Original'),
      (ExportResolution.res4k, '4K'),
      (ExportResolution.res1080p, '1080p'),
      (ExportResolution.res720p, '720p'),
      (ExportResolution.instagramSquare, 'Instagram Square'),
      (ExportResolution.instagramStory, 'Instagram Story'),
    ];

    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.neutralSurfaceVariantDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ExportResolution>(
          value: _resolution,
          dropdownColor: AppColors.editorSurface,
          style: const TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 14,
          ),
          isExpanded: true,
          items: options
              .map((e) => DropdownMenuItem(
                    value: e.$1,
                    child: Text(e.$2),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _resolution = v);
          },
        ),
      ),
    );
  }

  Widget _buildDpiSelector() {
    const dpis = [72.0, 150.0, 300.0];
    return Wrap(
      spacing: AppSpacing.sm,
      children: dpis
          .map((d) => FilterChip(
                label: Text('${d.toInt()} DPI'),
                selected: _dpi == d,
                onSelected: (_) => setState(() => _dpi = d),
                selectedColor: AppColors.brandPrimaryContainerDark,
                checkmarkColor: AppColors.brandPrimary,
                backgroundColor: AppColors.neutralSurfaceVariantDark,
                labelStyle: TextStyle(
                  color: _dpi == d
                      ? AppColors.brandPrimary
                      : AppColors.textPrimaryDark,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.semanticSuccessDark,
            size: 64,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Export complete',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _formatFileSize(_estimatedSize),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton(
            onPressed: () {
              if (_exportedPath != null) {
                // Share placeholder - path available when engine wired
              }
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
            ),
            child: const Text('Share'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimaryDark,
              side: const BorderSide(color: AppColors.neutralOutlineDark),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.editorSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.neutralOutlineDark,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.brandPrimary : AppColors.textPrimaryDark,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
