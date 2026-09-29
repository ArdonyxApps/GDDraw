# Layers

The Layers panel organizes editable content without changing the document's visible result until layer properties or pixels are modified.

> **Screenshot placeholder:** Show a compact Layers panel containing nested groups, paint-layer thumbnails, a filtered result, one locked layer, and visibility icons aligned at the far right.

## Layer hierarchy

A 2D document contains one document group and one or more paint layers. A 3D session adds Scene-object hierarchy rows and material/texture targets above their paint layers.

Rows can represent:

- A document or imported Scene object.
- A material and texture paint target.
- A layer group.
- A paint layer with an inline content thumbnail.
- An editable Gradient layer with stored color stops and endpoints.
- An editable Text layer with stored text, font, layout, and colors.

A narrow icon beside each content thumbnail identifies its type: pencil for
paint, Gradient for a gradient layer, T for text, and folder for a group. The artwork thumbnail keeps
its original size. Hover the row for its type description.

Selecting a Gradient layer opens its controls. **Edit Gradient Layer** reopens a
finished draft; **Rasterize Gradient Layer** converts it to ordinary paint pixels.
Both actions are available from the layer context menu. See [Gradients](gradients.md).

Selecting a Text layer restores its canvas editor and top toolbar. Commit updates
the layer; Cancel restores its saved contents. **Edit Text Layer** and **Rasterize
Text Layer** are available in its context menu. Text layers support duplication,
groups, opacity, visibility, locking, and undo/redo. See [Text](tools.md#text).

Scene-object rows use familiar Godot node icons where a matching icon is available.

## Selecting and renaming

Use **Shift-click** to select a visible range or **Ctrl-click** to toggle individual
layers. Right-click a selected row and choose **Group Selected**, or press `Ctrl+G`.
Grouping preserves relative stacking order and takes one undo step. Selected groups
include their descendants once. Selections stay within one paint target; locked
nodes or descendants prevent grouping.

The multi-selection context menu also offers **Show Selected**, **Hide Selected**,
**Lock Selected**, **Unlock Selected**, **Duplicate Selected**, and **Delete Selected**.
Each effective action takes one undo step. Delete uses one confirmation for the
selection and cannot remove the target's final paint layer. The confirmation counts
all layers and groups that will be removed, including nested contents, without
double-counting selected descendants. Locked selections or
locked descendants block duplication and deletion as a whole. Selecting a group
and its children applies the action to the group once; child property settings are retained.

When Text or Gradient is selected, starting a Brush, Fill, or shape operation creates
a new paint layer immediately above it. Text and Gradient use their output preferences
when drawing on a different layer type. Creation and drawing share one undo step;
canceled or ineffective gestures leave no empty layer. Simply selecting a tool does
not create a layer. Pan and Eyedropper leave the layer hierarchy alone. To erase
editable content, first select a paint layer or explicitly rasterize the editable layer.

- Select an unselected row with one click.
- Click the already-selected paint layer or group again to enter inline rename mode.
- Clicking a selected Text layer again resumes text editing; use **Rename** in its context menu to change its layer name.
- Press `Enter` to commit the name.
- Press `Escape` to cancel.
- Right-click and choose **Rename** as an alternative.

Visibility buttons, disclosure arrows, dragging, and context-menu clicks do not trigger accidental renaming.

## Visibility

Select the eye at the far right of any supported row to toggle its visibility. Group and Scene-object visibility affects descendants without deleting or changing their individual visibility settings.

In a 3D session, the imported hierarchy initially copies the source Scene's authored visibility. Scene Sync starts disabled, so the Layers eyes remain independently usable. Enabling Scene Sync adds the live source Scene visibility as another visibility gate.

## Opacity

The percentage field above the tree changes opacity for the selected paint layer or layer group. Thumbnails and the visible composite update with the new opacity.

## Locking

Use the lock control beside opacity to lock the selected paint layer or group. A locked row shows a lock icon beside visibility. Hovering the otherwise empty lock position reveals the lock action without cluttering every row.

Locking a layer prevents modifications from both the 2D canvas and associated 3D drawing interactions. A locked group protects its descendants.

## Filtering

Enter text in **Filter Layers** to find matching objects, materials, groups, or paint layers. The filtered result preserves the tree structure and includes the ancestors needed to understand each match. Select the clear icon to restore the full hierarchy.

## Creating and deleting

The bottom toolbar provides:

- **Add Layer** to create a paint layer in the current target or selected group.
- **Add Group** to create a nested layer group.
- **Delete** to remove the selected deletable layer or group.

The protected Base layer cannot be deleted. Creation and deletion participate in undo and redo.

## Reordering and nesting

Drag rows to reorder layers, nest them into groups, or move them out of groups. Placement bars show the proposed destination. Invalid drops, including hierarchy cycles and protected Base-layer moves, are rejected.

Drag any selected row to move the entire selection together. Drop onto a group or
subgroup to nest the selected items, between rows to reorder them, or onto the
target header to move them to the root. Relative stacking order is preserved and
the move takes one undo step. Moves stay within one target and reject locked
sources/destinations and hierarchy cycles. Clear the layer filter before reordering.

The context menu also provides **Move Up**, **Move Down**, **Move Into Group**, and **Move Out of Group** for keyboard-friendly hierarchy changes.

## Clipboard and context actions

Right-click a paint layer or group for actions appropriate to that row, including:

- Cut, Copy, and Paste complete layer nodes.
- Rename and Duplicate.
- Show, Hide, Hide Others, and Show All.
- Lock or Unlock.
- Merge Down or Merge Visible where valid.
- Create paint layers or groups.
- Reorder or reparent the hierarchy.
- Delete.

The context menu shows each available keyboard shortcut in a muted, right-aligned column. With the Layers tree focused, use `Ctrl+X`, `Ctrl+C`, and `Ctrl+V` for layer-node clipboard actions; `Ctrl+J` to duplicate; `Delete` to remove; `Ctrl+Shift+N` to add a paint layer; and `Ctrl+G` to group the selection. Duplicate, Delete, and Group also support multiple selected items. These follow Affinity's familiar layer shortcuts and do not replace `Ctrl+D` for duplicating a canvas pixel selection.

Document, Scene-object, and texture-target rows receive context menus appropriate to their higher-level responsibilities, such as document sizing, framing a 3D object, selecting it in the Scene, resizing a texture target, or saving textures.

## Thumbnails

Paint-layer thumbnails frame the layer's visible content rather than displaying the entire canvas at an unreadable scale. Thumbnail refreshes are cached and update when pixels, opacity, or other relevant layer state changes.

Groups use a combined preview of their visible descendants when available, making their contribution recognizable without expanding the group.
