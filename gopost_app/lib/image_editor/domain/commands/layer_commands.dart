import 'dart:typed_data';

import 'package:gopost_app/image_editor/domain/entities/edit_command.dart';
import 'package:gopost_app/image_editor/presentation/providers/canvas_notifier.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';

/// Command: add solid color layer. Undo = remove that layer.
class AddSolidLayerCommand extends EditCommand {
  AddSolidLayerCommand(
    this._notifier, {
    required this.r,
    required this.g,
    required this.b,
    required this.a,
  }) : super(description: 'Add solid layer');

  final CanvasNotifier _notifier;
  final double r, g, b, a;
  int? _addedLayerId;

  @override
  Future<void> execute() async {
    _addedLayerId = await _notifier.addSolidLayer(r, g, b, a);
  }

  @override
  Future<void> undo() async {
    if (_addedLayerId != null) {
      await _notifier.removeLayer(_addedLayerId!);
      _addedLayerId = null;
    }
  }
}

/// Command: add image layer. Undo = remove that layer.
class AddImageLayerCommand extends EditCommand {
  AddImageLayerCommand(
    this._notifier, {
    required this.pixels,
    required this.width,
    required this.height,
  }) : super(description: 'Add image layer');

  final CanvasNotifier _notifier;
  final Uint8List pixels;
  final int width;
  final int height;
  int? _addedLayerId;

  @override
  Future<void> execute() async {
    _addedLayerId = await _notifier.addImageLayer(pixels, width, height);
  }

  @override
  Future<void> undo() async {
    if (_addedLayerId != null) {
      await _notifier.removeLayer(_addedLayerId!);
      _addedLayerId = null;
    }
  }
}

/// Command: remove layer. Undo = no-op (full restore would need stored pixels).
class RemoveLayerCommand extends EditCommand {
  RemoveLayerCommand(this._notifier, {required this.layerId})
      : super(description: 'Remove layer');

  final CanvasNotifier _notifier;
  final int layerId;

  @override
  Future<void> execute() async {
    await _notifier.removeLayer(layerId);
  }

  @override
  Future<void> undo() async {
    // Full undo would require storing layer content; not implemented.
  }
}

/// Command: reorder layer. Undo = reorder back.
class ReorderLayerCommand extends EditCommand {
  ReorderLayerCommand(
    this._notifier, {
    required this.layerId,
    required this.oldIndex,
    required this.newIndex,
  }) : super(description: 'Reorder layer');

  final CanvasNotifier _notifier;
  final int layerId;
  final int oldIndex;
  final int newIndex;

  @override
  Future<void> execute() async {
    await _notifier.reorderLayer(layerId, newIndex);
  }

  @override
  Future<void> undo() async {
    await _notifier.reorderLayer(layerId, oldIndex);
  }
}

/// Command: set layer opacity. Undo = restore previous opacity.
class SetLayerOpacityCommand extends EditCommand {
  SetLayerOpacityCommand(
    this._notifier, {
    required this.layerId,
    required this.previousOpacity,
    required this.newOpacity,
  }) : super(description: 'Set opacity');

  final CanvasNotifier _notifier;
  final int layerId;
  final double previousOpacity;
  final double newOpacity;

  @override
  Future<void> execute() async {
    await _notifier.setLayerOpacity(layerId, newOpacity);
  }

  @override
  Future<void> undo() async {
    await _notifier.setLayerOpacity(layerId, previousOpacity);
  }
}

/// Command: set layer visible. Undo = restore previous visible.
class SetLayerVisibleCommand extends EditCommand {
  SetLayerVisibleCommand(
    this._notifier, {
    required this.layerId,
    required this.previousVisible,
    required this.newVisible,
  }) : super(description: 'Set visibility');

  final CanvasNotifier _notifier;
  final int layerId;
  final bool previousVisible;
  final bool newVisible;

  @override
  Future<void> execute() async {
    await _notifier.setLayerVisible(layerId, newVisible);
  }

  @override
  Future<void> undo() async {
    await _notifier.setLayerVisible(layerId, previousVisible);
  }
}

/// Command: set layer blend mode. Undo = restore previous blend mode.
class SetLayerBlendModeCommand extends EditCommand {
  SetLayerBlendModeCommand(
    this._notifier, {
    required this.layerId,
    required this.previousMode,
    required this.newMode,
  }) : super(description: 'Set blend mode');

  final CanvasNotifier _notifier;
  final int layerId;
  final BlendMode previousMode;
  final BlendMode newMode;

  @override
  Future<void> execute() async {
    await _notifier.setLayerBlendMode(layerId, newMode);
  }

  @override
  Future<void> undo() async {
    await _notifier.setLayerBlendMode(layerId, previousMode);
  }
}
