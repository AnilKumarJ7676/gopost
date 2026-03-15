import 'package:flutter/material.dart';
import 'package:gopost_app/core/cache/image_cache_manager.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';

class TemplateCard extends StatelessWidget {
  final TemplateEntity template;
  final VoidCallback? onTap;

  const TemplateCard({
    super.key,
    required this.template,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildThumbnail(theme),
          const SizedBox(height: AppSpacing.sm),
          _buildInfo(theme),
        ],
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    return AspectRatio(
      aspectRatio: template.width / template.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: template.thumbnailUrl != null
                ? AppCachedImage(
                    imageUrl: template.thumbnailUrl!,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      template.isVideo
                          ? Icons.videocam_outlined
                          : Icons.image_outlined,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          if (template.isPremium)
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'PRO',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          if (template.isVideo && template.durationMs != null)
            Positioned(
              bottom: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppRadius.sm / 2),
                ),
                child: Text(
                  _formatDuration(template.durationMs!),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.white),
                ),
              ),
            ),
          if (template.isVideo)
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            template.name,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                template.isVideo
                    ? Icons.videocam_outlined
                    : Icons.image_outlined,
                size: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                template.categoryName ?? template.type.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.favorite_outline,
                size: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Text(
                _formatCount(template.usageCount),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
