import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/image_editor/data/datasources/engine_canvas_datasource.dart';
import 'package:gopost_app/image_editor/data/repositories/canvas_repository_impl.dart';
import 'package:gopost_app/image_editor/data/repositories/export_repository_impl.dart';
import 'package:gopost_app/image_editor/data/repositories/filter_repository_impl.dart';
import 'package:gopost_app/image_editor/data/repositories/mask_repository_impl.dart';
import 'package:gopost_app/image_editor/data/repositories/project_repository_impl.dart';
import 'package:gopost_app/image_editor/data/repositories/text_repository_impl.dart';
import 'package:gopost_app/image_editor/domain/entities/editor_tool.dart';
import 'package:gopost_app/image_editor/domain/repositories/canvas_repository.dart';
import 'package:gopost_app/image_editor/domain/repositories/export_repository.dart';
import 'package:gopost_app/image_editor/domain/repositories/filter_repository.dart';
import 'package:gopost_app/image_editor/domain/repositories/mask_repository.dart';
import 'package:gopost_app/image_editor/domain/repositories/project_repository.dart';
import 'package:gopost_app/image_editor/domain/repositories/text_repository.dart';
import 'package:gopost_app/image_editor/presentation/providers/adjustment_notifier.dart';
import 'package:gopost_app/image_editor/presentation/providers/canvas_notifier.dart';
import 'package:gopost_app/image_editor/presentation/providers/filter_notifier.dart';
import 'package:gopost_app/image_editor/presentation/providers/photo_import_notifier.dart';
import 'package:gopost_app/image_editor/presentation/providers/text_notifier.dart';
import 'package:gopost_app/image_editor/presentation/providers/tool_notifier.dart';
import 'package:gopost_app/image_editor/presentation/providers/undo_redo_notifier.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// DIP: All providers depend on abstractions, not concretions.

final imageEditorEngineProvider = Provider<ImageEditorEngine>((ref) {
  throw UnimplementedError(
    'imageEditorEngineProvider must be overridden with a real engine.',
  );
});

final engineCanvasDataSourceProvider = Provider<EngineCanvasDataSource>((ref) {
  return EngineCanvasDataSourceImpl(ref.watch(imageEditorEngineProvider));
});

final canvasRepositoryImplProvider = Provider<CanvasRepositoryImpl>((ref) {
  return CanvasRepositoryImpl(ref.watch(engineCanvasDataSourceProvider));
});

final canvasRepositoryProvider = Provider<CanvasRepository>((ref) {
  return ref.watch(canvasRepositoryImplProvider);
});

final layerRepositoryProvider = Provider<LayerRepository>((ref) {
  return ref.watch(canvasRepositoryImplProvider);
});

final layerPropertyRepositoryProvider =
    Provider<LayerPropertyRepository>((ref) {
  return ref.watch(canvasRepositoryImplProvider);
});

final renderRepositoryProvider = Provider<RenderRepository>((ref) {
  return ref.watch(canvasRepositoryImplProvider);
});

final imageImportRepositoryProvider = Provider<ImageImportRepository>((ref) {
  return ref.watch(canvasRepositoryImplProvider);
});

// --- Sprint 6 providers ---

final filterRepositoryImplProvider = Provider<FilterRepositoryImpl>((ref) {
  return FilterRepositoryImpl(ref.watch(imageEditorEngineProvider));
});

final effectQueryRepositoryProvider = Provider<EffectQueryRepository>((ref) {
  return ref.watch(filterRepositoryImplProvider);
});

final adjustmentRepositoryProvider = Provider<AdjustmentRepository>((ref) {
  return ref.watch(filterRepositoryImplProvider);
});

final presetFilterRepositoryProvider = Provider<PresetFilterRepository>((ref) {
  return ref.watch(filterRepositoryImplProvider);
});

final textRepositoryProvider = Provider<TextLayerRepository>((ref) {
  return TextRepositoryImpl(ref.watch(imageEditorEngineProvider));
});

final canvasProvider =
    StateNotifierProvider<CanvasNotifier, CanvasState>((ref) {
  return CanvasNotifier(
    ref.watch(canvasRepositoryProvider),
    ref.watch(layerRepositoryProvider),
    ref.watch(layerPropertyRepositoryProvider),
    ref.watch(renderRepositoryProvider),
  );
});

final activeToolProvider =
    StateNotifierProvider<ToolNotifier, EditorTool>((ref) {
  return ToolNotifier();
});

final photoImportProvider =
    StateNotifierProvider<PhotoImportNotifier, PhotoImportState>((ref) {
  return PhotoImportNotifier(ref.watch(imageImportRepositoryProvider));
});

final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterState>((ref) {
  return FilterNotifier(
    ref.watch(effectQueryRepositoryProvider),
    ref.watch(presetFilterRepositoryProvider),
    ref.read(canvasProvider.notifier),
  );
});

final adjustmentProvider =
    StateNotifierProvider<AdjustmentNotifier, AdjustmentState>((ref) {
  return AdjustmentNotifier(
    ref.watch(effectQueryRepositoryProvider),
    ref.watch(adjustmentRepositoryProvider),
  );
});

final textToolProvider =
    StateNotifierProvider<TextToolNotifier, TextToolState>((ref) {
  return TextToolNotifier(ref.watch(textRepositoryProvider));
});

final undoRedoProvider =
    StateNotifierProvider<UndoRedoNotifier, UndoRedoState>((ref) {
  return UndoRedoNotifier();
});

// --- Sprint 7 providers ---

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return ExportRepositoryImpl(ref.watch(imageEditorEngineProvider));
});

final maskRepositoryProvider = Provider<MaskRepository>((ref) {
  return MaskRepositoryImpl(ref.watch(imageEditorEngineProvider));
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl(ref.watch(imageEditorEngineProvider));
});
