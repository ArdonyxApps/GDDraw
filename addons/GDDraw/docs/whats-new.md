# What's New

New features, improvements, and fixes in GDDraw, with the latest version first. Scroll down for earlier releases.

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
