import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/go_craft/domain/models/craft_project.dart';
import 'package:gopost_app/go_craft/presentation/providers/go_craft_notifier.dart';

class GoCraftScreen extends ConsumerStatefulWidget {
  const GoCraftScreen({super.key});

  @override
  ConsumerState<GoCraftScreen> createState() => _GoCraftScreenState();
}

class _GoCraftScreenState extends ConsumerState<GoCraftScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(goCraftNotifierProvider.notifier).loadProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(goCraftNotifierProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(goCraftNotifierProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(theme)),
              SliverToBoxAdapter(
                child: _EditorCards(
                  onVideoTap: () => context.push('/editor/video'),
                  onImageTap: () => context.push('/editor/image'),
                ),
              ),
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'My Projects',
                  icon: Icons.folder_outlined,
                  trailing: state.projects.isNotEmpty
                      ? Text(
                          '${state.projects.length} project${state.projects.length == 1 ? '' : 's'}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                ),
              ),
              if (state.isLoading && state.projects.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xxxl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (state.projects.isEmpty)
                SliverToBoxAdapter(child: _EmptyProjects(scheme: scheme))
              else
                _ProjectGrid(
                  projects: state.projects,
                  onTap: _openProject,
                  onDelete: _confirmDelete,
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.lg,
        AppSpacing.base,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Go Craft',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Start creating or continue where you left off',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _openProject(CraftProject project) {
    if (project.type == CraftProjectType.video) {
      context.push('/editor/video?projectId=${project.id}');
    } else {
      context.push('/editor/image?projectId=${project.id}');
    }
  }

  void _confirmDelete(CraftProject project) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
          'Are you sure you want to delete "${project.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(goCraftNotifierProvider.notifier)
                  .deleteProject(project);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _EditorCards extends StatelessWidget {
  final VoidCallback onVideoTap;
  final VoidCallback onImageTap;

  const _EditorCards({required this.onVideoTap, required this.onImageTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: _EditorCard(
              icon: Icons.videocam_rounded,
              title: 'Video Editor',
              subtitle: 'Create & edit videos',
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7),
                ],
              ),
              onTap: onVideoTap,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _EditorCard(
              icon: Icons.image_rounded,
              title: 'Image Editor',
              subtitle: 'Design & edit images',
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.secondary,
                  theme.colorScheme.secondary.withValues(alpha: 0.7),
                ],
              ),
              onTap: onImageTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _EditorCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.xl,
        AppSpacing.base,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  final ColorScheme scheme;

  const _EmptyProjects({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 36,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'No projects yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Start creating with the editors above.\nYour work will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProjectGrid extends StatelessWidget {
  final List<CraftProject> projects;
  final ValueChanged<CraftProject> onTap;
  final ValueChanged<CraftProject> onDelete;

  const _ProjectGrid({
    required this.projects,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final project = projects[index];
            return _ProjectCard(
              project: project,
              onTap: () => onTap(project),
              onDelete: () => onDelete(project),
            );
          },
          childCount: projects.length,
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final CraftProject project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateFormat = DateFormat.yMMMd().add_jm();
    final isVideo = project.type == CraftProjectType.video;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isVideo
                      ? scheme.primaryContainer
                      : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                  size: 24,
                  color: isVideo
                      ? scheme.onPrimaryContainer
                      : scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isVideo
                                ? scheme.primaryContainer
                                : scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isVideo ? 'VIDEO' : 'IMAGE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isVideo
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    _buildMeta(theme, scheme),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      dateFormat.format(project.updatedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeta(ThemeData theme, ColorScheme scheme) {
    final parts = <String>[];

    if (project.type == CraftProjectType.video) {
      if (project.trackCount != null) {
        parts.add('${project.trackCount} tracks');
      }
      if (project.clipCount != null) {
        parts.add('${project.clipCount} clips');
      }
      if (project.durationSeconds != null) {
        parts.add('${project.durationSeconds!.toStringAsFixed(1)}s');
      }
    } else {
      parts.add('${project.width} x ${project.height}');
    }

    if (project.sourceTemplateName != null) {
      parts.add('from ${project.sourceTemplateName}');
    }

    return Text(
      parts.join('  \u2022  '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
