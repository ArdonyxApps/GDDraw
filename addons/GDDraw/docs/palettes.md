# Palettes

Open **Palettes** using the palette icon below Layers in the right rail or
**View > Palettes Panel**. Layers and Palettes toggle independently.
The toolbar has **+ New**, **Save**, the palette selector, and an action menu.

## Create, edit, and save

- **New Palette** asks for a name and creates an empty draft.
- The final **+** tile opens Godot's color picker, including alpha. Press **Add**
  to append the color, or Cancel to leave the palette unchanged. An optional
  name can accompany each color. Moving the picker never changes drawing colors.
- **Shift+right-click** a swatch, or focus it and press **Shift+F10**, for
  **Edit Color** and **Remove Color**. Ordinary right-click still sets background.
- **Delete** removes the focused swatch while the grid has keyboard focus.
  The three-dot menu also offers **Edit Selected Color** and **Remove Selected
  Color**, disabled when the Add tile is selected or no color is available.
- An asterisk beside the palette name marks unsaved changes. Drafts are retained
  in the project collection across reloads. Switching away offers Save, Discard,
  or Cancel; discarding a never-saved new palette removes its draft.
- **Save** offers **Save Changes** and **Save as New Palette**. New and imported
  palettes save RGBA HEX files in the configured folder. Other formats' original
  files stay intact. Save Changes on a HEX palette writes its existing file. Save as New asks
  for a name and creates a distinct palette ID. Existing unrelated files require
  replacement confirmation. Files belonging to another loaded palette must be
  edited through that palette. External changes block a stale overwrite.
- **Export HEX** offers **RGB (RRGGBB)**, omitting transparency, or **RGBA
  (RRGGBBAA)**, preserving it. Export writes a separate copy without clearing
  unsaved edits or changing the saved source. Existing export files require
  replacement confirmation. Use Save Changes to update a managed source file.
- The action menu also contains New, Save, Import, Remove, Rescan, and view choices.
  Choose **Small**, **Medium**, or **Large Tiles**, or **Horizontal Rows** showing
  compact centered hex badges; color names remain in tooltips. The Add tile uses
  the same centered plus icon as New, scaled for the view. View choice is remembered
  per project, independently of palette files.

### Palette folder and HEX files

**Preferences > Files > Palettes** defaults to `res://gddraw/palettes` and accepts
project or absolute folders outside the plugin package. Startup and **Rescan
Palette Folder** read HEX, TXT, GPL, and legacy `.gddrawpalette` files directly in that folder.
Missing folders are created only on save. Invalid files report warnings without
blocking valid files. Repeated scans update known sources; dirty drafts are kept.
Successful saves, exports, and imports automatically rescan this folder, refresh
the palette selector and file dialogs, and request Godot's filesystem scan.
The active palette and unsaved edits are preserved. An export placed in the
scan folder appears as a separate palette after the refresh.
After an imported palette is saved to a different HEX file, its original import is remembered
so scanning both files does not duplicate it. Changed original imports are
reported; manually import one to keep a separate version.

Saving writes plain UTF-8 `.hex`: one uppercase eight-digit RGBA color per line,
without a leading hash. For example:

```text
E84941FF
4175C780
```

Names produce filenames such as `studio.hex`. HEX stores colors only: palette
names, swatch names, IDs, and drafts remain in `collection.json`, which scans ignore.
Empty palettes remain drafts until at least one color is added before saving or
exporting. Imports retain their 1 MiB / 4,096-color bounds. Existing version-1
`.gddrawpalette` JSON files remain importable, including their names and alpha;
future saves use HEX. GPL export is not included.

### FileSystem visibility

To display HEX and GPL files in Godot's FileSystem dock, open **Preferences >
Files > Palettes** and click **Enable** beside **Show palette files in Godot's
FileSystem**. Review the explanation, then choose **Continue** to enable it or
**Cancel** to leave settings unchanged. This optional action adds missing extensions to Godot's editor-wide
text file list and refreshes the FileSystem. Existing entries are preserved.
The button shows **Enabled** when both extensions are already registered.
This affects other projects using those editor settings and remains in place
when GDDraw is disabled. To remove them later, edit Godot's **Editor Settings >
Docks > FileSystem > Textfile Extensions**. Palette loading works without enabling it.

### Bundled starter palettes

GDDraw also scans `.hex` files directly in
`res://addons/GDDraw/resources/palettes/` on startup and each folder refresh.
This fixed location is separate from the configurable user folder. Bundled entries
are marked **(Bundled)** in the selector and can coexist with same-named user palettes.

You can edit their colors, but **Save** asks for a name and creates a separate
HEX copy in your configured folder. The bundled file stays untouched, and the
starter entry returns to its saved colors after the copy succeeds.

For bundled entries, **Hide Bundled Palette** replaces Remove. Hiding is remembered
per project across restarts and rescans; **Restore Bundled Palettes** in the action
menu restores all hidden entries. No packaged files are deleted. Stable filenames
identify bundled palettes across project moves and plugin updates. Source updates
refresh clean entries, while unsaved edits are preserved with a warning.

Bundled palettes can include author credits in `attribution.json` beside their
HEX files. A compact **Palette by Author** footer links to the supplied author or
palette page when clicked; license details appear on hover. No attribution means
no footer. Edited palettes and saved user copies display **Based on a palette by
Author**. Copies retain their credit in the project collection across reloads and
rescans. Standalone HEX files contain colors only, so include credits separately
when sharing or exporting. The metadata template is documented in
`res://addons/GDDraw/resources/palettes/README.md`.
Rescan applies credit corrections without changing colors.

## Use colors

### Undo and redo palette edits

Adding, editing, and removing swatches have their own per-palette undo history.
With the palette grid focused, use **Ctrl+Z** to undo and **Ctrl+Shift+Z** or
**Ctrl+Y** to redo (Command works in place of Ctrl). The three-dot menu also
offers **Undo Palette Edit** and **Redo Palette Edit**. These operations do not
change drawing colors, canvas pixels, layers, or artwork undo history.

Switching palettes retains each palette's history for the current session. New
edits clear that palette's redo branch. Saving preserves history when colors stay
unchanged; undo after saving marks the palette dirty until its saved colors are
restored. Discard, removal, reload, and rescans that replace colors clear affected
history. History is bounded to 64 snapshots / 8 MiB across palettes and does not
persist across editor restarts. Palette creation, removal, import, save, and export
are outside swatch undo/redo. Saved HEX files are not rewritten by Undo or Redo;
use Save to write the resulting colors.

### Assign drawing colors

- Left-click a swatch to set foreground; right-click to set background.
- Focus the grid with Tab or a click. Arrows move spatially; Home and End reach
  the first tile and final Add tile. Focus movement alone does not change colors.
- Enter or Space sets foreground; Shift+Enter sets background.
- Hover for the swatch name, hex value, alpha, and interaction hints.
- **F** and **B** mark matching foreground and background colors, including
  duplicates. A separate editor-accent blue outline marks keyboard focus. Checkerboards
  show transparency.

The grid offers 24-, 32-, or 48-pixel cells and adjusts its columns to available width.
Scroll vertically to browse; keyboard navigation reveals the focused swatch.
Choosing or importing a palette never assigns its first color. Assignments use
the existing color controls and draft-preview behavior. Foreground assignments
also enter recent colors.

## Import syntax

Each file must be valid UTF-8, at most **1 MiB (1,048,576 bytes)**, and contain
**1–4,096 swatches**. Optional UTF-8 BOM and LF or CRLF line endings are accepted.
Order, duplicates, and supported names and alpha are retained. Invalid records
reject the entire import; errors identify the line where applicable.

**.hex and .txt:** one `RRGGBB` or `RRGGBBAA` per line, with an optional leading
`#` (for example, `E84941` and `#E84941` are equivalent). Hex digits are
case-insensitive. Surrounding whitespace, empty lines, and full-line comments
starting with `;` or `//` are accepted. `#` belongs to the color token; it is
never a comment prefix. Inline comments, extra tokens, shorthand colors, and
`0x` prefixes are rejected. The filename stem supplies the palette name.

```text
; Opaque coral and translucent blue
#E84941
#4175C780
```

**.gpl:** the first line must be `GIMP Palette`. Optional `Name:` and
`Columns:` metadata may each occur once before colors. Name defaults to the
filename stem; a supplied name must not be empty. Columns must be an integer
from 0 to 255; it is validated but the responsive grid chooses its own columns.
Blank lines and full-line `#` comments are allowed. Each color line contains
three decimal RGB channels from 0 to 255, separated by spaces or tabs, followed
by an optional name. Leading zeros and explicit positive signs are accepted.
Colors are opaque.

```text
GIMP Palette
Name: Studio
Columns: 0
# RGB and optional swatch name
232 73 65 Coral
65 117 199 Blue
```

The GPL reader follows the [GIMP format specification](https://developer.gimp.org/core/standards/gpl/).
It also tolerates surrounding whitespace, whitespace-only lines, comments
before metadata, and Columns without Name. Duplicate metadata or metadata
after a color is rejected. Unsupported formats are not inferred from content.

## Project storage and removal

Parsed palettes live in `res://gddraw/palettes/collection.json`, separate from
artwork and panel layout. No source file is needed after import. Same-named
imports get distinct IDs and names such as `Studio (2)`. Successful import
selects the new palette for viewing. The active palette and collection order
survive editor restart. The collection supports up to 256 palettes and 64 MiB
of normalized JSON; exceeding either limit rejects the operation.

The directory is created on the first write. Writes verify a temporary sibling
file and replace the collection with one rename. On failure the old collection
and active palette remain intact. Invalid, unreadable, or unsupported stored
data blocks changes and reports an error rather than overwriting it. Repair or
move that file, then reopen GDDraw. An external collection change also blocks
stale writes until reopening.

Removal asks for confirmation and removes only the managed project copy.
Cancel keeps it. The original import file is never deleted. Removing the active
palette shows the next palette in collection order, or the previous one when
removing the last entry. Removing the sole palette returns to the empty state.
If its source remains in the configured scan folder, a later scan can import it
again. Move that source out of the scan folder to stop automatic discovery.

Move Palettes using the same tabs, placement menus, splits, collapse/reopen,
and **View > Reset Panel Layout** as Layers. The selected palette, remembered
swatch, and scroll survive placement changes. Importing, browsing, removal,
and placement do not dirty artwork or add drawing history. Plugin updates do
not replace project palettes. Image extraction, online
services, gradients, and additional import formats are outside this milestone.

Rail buttons independently toggle their own panels. Blue means open, even for
an inactive tab. Opening Palettes adds its tab beside Layers in the default
arrangement; closing Layers leaves Palettes open. Closed panels retain their
tab order and split placement across editor restarts. Reset opens all panels
in one tab group; the group menu retains its explicit Collapse Group action.
