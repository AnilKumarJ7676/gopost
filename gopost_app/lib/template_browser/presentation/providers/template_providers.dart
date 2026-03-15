import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/di/providers.dart';
import 'package:gopost_app/rendering_bridge/ffi/gopost_engine_ffi.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/rendering_bridge/template_bridge.dart';
import 'package:gopost_app/template_browser/data/datasources/template_remote_datasource.dart';
import 'package:gopost_app/template_browser/data/repositories/template_repository_impl.dart';
import 'package:gopost_app/template_browser/domain/repositories/template_repository.dart';
import 'package:gopost_app/template_browser/domain/usecases/get_categories_usecase.dart';
import 'package:gopost_app/template_browser/domain/usecases/get_featured_templates_usecase.dart';
import 'package:gopost_app/template_browser/domain/usecases/get_template_detail_usecase.dart';
import 'package:gopost_app/template_browser/domain/usecases/get_templates_usecase.dart';
import 'package:gopost_app/template_browser/domain/usecases/request_template_access_usecase.dart';
import 'package:gopost_app/template_browser/domain/usecases/search_templates_usecase.dart';
import 'package:gopost_app/template_browser/presentation/providers/download_notifier.dart';
import 'package:gopost_app/template_browser/presentation/providers/home_notifier.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_detail_notifier.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_list_notifier.dart';
import 'package:gopost_app/template_browser/presentation/providers/template_search_notifier.dart';

// --- Engine & template bridge (FFI) ---

final gopostEngineProvider = Provider<GopostEngine>((ref) {
  return GopostEngineFfi();
});

final templateBridgeProvider = Provider<TemplateBridge>((ref) {
  return TemplateBridge(ref.watch(gopostEngineProvider));
});

// --- Data layer ---

final templateRemoteDataSourceProvider =
    Provider<TemplateRemoteDataSource>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  return TemplateRemoteDataSourceImpl(httpClient.dio);
});

/// DIP: Upper layers depend on this abstract TemplateRepository,
/// not the concrete TemplateRepositoryImpl.
final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepositoryImpl(
    remote: ref.watch(templateRemoteDataSourceProvider),
  );
});

// --- Use cases (SRP: each provider creates exactly one use case) ---

final getTemplatesUseCaseProvider = Provider<GetTemplatesUseCase>((ref) {
  return GetTemplatesUseCase(ref.watch(templateRepositoryProvider));
});

final getTemplateDetailUseCaseProvider =
    Provider<GetTemplateDetailUseCase>((ref) {
  return GetTemplateDetailUseCase(ref.watch(templateRepositoryProvider));
});

final searchTemplatesUseCaseProvider =
    Provider<SearchTemplatesUseCase>((ref) {
  return SearchTemplatesUseCase(ref.watch(templateRepositoryProvider));
});

final getCategoriesUseCaseProvider = Provider<GetCategoriesUseCase>((ref) {
  return GetCategoriesUseCase(ref.watch(templateRepositoryProvider));
});

final requestTemplateAccessUseCaseProvider =
    Provider<RequestTemplateAccessUseCase>((ref) {
  return RequestTemplateAccessUseCase(ref.watch(templateRepositoryProvider));
});

final getFeaturedTemplatesUseCaseProvider =
    Provider<GetFeaturedTemplatesUseCase>((ref) {
  return GetFeaturedTemplatesUseCase(ref.watch(templateRepositoryProvider));
});

final getTrendingTemplatesUseCaseProvider =
    Provider<GetTrendingTemplatesUseCase>((ref) {
  return GetTrendingTemplatesUseCase(ref.watch(templateRepositoryProvider));
});

final getRecentTemplatesUseCaseProvider =
    Provider<GetRecentTemplatesUseCase>((ref) {
  return GetRecentTemplatesUseCase(ref.watch(templateRepositoryProvider));
});

// --- State notifiers ---

final templateListProvider =
    StateNotifierProvider<TemplateListNotifier, TemplateListState>((ref) {
  return TemplateListNotifier(
    getTemplates: ref.watch(getTemplatesUseCaseProvider),
  );
});

final templateSearchProvider =
    StateNotifierProvider<TemplateSearchNotifier, TemplateSearchState>((ref) {
  return TemplateSearchNotifier(
    searchTemplates: ref.watch(searchTemplatesUseCaseProvider),
  );
});

final templateDetailProvider = StateNotifierProvider.family<
    TemplateDetailNotifier, TemplateDetailState, String>((ref, id) {
  final notifier = TemplateDetailNotifier(
    getDetail: ref.watch(getTemplateDetailUseCaseProvider),
  );
  notifier.load(id);
  return notifier;
});

final homeProvider =
    StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(
    getFeatured: ref.watch(getFeaturedTemplatesUseCaseProvider),
    getTrending: ref.watch(getTrendingTemplatesUseCaseProvider),
    getRecent: ref.watch(getRecentTemplatesUseCaseProvider),
    getCategories: ref.watch(getCategoriesUseCaseProvider),
  );
});

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier(
    requestAccess: ref.watch(requestTemplateAccessUseCaseProvider),
    accessRepo: ref.watch(templateRepositoryProvider),
    templateBridge: ref.watch(templateBridgeProvider),
  );
});
