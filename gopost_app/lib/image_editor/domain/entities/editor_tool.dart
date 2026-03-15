/// Active tool in the image editor toolbar.
enum EditorTool {
  select,
  move,
  layers,
  addImage,
  addText,
  addShape,
  filter,
  adjust,
  crop,
  mask,
  sticker,
  draw,
  eraser,
  export_,
}

/// Display metadata for toolbar rendering.
extension EditorToolInfo on EditorTool {
  String get label => switch (this) {
        EditorTool.select => 'Select',
        EditorTool.move => 'Move',
        EditorTool.layers => 'Layers',
        EditorTool.addImage => 'Image',
        EditorTool.addText => 'Text',
        EditorTool.addShape => 'Shape',
        EditorTool.filter => 'Filter',
        EditorTool.adjust => 'Adjust',
        EditorTool.crop => 'Crop',
        EditorTool.mask => 'Mask',
        EditorTool.sticker => 'Sticker',
        EditorTool.draw => 'Draw',
        EditorTool.eraser => 'Eraser',
        EditorTool.export_ => 'Export',
      };

  String get iconName => switch (this) {
        EditorTool.select => 'touch_app',
        EditorTool.move => 'open_with',
        EditorTool.layers => 'layers',
        EditorTool.addImage => 'add_photo_alternate',
        EditorTool.addText => 'text_fields',
        EditorTool.addShape => 'category',
        EditorTool.filter => 'auto_fix_high',
        EditorTool.adjust => 'tune',
        EditorTool.crop => 'crop',
        EditorTool.mask => 'gradient',
        EditorTool.sticker => 'emoji_emotions',
        EditorTool.draw => 'brush',
        EditorTool.eraser => 'auto_fix_off',
        EditorTool.export_ => 'save_alt',
      };
}
