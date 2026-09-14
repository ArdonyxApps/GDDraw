# 2D Drawing

The 2D workspace combines a movable image canvas, layered pixel content, selections, and image-level operations.

## Canvas and layer bounds

The document canvas is the export boundary. Individual paint layers may contain pixels outside that boundary, including oversized images dragged or pasted into the document.

The canvas outline remains visible so the exported area is always identifiable. Use Selection tools to move, resize, or rotate oversized layer content.

Middle-drag moves the view of the canvas within the 2D drawing panel; it does not move the document canvas relative to its layers.

## Importing images

Drag a PNG or other supported image onto the 2D canvas or directly into the Layers tree.

- Dropping into an active layered setup imports the image as a new layer.
- The inserted layer is selected automatically.
- Oversized images remain at their original size and enter a workflow where Selection controls can position or scale them.
- Dropping into the Layers tree honors the indicated hierarchy placement where valid.

## Image operations

### Scale Image

Resamples the complete document to new dimensions. Nearest-neighbor is appropriate for pixel art; bilinear interpolation is useful for smoother imagery.

### Resize Canvas

Changes the document boundary. Existing pixels can be retained and anchored according to the resize controls. Layer content is not unintentionally dragged merely because another layer has larger bounds.

### Crop Rectangle

Uses an explicit rectangle to define the new canvas bounds.

### Trim Transparent Bounds

Shrinks the document around visible non-transparent content.

### Crop to Selection

Uses the occupied selected area as the new canvas boundary.

> **Screenshot placeholder:** Show an oversized imported layer extending beyond a clearly visible canvas outline, with Selection handles active and the Navigator visible in the lower-left corner.

## Grid, snapping, and mirroring

The View menu controls the 2D grid and grid snapping. Mirror modes repeat brush and supported tool actions across horizontal, vertical, or both symmetry axes.

## Tile Preview

Tile Preview repeats the current canvas around the main image, helping evaluate seamless textures. The central editable document remains visually identifiable.

## Navigator

Enable **View > Navigator** when zoomed into a large image. The miniature preview displays the complete drawing and a viewport rectangle. Drag the rectangle or click within the Navigator to move to another portion of the document.

## Create a Sprite2D

Choose **Godot > Create Sprite2D** to create a node from the current visible image in the edited 2D Scene. Save the image first when a persistent project texture is required. Node creation integrates with Godot editor undo and redo.
