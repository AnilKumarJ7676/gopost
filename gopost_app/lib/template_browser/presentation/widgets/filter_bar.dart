import 'package:flutter/material.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/template_filter.dart';

class FilterBar extends StatelessWidget {
  final TemplateFilter filter;
  final ValueChanged<TemplateFilter> onFilterChanged;

  const FilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        children: [
          _TypeFilterChip(
            label: 'Video',
            isSelected: filter.type == TemplateType.video,
            onTap: () => onFilterChanged(
              filter.type == TemplateType.video
                  ? filter.copyWith(clearType: true, clearCursor: true)
                  : filter.copyWith(
                      type: TemplateType.video, clearCursor: true),
            ),
            icon: Icons.videocam_outlined,
            theme: theme,
          ),
          const SizedBox(width: AppSpacing.sm),
          _TypeFilterChip(
            label: 'Image',
            isSelected: filter.type == TemplateType.image,
            onTap: () => onFilterChanged(
              filter.type == TemplateType.image
                  ? filter.copyWith(clearType: true, clearCursor: true)
                  : filter.copyWith(
                      type: TemplateType.image, clearCursor: true),
            ),
            icon: Icons.image_outlined,
            theme: theme,
          ),
          const SizedBox(width: AppSpacing.sm),
          _TypeFilterChip(
            label: 'Free',
            isSelected: filter.isPremium == false,
            onTap: () => onFilterChanged(
              filter.isPremium == false
                  ? filter.copyWith(clearPremium: true, clearCursor: true)
                  : filter.copyWith(isPremium: false, clearCursor: true),
            ),
            icon: Icons.lock_open_outlined,
            theme: theme,
          ),
          const SizedBox(width: AppSpacing.sm),
          _TypeFilterChip(
            label: 'Premium',
            isSelected: filter.isPremium == true,
            onTap: () => onFilterChanged(
              filter.isPremium == true
                  ? filter.copyWith(clearPremium: true, clearCursor: true)
                  : filter.copyWith(isPremium: true, clearCursor: true),
            ),
            icon: Icons.workspace_premium_outlined,
            theme: theme,
          ),
          const SizedBox(width: AppSpacing.base),
          _SortDropdown(filter: filter, onFilterChanged: onFilterChanged),
        ],
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final ThemeData theme;

  const _TypeFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final TemplateFilter filter;
  final ValueChanged<TemplateFilter> onFilterChanged;

  const _SortDropdown({
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<TemplateSortBy>(
      onSelected: (sort) =>
          onFilterChanged(filter.copyWith(sortBy: sort, clearCursor: true)),
      itemBuilder: (_) => [
        _sortItem(TemplateSortBy.popular, 'Popular', Icons.trending_up),
        _sortItem(TemplateSortBy.newest, 'Newest', Icons.schedule),
        _sortItem(TemplateSortBy.trending, 'Trending', Icons.local_fire_department),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              filter.sortBy.name[0].toUpperCase() +
                  filter.sortBy.name.substring(1),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<TemplateSortBy> _sortItem(
      TemplateSortBy sort, String label, IconData icon) {
    return PopupMenuItem(
      value: sort,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
