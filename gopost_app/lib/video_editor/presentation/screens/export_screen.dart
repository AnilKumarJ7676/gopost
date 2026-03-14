import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gopost_app/video_editor/domain/models/export_config.dart';
import 'package:gopost_app/video_editor/presentation/providers/export_notifier.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(exportNotifierProvider);
    final notifier = ref.read(exportNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Video'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: state.isExporting ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: state.isExporting
            ? _buildProgress(state, notifier, theme, scheme)
            : state.result != null
                ? _buildResult(state, notifier, theme, scheme)
                : _buildPresetPicker(state, notifier, theme, scheme),
      ),
    );
  }

  Widget _buildPresetPicker(
    ExportState state,
    ExportNotifier notifier,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final estimatedSize = notifier.estimateFileSize();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Choose Export Preset',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a platform-optimized preset or customize your export settings.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ...ExportPreset.all.map((preset) => _PresetCard(
                preset: preset,
                isSelected: state.selectedPreset == preset.id,
                onTap: () => notifier.selectPreset(preset.id),
              )),
            ],
          ),
        ),
        _buildExportFooter(state, notifier, estimatedSize, theme, scheme),
      ],
    );
  }

  Widget _buildExportFooter(
    ExportState state,
    ExportNotifier notifier,
    int estimatedSize,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final preset = ExportPreset.byId(state.selectedPreset);
    final sizeStr = _formatBytes(estimatedSize);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: scheme.outlineVariant, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${preset.width} x ${preset.height} @ ${preset.frameRate.round()} fps',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Text(
                'Est. size: $sizeStr',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${preset.videoCodec.label} / ${preset.audioCodec.label}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Text(
                preset.container.label,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Text(state.error!, style: TextStyle(color: scheme.error, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: notifier.startExport,
            icon: const Icon(Icons.file_download, size: 18),
            label: const Text('Start Export'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(
    ExportState state,
    ExportNotifier notifier,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final p = state.progress;
    final phaseLabel = switch (p.phase) {
      ExportPhase.preparing => 'Preparing...',
      ExportPhase.encoding => 'Encoding video...',
      ExportPhase.muxing => 'Muxing audio & video...',
      ExportPhase.finalizing => 'Finalizing...',
      ExportPhase.cancelled => 'Cancelled',
      _ => 'Processing...',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: p.percent / 100,
                      strokeWidth: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  Text(
                    '${p.percent.toInt()}%',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(phaseLabel, style: theme.textTheme.titleMedium),
            if (p.estimatedRemaining != null) ...[
              const SizedBox(height: 8),
              Text(
                'About ${_formatDuration(p.estimatedRemaining!)} remaining',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Elapsed: ${_formatDuration(p.elapsed)}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: notifier.cancelExport,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(
    ExportState state,
    ExportNotifier notifier,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final result = state.result!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Export Complete!', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            _InfoRow(label: 'Size', value: result.fileSizeFormatted),
            _InfoRow(label: 'Duration', value: '${result.durationSeconds.toStringAsFixed(1)}s'),
            _InfoRow(label: 'Resolution', value: '${result.width} x ${result.height}'),
            _InfoRow(label: 'Export time', value: _formatDuration(result.exportTime)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.filePath.split('/').last,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    notifier.reset();
                    context.pop();
                  },
                  child: const Text('Done'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _shareFile(result.filePath),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _shareFile(String path) {
    // Open the file's parent directory on desktop, or use share sheet on mobile
    final dir = File(path).parent.path;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      Process.run('open', [dir]).catchError((_) {});
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }
}

class _PresetCard extends StatelessWidget {
  final ExportPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide(color: scheme.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _iconForPreset(preset.id),
                  size: 20,
                  color: isSelected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${preset.width}x${preset.height} / ${preset.videoCodec.label} / ${preset.videoBitrateMbps} Mbps',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: scheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForPreset(ExportPresetId id) => switch (id) {
    ExportPresetId.instagramReel => Icons.camera,
    ExportPresetId.tiktok => Icons.music_video,
    ExportPresetId.youtube4k => Icons.four_k,
    ExportPresetId.youtube1080p => Icons.hd,
    ExportPresetId.generalHd => Icons.high_quality,
    ExportPresetId.custom => Icons.tune,
  };
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}
