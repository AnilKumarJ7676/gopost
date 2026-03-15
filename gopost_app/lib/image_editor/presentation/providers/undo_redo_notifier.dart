import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/image_editor/domain/entities/edit_command.dart';

class UndoRedoState {
  final List<EditCommand> undoStack;
  final List<EditCommand> redoStack;
  final bool isProcessing;

  const UndoRedoState({
    this.undoStack = const [],
    this.redoStack = const [],
    this.isProcessing = false,
  });

  bool get canUndo => undoStack.isNotEmpty && !isProcessing;
  bool get canRedo => redoStack.isNotEmpty && !isProcessing;
  String? get lastActionName =>
      undoStack.isNotEmpty ? undoStack.last.description : null;
  String? get nextRedoName =>
      redoStack.isNotEmpty ? redoStack.last.description : null;

  UndoRedoState copyWith({
    List<EditCommand>? undoStack,
    List<EditCommand>? redoStack,
    bool? isProcessing,
  }) =>
      UndoRedoState(
        undoStack: undoStack ?? this.undoStack,
        redoStack: redoStack ?? this.redoStack,
        isProcessing: isProcessing ?? this.isProcessing,
      );
}

class UndoRedoNotifier extends StateNotifier<UndoRedoState> {
  static const int maxUndoLevels = 50;

  UndoRedoNotifier() : super(const UndoRedoState());

  /// Execute a command and push to undo stack. Clears redo stack.
  Future<void> execute(EditCommand command) async {
    state = state.copyWith(isProcessing: true);
    try {
      await command.execute();
      final newStack = [...state.undoStack, command];
      if (newStack.length > maxUndoLevels) {
        newStack.removeAt(0);
      }
      state = state.copyWith(
        undoStack: newStack,
        redoStack: [], // clear redo on new action
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      rethrow;
    }
  }

  /// Undo the last command.
  Future<void> undo() async {
    if (!state.canUndo) return;
    state = state.copyWith(isProcessing: true);
    try {
      final command = state.undoStack.last;
      await command.undo();
      final newUndo = [...state.undoStack]..removeLast();
      final newRedo = [...state.redoStack, command];
      state = state.copyWith(
        undoStack: newUndo,
        redoStack: newRedo,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      rethrow;
    }
  }

  /// Redo the last undone command.
  Future<void> redo() async {
    if (!state.canRedo) return;
    state = state.copyWith(isProcessing: true);
    try {
      final command = state.redoStack.last;
      await command.execute();
      final newRedo = [...state.redoStack]..removeLast();
      final newUndo = [...state.undoStack, command];
      state = state.copyWith(
        undoStack: newUndo,
        redoStack: newRedo,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      rethrow;
    }
  }

  void clear() {
    state = const UndoRedoState();
  }
}
