import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';

/// Bottom sheet for adding stickers to the image editor.
/// Displays category tabs and a grid of emoji stickers.
class StickerPickerSheet extends ConsumerStatefulWidget {
  final void Function(String emoji)? onStickerSelected;

  const StickerPickerSheet({super.key, this.onStickerSelected});

  @override
  ConsumerState<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends ConsumerState<StickerPickerSheet> {
  static const List<String> _categories = [
    'Smileys',
    'Animals',
    'Food',
    'Travel',
    'Objects',
    'Symbols',
  ];

  static const Map<String, List<String>> _stickers = {
    'Smileys': ['😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂'],
    'Animals': ['🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼'],
    'Food': ['🍎', '🍕', '🍔', '🍟', '🍰', '🍩', '🍪', '☕'],
    'Travel': ['🏠', '✈️', '🚗', '🚢', '🏖️', '🗺️', '🧳', '🎒'],
    'Objects': ['🎵', '📱', '💡', '🔑', '🎨', '📷', '📚', '✏️'],
    'Symbols': ['❤️', '⭐', '💎', '🔥', '🌟', '✅', '❌', '💪'],
  };

  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final stickers = _stickers[_categories[_selectedCategoryIndex]] ?? [];

    return Container(
      height: 400,
      decoration: const BoxDecoration(
        color: AppColors.editorSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
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
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Add Sticker',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedCategoryIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategoryIndex = index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brandPrimary.withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _categories[index],
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.brandPrimaryDark
                              : Colors.white70,
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1,
              ),
              itemCount: stickers.length,
              itemBuilder: (context, index) {
                final emoji = stickers[index];
                return GestureDetector(
                  onTap: () => widget.onStickerSelected?.call(emoji),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.neutralSurfaceVariantDark
                          .withValues(alpha: 0.3),
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
