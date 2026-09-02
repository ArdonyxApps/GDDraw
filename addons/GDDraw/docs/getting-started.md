# Getting Started

This page covers installation and the shortest paths to a first 2D drawing or 3D texture-painting session.

## Installing the plugin

1. Copy the `GDDraw` folder into `res://addons/GDDraw` in the Godot project.
2. Open **Project > Project Settings > Plugins**.
3. Enable **GDDraw**.
4. Select the **GDDraw** bottom-panel tab.

> **Screenshot placeholder:** Show Godot's Plugins settings with GDDraw enabled and the GDDraw bottom-panel tab visible below the main viewport.

## Create a 2D drawing

1. Open GDDraw. A new 128 × 128 layered document is available by default.
2. Select the Brush tool and draw with the foreground color.
3. Add paint layers or groups from the bottom of the Layers panel.
4. Choose **File > Save Layered Project** to preserve the editable layer stack.
5. Choose **File > Save As** to export the visible result as a flattened PNG.

The default PNG folder is `res://gddraw/images`. The destination can be changed under **Edit > Preferences**.

## Paint a 3D hierarchy

1. Select a `MeshInstance3D`, supported CSG node, or hierarchy root in Godot's Scene dock.
2. Open GDDraw and switch to 3D or Split View.
3. Choose **Godot > Use Selected 3D Object**, or drag the selected Scene node into GDDraw's 3D view.
4. In the import window, check the textures that should participate in the painting session.
5. Confirm creation if a supported surface needs a `StandardMaterial3D` or albedo texture.
6. Select a texture layer and paint on either the 3D model or its 2D texture.
7. Select **Stop Editing** to review and save every changed texture together.

> **Screenshot placeholder:** Show the 3D hierarchy import window with object names visible, several texture checkboxes selected, and the selection count at the top.

## Understand the two save formats

- **PNG** stores the merged visible pixels for one paint target. Other applications can open it, but the layer stack is flattened.
- **GDDraw layered project (`.gddraw`)** preserves layers, groups, per-target canvas sizes, visibility, opacity, locks, and 3D target bindings.

See [Saving and Files](saving-and-files.md) for the complete workflow.

## Next steps

- Learn where controls live in [Interface](interface.md).
- Read every drawing mode in [Tools](tools.md).
- Learn layer organization in [Layers](layers.md).
