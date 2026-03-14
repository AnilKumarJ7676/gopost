import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_list_notifier.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_providers.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_search_notifier.dart';
import 'package:gopost_app/template_browser/presentation/widgets/category_chips.dart';
import 'package:gopost_app/template_browser/presentation/widgets/filter_bar.dart';
import 'package:gopost_app/template_browser/presentation/widgets/search_bar_widget.dart';
import 'package:gopost_app/template_browser/presentation/widgets/shimmer_loading.dart';
import 'package:gopost_app/template_browser/presentation/widgets/template_card.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(templateListProvider.notifier).loadTemplates();
      ref.read(homeProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll * 0.8) {
      ref.read(templateListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(templateListProvider);
    final homeState = ref.watch(homeProvider);
    final searchState = ref.watch(templateSearchProvider);

    final isSearchActive = searchState.query.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(templateListProvider.notifier).refresh(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.base,
                    bottom: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.base),
                        child: Text(
                          'Templates',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TemplateSearchBar(
                        onChanged: (query) =>
                            ref.read(templateSearchProvider.notifier).search(query),
                        onClear: () =>
                            ref.read(templateSearchProvider.notifier).clear(),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isSearchActive) ...[
                SliverToBoxAdapter(
                  child: CategoryChips(
                    categories: homeState.categories,
                    selectedCategoryId: listState.filter.categoryId,
                    onCategorySelected: (id) {
                      final newFilter = id != null
                          ? listState.filter.copyWith(
                              categoryId: id, clearCursor: true)
                          : listState.filter.copyWith(
                              clearCategory: true, clearCursor: true);
                      ref.read(templateListProvider.notifier).updateFilter(newFilter);
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: FilterBar(
                      filter: listState.filter,
                      onFilterChanged: (filter) =>
                          ref.read(templateListProvider.notifier).updateFilter(filter),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.base),
                ),
              ],
              if (isSearchActive)
                _buildSearchResults(searchState)
              else
                _buildTemplateGrid(listState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(TemplateSearchState searchState) {
    if (searchState.isSearching && searchState.results.isEmpty) {
      return const SliverToBoxAdapter(child: ShimmerGrid());
    }

    if (!searchState.isSearching && searchState.results.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                'No templates found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Try adjusting your search terms',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.base),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.base,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final template = searchState.results[index];
            return TemplateCard(
              template: template,
              onTap: () => context.push('/templates/${template.id}'),
            );
          },
          childCount: searchState.results.length,
        ),
      ),
    );
  }

  Widget _buildTemplateGrid(TemplateListState listState) {
    if (listState.isLoading && listState.templates.isEmpty) {
      return const SliverToBoxAdapter(child: ShimmerGrid());
    }

    if (listState.error != null && listState.templates.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.base),
              Text(listState.error!,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.base),
              FilledButton(
                onPressed: () =>
                    ref.read(templateListProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final itemCount =
        listState.templates.length + (listState.hasMore ? 1 : 0);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.base,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == listState.templates.length) {
              return _buildLoadMoreIndicator(listState);
            }
            final template = listState.templates[index];
            return TemplateCard(
              template: template,
              onTap: () => context.push('/templates/${template.id}'),
            );
          },
          childCount: itemCount,
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator(TemplateListState listState) {
    if (listState.isLoadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.base),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (!listState.hasMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You\'ve seen all templates',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
