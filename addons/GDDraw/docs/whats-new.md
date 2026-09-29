# What's New

New features, improvements, and fixes in GDDraw, with the latest version first. Scroll down for earlier releases.

## 0.4.0 — Palettes, editable tools, and flexible panels

### Palettes for drawing and texture painting

- Create palettes, add colors with Godot's color picker, and edit or remove individual swatches.
- Remove focused swatches with Delete or use Edit/Remove Selected Color in the palette menu. Palette-local Undo/Redo reverses swatch edits independently of artwork history.
- Import GIMP `.gpl` palettes and RGB/RGBA `.hex` or `.txt` files, with or without a leading `#` on hex colors.
- Save palettes as standard RGBA HEX files. Export separate RGB or RGBA copies for use in other applications.
- Support bundled starter HEX palettes from `addons/GDDraw/resources/palettes`, with Save as Copy and per-project Hide/Restore actions.
- Show author credits and links beneath attributed palettes. Saved user copies retain their original author credit in the project collection.
- Optionally enable HEX/GPL visibility in Godot's FileSystem from Preferences > Files > Palettes, preserving existing editor-wide text extensions.
- Choose a palette folder under **Preferences > Files > Palettes**, defaulting to `res://gddraw/palettes`. Palettes are discovered on startup, and successful saves, exports, and imports refresh the folder.
- Use left-click for foreground and right-click for background. Choose small, medium, or large swatches, or horizontal rows with hex values.

See [Palettes](palettes.md) for editing, file formats, and keyboard controls.

### Editable Gradient and Text layers

- Draw linear or radial gradients with the new **Gradient** tool (`G`), between Paint Bucket and Shapes. Release the drag to create an editable Gradient layer.
- Adjust endpoints on the canvas or edit colors, positions, and opacity in the Gradient panel. Add, duplicate, and delete intermediate stops. Drag away from existing handles to create another gradient.
- Keep Text editable in its own layer, with font, content, layout, rotation, colors, and optional background fill preserved. Select the layer to resume editing; with Text active, click the letters or text box to reopen its handles.
- Preview Text background-fill changes immediately. Text controls remain in the top bar and canvas editor.
- Choose the default output for Text and Gradients under **Preferences > Tools**. Both default to new editable layers; raster output remains available.
- Save `.gddraw` projects to retain editable tool layers, selection masks, and embedded Text fonts. PNG output remains flattened. Layer thumbnails have small type indicators, and context menus provide explicit rasterization.

Learn more in [Gradients](gradients.md), [Text](tools.md#text), and [Saving and Files](saving-and-files.md).

### A configurable right-side workspace

- Toggle Layers and Palettes independently. A blue rail button means its panel is open, even when another tab is active.
- Reorder tabs by dragging, move panels between groups, or split groups horizontally or vertically. Placement, tab order, and open states are remembered for persistent panels.
- Use the panel placement menu or **View > Reset Panel Layout** to reorganize the workspace. Compact Godot-style arrows navigate overflowing tabs.
- Keep the Gradient button available through **Preferences > Tools > Gradients > Always show Gradient panel button**. Selecting Gradient or starting a gesture reveals its helper panel.
- On ordinary layers, the Gradient panel previews the next gradient using current foreground/background colors. Existing Gradient layers and active drafts retain their edited stops.

See [Interface](interface.md) and [Preferences](preferences.md).

### Layer workflow improvements

- **Shift-click** selects a range; **Ctrl-click** toggles individual layers. Right-click offers Show, Hide, Lock, Unlock, Duplicate, Group, and Delete for the selection.
- Drag selected layers together to reorder them or move them into groups and subgroups. Relative stacking order is preserved, and selected descendants travel with their selected parent only once.
- Bulk edits and moves each use one undo step. Locks and the final paint layer remain protected. Delete confirmation counts all affected layers and groups, including nested contents.
- Starting Brush, Fill, or a shape on a selected Text or Gradient layer creates a paint layer above it. The editable original remains intact, and creation plus drawing share one undo step. Canceled or ineffective gestures leave no empty layer.
- Eraser still requires a paint layer or explicit rasterization. Selecting a tool, panning, or sampling a color does not create layers.

See [Layers](layers.md) and [Shortcuts](shortcuts.md).

### Continuous painting across 3D objects

- Hold a Brush or Eraser gesture across imported objects and compatible material slots, including different texture targets. Each target uses its remembered selected layer and native resolution.
- Undo or redo the whole gesture as one action, including strokes that leave and revisit a target.
- Misses and disconnected surfaces break interpolation instead of drawing a line across unrelated texture areas. Hidden objects, locks, UV validation, and Target Lock continue to apply.
- Target handoffs reuse painting state and avoid repeatedly rebuilding the Layers tree during a stroke.

See [Painting in 3D](3d-painting.md).

## 0.3.0 — Layers and multi-object painting

### Layered artwork

- Build artwork with paint layers and nested groups in a shared Layers panel, available in 2D, 3D, and both split layouts.
- Organize layers with names, thumbnails, filtering, drag-and-drop reordering, visibility, opacity, and locking. Duplicate, copy, paste, and merge layers through their context menus.
- Save editable artwork as a `.gddraw` project, preserving layers and groups. PNG output uses the combined visible result.
- Keep layer pixels beyond the canvas edges and bring them back into view when resizing the canvas. Layer operations participate in undo and redo.

Learn more in [Layers](layers.md) and [2D Drawing](2d-drawing.md).

### Paint an imported hierarchy

- Import a selected surface, an object hierarchy, or multiple selected objects into one 3D painting workspace.
- Paint across imported objects and material slots. Objects using the same texture share one layer stack and update together in the preview.
- Use Target Lock to keep painting on the active texture target.
- Enable Scene Sync to follow source-scene transforms and visibility. Reset restores every imported object's preview transform in one press.
- Reopen layered 3D projects with their source scene, relink them to a compatible current scene, or open their layers alone.
- Review texture changes together in the hierarchy save dialog, including original, edited, and split comparisons. Texture rows default to **Save As & Reassign** each time the dialog opens; choose **Save** deliberately to overwrite an existing texture.

See [Painting in 3D](3d-painting.md) and [Saving and Files](saving-and-files.md).

### Workflow improvements

- Toggle the Text tool's background fill on or off: use the background color behind the text, or leave the text box unfilled.
- Choose colors with an updated color picker that more closely matches Godot's familiar controls.
- Enable **View > Navigator** for a miniature canvas preview showing the visible area. Drag inside it to navigate around the artwork.
- Reduce duplicate image and preview-texture memory when many objects share textures, and improve undo/redo responsiveness for large painting sessions.
- Prepare large hierarchy imports in stages with progress and cancellation.
- Read the bundled offline manual through **Help > Documentation**.
- See **What's New** once after a successful built-in update, or revisit the release history through **Help > What's New**.
- Use GDDraw on Godot 4.4 and later.

## 0.2.0 — More drawing tools and built-in updates

### Drawing and creation

- Add raster text with an editable text box, font size, color, alignment, and wrapping. Position the draft before committing it as one undoable edit.
- Fill 2D regions with Solid, Dither, Pattern, or Custom Image styles. Configure repetition, spacing, scale, rotation, and offsets for patterned artwork.
- Choose how shapes grow: Corner to Corner, From Start Point, or From Canvas Center.
- Draw lines, rectangles, and ellipses on compatible 3D surfaces with previews before committing.
- Create textured CSG spheres and cylinders as well as boxes, with configurable collision and creation options.

### Preview and updates

- Use adjustable preview lighting to make surface depth easier to see, or switch to an unshaded view for texture-color inspection.
- Receive stable-release notifications in Help, download and validate an update, then explicitly choose **Install and Restart**. The updater backs up the installed plugin and supports recovery if installation fails.
- Keep project artwork and settings separate from the replaceable plugin package. Generated images default to `res://gddraw/images`.

## 0.1.0 — Initial release

- Draw directly inside Godot with brush, eraser, fill, line, rectangle, ellipse, and eyedropper tools.
- Edit rectangular and lasso selections with copy, cut, paste, movement, flipping, and rotation. Crop, trim, and scale images with undo and redo.
- Use mirror drawing, a configurable grid, snapping, transparency checkerboards, and tile previews.
- Create, open, and save PNG artwork, then create a `Sprite2D` or textured `CSGBox3D` from a saved image.
- Paint albedo textures on supported meshes and CSG surfaces with usable UVs. Preview UV overlays and use editor-style 3D navigation.
- Work in 2D, 3D, or horizontal and vertical split views, with linked texture and model feedback.
- Protect unsaved work with Save, Discard, and Cancel transitions, and restore the independent 2D workspace after a 3D painting session.

New to GDDraw? Start with [Getting Started](getting-started.md).
