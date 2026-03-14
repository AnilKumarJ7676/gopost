import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/image_editor/presentation/providers/editor_providers.dart';
import 'package:gopost_app/image_editor/presentation/providers/photo_import_notifier.dart';

/// Photo picker bottom sheet with gallery, camera, and multi-select options.
/// Calls [onImageSelected] with path and bytes so decoding works on all platforms
/// (including web where file path is not available).
class PhotoPickerSheet extends ConsumerWidget {
  final void Function(String path, Uint8List bytes)? onImageSelected;

  const PhotoPickerSheet({super.key, this.onImageSelected});

  bool get _isDesktop {
    if (kIsWeb) return false;
    final p = defaultTargetPlatform;
    return p == TargetPlatform.macOS ||
        p == TargetPlatform.windows ||
        p == TargetPlatform.linux;
  }

  bool get _isMobile {
    if (kIsWeb) return false;
    final p = defaultTargetPlatform;
    return p == TargetPlatform.iOS || p == TargetPlatform.android;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(photoImportProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Import Image',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (importState.status == ImportStatus.decoding)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: CircularProgressIndicator(),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ImportOption(
                    icon: _isDesktop
                        ? Icons.folder_open
                        : Icons.photo_library,
                    label: _isDesktop ? 'Open File' : 'Gallery',
                    onTap: () => _pickFromGallery(context, ref),
                  ),
                  if (_isMobile)
                    _ImportOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () => _pickFromCamera(context, ref),
                    ),
                  _ImportOption(
                    icon: Icons.collections,
                    label: 'Multiple',
                    onTap: () => _pickMultiple(context, ref),
                  ),
                ],
              ),
            ],
            if (importState.error != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  importState.error!,
                  style: const TextStyle(color: AppColors.semanticErrorDark),
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        onImageSelected?.call(picked.path, bytes);
        if (context.mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickFromCamera(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        onImageSelected?.call(picked.path, bytes);
        if (context.mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: $e')),
        );
      }
    }
  }

  Future<void> _pickMultiple(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (images.isNotEmpty) {
        for (final img in images) {
          final bytes = await img.readAsBytes();
          onImageSelected?.call(img.path, bytes);
        }
        if (context.mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick images: $e')),
        );
      }
    }
  }
}

class _ImportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImportOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.brandPrimaryDark, size: 28),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
