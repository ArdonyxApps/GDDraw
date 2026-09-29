# Shortcuts

Shortcuts use `Ctrl` terminology. On platforms where Godot maps command shortcuts differently, use the platform-equivalent primary modifier.

## Files and history

- `Ctrl+N` — New document.
- `Ctrl+O` — Open.
- `Ctrl+S` — Save.
- `Ctrl+Shift+S` — Save As.
- `Ctrl+Alt+S` — Save Layered Project.
- `Ctrl+W` — Close the current drawing session.
- `Ctrl+Z` — Undo.
- `Ctrl+Y` — Redo.

## Canvas clipboard and selection

- `Ctrl+A` — Select all.
- `Ctrl+X` — Cut the current pixel selection.
- `Ctrl+C` — Copy the current pixel selection.
- `Ctrl+V` — Paste pixels or an image as a floating selection.
- `Ctrl+D` — Duplicate the current selection.
- `Delete` — Delete selected pixels.
- `Enter` — Commit a floating selection or layer rename.
- `Escape` — Cancel a transform, rename, text draft, or active selection state.
- Arrow keys — Nudge the selection by one pixel.
- `Shift+Arrow` — Nudge the selection by ten pixels.

## Layers tree

When a paint layer or group has keyboard focus in the Layers tree, these Affinity-style shortcuts operate on the complete layer node instead of canvas pixels:

- `Ctrl+X` — Cut the selected layer or group.
- `Ctrl+C` — Copy the selected layer or group.
- `Ctrl+V` — Paste a copied layer or group beside the selected item.
- `Shift+click` — Select a visible range of layers.
- `Ctrl+click` — Add or remove an individual layer from the selection.
- `Ctrl+J` — Duplicate the selected layer items.
- `Delete` — Delete the selected layer items after confirmation.
- `Ctrl+Shift+N` — Create a new paint layer at the selected location.
- `Ctrl+G` — Create a new group containing the selected layer items.

The same shortcuts appear at the right side of the layer context menu. Commands that cannot modify a protected or locked item are disabled.

Right-click a selected row to keep the selection and open its bulk actions.
Drag a selected row to move the selection together, including into nested groups.

## Panel tabs

- Drag a tab — Reorder it or move it to another group; edge drops create splits.
- Left / Right Arrow — Select the neighboring tab while the tab strip has focus.
- Home / End — Select the first or last tab in that group.
- Rail button — Toggle that panel; its blue state means open, including inactive tabs.

## Text

- `Ctrl+Enter` — Commit the Text draft using its selected output mode (editable layer by default).
- `Escape` — Discard the active text draft.
- `Ctrl+C` with highlighted text — Copy characters.
- `Ctrl+C` without highlighted text — Copy the rendered text box as an image selection.

## 2D navigation

- Primary drag — Use the active tool.
- Middle drag — Pan the canvas.
- Mouse wheel — Zoom.
- `Ctrl++` — Zoom in.
- `Ctrl+-` — Zoom out.
- `Ctrl+0` — Reset view.
- `Shift` while drawing a shape — Constrain angles, squares, or circles.

## Gradient

- `G` — Select Gradient while GDDraw has input focus.
- Left drag / release — Preview and apply a gradient as one undoable edit.
- Drag a control node — Adjust the existing Gradient layer; release saves the edit.
- Drag elsewhere — Create another Gradient layer without leaving the current one.
- `Shift` while dragging — Constrain the angle to 45-degree increments.
- `Escape` — Cancel an unfinished gradient gesture without changing pixels or history.

## Palette grid

- Left-click / Enter / Space — Set foreground.
- Right-click / Shift+Enter — Set background.
- Arrows — Move focus spatially without changing colors.
- Home / End — Focus and reveal the first tile / final Add Color tile.
- Enter / Space on Add Color — Open the color picker.
- Shift+right-click / Shift+F10 — Open the focused swatch's edit/remove menu.
- Delete — Remove the focused swatch.
- Ctrl+Z — Undo a palette swatch edit.
- Ctrl+Shift+Z / Ctrl+Y — Redo a palette swatch edit. Command can replace Ctrl.

These keys apply while the palette grid has focus. See [Palettes](palettes.md).

## 3D navigation

- Primary drag — Paint or use the active supported surface tool.
- Middle drag — Orbit.
- `Shift+Middle` — Pan.
- Mouse wheel — Zoom.
- Hold secondary mouse button plus `W`, `A`, `S`, `D` — Freelook.
- `Q` / `E` during freelook — Move down or up.
- `Shift` / `Alt` during freelook — Increase or decrease speed.
- `F` — Frame the active 3D surface.
