/// Base class for all undoable editing operations.
abstract class EditCommand {
  final String description;
  final DateTime timestamp;

  EditCommand({required this.description}) : timestamp = DateTime.now();

  /// Execute the command (do/redo).
  Future<void> execute();

  /// Reverse the command (undo).
  Future<void> undo();
}
