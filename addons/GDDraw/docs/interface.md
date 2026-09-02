# Interface

GDDraw follows Godot's compact editor layout: menus and contextual options at the top, tools on the left, the drawing workspace in the center, and Layers on the right.

> **Screenshot placeholder:** Add a numbered interface overview. Label the menu bar, tool options, tool rail, 2D canvas, 3D preview, status bar, Layers panel, and view selector.

## Menu bar

### File

Creates, opens, saves, exports, and closes drawing sessions. During a 3D hierarchy session, saving is consolidated through **Stop Editing** so all changed textures can be reviewed together.

### Edit

Contains undo, redo, clipboard commands, clear, and Preferences. See [Preferences](preferences.md) for Brush, View, and Files defaults.

### Image

Scales the current document, resizes its canvas, crops to a rectangle, or trims transparent bounds. Imported 3D texture targets protect their texture dimensions while the 3D session is active.

### Select

Contains selection creation, transformation, clipboard, crop, commit, and cancellation commands.

### Tool

Provides brush presets and settings that complement the contextual options bar.

### View

Controls the 2D, 3D, and Split View layout, Layers panel visibility, grids, UV overlays, linked hover, tile preview, Navigator, mirroring, and zoom.

### Godot

Starts a 3D session from selected Scene nodes and creates Godot nodes from the current image.

### Help

Opens the searchable documentation reader, update checks, and About information. Shortcuts and Known Limitations are pages in the reader's left navigation.

## Tool options bar

The row below the menus changes with the selected tool. Shared foreground and background colors remain available for tools that use color. Numeric fields display their unit, such as `px`, `%`, or degrees.

## Tool rail

The left rail selects Brush, Eraser, Paint Bucket, Shapes, Text, Eyedropper, and Selection. Shape and Selection each expose related subtools in the options bar.

See [Tools](tools.md) for every option and interaction.

## Drawing workspace

The workspace supports four layouts:

- **2D** displays the image canvas.
- **3D** displays the isolated model preview.
- **Split Horizontal** places 2D and 3D views above and below each other.
- **Split Vertical** places the views side by side.

When linked hover is enabled, pointing at a usable UV area in one view highlights its corresponding location in the other.

## 2D Navigator and scrollbars

When the image extends beyond the visible area, hover near the canvas edges to reveal horizontal or vertical scrollbars. Enable **View > Navigator** to show a small overview with a rectangle representing the visible portion of the image. Drag inside the Navigator to move the viewport.

## Layers panel

The Layers panel can be shown or hidden under **View > Layers Panel**. Its toolbar controls the selected layer's opacity and lock, filters the hierarchy, and optionally enables Scene Sync for a 3D session.

## Status bar

The bottom status line reports actions, validation failures, save progress, and 3D target information. Hover longer messages when the available width clips them.
