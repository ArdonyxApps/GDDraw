# Saving and Files

GDDraw distinguishes flattened image output from editable layered project data.

## PNG files

PNG is the final visible image for a single paint target.

- **Save** writes to the current PNG destination.
- **Save As** chooses a new PNG destination.
- PNG output merges visible layers and groups using their opacity.
- Content outside the canvas boundary is not part of the exported image.

PNG cannot preserve the editable layer hierarchy.

## Layered projects

Choose **File > Save Layered Project** to write a `.gddraw` document. It preserves:

- Paint layers and nested groups.
- Editable Gradient layers, including color stops, endpoints, and fixed selection masks.
- Editable Text layers, including text, embedded font data, layout, colors, and fixed selection masks.
- Layer pixels and out-of-canvas bounds.
- Names, order, visibility, opacity, and locking.
- Per-target canvas dimensions.
- Active target and layer selection.
- 3D hierarchy and material bindings.
- Eraser baselines required for restored 3D texture editing.

For 3D projects, mesh geometry remains in the Godot Scene and is not silently duplicated into the layered file.

Layered documents now use format version 4. This version reads older version 1/2/3
files; older plugin versions cannot open version 4 files. PNG exports remain
flattened and do not retain Gradient or Text editability.

## Closing a document

**File > Close** closes or discards the current drawing session; it does not minimize the GDDraw bottom panel. Dirty documents receive Save, Discard, and Cancel protection.

During a 3D hierarchy session, use **Stop Editing** for the consolidated texture review. Ordinary File-menu Save commands are disabled or redirected appropriately so one texture cannot be saved accidentally while other edited targets are overlooked.

## Drag-and-drop

- Drop images into a layered 2D document to create new paint layers.
- Drop images directly into the Layers tree to control their placement.
- Drop Godot Scene nodes into the 3D view to inspect their compatible hierarchy.
- Dragging a complete hierarchy discovers every compatible descendant instead of stopping at the first texture.

## Project storage

By default, project-owned files are separated from replaceable plugin files:

- `res://addons/GDDraw/` contains installed plugin code, icons, and this manual.
- `res://gddraw/images/` contains generated or saved PNG files.
- `res://gddraw/fonts/` is the default custom-font discovery folder.
- `res://gddraw/palettes/collection.json` stores imported [palettes](palettes.md),
  stable IDs, order, draft snapshots, and the active palette independently of artwork and layout.
- Plain `.hex` files store RGBA colors; names remain in the internal collection. The default folder
  is `res://gddraw/palettes`, configurable under Preferences > Files > Palettes.
  Palette Save offers Save Changes and Save as New. Export HEX offers RGB or RGBA
  copies. GPL/TXT/legacy GDDraw originals are kept when converted to HEX.
- `res://gddraw/brushes/` is reserved for file-backed brush assets; parameter-only presets use project editor metadata.
- `user://gddraw/updates/` stores explicitly downloaded update staging and recovery data.

Folders are created lazily when an operation actually needs to write into them.

Use **Edit > Preferences > Files** to change the default blank-canvas dimensions,
PNG save folder, custom-font folder, or palette folder. See [Preferences](preferences.md)
for when each default applies and which settings leave existing documents unchanged.

## Safe updates

Use **Help > Check for Updates** to perform a manual release check. Downloading and installing remain separate explicit actions. A validated update is staged before **Install and Restart** replaces the complete plugin package.

User-created assets under `res://gddraw/` are outside the replaceable plugin package and are not removed by the updater.
