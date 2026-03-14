import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gopost_app/auth/presentation/providers/auth_providers.dart';
import 'package:gopost_app/auth/presentation/widgets/login_required_sheet.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/presentation/providers/download_notifier.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_providers.dart';
import 'package:gopost_app/template_browser/presentation/widgets/preview_player.dart';
import 'package:gopost_app/template_browser/presentation/widgets/shimmer_loading.dart';

class TemplateDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const TemplateDetailScreen({super.key, required this.id});

  @override
  ConsumerState<TemplateDetailScreen> createState() =>
      _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends ConsumerState<TemplateDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(templateDetailProvider(widget.id));
    final downloadState = ref.watch(downloadProvider);
    final theme = Theme.of(context);

    ref.listen<DownloadState>(downloadProvider, (prev, next) {
      if (prev?.status != DownloadStatus.complete &&
          next.status == DownloadStatus.complete) {
        final template = state.template;
        if (template != null) {
          final route = template.editableFields.isNotEmpty
              ? (template.isVideo
                  ? '/editor/video/customize/${template.id}'
                  : '/editor/customize/${template.id}')
              : template.isVideo
                  ? '/editor/video'
                  : '/editor/image';
          context.push(route);
          ref.read(downloadProvider.notifier).reset();
        }
      }
    });

    return Scaffold(
      body: state.isLoading
          ? const _LoadingState()
          : state.error != null
              ? _ErrorState(
                  error: state.error!,
                  onRetry: () => ref
                      .read(templateDetailProvider(widget.id).notifier)
                      .load(widget.id),
                )
              : state.template != null
                  ? _DetailContent(
                      template: state.template!,
                      downloadState: downloadState,
                      onUseTemplate: () => _handleUseTemplate(),
                      onShare: () => _share(context, state.template!),
                    )
                  : const SizedBox.shrink(),
      bottomNavigationBar: state.template != null
          ? _BottomBar(
              template: state.template!,
              downloadState: downloadState,
              onUseTemplate: () => _handleUseTemplate(),
              theme: theme,
            )
          : null,
    );
  }

  void _handleUseTemplate() {
    final authState = ref.read(authStateProvider);
    if (authState.isGuest) {
      LoginRequiredSheet.show(context, feature: 'use templates');
      return;
    }
    ref.read(downloadProvider.notifier).download(widget.id);
  }

  void _share(BuildContext context, TemplateEntity template) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share: ${template.name}')),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            ShimmerBox(
                width: double.infinity,
                height: 300,
                borderRadius: BorderRadius.zero),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 200, height: 24),
                  SizedBox(height: 8),
                  ShimmerBox(width: 300, height: 16),
                  SizedBox(height: 16),
                  ShimmerBox(width: double.infinity, height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(error),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final TemplateEntity template;
  final DownloadState downloadState;
  final VoidCallback onUseTemplate;
  final VoidCallback onShare;

  const _DetailContent({
    required this.template,
    required this.downloadState,
    required this.onUseTemplate,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 400,
          pinned: true,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share, color: Colors.white, size: 20),
              ),
              onPressed: onShare,
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: PreviewPlayer(
              previewUrl: template.previewUrl,
              thumbnailUrl: template.thumbnailUrl,
              isVideo: template.isVideo,
              width: template.width,
              height: template.height,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: AppSpacing.base),
                if (template.creatorName != null)
                  _buildCreatorInfo(theme),
                const SizedBox(height: AppSpacing.base),
                _buildDescription(theme),
                if (template.editableFields.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildEditableFields(theme),
                ],
                const SizedBox(height: AppSpacing.xl),
                _buildMetadata(theme),
                if (template.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildTags(theme),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.name,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  if (template.categoryName != null)
                    _InfoChip(
                        label: template.categoryName!, theme: theme),
                  const SizedBox(width: AppSpacing.sm),
                  _InfoChip(
                    label: template.type.name,
                    icon: template.isVideo
                        ? Icons.videocam_outlined
                        : Icons.image_outlined,
                    theme: theme,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (template.isPremium)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.tertiary,
                  theme.colorScheme.primary,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              'PRO',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCreatorInfo(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: template.creatorAvatarUrl != null
                ? NetworkImage(template.creatorAvatarUrl!)
                : null,
            child: template.creatorAvatarUrl == null
                ? Text(
                    template.creatorName![0].toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.creatorName!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                'Creator',
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

  Widget _buildDescription(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          template.description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEditableFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Editable Fields', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...template.editableFields.map((field) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    _fieldIcon(field.fieldType),
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(field.label, style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm / 2),
                    ),
                    child: Text(
                      field.fieldType.name,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  IconData _fieldIcon(EditableFieldType type) {
    return switch (type) {
      EditableFieldType.text => Icons.text_fields,
      EditableFieldType.image => Icons.image_outlined,
      EditableFieldType.color => Icons.palette_outlined,
      EditableFieldType.number => Icons.tag,
    };
  }

  Widget _buildMetadata(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Details', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _MetaRow(label: 'Dimensions', value: template.dimensions, theme: theme),
        _MetaRow(
            label: 'Layers',
            value: template.layerCount.toString(),
            theme: theme),
        if (template.duration != null)
          _MetaRow(
              label: 'Duration',
              value:
                  '${template.duration!.inSeconds}s',
              theme: theme),
        _MetaRow(
            label: 'Uses',
            value: template.usageCount.toString(),
            theme: theme),
        _MetaRow(
            label: 'Version',
            value: 'v${template.version}',
            theme: theme),
      ],
    );
  }

  Widget _buildTags(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: template.tags
              .map((tag) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '#$tag',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final ThemeData theme;

  const _InfoChip({required this.label, this.icon, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _MetaRow(
      {required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final TemplateEntity template;
  final DownloadState downloadState;
  final VoidCallback onUseTemplate;
  final ThemeData theme;

  const _BottomBar({
    required this.template,
    required this.downloadState,
    required this.onUseTemplate,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.base,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: downloadState.status == DownloadStatus.downloading ||
                  downloadState.status == DownloadStatus.loadingInEngine ||
                  downloadState.status == DownloadStatus.requestingAccess
              ? null
              : onUseTemplate,
          child: _buildButtonContent(),
        ),
      ),
    );
  }

  Widget _buildButtonContent() {
    return switch (downloadState.status) {
      DownloadStatus.requestingAccess => const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 8),
            Text('Requesting access...'),
          ],
        ),
      DownloadStatus.loadingInEngine => const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 8),
            Text('Loading template...'),
          ],
        ),
      DownloadStatus.downloading => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: downloadState.progress,
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text('${(downloadState.progress * 100).toInt()}%'),
          ],
        ),
      DownloadStatus.complete => const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 18),
            SizedBox(width: 8),
            Text('Open in Editor'),
          ],
        ),
      _ => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined, size: 18),
            const SizedBox(width: 8),
            Text(template.isPremium ? 'Use Template (PRO)' : 'Use Template'),
          ],
        ),
    };
  }
}
