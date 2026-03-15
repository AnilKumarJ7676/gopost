import 'package:gopost_app/video_editor/domain/models/video_project.dart';

/// Snapshot-based undo/redo: each command stores the full project state
/// before and after the operation. Simple and robust for timeline editing.
class EditorCommand {
  final String description;
  final VideoProject stateBefore;
  final VideoProject stateAfter;

  const EditorCommand({
    required this.description,
    required this.stateBefore,
    required this.stateAfter,
  });
}

class UndoRedoStack {
  final List<EditorCommand> _undoStack = [];
  final List<EditorCommand> _redoStack = [];
  static const int maxUndoLevels = 100;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  String? get undoDescription => _undoStack.lastOrNull?.description;
  String? get redoDescription => _redoStack.lastOrNull?.description;

  void push(EditorCommand command) {
    _undoStack.add(command);
    _redoStack.clear();
    if (_undoStack.length > maxUndoLevels) {
      _undoStack.removeAt(0);
    }
  }

  EditorCommand? undo() {
    if (_undoStack.isEmpty) return null;
    final cmd = _undoStack.removeLast();
    _redoStack.add(cmd);
    return cmd;
  }

  EditorCommand? redo() {
    if (_redoStack.isEmpty) return null;
    final cmd = _redoStack.removeLast();
    _undoStack.add(cmd);
    return cmd;
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
