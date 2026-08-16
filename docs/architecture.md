# GDDraw Architecture

This document is a compact handoff for future work on the GDDraw Godot editor plugin.

Unless otherwise noted, source paths in this document are relative to `addons/GDDraw/`.

## Plugin Shape

- `GDDraw.gd` is the `EditorPlugin` entry point.
- `gddraw_dock.gd` builds and owns the editor dock UI.
- `gddraw_canvas.gd` owns the image data, canvas view state, drawing behavior, and rendering.
- `gddraw_history.gd` owns the dock undo/redo image stacks.
- `gddraw_shortcuts.gd` translates raw key events into GDDraw shortcut actions.
- `gddraw_storage_paths.gd` defines the immutable plugin boundary, canonical project asset paths, reserved update-staging path, and shared metadata access for font and parameter-only brush preferences.
- `gddraw_update_checker.gd` owns the stable GitHub Release request, semantic version comparison, exact release-asset selection, and release/asset URL validation.
- `gddraw_updater.gd` owns download progress/cancellation, archive and digest validation, staging manifests, verified backups, transactional replacement, rollback/recovery, and the wrapped restart request.
- `gddraw_png_io.gd` owns PNG path normalization, default PNG names, resource-directory creation, and default-save-dir metadata access.
- `gddraw_3d_texture_session.gd` owns active mesh/material/texture identity, UV data, the loaded eraser source, and the equality-based saved baseline.
- `editor_integration/` contains narrow helpers for editor-scene workflows that need `EditorPlugin` access.
- `plugin.cfg` registers the plugin.
- `icons/` contains only the Lucide families used by GDDraw. Each family uses `icons/<name>/<name>_0.svg` for its normal state, `_1.svg` for its selected state, and an optional `_2.svg` for its disabled state. SVG colors are authoritative, so shared icon-button styling uses a white theme tint in every authored state. The dock falls back to `_0.svg` with a consistent disabled fade when a requested `_2.svg` is absent.
- Release packages intentionally exclude generated `.import` metadata and `.godot/` content. After all icon-bearing controls have been constructed and registered, the dock always starts one bounded icon-readiness cycle with an immediate pass; `filesystem_changed`, `resources_reimported`, and `resources_reload` can coalesce and expedite later passes but cannot restart or extend that cycle. Each idle pass reloads pending button, toggle, disabled, menu-button, and static `TextureRect` textures with `ResourceLoader.CACHE_MODE_REPLACE`; scanning/importing checks defer loading but still count as attempts. The cycle stops when every registered icon returns a `Texture2D`, after 180 attempts at approximately one-second intervals, or at its monotonic three-minute deadline, whichever comes first. Generation and callback tokens make queued callbacks harmless after expiry or teardown, and imported-cache paths are correlated to registered icon families where Godot reports them instead of SVG sources. `is_importing()` is feature-detected because Godot 4.4 exposes `is_scanning()` but not the newer import-state method. The recovery only reapplies recorded icon intent and never rebuilds the dock or changes document, history, preferences, viewport, or 3D-session state.

## Quick Code Map

- Start with `GDDraw.gd` for plugin lifecycle and bottom-panel registration.
- Read `gddraw_dock.gd` when changing menus, dialogs, toolbar controls, preferences, status text, 3D viewport orchestration, save prompts, or editor-scene integration.
- Read `gddraw_canvas.gd` when changing pixels, tools, selection behavior, canvas input, zoom/pan, drawing previews, crop/scale, fill, brush stamping, or image mutation.
- Read `gddraw_3d_surface_target.gd` when changing which 3D/CSG nodes are supported, how material slots are discovered, or how scene materials/textures are assigned.
- Read `gddraw_3d_texture_session.gd` when changing 3D texture-session lifecycle, dirty-state tracking, source texture loading, Save/Save As, eraser baseline behavior, or UV data handoff.
- Read `gddraw_png_io.gd`, `gddraw_history.gd`, and `gddraw_shortcuts.gd` for small focused helpers that should stay easy to reason about.
- Read `editor_integration/gddraw_sprite_creator.gd` for editor-scene actions that require `EditorPlugin` or editor undo/redo access.

`gddraw_canvas.gd` and `gddraw_dock.gd` are intentionally the large coordination files for 0.1.0. Prefer small helper extraction after release, once behavior has settled, rather than broad pre-release movement.

## Responsibilities

### `GDDraw.gd`

- Creates one `GDDrawDock` instance in `_enter_tree`.
- Adds the GDDraw UI to the editor bottom panel.
- Removes and frees the dock in `_exit_tree`.
- Should stay thin unless plugin lifecycle behavior changes.

### `gddraw_dock.gd`

Owns editor-facing workflow and controls:

- Top file row: save PNG, load PNG, create `Sprite2D`, and settings toggle.
- Tool row: brush, eraser, paint bucket, line, rectangle, ellipse, eyedropper, pan, zoom out, zoom in, reset view, undo, redo, and clear.
- Brush color, preset, recent-size, hardness, head, touch-pixels, fill-mode, and shape controls.
- Select-menu quarter turns, duplication, and explicit floating-selection Commit/Cancel controls.
- Canvas resize controls.
- Canvas overlay settings panel for pixel-perfect mode, grid controls, checkerboard colors, zoom readout, grid display threshold, default canvas size, and default save location.
- Undo/redo stacks for image-changing actions.
- PNG saving through a resource `FileDialog`, defaulting to `res://gddraw/images`.
- PNG loading through a resource `FileDialog`, starting from the default save location.
- Canvas drag/drop accepts image files, texture resources, and Sprite2D nodes with texture paths.
- Paste routes native clipboard images and text image paths into the same floating-selection workflow as GDDraw selection copies.
- Delegation to editor integration helpers for creating a `Sprite2D` in the edited scene.
- Save / Discard / Cancel coordination for destructive active-session transitions. Pending image or mesh replacements stay staged until the choice resolves.
- The explicit 3D session picker, persistent session identity, Stop Editing action, and pre-session 2D workspace snapshot/restoration.
- Independent 2D document identity and an RGBA8 saved baseline. Starting a 3D session stages the picker choice until Save, Continue Without Saving, or Cancel resolves.
- A compact bottom context row reserved for actionable controls. The active 3D identity lives in the Stop Editing tooltip rather than a permanent wrapping label.

The dock should coordinate state, but avoid owning drawing math. If a feature changes canvas pixels or canvas view behavior, prefer exposing a small method/property on `gddraw_canvas.gd`.

Small helper scripts should stay free of editor-node ownership. The dock should continue to own dialogs, status text, canvas calls, and editor-plugin integration.

### Update checker and updater

See [`updater-guide.md`](updater-guide.md) for the maintainer-facing release checklist and the complete user-visible upgrade, rollback, restart, and activation flow.

- `GDDraw.gd`'s `PLUGIN_VERSION` remains the only installed-version authority. The dock reads that script constant when starting a check and when presenting update details.
- `gddraw_update_checker.gd` queries `https://api.github.com/repos/ArdonyxApps/GDDraw/releases/latest`, rejects draft/prerelease or malformed responses, distinguishes current from an installed build ahead of the release, and accepts only the exact `GDDraw-vX.Y.Z.zip` asset and its GitHub-provided SHA-256 digest from the configured repository.
- One automatic check is allowed per editor session. Manual checks may run again after completion, simultaneous requests are rejected, and network/HTTP/JSON/version errors return ordinary result data rather than editor errors.
- `gddraw_updater.gd` uses explicit `IDLE`, `CHECKING`, `CURRENT`, `INSTALLED_AHEAD_OF_RELEASE`, `UPDATE_AVAILABLE`, `DOWNLOADING`, `VERIFYING`, `READY_TO_INSTALL`, `INSTALLING`, `RESTART_REQUIRED`, `RECOVERING`, and `FAILED` states. Network, archive creation, filesystem mutation, restart, and browser opening have test seams; tests never contact GitHub, replace the development plugin, restart Godot, or open a browser.
- The dock owns the Help badge, user consent, progress controls, action buttons, state-to-copy mapping, and reusable clipped update popup. The popup remains a child of the workspace region, not a native `Window` or dialog.
- Download and validation write only below `user://gddraw/updates/`. Installation begins only after **Install and Restart**, revalidates the stage, makes and verifies a full backup, records a transaction, builds an exact sibling candidate, and performs a two-rename swap. The short boundary between moving the old directory aside and moving the verified candidate into place is not atomic, but failure deterministically renames the old directory back or restores the verified backup.
- The official `EditorInterface.restart_editor(true)` API is available throughout Godot 4.4-4.7 and is feature-detected before use. A pending transaction is not called active until the next editor session validates the target version. Startup recovery completes a valid target, rolls an invalid/incomplete target back from its verified backup, or stops without further mutation when neither copy validates.
- Godot 4.4 `ZIPReader` exposes entry paths and contents but not ZIP external attributes. Link-like names are rejected, all disk extraction is confined after full-list validation, and unexpected native payloads are forbidden, but a symlink encoded only in unavailable external attributes cannot be identified directly. GitHub's externally supplied digest authenticates the downloaded bytes against release metadata; it is not maintainer code signing.

## Storage Boundaries

The installed package and project content have separate lifecycles:

- `res://addons/GDDraw/` is immutable during checks, downloads, validation, popup use, and cancellation. Only the explicitly confirmed installation transaction may replace this package. It contains plugin code, bundled icons/resources, licenses, and notices only; no generated asset, archive, or temporary file is written below it.
- `res://gddraw/images/` is the new-user PNG default.
- `res://gddraw/brushes/` is the canonical reserved location for future file-backed brushes. The current parameter-only custom brush dictionaries stay under the `GDDraw/custom_brush_presets` project metadata key; there is no brush-import workflow in 0.2.0.
- `res://gddraw/fonts/` is the new-user project-font default. The Text tool scans configured project or external folders in place without copying fonts.
- `user://gddraw/updates/downloads/` contains unique partial/completed archives, `staged/vX.Y.Z/<unique>/` contains extracted candidates and validation manifests, and `backups/vX.Y.Z-<unique>/` contains verified previous packages. A transaction descriptor at the update root coordinates replacement and recovery. These paths are created only by explicit download/install actions or recovery, never by ordinary checking.

Directory creation is write-driven. Plugin enablement, dock construction, Preferences construction/opening, file-dialog opening, and missing font/brush scans are read-only. A resource directory is created only at the immediate PNG write boundary used by 2D Save/Save As, confirmed missing 3D texture creation, 3D texture Save As, or current-image CSG creation. Path validation normalizes resource paths and rejects every write under the plugin package.

Defaults are fallbacks, not migrations. Project-scoped editor metadata remains authoritative when a key already exists, including legacy values such as `res://gddraw` and `res://fonts`. GDDraw does not rewrite those values merely because the 0.2.0 defaults changed, and it never moves, copies, renames, or deletes existing user images, fonts, brushes, or preference data.

### `gddraw_3d_texture_session.gd`

- Consumes an editable 3D surface target and discovers material/surface slots without mutating the source node, material, or texture.
- Reports supported `StandardMaterial3D` albedo file textures, missing textures that require explicit creation confirmation, and explanations for disabled choices.
- Treats readable in-memory albedo textures as recoverable sessions whose first persistent write must use Save As.
- Normalizes loaded and saved working images to RGBA8.
- Keeps `base_image` as the original loaded eraser-restore source.
- Keeps `baseline_image` as the last successfully loaded or saved image used for clean/unsaved equality checks.
- Advances `baseline_image` only after the texture write succeeds.
- Exposes compact mesh/texture identity without owning status controls or dialogs.
- The dock creates a candidate session for mesh replacement and commits it only after loading succeeds, preserving the current session on replacement errors.

### `gddraw_3d_surface_target.gd`

- Adapts both `MeshInstance3D` and supported material-bearing `CSGShape3D` nodes behind one source-node, transform, mesh-snapshot, material-slot, identity, and assignment interface.
- Uses a read-only generated CSG mesh snapshot for UV extraction, preview rendering, ray hits, linked hover, and painting; the edited scene keeps its original CSG nodes.
- Validates triangle topology and matching UV data before entry. It never fabricates UV coordinates.
- Treats CSG combiners as parents to resolve rather than assignable targets, and disables multi-material generated CSG results instead of choosing an arbitrary material.
- Assigns duplicated materials/textures through editor undo/redo callbacks. CSG nodes with no material can receive a new `StandardMaterial3D` only after the separate creation confirmation.
- Fingerprints generated geometry so the session can refresh a still-usable snapshot or pause 3D painting safely when geometry becomes unusable.

### `editor_integration/`

Contains editor-focused helpers for workflows that touch the edited scene or editor undo/redo.

- `gddraw_sprite_creator.gd` creates a `Sprite2D` named `GDDrawSprite`, or a configured `CSGBox3D`, `CSGSphere3D`, or `CSGCylinder3D`, in the current edited scene through Godot editor undo/redo.
- The dock owns the confined **Create Textured CSG3D…** workspace overlay and passes one options dictionary for shape, current-image assignment, created-node selection, and native collision. It is a clipped dock child rather than a native editor window. The helper owns validation, scene/resource construction, unique PNG paths, and the single editor undo/redo transaction.
- Textured creation duplicates and normalizes the input to RGBA8 without changing the canvas, writes a unique shape-specific PNG under the configured `res://` folder, and centralizes path-backed `Texture2D` creation. The local-to-scene white `StandardMaterial3D` uses nearest filtering and explicit per-shape UV transforms: Box and Cylinder mirror U around the texture center; Sphere keeps Godot's image-oriented generated UVs unchanged.
- Creation without current-image assignment does not inspect visible pixels, create a PNG, or allocate a material. Optional selection uses `EditorSelection`; selection-disabled creation never touches the prior selection, and selection-enabled undo removes the created node from selection before removing it from the scene.
- Undo retains the PNG as a non-destructive project asset while removing the scene node and its scene-owned resource reachability. Redo restores the same node, name, owner, material, texture, collision state, and requested selection.
- `CSGTorus3D` remains intentionally unexposed. Deterministic generated-mesh validation finds seam triangles whose UVs wrap from near 1 to 0 along both axes, so interpolation and paint hits cross unrelated texture regions at both periodic seams.
- Helpers in this folder should stay narrow and return status data for the dock to display.
- The dock keeps ownership of status text, UI controls, dialogs, and canvas state. Avoid broad scene-integration refactors here until the UI overhaul is complete.

### `gddraw_canvas.gd`

Owns canvas behavior:

- Image storage and texture refresh.
- Active tool mode, brush and eraser stamping, contiguous/global/replace-color fill, eyedropper sampling, and shape previews/commits.
- Pixel-perfect and deterministic hardness-controlled antialiased brush modes.
- Stroke preview generated from the same footprint and coverage math as committed brush pixels.
- Exact RGBA8 rectangular/lasso/floating selection quarter turns, duplication, nudging, commit, and cancel behavior.
- Canvas resize and clear.
- Local mouse position to image pixel conversion.
- Preference-colored checkerboard background and preview-only neighboring tile rendering.
- Texture drawing.
- Grid drawing.
- Canvas outline.
- Zoom and pan state.
- Capture/restoration of the raw image plus selection masks, floating-selection state, and view state for 3D session isolation.
- Clipping all zoomed/panned drawing to the canvas work area.

Current view behavior:

- Zoom starts at `10%`; the maximum is half the shorter drawable 2D viewport dimension, expressed as a pixel-scale percentage, with a high numerical safety ceiling.
- Toolbar zoom buttons call `zoom_in()` and `zoom_out()`.
- Mouse wheel zooms around the cursor.
- Reset view returns zoom to `100%` and clears pan.
- Pan tool uses left-drag.
- Middle mouse drag pans as a shortcut.

## Data Flow

- The dock creates the canvas and connects:
  - `stroke_committed(previous_image)` to push undo history.
  - `canvas_size_changed(size)` to sync width/height spinboxes.
  - `view_changed(zoom_percent)` to update the zoom readout and zoom button disabled state.
  - `color_picked(color, pixel)` to sync the brush color swatch and status text.
- The dock writes simple canvas properties directly for active tool, brush/preset settings, fill mode, mirror mode, view preferences, grid visibility, and grid settings.
- Canvas image mutation methods return or emit the previous image so dock-level undo remains centralized.
- While a 3D texture session is active, canvas image changes refresh the live preview and recompute dirty state from exact dimensions and RGBA8 bytes. Tool/view/hover/selection-only changes do not affect it.
- A 3D drag remains one canvas/history stroke, but interpolation between samples is continuity-gated in the dock. Same-triangle hits connect; edge-adjacent triangles connect only across a locally continuous UV boundary. Ray misses, surface changes, nonadjacent triangles, and large UV seams restart with a single stamp so unrelated texture regions are never bridged.
- The 3D Line, Rectangle, and Ellipse tools capture their starting mesh/material surface, triangle, mesh/texture UV, deterministic image pixel, foreground/background colors, and shape settings. Their endpoint stays valid only on the same surface and geometry-plus-UV-connected island; seams and disconnected geometry cancel with a status reason. A ray-selected, spatially distinct mirrored piece remains usable with the existing shared-UV warning, while coincident interior mappings that the ray cannot disambiguate are rejected. The canvas owns the temporary raster preview and delegates commit to each ordinary 2D shape path, so preview pixels never enter the editable image and a changed result emits exactly one history event.
- Switching 2D, 3D, Split Horizontal, and Split Vertical changes layout only. It never detects, starts, ends, or replaces a texture session.
- Editor scene-tab changes also do not own the texture-session lifecycle. The session retains its mesh snapshot, material, texture identity, UV/cache data, source label, and private preview transform when the original source node leaves the active SceneTree or is freed. Painting and normal texture saving continue without a live source scene; Save As updates the retained private material when no scene property remains to assign.
- Source geometry/transform polling never clears a valid private preview merely because the source scene is inactive. **Scene Transform Link** is automatically unlinked and disabled while the source node is unavailable, then re-enabled if the same live source returns. A view-mode rebuild uses retained session data and never dereferences a freed source node.
- With no active session, the 3D pane shows an explicit empty state. **Use Selected 3D Surface** and Scene-tree mesh/CSG/parent drops over either the empty pane or active viewport open the same read-only picker.
- Picker confirmation starts only a supported `StandardMaterial3D.albedo_texture` session. A missing texture opens a separate creation confirmation. A supported CSG node with no material offers one explicit confirmation that creates and assigns both a `StandardMaterial3D` and PNG; opening or canceling the picker never mutates the scene.
- Texture creation and Save As duplicate an embedded active material into the mesh instance's Surface Material Override, then assign the path-backed PNG there through editor undo/redo. Imported mesh materials remain unchanged.
- Before the first session in a chain, the dock snapshots the independent 2D raw RGBA8 image, undo/redo stacks, zoom/pan, selection mask, and floating-selection state. Session-to-session replacement retains that same snapshot.
- The independent 2D document keeps its current `res://` PNG path when one exists and an exact RGBA8 baseline from the last successful load/save. Starting a picked 3D session prompts only when the visible 2D pixels differ from that baseline.
- The 2D-to-3D entry prompt shows an aspect-preserving thumbnail and exact pixel dimensions of the staged 2D image. It is atomic: **Save** writes the existing path or opens Save As and continues only on success; **Continue Without Saving** captures the still-dirty workspace without writing; **Cancel** clears only the staged transition and preserves the picker choice plus all document/workspace state.
- **Stop Editing** exits a clean session immediately. An unsaved session uses Save / Save As / Discard / Cancel. Save As writes a new PNG, assigns it to the active material through editor undo/redo, updates session identity/baseline, and exits only after success. Cancel or failure leaves all session state untouched.
- While a session is active, **File > Stop Editing 3D Texture…** is added with a red destructive marker and calls the same Stop Editing handler. It is removed only after a successful exit.
- **Stop Editing** is colocated immediately left of the View selector and appears only for an active session. Its tooltip reports the source node/type, material, texture identity, and clean/unsaved state for either mesh or CSG targets.
- The bottom context row intentionally omits transient status and partial activity history. A future action-history UI should be added only if mutation labels are wired comprehensively to the image-snapshot undo/redo model.
- Successful exit restores the snapshot (or a normal default canvas when none exists) and clears it so repeated entry/exit cannot leak state.
- Opening an image or loading/dropping another mesh/image is a destructive session transition. If the active canvas differs from `baseline_image`, the dock stages the transition and requires:
  - **Save:** write the active texture, then continue only on success.
  - **Discard:** continue without writing.
  - **Cancel:** clear only the staged transition.
- GDDraw's 3D material is a live private preview fed from the shared canvas. **Save Texture** persists that canvas to the texture resource; there is no separate pending preview/material state for an **Apply** command today.
- Editable and preview images discard imported mip levels while preserving the base RGBA8 pixels. The private preview uses nearest filtering and forces the selected mesh's highest-detail LOD so stale imported mipmaps or generated mesh LODs cannot reveal the pre-edit texture as the camera moves away.

Current 3D preview navigation follows Godot's default primary mouse conventions:

- Middle drag orbits the framed mesh.
- Shift+Middle drag pans.
- Holding Right captures the pointer for freelook. `WASD` moves in camera space, `Q`/`E` moves down/up, and Shift/Alt temporarily increases/decreases flight speed.
- Mouse wheel zooms normally and adjusts flight speed while freelooking.
- `F` reframes the active mesh when the preview has keyboard focus.

## Split View State

- The dock owns one shared 2D canvas image and one live 3D preview; changing 2D/3D/Split layouts never creates another image buffer or replaces the texture session.
- Split orientation, independent normalized horizontal/vertical divider ratios, and linked-view preference are stored as project metadata. Both ratios default to 50/50. Horizontal and vertical split containers are rebuilt around the same 2D/3D host controls, preserving their canvas, camera, history, and session state.
- A compact View dropdown at the right edge of Tool Options exposes 2D, 3D, horizontal split, and vertical split; the linked-hover toggle sits beside it when Split View is active.
- Pan/Grid are overlaid in the 2D pane. Each pane owns a bottom-right zoom cluster, so Split View keeps the 2D percentage and 3D camera distance spatially associated with their canvases.
- The dock builds triangle and UV-edge connectivity caches once when the preview mesh changes. Hover synchronization uses those caches to draw only the connected island's outer boundary in 2D and 3D; it never fills or obscures the texture.
- The UV toggle exclusively controls full topology display and applies to both panes: 2D UV edges/vertices and the 3D mesh wire overlay appear and disappear together. Linked-hover boundaries remain a distinct lightweight location cue.
- Linked hover is view-only: it changes overlay drawing and preview meshes without touching RGBA8 pixels, selection masks, or history. Disabling the link or leaving Split View clears both directions immediately.
- 2D-to-3D island selection still inherits the documented ambiguity for overlapping UV shells because the current UV lookup uses camera distance as a visibility proxy.

## UI Guidelines

- Keep the main toolbar clean and action-focused.
- Put secondary options in the canvas settings overlay.
- Keep save/load/create-sprite actions on the top file row.
- Keep drawing and view tools on the tool row.
- Avoid adding explanatory text to the dock; prefer tooltips on icon buttons.

Colors:

- Button Active : icon #57A0FF
- Button Inactive : icon #c4c4c4
- Button Inaccessible : icon #696969
- Button Background when Selected : #424242
- Button Hover Highlight : #383838
- Toolbar Background : #292929
- Toolbar Divider / Darker Background for top menu : #141414

## Maintenance Boundaries

The 0.1.0 preview keeps the current coordinator/canvas split intact. Release stabilization should not redesign these systems.

- History, shortcut, PNG IO, 3D target, 3D session, UV overlay, and editor-integration helpers already have narrow responsibilities.
- Keep `gddraw_canvas.gd` behavior in place for now, especially dense selection, floating transform, lasso, and rotation logic.
- Keep `gddraw_dock.gd` as the editor-facing coordinator unless a later extraction replaces real duplication without changing lifecycle behavior.
- Preserve current canvas and texture-session method/property contracts where practical.
- Keep undo/redo ownership explicit; image-changing actions should still report previous image state in a predictable way.
- Preserve 2D document snapshots, dirty baselines, active 3D session state, and editor undo/redo across plugin lifecycle changes.
- Put feature ideas and non-blocking limitations in `feature-backlog.md` rather than expanding release-cleanup scope.

## Verification

After editor-plugin changes:

1. Reimport touched files through the Godot MCP server.
2. Reload the plugin when UI construction or plugin lifecycle code changes.
3. Reconnect to the new MCP session if plugin reload drops the transport.
4. Read editor logs and fix any script/runtime errors.

Useful MCP checks:

- `filesystem_manage(op="reimport", paths=[...])`
- `editor_reload_plugin`
- `session_manage(op="list")`
- `session_activate`
- `logs_read(source="editor", include_details=true)`
- `script_manage(op="find_symbols", path="res://addons/GDDraw/...")`
