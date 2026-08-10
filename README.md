# GDDraw

GDDraw 0.1.0 is a preview Godot editor plugin for drawing prototype PNG assets and painting albedo textures on supported 3D surfaces without leaving the editor.

## Requirements

- Godot 4.7 or later.
- A desktop editor build. Clipboard and native file-dialog behavior can vary by operating system.

## Installation

1. Copy the `GDDraw` folder to `res://addons/GDDraw` in your project.
2. Open **Project > Project Settings > Plugins**.
3. Enable **GDDraw**.
4. Open the **GDDraw** bottom panel.

For an Asset Store package, `addons/GDDraw` is the package boundary. Do not include the repository's `docs`, development files, `.godot` cache, generated `.import` files, or user-created content.

## What Is Included

- 2D drawing with brush, eraser, fill, line, rectangle, ellipse, eyedropper, selection, lasso, transforms, crop, scale, mirror, grid, and tile preview tools.
- PNG new/open/save/save-as workflows and `Sprite2D` creation.
- Undo/redo and exact dirty-state tracking for independent 2D documents.
- Texture-painting sessions for `MeshInstance3D` and supported single-material CSG geometry with triangle UVs.
- 2D, 3D, and linked split views with UV overlays and editor-style 3D navigation.
- Protected session replacement, save/discard/cancel flows, 2D workspace restoration, and editor undo/redo for material or texture assignment.

## Quick Start: 2D

1. Open the GDDraw bottom panel and draw on the canvas.
2. Use **File > New**, **Open**, **Save**, or **Save As** for PNG documents.
3. Use **Godot > Create Sprite2D** to add the current saved image to the edited 2D scene.

The default save folder is `res://gddraw`, and it can be changed in Preferences.

## Quick Start: Paint a 3D Surface Texture

1. Select a `MeshInstance3D`, a supported material-bearing CSG shape, or a parent containing one.
2. Switch GDDraw to 3D or Split view and choose **Use Selected 3D Surface**. You can also drag the Scene-tree node into the 3D pane.
3. Choose an editable material slot. Missing materials or textures are created only after explicit confirmation.
4. Paint the albedo texture. The eraser restores pixels from the texture loaded at session start.
5. Use **Save**, **Save As**, or **Stop Editing**. A successful Save As assigns the new PNG through Godot's editor undo/redo system.

Starting a 3D session preserves the independent 2D workspace. Unsaved 2D or 3D changes are guarded by save/discard/cancel prompts.

## Controls

- 2D: left drag uses the active tool, mouse wheel zooms, and middle drag pans.
- 2D zoom starts at 10% and uses the visible 2D viewport to set its maximum, allowing detailed pixel inspection without unbounded zoom.
- 3D: left drag paints, middle drag orbits, Shift+middle drag pans, and the mouse wheel zooms.
- 3D freelook: hold right mouse and use WASD; Q/E move vertically; Shift/Alt adjust speed.
- Press F to frame the active 3D surface.
- Use **Help > Controls** in the plugin for selection shortcuts and the complete compact reference.

## Known Limitations

- Overlapping UV shells can make linked 2D-to-3D hover highlight a hidden or rear surface.
- 3D painting is limited to albedo textures on `StandardMaterial3D` targets and supported single-material CSG generated geometry with usable triangle UVs.
- Unsupported shader materials, texture channels, and multi-material CSG results must be prepared outside GDDraw.
- Dense seams, mirrored UVs, tiny islands, and complex UV overlap need additional validation.
- Split mode and Preferences can crowd narrow bottom-panel layouts.
- Active 3D texture sessions lock canvas resizing to protect the source texture.
- Independent 2D document Save/Save As output is PNG.

See [`docs/feature-backlog.md`](docs/feature-backlog.md) for non-blocking follow-up work and [`docs/architecture.md`](docs/architecture.md) for implementation boundaries.

## Release Packaging

Ship only the contents rooted at `addons/GDDraw`. Keep source `.gd.uid` files because they preserve Godot resource identity; exclude generated `.import` sidecars and editor caches. The release archive should contain `addons/GDDraw/plugin.cfg` at that exact path. Repository documentation and development metadata live outside the package boundary.

## AI-Assisted Development

AI-assisted development tools were used during implementation, refactoring, documentation, and code review. All changes were directed, reviewed, tested, and approved by the maintainer.

## License

GDDraw is released under the MIT License. See [`LICENSE`](LICENSE) for the full license text.

The bundled icons are derived from Lucide and require Lucide's ISC license notice; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
