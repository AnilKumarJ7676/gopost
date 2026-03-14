import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/image_editor/domain/entities/editor_tool.dart';

/// SRP: Manages the active tool selection in the editor.
class ToolNotifier extends StateNotifier<EditorTool> {
  ToolNotifier() : super(EditorTool.select);

  void selectTool(EditorTool tool) {
    state = tool;
  }
}
