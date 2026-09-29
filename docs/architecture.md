# GDDraw Architecture

The 0.4.0 feature scope is complete; release validation and packaging are tracked in
[`0.4.0-release-plan.md`](0.4.0-release-plan.md). Implemented work includes continuous
cross-object painting, reusable tabbed/split panels, palette editing and HEX
save/export, editable Gradient and Text layers, bulk layer actions, and multi-layer
hierarchy moves. Tools preferences collect Brush, Gradient, and Text defaults.
The user has completed native workflow testing and accepted the final UI adjustments.
Exact selection sizing is deferred beyond 0.4.0, with no release assigned.

The packaged [What's New](../addons/GDDraw/docs/whats-new.md) page and offline manual
describe the user-facing 0.4.0 behavior. Runtime release-version changes, packaging,
and publication remain separate release steps.

This document is a compact handoff for future work on the GDDraw Godot editor plugin.

The active 0.3.0 layer-system design and phased migration plan live in
[`0.3.0-layer-architecture.md`](0.3.0-layer-architecture.md). Its distinction
between object groups, paint targets, and composited layer nodes is authoritative
for layer work. The live implementation checkpoint is
[`0.3.0-current-handoff.md`](0.3.0-current-handoff.md); the older sections below
remain useful for unchanged 0.2.0-era subsystems.

Unless otherwise noted, source paths in this document are relative to `addons/GDDraw/`.

## Plugin Shape

- `GDDraw.gd` is the `EditorPlugin` entry point.
- `gddraw_dock.gd` builds and owns the editor dock UI.
- `gddraw_panel_host.gd` owns registered right-side panels, rail activation,
  placement, project layout metadata, validation, migration, and reset.
- `gddraw_panel_group.gd` owns tab chrome, overflow navigation, placement menus,
  and panel drag feedback; it has no artwork or history responsibilities.
- `gddraw_canvas.gd` owns the image data, canvas view state, drawing behavior, and rendering.
- `gddraw_history.gd` owns the dock undo/redo image stacks.
- `gddraw_layer_node.gd` owns recursive paint-layer/group state and deep snapshots.
- `gddraw_paint_target.gd` owns one compatible layer stack, selection invariants,
  CPU compositing, per-layer eraser sources, and target-local binding metadata.
- `gddraw_layer_session.gd` owns object groups, paint targets, active-target
  selection, target-lock routing, and complete in-memory session snapshots.
- `gddraw_layer_document.gd` owns validated, versioned `.gddraw` ZIP
  persistence and atomic replacement.
- `gddraw_3d_layer_discovery.gd` owns read-only scoped scene discovery, while
  `gddraw_3d_layer_coordinator.gd` binds the resulting targets to one shared
  layer session and the existing per-texture session implementation.
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
- Read `gddraw_layer_node.gd`, `gddraw_paint_target.gd`, and
  `gddraw_layer_session.gd` before changing 0.3.0 layer hierarchy,
  compositing, object ownership, paint-target routing, or snapshots.
- Read `gddraw_layer_document.gd` before changing layered save/load or dirty
  baselines. Read the 3D discovery and coordinator helpers before changing
  import scopes, multi-object previews, target routing, or scene reattachment.
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
- A coordinated 3D brush/eraser gesture owns one immutable complete-session history snapshot. The canvas suspends/resumes raster segments without emitting history; the dock retains each target's original image and one-pass coverage across revisits. Binding changes, misses, blocked destinations, and incompatible geometric/UV edges restart interpolation at the accepted hit. Every received held-motion sample is routed, while display uploads remain coalesced. Target promotion reuses prepared preview meshes, materials, indexes, and display caches. Layers-tree and scene-selection synchronization are deferred until release; fill/eyedropper retain single-click behavior and shapes retain their surface restrictions.
- Release commits one changed gesture; no-ops preserve history and native layer bounds. Escape, application focus loss, source loss, hidden/cleared previews, and session teardown cancel the entire gesture. Tool/layer/layout changes, undo/redo, Stop Editing, and document-transition guards resolve it before replacing state. Cancellation restores pixels, native bounds, selected layers, dirty state, and routing together. History restoration refreshes changed inactive previews even when the active target ID stays the same. See the release-plan checkpoint for automated evidence, performance limits, and remaining native checks.
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

## Reusable right-side panels (0.4.0 milestone 2)

`gddraw_dock.gd` builds the Layers controls and connects their model actions once,
then registers stable ID `layers`, title, icon, content control, and minimum
content size with `gddraw_panel_host.gd`. The existing Layers icon still uses the
dock's bounded icon-import recovery. Palettes registers stable ID `palettes`
after Layers, with its content, title, palette icon, and 160×100 minimum.
Additional built-in clients use the same registration method;
duplicate IDs and duplicate content ownership are rejected.

The host remains the right child of the workspace split, outside the four
2D/3D canvas arrangements. Both outer split children expand, so a stored panel
width actually controls divider geometry. Host-owned groups use native
horizontal/vertical split containers with always-visible, 10-pixel handles.
The rail stays outside the scrollable group area. When minimum-size groups
cannot fit, horizontal/vertical scrolling preserves access to their controls;
the rail itself can scroll vertically in a short dock.

The version-2 `GDDraw/right_panel_layout` project metadata contains `width` and
a `root` tree. A group stores `id`, ordered panel `tabs`, `closed`, `active`, and
derived `visible`. `tabs` retains placement for both open and closed clients;
`closed` identifies clients omitted from the rendered tab strip.
A split stores `axis`, normalized `ratio`, `first`, and `second`. Collapse keeps
the group and ratios in that tree. Each rail icon toggles only its own panel;
all open clients stay highlighted regardless of the active tab. Closing the
active client selects the first remaining open tab. Empty groups remain in the
placement tree but are hidden, retaining orientation/ratios on reopening.
View > Reset Panel Layout opens every client in one tab group at the default
280-pixel width. Each group's ⋮ menu
also exposes reset, collapse, split directions, and moving to other groups.

Registration precedes restoration. Validation bounds recursion and group/tab
counts, rejects duplicate IDs and invalid types/nonfinite numbers, and normalizes
finite ratios to 0.1–0.9. Unknown panel IDs are dropped from otherwise usable
groups; an unknown active tab selects the first known tab. Missing registered
clients are appended closed to the first group. Version-1 visible groups migrate
their existing tabs as open; hidden groups migrate them as closed. Legacy
expanded Layers preferences open only the first client. Live version-1 groups
are also normalized when tool scripts reload. Invalid or empty branches fall back
to one safe group containing every registered client. Missing/invalid layouts
migrate the legacy `layers_panel_width` (280–520) and `layers_panel_expanded`
preferences. Loading is read-only; the next layout operation writes the new
metadata key. The old keys are retained but no longer written. Layout data is
outside the replaceable addon and outside document/history serialization.

Panel lifetime is separate from group/split lifetime. The host parks and
reparents the same content subtrees while rebuilding placement containers;
it never reconstructs Layers, TreeItems, client models, or their signal wiring.
It captures visible clients' scrollbar values (including native Tree bars)
before placement changes and restores them after container layout. Hidden
clients keep their saved scroll state. Generation checks and weak split
references make superseded deferred work harmless. Existing client selection,
text/caret, layer-session state, and history owners remain intact.

Visible client keyboard focus is restored after reparenting. Explicit rail/tab
activation still focuses tab chrome; collapse focuses the rail. The palette
grid independently remembers the focused swatch index across hidden states.

Group tabs use a native TabBar inside a clipped ScrollContainer, with explicit
28×28 previous/next buttons. Those buttons select adjacent tabs and reveal the
complete active tab; long titles are bounded to the available width and retain
full-title tooltips. Arrows disable at the first/last tab and disappear when all
tabs fit. Left/Right and Home/End work through keyboard focus. Layout chrome
does not route drawing shortcuts; Layers content retains its existing shortcuts.

Panel drags carry both a host instance token and stable panel ID. A temporary
overlay receives these drags over client controls such as Tree, without changing
their ordinary layer/asset drag handlers. The tab strip/center merges tabs;
left/right/top/bottom drop zones create splits and show a highlighted target.
Drop/menu mutations defer until native input dispatch completes. The overlay
disappears after drag completion or cancellation.

`tests/test_panel_host.gd` supplies temporary clients and regression coverage.
Its `--demo` mode opens a standalone full-dock review fixture; `--screenshot`
renders that fixture to `res://panel_review.png` and exits. Run those modes in
a disposable project. Automated GUI event dispatch and renderer screenshots do
not replace the native-editor interaction checklist in the release plan.

## Palette import and use (0.4.0 milestone 3)

- `gddraw_palette_parser.gd` reads and validates complete candidates without
  writes. `gddraw_palette_store.gd` owns one project collection and transactional
  persistence. `gddraw_palette_panel.gd` owns the dropdown, action menu, import,
  confirmation/error dialogs, and per-palette view state. The virtual
  `gddraw_palette_grid.gd` draws only visible rows, using one focusable control.
- The dock registers the panel before restoring layout and connects one color
  request signal. No palette placement branches or additional history owners
  are introduced. Existing Layers-only descriptions gain a tab using the host's
  normal missing-client migration, retaining active tab, ratios, and visibility.
- The supplied `palette_0.svg`, `_1.svg`, and `_2.svg` remain authored assets.
  The rail button uses `_make_icon_button`, the same state selection and bounded
  import recovery as Layers. The existing Lucide notice covers these icons.
- Left-click/Enter/Space requests foreground; right-click/Shift+Enter requests
  background. Arrows move spatially; Home/End reach the ends and reveal focus.
  Focus movement, import, palette selection, removal, reopening, and restoration
  never assign a default color. Tooltips carry names, hex/alpha, and hints.
- F/B corner badges use white letters on black backing, distinct from the
  black/yellow keyboard-focus outline. Checkerboards show alpha. Matching uses
  Color approximate equality, matching duplicate swatches identically. Marker
  updates redraw visible swatches without rebuilding controls or palette data.
- Foreground requests call `_set_foreground_color` and record a recent color;
  background requests call `_set_background_color`. Both setters synchronize
  the panel for picker, eyedropper, swap, and fill-control changes. Existing
  text/shape preview semantics remain in the canvas. Palette focus isolates
  grid keys and dialogs from drawing shortcuts. Browsing/placement has no
  drawing commit/cancel, pixel, dirty-state, or history path.
- Columns adapt around 32-pixel cells; vertical scrolling remains available in
  narrow/short panels. The same panel/model/grid are retained across placement.
  Each palette remembers its focused index and scroll while the panel lives;
  only active palette selection is persisted across editor restart. Pending
  scroll restoration uses short-lived node processing, so freeing the panel
  cannot resume asynchronous work against a dead instance. Dropdown text is
  bounded to 160 displayed characters; full names remain stored.

### Syntax and bounds

The offline [palette manual](../addons/GDDraw/docs/palettes.md) is the complete
user syntax reference. UTF-8 inputs accept BOM, LF/CRLF, and surrounding
whitespace. `.hex`/`.txt` require one `RRGGBB` or `RRGGBBAA` token, optionally
prefixed with `#`, per color
line, with blank lines and full-line `;`/`//` comments. No inline comments,
shorthand, or inferred format. Names use the filename stem.

GPL is verified against the [GIMP specification](https://developer.gimp.org/core/standards/gpl/).
It accepts the header, optional Name/Columns, comments, RGB integers 0–255 and
optional names. Columns 0–255 is validated but ignored for responsive layout.
Metadata must precede colors and cannot repeat. Whitespace-only lines, indented
comments, surrounding whitespace, and Columns without Name are documented
extensions. GPL is opaque. Both formats preserve order and duplicates, reject
empty/malformed candidates, and report line numbers. Inputs are bounded to
1 MiB before reading/parsing and 4,096 swatches before append/UI construction;
oversized input is rejected without truncation.

### Collection storage contract

`gddraw_palette_store.gd.DEFAULT_STORAGE_PATH`, derived from the existing
`GDDrawStoragePaths.PROJECT_ASSET_ROOT`, is
`res://gddraw/palettes/collection.json`, outside the replaceable addon. Version 1:

```json
{"version":1,"next_id":2,"active_id":"palette_1","palettes":[
  {"id":"palette_1","name":"Studio","swatches":[
    {"color":"e84941ff","name":"Coral"}
  ]}
]}
```

`palettes` order is collection order; colors are eight-digit RGBA hex strings.
Increasing `next_id` supplies nonreused stable IDs. Same-name imports choose
the first available numbered suffix starting at `(2)`. Missing active IDs fall
back to the first palette with a warning. Missing/duplicate palette IDs, corrupt
records, invalid counters, and unsupported versions block writes, retain the
file, and show a repair/reopen error. Missing storage is an empty collection.
Loading never creates directories or rewrites migration/fallback state.

Collection files are bounded to 64 MiB before JSON parsing and 256 palettes
before UI construction; each stored palette also validates its swatch bound,
names, colors, and stable ID. Complete proposed data is validated before any
write. A uniquely named sibling temporary file is flushed and read back, then
one same-directory rename replaces the old collection. The destination is never
deleted first. A failed write/verification/rename preserves memory and the old
file; temporary-file cleanup is attempted. Abandoned temporary files are never
treated as collections on restart. Memory and signals advance only after a
successful replacement. Byte comparison detects stale writes from external
collection edits. Storage is designed for one plugin writer per project.

Removal captures an ID in a confirmation dialog, never deletes the external
source, and selects the next remaining entry (previous when removing the last)
or the empty state. Cancel is inert. Parsed data remains usable after the source
file disappears. Collection persistence is independent of layout metadata,
artwork serialization, and drawing undo/redo.

### Verification boundary

`tests/test_palettes.gd` covers parser/storage failures, view/model recreation,
keyboard and mouse events, focus reveal, actual dock color setters, text/surface
draft semantics, all four views, old layout migration, tab/split movement,
focus/scroll lifetime, and dirty 3D sessions with populated history. Existing
panel-host, Layers, gesture, storage, text/fill/shape, icon and documentation
suites run sequentially on Godot 4.7 and 4.4. Exact totals and known diagnostics
are in the milestone-3 release-plan checkpoint.

`--screenshot` renders a standalone full-dock palette fixture to
`res://palette_review.png`; use a disposable project. Automated input dispatch
and renderer checks are distinct from physical native-editor interaction.
There was no connected GDDraw MCP session during this milestone (the available
session belonged to another project), so fresh editor imports and renderer
checks used the disposable project. Native file chooser, rail dragging, keyboard
feel, high DPI, restart persistence, and real update protection remain manual
checks. Gradients, authoring, image extraction, online services, additional
formats, release declarations, and publication are outside this checkpoint.

### HEX as the main palette format — 2026-09-21

The user-approved HEX decision supersedes native JSON writing in the authoring
extension below. Save writes uppercase `RRGGBBAA` values, one per line, to `.hex`.
The existing internal collection retains palette/swatch names, IDs, snapshots,
and source hashes. Empty palettes remain drafts; saving/exporting requires one
color. Existing HEX sources are updated by Save Changes; GPL, TXT, and legacy
`.gddrawpalette` sources convert to HEX while retaining the original file.
All established import formats remain supported. Legacy native IDs are removed
from converted collection records so scanning the retained original cannot
replace the new HEX source. Converted source aliases prevent duplicate imports.

Export HEX writes a separate RGB or RGBA copy through the same verified atomic
file replacement. RGB omits alpha without modifying the palette. Export never
clears dirty state, changes selection, or changes source metadata; managed source
paths are protected and existing unrelated export files require confirmation.
Save-as-new rejects the current source path even if the display name differs.
Both Godot 4.7 and 4.4 pass 211 palette and 13 startup assertions for this change.

### Palette authoring extension — 2026-09-21 (original file format superseded above)

The approved extension adds native `.gddrawpalette` v1 JSON (stable native ID,
name, ordered named `#RRGGBBAA` swatches). Native files allow zero colors;
GPL/HEX/TXT imports retain their nonempty requirement. Limits remain 1 MiB and
4,096 colors per file, 256 entries and 64 MiB in the internal collection.
Collection records remain backward compatible and optionally include `source`,
`source_hash`, `native_id`, `import_sources`, `dirty`, `unsaved`, and
`saved_swatches`. These fields preserve drafts and the last saved snapshot;
they do not enter portable palette files or artwork history.

Native saves validate and bound the prospective collection before writing a
verified sibling temporary and renaming it. Then the collection is committed.
These are two separate atomic file replacements, not a multi-file transaction.
If the second write fails, the UI explicitly reports that the native file was
saved and retains the draft. Source hashes and collection byte comparisons
reject stale overwrites. Save as New creates a fresh native ID and keeps the
original entry. Removal deletes only the collection entry, never source files.

Project metadata `GDDraw/palette_directory` defaults to `res://gddraw/palettes`.
Startup and explicit scans inspect supported files directly in that folder,
ignore `collection.json`, and skip dirty entries with a warning when sources
change. Known source paths/native IDs avoid repeated imports. Converted import
paths are retained to avoid importing both the native file and original again.
The native file becomes authoritative after conversion. Missing folders are
created only on writes. Scan selection is restored after imports.

The panel owns New/Save/name/replacement/dirty dialogs and Godot's HSV-wheel
ColorPicker with alpha, explicit Add/Apply and Cancel. Shift+right-click or
Shift+F10 opens Edit/Remove; normal right-click retains background assignment.
The virtual grid includes one final Add tile and selectable 24/32/48-pixel cells
or full-width rows. `GDDraw/palette_view` remembers presentation separately from
content. View > Palettes Panel delegates to the same independent panel toggle.

## Gradient tool (0.4.0 milestone 4)

### Editable Gradient layers

LayerNode.Kind.GRADIENT is an image-bearing leaf with a JSON-compatible recipe
and a fixed selection-mask Image. The cached image remains the compositor,
thumbnail, and export input. `is_paint_layer()` includes these image-bearing leaves
for hierarchy traversal; raster mutation APIs reject Gradient nodes until explicit
rasterization. The canvas separately enables gradient editing while disabling
ordinary pixel editing. Layer thumbnails prepend a narrow 12-pixel type-icon area
without shrinking the 24-pixel artwork preview; cache keys include node kind.

The default output creates a Gradient layer above the selected leaf in its group;
the alternate output retains the existing raster operation. A draft starts from
transparent pixels in layer mode. Its compositor inserts an ephemeral preview
leaf into a copied hierarchy, or replaces the selected gradient's cached pixels,
without modifying the actual layer tree. Commit captures one session undo state
and writes recipe, mask, origin, and rendered pixels together. Cancel leaves all
stored layer data unchanged. Reopening uses layer-local endpoints translated to
the current canvas workspace and retains the stored mask independently of selection.

Mouse release commits a canvas gesture and reloads editable handles immediately.
An explicit creation flag distinguishes an off-handle drag from editing an existing
node, including when another Gradient layer is selected. The flag also chooses
insert-versus-replace preview compositing. Zero-length gestures create nothing;
Escape restores the previous layer's handles. Apply/Cancel buttons are absent.
Control changes on saved gradients coalesce after 300 ms of inactivity, wait for
canvas/strip drags to finish, and flush before tool/layer changes and layered saves.
Loading stored settings suppresses auto-apply scheduling to avoid feedback loops.

Gradient support introduced layered document format 3, storing the validated recipe
in manifest JSON and a separate mask PNG alongside cached layer pixels. Current
format 4 adds Text layers and reads versions 1/2/3. History, duplication, and dirty-state
fingerprints include recipe/mask. Resize scales endpoints and mask and regenerates
the image; layer movement retains local coordinates. Merge and explicit Rasterize
produce ordinary paint leaves. Texture sessions consume the same composite cache.

`gddraw_gradient_panel.gd` edits session-local color stops on the canvas. Stops
have a color including alpha and a normalized position, with immutable endpoint
positions and ordered intermediate stops. The native Gradient ramp uses the stop
array; reverse mirrors offsets and colors and overall opacity multiplies stop
alpha. Editing a stop detaches the recipe from drawing colors.
Canvas handles, strip markers, and editable rows share selected-stop state. Each
row owns a native color picker and position/alpha text fields with persistent
percent units. Endpoint positions are read-only. Rows survive ordinary preview
refreshes so focus, unfinished text, and picker popups remain stable; row-count
changes retire old field callbacks before rebuilding. Add/Duplicate/Delete use
shared icon styling in evenly spaced bottom slots. The temporary panel rail button
uses the same icon factory and active styling as the left Gradient tool. Updates
reuse the existing draft renderer and commit/history path.

The panel host can temporarily register a tool panel, snapshot its layout, and
suppress layout persistence until that panel closes. Closing parks its content,
removes its registration, and restores the prior description (including active
tabs and width). This keeps Gradient out of persistent Layers/Palettes layouts.

`ToolMode.GRADIENT` is appended to the canvas enum, preserving existing numeric
tool IDs. The dock owns its toolbar button (between Bucket and Shapes), top-bar
options, Tool menu entry, and scoped G shortcut. The supplied Lucide `blend_0`
and `blend_1` SVGs use the normal icon import/recovery path. Existing foreground
and background controls are reparented into the gradient options row.

The gradient toolbar exposes Linear/Radial and Reverse alongside shared colors.
Preferences > Tools groups Brush and Gradients sections. The gradient output
default is stored as project metadata `GDDraw/gradient_default_new_layer` (true by
default, with invalid values falling back to true). Selecting an existing Gradient
does not mutate the preference; its handles always retain editable-layer behavior.
Output/color-mode/overall-opacity controls are absent from the toolbar. Stop alpha
and layer opacity remain the user-facing controls for transparency; legacy recipe
opacity is retained internally for saved-document compatibility.

`gddraw_gradient.gd` is a raster helper: pixel-space linear projection and radial
distance drive Godot's native GradientTexture2D generation. Normalized coordinates
are corrected for non-square linear images; radial color generation uses a square
domain to preserve circular radii. RGBA interpolation is straight, linear in
stored sRGB components, then source-over blended. Foreground-to-transparent keeps
foreground RGB at both ends. Reverse swaps local endpoints; opacity multiplies
alpha. Alpha lock blends RGB against an opaque copy and restores original alpha
bytes (including hidden RGB for fully transparent source pixels). Selection masks
use native masked blits, and affected regions intersect document/workspace bounds.

Canvas drafts capture one immutable active-layer base and mask snapshot. Colors
and options remain live; either endpoint can be dragged after mouse release.
Preview never emits image_changed or updates a layer's stored image. Mouse release
compares output bytes, adopts changed pixels, refreshes through the existing
compositor, and emits one stroke_committed(previous_image). Existing layer history
and 3D texture synchronization own the resulting edit. Zero-length/unchanged
gestures create no history. Escape, tool/layer operations, image replacement,
and editing disablement cancel. Window focus loss only ends endpoint dragging,
preserving drafts while color pickers are open. Selecting Gradient preserves
an existing selection; floating selections are resolved through the existing path.

For regions over 512 pixels, main-thread color generation is bounded to 512;
one worker blends private Images without nodes or rendering-server calls. Pointer
updates coalesce while a job runs. Completed results display only for the same
gesture generation; cancel/restart invalidates older results. Node teardown joins
the worker. Completed image composition/upload stays on the main thread. Large
drag previews approximate fine transitions; final commits always render full
resolution and may pause briefly on large alpha-locked images.

Direct 3D-surface gradient gestures are rejected with a status message. Applying
the gradient on a 3D session's 2D texture canvas uses the existing texture update
path. Tests verify raster projections, radial aspect, alpha, clipping, selection
retention, cancellation, worker replacement/teardown, mouse dispatch, undo/redo,
layer opacity, inactive-layer preservation, and real-renderer 3D texture updates.
Godot's dummy renderer retains original ImageTexture uploads on get_image(), so
GPU texture readback assertions run only with a real renderer.

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

## Editable Text layers

Text commits create a `Kind.TEXT` leaf with a validated text recipe, cached RGBA
pixels, origin, and optional fixed selection mask. The recipe preserves text,
font bytes/name, size, box, rotation, alignment, wrapping, fill, and RGBA colors.
History, clipboard duplication, and dirty fingerprints include the editable data.
The existing canvas text editor and top toolbar own edits; no Text panel is added.
Selecting a Text layer reopens that editor. Commit updates the selected Text layer,
Cancel leaves its stored data intact, and a fresh box after Commit creates a sibling.
Tool/layer switches and saves finish the current draft. Paint tools require explicit
Rasterize Text Layer; merging produces paint pixels through existing layer behavior.

The canvas retains its legacy raster commit path for standalone integrations.
Dock-owned canvases enable `text_layer_mode` and emit a recipe/pixels payload instead
of a raster stroke. A separate text permission permits editing Text layers while
ordinary pixel edits are disabled. Preview composition inserts a new layer or
replaces the selected one, preserving stacking, group opacity, and visibility.
Selection masks remain fixed across later text edits. 3D sessions receive committed
composites through the existing texture synchronization path.

Layered format 4 stores recipes in JSON, embedded font bytes in separate archive
entries, and optional masks in PNG entries. Documents load font bytes from the
archive rather than following machine-specific paths. Cached pixels preserve
flattened output; opening the editor reconstructs the font and text layout.
`tests/test_text_layers.gd` covers creation, replacement, cancellation, undo/redo,
font/pixel round trips, masks, duplication, locks, rasterization, sizing, and 3D.
Document scaling updates the box and font size, scales the mask, and regenerates
cached text pixels through the same canvas text engine using a temporary off-tree
canvas. This keeps the scaled cache consistent with the reopened editor. Crop and
canvas-bound changes retain editable data and adjust layer origins as usual.
