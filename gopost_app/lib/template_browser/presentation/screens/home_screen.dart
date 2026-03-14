import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gopost_app/core/cache/image_cache_manager.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/template_browser/domain/entities/category_entity.dart';
import 'package:gopost_app/template_browser/domain/entities/template_entity.dart';
import 'package:gopost_app/template_browser/presentation/providers/home_notifier.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_providers.dart';
import 'package:gopost_app/template_browser/presentation/widgets/shimmer_loading.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(homeProvider.notifier).refresh(),
          child: state.isLoading && state.featured.isEmpty
              ? const _LoadingHome()
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(theme)),
                    if (state.featured.isNotEmpty)
                      SliverToBoxAdapter(
                          child: _FeaturedBanner(templates: state.featured)),
                    SliverToBoxAdapter(
                      child: _QuickCreate(
                        onNewVideo: () => context.push('/editor/video'),
                        onNewImage: () => context.push('/editor/image'),
                      ),
                    ),
                    if (state.categories.isNotEmpty)
                      SliverToBoxAdapter(
                          child: _CategoryQuickAccess(
                        categories: state.categories,
                        onCategoryTap: (id) => context.push('/templates'),
                      )),
                    if (state.trending.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _HorizontalSection(
                          title: 'Trending Now',
                          icon: Icons.local_fire_department,
                          templates: state.trending,
                          onViewAll: () => context.push('/templates'),
                          onTemplateTap: (id) =>
                              context.push('/templates/$id'),
                        ),
                      ),
                    if (state.recent.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _HorizontalSection(
                          title: 'Recently Added',
                          icon: Icons.schedule,
                          templates: state.recent,
                          onViewAll: () => context.push('/templates'),
                          onTemplateTap: (id) =>
                              context.push('/templates/$id'),
                        ),
                      ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xxxl)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.sm),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gopost',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                'Create something amazing',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.notifications_outlined,
                color: theme.colorScheme.onSurfaceVariant),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 80),
          ShimmerBox(width: double.infinity, height: 200, borderRadius: BorderRadius.zero),
          SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 150, height: 20),
                SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 160),
                SizedBox(height: 24),
                ShimmerBox(width: 150, height: 20),
                SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 160),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedBanner extends StatefulWidget {
  final List<TemplateEntity> templates;

  const _FeaturedBanner({required this.templates});

  @override
  State<_FeaturedBanner> createState() => _FeaturedBannerState();
}

class _FeaturedBannerState extends State<_FeaturedBanner> {
  final _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: widget.templates.length,
            itemBuilder: (context, index) {
              final template = widget.templates[index];
              return GestureDetector(
                onTap: () => context.push('/templates/${template.id}'),
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (template.thumbnailUrl != null)
                          AppCachedImage(
                            imageUrl: template.thumbnailUrl!,
                            fit: BoxFit.cover,
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primaryContainer,
                                  theme.colorScheme.secondaryContainer,
                                ],
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: AppSpacing.base,
                          left: AppSpacing.base,
                          right: AppSpacing.base,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (template.isPremium)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(
                                      bottom: AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.tertiary,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm / 2),
                                  ),
                                  child: Text(
                                    'FEATURED',
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              Text(
                                template.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.templates.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.templates.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickCreate extends StatelessWidget {
  final VoidCallback onNewVideo;
  final VoidCallback onNewImage;

  const _QuickCreate({required this.onNewVideo, required this.onNewImage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          Expanded(
            child: _QuickCreateButton(
              icon: Icons.videocam_rounded,
              label: 'New Video',
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
              onTap: onNewVideo,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _QuickCreateButton(
              icon: Icons.image_rounded,
              label: 'New Image',
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.secondary,
                  theme.colorScheme.secondary.withValues(alpha: 0.8),
                ],
              ),
              onTap: onNewImage,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCreateButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _QuickCreateButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.base, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryQuickAccess extends StatelessWidget {
  final List<CategoryEntity> categories;
  final ValueChanged<String> onCategoryTap;

  const _CategoryQuickAccess({
    required this.categories,
    required this.onCategoryTap,
  });

  static const _categoryIcons = <String, IconData>{
    'social-media': Icons.share,
    'marketing': Icons.campaign,
    'presentation': Icons.slideshow,
    'youtube': Icons.play_circle,
    'instagram': Icons.camera_alt,
    'tiktok': Icons.music_note,
    'education': Icons.school,
    'business': Icons.business_center,
    'personal': Icons.person,
    'other': Icons.category,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final icon =
                    _categoryIcons[cat.slug] ?? Icons.category;
                return GestureDetector(
                  onTap: () => onCategoryTap(cat.id),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            icon,
                            color: theme.colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          cat.name,
                          style: theme.textTheme.labelSmall,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<TemplateEntity> templates;
  final VoidCallback onViewAll;
  final ValueChanged<String> onTemplateTap;

  const _HorizontalSection({
    required this.title,
    required this.icon,
    required this.templates,
    required this.onViewAll,
    required this.onTemplateTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onViewAll,
                  child: Text(
                    'View All',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              itemCount: templates.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final template = templates[index];
                return GestureDetector(
                  onTap: () => onTemplateTap(template.id),
                  child: SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            child: template.thumbnailUrl != null
                                ? AppCachedImage(
                                    imageUrl: template.thumbnailUrl!,
                                    width: 140,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: theme.colorScheme
                                        .surfaceContainerHighest,
                                    child: Icon(
                                      template.isVideo
                                          ? Icons.videocam_outlined
                                          : Icons.image_outlined,
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          template.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            if (template.isPremium)
                              Container(
                                margin: const EdgeInsets.only(
                                    right: AppSpacing.xs),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiary,
                                  borderRadius:
                                      BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'PRO',
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            Text(
                              template.type.name,
                              style:
                                  theme.textTheme.labelSmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
