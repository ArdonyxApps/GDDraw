# Interface

GDDraw follows Godot's compact editor layout: menus and contextual options at the top, tools on the left, the drawing workspace in the center, and Layers on the right.

> **Screenshot placeholder:** Add a numbered interface overview. Label the menu bar, tool options, tool rail, 2D canvas, 3D preview, status bar, Layers panel, and view selector.

## Menu bar

### File

Creates, opens, saves, exports, and closes drawing sessions. During a 3D hierarchy session, saving is consolidated through **Stop Editing** so all changed textures can be reviewed together.

### Edit

Contains undo, redo, clipboard commands, clear, and Preferences. See [Preferences](preferences.md) for Tools, View, and Files defaults.

### Image

Scales the current document, resizes its canvas, crops to a rectangle, or trims transparent bounds. Imported 3D texture targets protect their texture dimensions while the 3D session is active.

### Select

Contains selection creation, transformation, clipboard, crop, commit, and cancellation commands.

### Tool

Provides brush presets and settings that complement the contextual options bar.

### View

Controls the 2D, 3D, and Split View layout, Layers and Palettes visibility, panel layout reset, grids, UV overlays, linked hover, tile preview, Navigator, mirroring, and zoom.

### Godot

Starts a 3D session from selected Scene nodes and creates Godot nodes from the current image.

### Help

Opens the searchable documentation reader, update checks, and About information. Shortcuts and Known Limitations are pages in the reader's left navigation.

## Tool options bar

The row below the menus changes with the selected tool. Shared foreground and background colors remain available for tools that use color. Numeric fields display their unit, such as `px`, `%`, or degrees.

## Tool rail

The left rail selects Brush, Eraser, Paint Bucket, Gradient, Shapes, Text, Eyedropper, and Selection. Shape and Selection each expose related subtools in the options bar. Gradient keeps Linear/Radial and Reverse there; output defaults live in Tools preferences, stop opacity in the Gradient panel, and layer opacity in Layers.

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

## Right-side panels and placement

The palette icon below Layers opens [Palettes](palettes.md). Both panels use
the same tab groups, horizontal/vertical splits, placement menus, and project
layout persistence. Each rail icon independently opens or closes its panel.
Drag a panel tab left or right to reorder it. A blue insertion marker shows its
destination; dropping on another group's tab strip also uses that position.
Tab order is saved with the project layout and survives editor restarts.
Drop near a group's left, right, top, or bottom edge to create a split, or use
its three-dot placement menu. Drag a split divider to adjust the space it receives.
When tabs overflow, the compact arrows at their right select and reveal adjacent
tabs. With the tab strip focused, Left/Right selects a neighbor and Home/End selects
the first/last tab.
Every open panel stays highlighted blue, including inactive tabs. Closing a
panel removes its tab but remembers its position and split orientation for
reopening and editor restarts. **View > Reset Panel Layout** opens all panels
in the default tab group. The group menu can still collapse the entire group.
Older Layers-only layouts gain a Palettes tab while retaining their visibility
and arrangement.

The [Gradient](gradients.md) helper is available when its tool or an editable
Gradient layer is selected. Select the tool or begin a gradient gesture to reveal
the helper. Enable **Preferences > Tools > Gradients > Always show Gradient panel
button** to keep its rail button available at all times and persist its placement.
Its rail button stays highlighted whenever the panel is open, including when a
different tab is active.

## Status bar

The bottom status line reports actions, validation failures, save progress, and 3D target information. Hover longer messages when the available width clips them.
