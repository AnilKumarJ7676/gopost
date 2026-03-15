import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// Crop aspect ratio option. Null means no crop (original).
class CropAspect {
  final String label;
  final double? widthRatio;
  final double? heightRatio;

  const CropAspect(this.label, this.widthRatio, this.heightRatio);
}

const List<CropAspect> kCropAspects = [
  CropAspect('Original', null, null),
  CropAspect('1:1', 1, 1),
  CropAspect('4:5', 4, 5),
  CropAspect('16:9', 16, 9),
];

/// Center-crops [image] to the given aspect ratio. Returns a new [DecodedImage].
/// If [aspectW] or [aspectH] is null, returns the image unchanged.
DecodedImage cropToAspect(
    DecodedImage image, double? aspectW, double? aspectH) {
  if (aspectW == null || aspectH == null) {
    return DecodedImage(
        width: image.width,
        height: image.height,
        pixels: Uint8List.fromList(image.pixels));
  }
  final w = image.width;
  final h = image.height;
  final aspect = aspectW / aspectH;
  int cropW;
  int cropH;
  if (aspect >= w / h) {
    cropW = w;
    cropH = (w / aspect).round().clamp(1, h);
  } else {
    cropH = h;
    cropW = (h * aspect).round().clamp(1, w);
  }
  final x0 = ((w - cropW) / 2).round().clamp(0, w - 1);
  final y0 = ((h - cropH) / 2).round().clamp(0, h - 1);
  final out = Uint8List(cropW * cropH * 4);
  for (int y = 0; y < cropH; y++) {
    final srcRow = (y0 + y) * w * 4;
    final dstRow = y * cropW * 4;
    for (int x = 0; x < cropW; x++) {
      final src = srcRow + (x0 + x) * 4;
      final dst = dstRow + x * 4;
      out[dst] = image.pixels[src];
      out[dst + 1] = image.pixels[src + 1];
      out[dst + 2] = image.pixels[src + 2];
      out[dst + 3] = image.pixels[src + 3];
    }
  }
  return DecodedImage(width: cropW, height: cropH, pixels: out);
}

/// Panel to apply center crop by aspect ratio and replace canvas with result.
class CropPanel extends ConsumerStatefulWidget {
  const CropPanel({super.key});

  @override
  ConsumerState<CropPanel> createState() => _CropPanelState();
}

class _CropPanelState extends ConsumerState<CropPanel> {
  int _selectedIndex = 0;
  bool _isApplying = false;

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final canvasId = canvasState.canvas?.canvasId;

    return Container(
      height: 120,
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Crop',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(kCropAspects.length, (i) {
                        final a = kCropAspects[i];
                        final selected = _selectedIndex == i;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: FilterChip(
                            label: Text(a.label),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _selectedIndex = i),
                            selectedColor: AppColors.brandPrimary.withValues(alpha: 0.3),
                            checkmarkColor: AppColors.brandPrimary,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: (canvasId == null || _isApplying)
                      ? null
                      : () => _applyCrop(canvasId),
                  child: _isApplying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyCrop(int canvasId) async {
    setState(() => _isApplying = true);
    try {
      final renderRepo = ref.read(renderRepositoryProvider);
      final current = await renderRepo.renderCanvas(canvasId);
      final a = kCropAspects[_selectedIndex];
      final cropped =
          cropToAspect(current, a.widthRatio, a.heightRatio);
      final ok = await ref
          .read(canvasProvider.notifier)
          .replaceWithImage(cropped);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Crop applied'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Crop failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }
}
