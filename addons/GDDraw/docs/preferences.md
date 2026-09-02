# Preferences

Open **Edit > Preferences** to configure GDDraw drawing, view, and file behavior. Changes apply immediately. File defaults and selected workspace preferences are remembered through Godot's project editor metadata.

> **Screenshot placeholder:** Show the complete Preferences overlay with the Brush, View, and Files tabs visible. Use a second close crop of the Files tab showing Default Canvas, Default Save Location, and Fonts.

## Project-specific settings

Remembered Preferences apply to the current Godot project rather than every project opened by the editor. This prevents one project's asset folders, canvas defaults, or display choices from unexpectedly changing another project.

Changing a default does not rewrite existing drawings, textures, or saved files. It affects new documents or later operations as described below.

Close Preferences with the **Close** button or `Escape`. Values are updated as their controls are changed; there is no separate Apply button. Brush settings and several grid controls describe the active dock state, while the Files defaults, checkerboard colors, and grid snapping choice are saved as project-specific preferences.

## Brush tab

### Draw Mode

- **Pixel Perfect** aligns brush coverage to exact image pixels and produces crisp edges.
- **Antialiasing** enables smoother partial coverage around the brush edge.

The selected mode also appears in the contextual Brush options bar.

Brush-tab changes affect the active GDDraw dock. Save a custom Brush preset when a reusable brush configuration is needed.

### Hardness

Hardness controls the falloff of the antialiased brush from `0%` to `100%`. It is hidden when Pixel Perfect mode is active because crisp pixel coverage has no antialiased falloff.

### Allow Stroke Overlap

When enabled, repeatedly passing over a pixel during one continuous stroke can build additional color or opacity. Disable it when one stroke should apply consistent coverage regardless of how often its path overlaps itself.

See [Tools](tools.md) for the other Brush options and their drawing behavior.

## View tab

### Grid

- **Show** displays the 2D image grid once zoom is high enough for its cells to remain readable.
- **Snap** constrains brush strokes, shape endpoints, and selection geometry to grid-cell boundaries. Snapping can remain active even when the grid is hidden.
- **Size px** sets the grid-cell size in image pixels.
- **Min px** sets the minimum displayed cell size before the grid becomes visible at the current zoom.
- **Color** changes the grid-line color and alpha.

### Transparency

The Light and Dark colors control the checkerboard shown behind transparent pixels. These are display settings only; changing them does not alter image pixels or exported PNG files.

Select **Reset** to restore the neutral default checkerboard colors.

## Files tab

### Default Canvas

Width and height determine the starting dimensions of newly created blank GDDraw documents.

- The default is `128 × 128 px` unless changed.
- Each dimension is limited to GDDraw's supported `1–4096 px` canvas range.
- Updating these values does not resize the current document.
- Existing `.gddraw` files and imported PNGs retain their saved or native dimensions.
- Use **Image > Resize Canvas** or the document context menu when the current document itself must change.

### Default Save Location

This folder is offered when saving new PNG files. The initial value is `res://gddraw/images`.

- Enter a `res://` project folder or select the folder button to browse. The destination must remain outside `res://addons/GDDraw`.
- Project overrides are remembered.
- GDDraw does not create a missing folder merely because Preferences was opened.
- A missing valid folder is created only when an image is actually written.
- Changing the default does not move or rename existing PNGs.
- **Save** continues using an existing document's current path; the default primarily affects new **Save As** destinations and generated image assets.

Keeping generated artwork outside `res://addons/GDDraw` ensures plugin updates can replace the installed package without touching project-owned images.

### Fonts

The font folder controls where the Text tool discovers project-specific custom fonts. The initial project folder is `res://gddraw/fonts`.

- Project `res://` folders and supported external filesystem folders can be selected.
- Existing overrides are preserved.
- Scanning does not create a missing folder.
- Supported formats are TTF, OTF, WOFF, and WOFF2.
- Fonts remain in their selected location and are not copied into GDDraw.
- Reopen the Text font selector after adding files so its available choices can refresh.

## Other remembered workspace settings

Some frequently adjusted controls are remembered automatically even though they do not appear as fields in the Preferences overlay. These include Split View orientation and ratios, linked hover state, Layers panel expansion and width, preview-light settings, transform-gizmo visibility, and 3D grid visibility.

These values affect workspace presentation and do not modify document pixels or source Scene resources.

## Resetting defaults

Transparency colors provide a dedicated Reset action. Other fields can be returned manually to the documented defaults.

GDDraw does not currently provide one destructive “Reset All Preferences” button. This avoids unexpectedly replacing established project folders and other project-specific choices.
