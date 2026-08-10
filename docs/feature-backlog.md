# GDDraw Feature Backlog

This document tracks post-0.1.0 work, known limitations, and completed stabilization milestones for GDDraw.

## Current Strengths

- Bottom-panel Godot editor plugin with a compact drawing workspace.
- 2D canvas mode for direct texture/sprite painting.
- 3D texture painting mode for selected `MeshInstance3D` and supported single-material CSG albedo textures.
- Split mode showing the 2D texture canvas and 3D preview side by side.
- Shared image buffer between 2D and 3D views.
- Brush, eraser, paint bucket, line, rectangle, ellipse, eyedropper, pan, selection, lasso selection, copy, cut, paste, flip, undo, redo, clear, save, load, and Sprite2D creation.
- Brush size, color, square/circle brush heads, touch-pixels mode, and pixel-perfect mode.
- UV overlay on the 2D texture canvas and optional UV wire overlay on the 3D preview.
- 3D orbit, pan, zoom, transparent grid-line stage, and selected mesh preview.
- Flat unshaded 3D texture preview material with nearest filtering, mipmap-free live images, and highest-detail mesh LOD to keep painted pixels stable at every camera distance.
- 3D brush footprint preview that reflects brush size and brush head.
- 3D texture-session eraser restores pixels from the original loaded texture instead of erasing to transparent.
- Shared/mirrored UV warning without blocking painting.
- Non-destructive preview flow: original imported mesh and material are not destructively modified for preview.
- Editable 3D surface targets centralize source identity, generated mesh snapshots, transforms, material discovery, and undoable assignment for meshes and CSG without replacing CSG scene nodes.

## Known Limitations

- Split View 2D-to-3D hover preview is partially working but does not reliably select the visible surface for complex meshes.
  - The release build uses a subtle blue point marker plus the normal linked-view surface highlight; diagnostic console logging remains disabled.
  - Canvas signal emission, normalized UV coordinates, indexed/non-indexed triangle lookup, hit transforms, highlighting, and cleanup have been verified.
  - Known reproduction: on a complex character texture, hovering some overlapping UV regions can highlight a hidden surface instead of the visible outer surface. Selecting the nearest overlapping UV candidate did not eliminate this behavior.
  - Simple planes, cubes, and synthetic overlapping shells work, so the remaining issue is specific to ambiguous/complex UV-to-visible-surface selection rather than basic signal or rendering failure.
  - Defer deeper work until this feature is prioritized; a robust solution may require cached UV triangle data plus an actual camera-visibility/occlusion test.
- 3D brush visibility can still vary by texture/model colors. It is more accurate now, but may need stronger contrast controls.
- Touch-pixels behavior should be validated on dense UV seams, mirrored UVs, and tiny islands to ensure it paints exactly the intended texture footprint.
- Split mode layout can crowd controls on narrow docks, especially with the settings panel open.
- 3D-to-2D hover marker can be difficult to see on very large canvases or visually busy UV maps.
- The 2D zoom ceiling follows the drawable viewport so pixel inspection remains detailed and bounded across dock and Split View layouts.

## Planned Core Work

### Recommended Next Stabilization Slice

- [x] Make the 3D texture-session lifecycle explicit and independent from view layout.
  - [x] Entering 3D, Split Horizontal, or Split Vertical never detects or loads a mesh.
  - [x] Show a no-session 3D state with **Use Selected 3D Surface** and mesh/CSG drag/drop instructions.
  - [x] Route selected meshes and mesh drops through a read-only picker listing every material/surface slot.
  - [x] Accept Scene-tree mesh nodes and parents directly over both the empty 3D pane and active 3D viewport.
  - [x] Enable safe `StandardMaterial3D.albedo_texture` choices, including readable non-file textures recoverable through Save As; explain unsupported and missing materials.
  - [x] Keep missing-texture creation behind a separate explicit confirmation; the picker never creates or assigns resources.
  - [x] Show persistent `Editing mesh · Material slot · texture · Clean/Unsaved` identity plus **Stop Editing**, separate from transient status.
  - [x] Snapshot the independent 2D image, undo/redo history, zoom/pan, selection mask, and floating-selection state before the first session.
  - [x] Restore that workspace after clean exit or successful Save/Discard, while Cancel and failed saves preserve the complete live session.
  - [x] Preserve one snapshot across in-session mesh replacement and clear it after exit so repeated sessions cannot leak state.
  - [x] Support **Save As** from File and the unsaved Stop Editing prompt, assigning the successful new PNG through editor undo/redo before continuing.
  - [x] Put newly created and Save As textures on a duplicated per-instance Surface Material Override rather than mutating embedded mesh materials.
  - [x] Admit `CSGBox3D`, `CSGSphere3D`, `CSGCylinder3D`, `CSGMesh3D`, and other material-bearing CSG primitives through selected-node, parent-resolution, and drag/drop workflows.
  - [x] Validate generated CSG triangles/UVs, reject unsupported or multi-material generated results explicitly, and refresh or pause the preview when source geometry changes.
  - [x] Keep missing CSG materials and textures behind explicit confirmation, with file/assignment failure cleanup and editor undo/redo for successful scene assignments.
- [x] Protect active 3D texture sessions from accidental canvas resizing.
  - [x] Disable canvas width, height, aspect-lock, keep-pixels, and resize controls while an imported texture session is active.
  - [x] Explain the restriction in the control tooltip/status message and reject indirect resize commands without changing the canvas or history.
  - Later, add an explicit confirmed resize workflow if resizing 3D textures proves necessary.
- [x] Protect unsaved active 3D texture sessions during replacement.
  - [x] Compare the live RGBA8 canvas with the last successfully loaded/saved RGBA8 baseline, so exact undo back to that image becomes clean and redo becomes unsaved.
  - [x] Keep the saved baseline separate from the original loaded image used by the 3D eraser restore behavior.
  - [x] Show `mesh · texture · clean/unsaved` in the compact status bar.
  - [x] Gate selected-mesh loads, mesh/image drops, and opened images behind Save / Discard / Cancel when the active session is unsaved.
  - [x] Continue after Save only when the texture write succeeds; canceled or failed saves preserve the current session, pixels, history, and dirty state.
  - [x] Stage replacement mesh sessions before committing them, so a failed replacement load does not clear the current session.
  - [x] Keep 2D, 3D, and Split view changes session-preserving and history-free.
- [x] Protect the independent 2D document when starting a 3D texture session.
  - [x] Track the current PNG path and last successfully loaded/saved RGBA8 baseline; exact undo to the baseline is clean.
  - [x] Prompt only for unsaved pixel differences, after either selected-mesh or drag/drop picker confirmation and before replacing the canvas.
  - [x] Show an aspect-preserving thumbnail and pixel dimensions of the unsaved 2D image in the entry prompt.
  - [x] Save to the existing PNG when available, otherwise use Save As, and continue only after a successful write.
  - [x] Support Continue Without Saving while preserving the complete in-memory image, history, selection/floating selection, view, and dirty state for restoration.
  - [x] Make Cancel atomic, including the pending picker mesh/material choice.
  - [x] Expose a red, session-only **File > Stop Editing 3D Texture…** action routed through the existing Stop Editing save/discard/cancel handler.
- [x] Compact the bottom context bar.
  - [x] Replace the permanently visible 3D session identity with a dynamic tooltip on **Stop Editing**.
  - [x] Move **Stop Editing** immediately left of the 2D/3D/Split View selector.
  - [x] Remove the interim transient-status label and partial activity-history popup rather than presenting an incomplete action log as authoritative history.

### 3D Texture Painting

- [x] Prevent 3D strokes from bridging unrelated visible surfaces or UV islands.
  - [x] Continue interpolated strokes only on the same triangle or an edge-adjacent triangle with locally continuous UVs.
  - [x] Break continuity when the pointer ray misses, changes material surfaces, jumps to a nonadjacent triangle, or crosses a large UV seam.
  - [x] Stamp the first valid hit after a break without starting another history entry.
- Finish 2D-to-3D hover preview when its remaining complex-mesh ambiguity is worth the implementation and runtime cost.
- Focused hover diagnostics remain available behind disabled debug constants:
  - Canvas hover and normalized UV flow.
  - UV lookup hit/miss.
  - Candidate and accepted triangle counts.
  - Selected surface/triangle and facing state.
  - Dedicated marker visibility and cleanup.
- Improve 3D brush footprint painting across UV seams and islands.
- Add a clear mode distinction between:
  - Paint hovered triangle only.
  - Paint full UV texture footprint.
  - Paint visible surface footprint, if feasible later.
- Add optional seam bleed/padding around painted UV pixels to reduce visible texture seams.
- Add a 3D paint cursor contrast mode:
  - Light ring.
  - Dark ring.
  - Two-tone ring.
  - Color follows brush.
- Add a way to frame/reset the 3D preview camera to the mesh.
- Add a 3D view orientation helper or small axis gizmo.
- Add an optional grid visibility toggle for the 3D preview.
- [x] Add material slot selection for meshes with multiple materials.
- Add texture channel selection:
  - [x] Albedo/base color first through the explicit session picker.
  - Normal, roughness, emission later if safe.
- Support more texture source cases:
  - `StandardMaterial3D.albedo_texture`.
  - Common `ShaderMaterial` texture uniforms.
  - Material override and surface override paths.
- [x] Audit the proposed "Save Texture" / "Apply" distinction for active 3D sessions.
  - The canvas already drives a live, flat `ImageTexture` on GDDraw's private preview material in 3D and Split views. There is therefore no unapplied preview state to commit.
  - **Save Texture** writes the current RGBA8 canvas to the active texture resource path and advances the clean baseline only after a successful write.
  - The edited scene's source material is not continuously overwritten by painting; only explicit material/texture creation or assignment uses editor undo/redo.
  - Do not add an **Apply** command unless a future workflow introduces a distinct destination or a deferred material-assignment state.
- [x] Add dirty-state warnings when switching sessions or loading another image before saving.
- Add visual warning when shared/mirrored UVs are under the brush.
- Add an "isolate UV island" or "highlight hovered UV island" mode.

### Split View Workflow

- [x] Preserve independent normalized horizontal and vertical split ratios plus orientation between sessions, with both layouts initially 50/50.
- [x] Add one compact View dropdown at the right side of Tool Options:
  - [x] 2D only.
  - [x] 3D only.
  - [x] Split horizontal.
  - [x] Split vertical for tall docks.
- [x] Keep canvas navigation controls contextual:
  - [x] Pan and Grid live in the top-right of the 2D canvas.
  - [x] Each canvas owns its bottom-right zoom/readout/reset controls.
- [x] Show independent 2D zoom and 3D camera-distance readouts.
- [x] Keep 2D and 3D hover previews synchronized both ways when linked:
  - [x] A 3D hit shows the brush point and an unobtrusive outer boundary around the connected UV island in 2D.
  - [x] A 2D UV hover outlines the corresponding connected surface island in 3D without covering the texture.
  - The documented complex-mesh 2D-to-3D visibility ambiguity still applies when UV shells overlap.
- [x] Keep full UV topology exclusive to the UV toggle, which controls both the 2D UV overlay and 3D wire overlay together.
- [x] Cache triangle-to-UV-island connectivity once per preview mesh rather than rescanning the mesh on every hover.
- [x] Add a persistent linked-view toggle in the compact status controls and View menu:
  - [x] On synchronizes hover/island correspondence.
  - [x] Off clears linked previews and lets each pane behave independently.

### 2D Painting

The first painting milestone is complete; remaining enhancements are tracked below.

- [x] Complete first 2D painting milestone:
  - [x] Brush and eraser opacity through the native color picker's alpha channel.
  - [x] Optional single-stroke overlap buildup, disabled when consistent per-stroke opacity is desired.
  - [x] Alpha lock for brush, eraser, fill, line, rectangle, and ellipse painting.
  - [x] Deterministic RGBA8 fill tolerance using maximum per-channel difference.
  - [x] Contiguous and global fill modes with no-op history protection.
- [x] Add crop tools:
  - [x] Crop to clipped rectangular selections and occupied lasso-mask bounds without masking pixels inside the crop result.
  - [x] Trim transparent bounds using nonzero-alpha pixels, including exact 1x1 results.
  - [x] Add an exact crop-rectangle dialog with a non-destructive canvas preview and Apply/Cancel workflow.
  - [x] Preserve RGBA8 pixels and exact dimensions through one-entry undo/redo, with no-op history protection.
  - [x] Clear stale selection state, synchronize canvas-size controls/signals, and reject all crop commands during active 3D texture sessions.
  - [x] Cover crop geometry, pixels, selection cleanup, preview parity, history, and 3D/Split restrictions with focused synthetic-image tests.
- [x] Add image scaling/resampling options:
  - [x] Add a focused Image > Scale Image dialog with exact 1x1 through 4096x4096 target sizes, Apply/Cancel, and nearest-neighbor as the default.
  - [x] Keep nearest-neighbor and premultiplied-alpha bilinear resampling explicit, deterministic, RGBA8, and separate from canvas resizing/cropping.
  - [x] Preserve the source aspect ratio when requested with synchronized, non-recursive, deterministically rounded and clamped dimensions.
  - [x] Resolve floating pixels into the single scale history entry, clear stale selection/crop state after success, and synchronize dimensions, textures, and signals.
  - [x] Preserve exact pixels and dimensions through one-entry undo/redo while protecting invalid, unchanged, and canceled operations from history.
  - [x] Disable and reject scaling during active imported 3D texture sessions in 3D and Split modes.
  - [x] Cover dimensions, RGBA8 pixels, interpolation/alpha edges, 1x1 boundaries, aspect behavior, cancellation, floating selections, history, signals, and 3D restrictions with synthetic-image tests.
- [x] Add exact clockwise/counterclockwise 90-degree rectangular, lasso-mask, and floating selection transforms.
- [x] Add shape modifiers:
  - [x] Hold Shift for constrained lines/squares/circles, including live preview updates when Shift changes during a drag.
  - [x] Add a From center option for lines, rectangles, and ellipses.
  - [x] Share modifier geometry between previews and committed pixels while preserving opacity, alpha lock, fill modes, selection behavior, and no-op history protection.
  - [x] Apply the brush no-overlap setting across each complete shape so repeated stamps and joined outline edges do not compound alpha.
  - [x] Render shape previews from the same raster result so preview RGBA, opacity, and no-overlap behavior match committed pixels.
  - [x] Cover constrained and center-origin line/rectangle/ellipse raster bounds, symmetry, opacity, alpha lock, undo/redo snapshots, and no-op commits with focused synthetic-image tests.
- [x] Add compact built-in brush presets with automatic Custom transitions.
- [x] Add bounded, deduplicated recent brush sizes.
- [x] Add optional brush opacity.
- [x] Add deterministic brush hardness/softness while keeping pixel-perfect heads hard-edged.
- [x] Add alpha lock.
- [x] Add fill tolerance.
- [x] Add contiguous vs global fill mode.
- [x] Add selection-aware, mirror-independent Replace Color mode using RGBA8 tolerance.
- Add dither/pattern fill modes later if they fit the tool.
- [x] Add mirror drawing:
  - [x] Add Off, Horizontal (top-to-bottom), Vertical (left-to-right), and Both modes with exact pixel-center symmetry.
  - [x] Share deterministic mirrored-coordinate deduplication across brush, eraser, shape rasterization/previews, and contiguous fill seeds.
  - [x] Preserve opacity/overlap, alpha lock, brush behavior, shape modifiers/fill, selection masks, clipping, and one-entry no-op-safe history.
  - [x] Keep global fill single-pass and 3D/Split UV surface strokes explicitly unmirrored.
  - [x] Add a compact contextual mode selector synchronized with View-menu commands and status text.
  - [x] Cover even/odd and degenerate dimensions, center axes, painting tools, fills, preview parity, selection masks, history, resize/load state, and UV regressions with synthetic-image tests.
- [x] Add preview-only neighboring tile repetitions for repeatable textures.
- [x] Add persistent transparent checkerboard color customization without pixel/history changes.

### Selection And Editing

- [x] Refine rectangular and lasso selection outlines and zoom-stable handles.
- [x] Add better selection affordances for small zoom levels.
- [x] Add arrow-key selection nudging with Shift for 10-pixel steps and held-key history grouping.
- [x] Add duplicate selection as a cancelable movable floating copy.
- [x] Add exact clockwise/counterclockwise 90-degree selection rotation.
- [x] Add visible transform Commit/Cancel controls while a floating selection is active.
- [x] Improve lasso selection-mask previews without modifying selected pixels.
- Add select by color / magic wand later.

## UI And Usability Polish

### Toolbar And Controls

- [x] Add a native top-level menu bar for common commands:
  - [x] File.
  - [x] Edit.
  - [x] Select.
  - [x] View.
  - [x] Godot.
  - [x] Help.
- [x] Synchronize menu checks for 2D/3D/Split mode, grid visibility, and UV overlay visibility.
- [x] Synchronize menu availability for history, clipboard, selection, UV, mesh, zoom, and active texture-session commands.
- [x] Add compact native Controls, Known Limitations, and About dialogs.
- [x] Move document, history, mode, preferences, and secondary selection commands out of the always-visible toolbar into menus.
- [x] Keep painting tools, contextual tool options, and frequently used navigation/3D context actions available as quick controls.
- [x] Use flat native menu-bar buttons so idle menu headings blend into the editor background.
- File menu candidates:
  - [x] New canvas.
  - [x] Open/load image.
  - [x] Save.
  - Save as. Deferred until GDDraw tracks the current 2D document path; the disabled menu item explains this.
  - [x] Save active 3D texture.
  - Save texture as new resource.
  - Recent files/textures.
- Edit menu candidates:
  - [x] Undo.
  - [x] Redo.
  - [x] Cut.
  - [x] Copy.
  - [x] Paste.
  - [x] Clear.
  - [x] Preferences/settings.
- Selection menu candidates:
  - [x] Select all.
  - [x] Deselect.
  - [x] Delete selection.
  - [x] Flip horizontal.
  - [x] Flip vertical.
  - [x] Rotate selection 90 degrees in either direction.
  - [x] Crop to selection.
- View menu candidates:
  - [x] 2D mode.
  - [x] 3D mode.
  - [x] Split mode.
  - [x] Zoom in.
  - [x] Zoom out.
  - Zoom to fit.
  - [x] Reset view.
  - [x] Toggle grid.
  - [x] Toggle UV overlay.
  - Toggle the 3D grid.
  - Frame 3D mesh.
- Help menu candidates:
  - [x] Controls reference.
  - 3D texture painting quick start.
  - [x] Known limitations.
  - [x] About GDDraw.
  - Add a lightweight update-available notice near Help after 0.1.0; first pass should notify/open the release page, not auto-replace plugin files.
- [x] Complete the first icon-control polish pass:
  - [x] Replace Resize text with the Lucide Scaling icon.
  - [x] Replace Use Selected 3D Surface text with the Lucide MousePointer2 icon.
  - [x] Replace the UV checkbox/text with a Lucide Network icon toggle.
  - [x] Replace Browse text with the Lucide FolderOpen icon.
  - [x] Replace the generic Shapes icon with the Lucide Shapes icon.
  - [x] Replace the generic Reset View icon with the Lucide RotateCcw icon.
  - [x] Add descriptive tooltips to the converted icon-only controls.
- [x] Audit every icon-only control for a clear tooltip and consistent active state.
- [x] Differentiate the 3D preview from the editor chrome with a brighter neutral background.
- Separate global file actions, drawing tools, view tools, and 3D-session actions more clearly.
- Improve transient status messaging so it reflects the active mode without obscuring action feedback.
- [x] Show active mesh/texture identity in the status bar.
- [x] Add equality-based clean/unsaved indicator.
- [x] Add a clear active 3D texture-session indicator through the compact identity label.
- Disable irrelevant controls by mode:
  - [x] Hide `Use Selected 3D Surface` outside 3D/Split.
  - [x] Hide UV toggle until UV data exists.
  - [x] Disable canvas resize when editing an imported texture unless explicitly allowed.
- Consider moving canvas size controls out of the main top row when editing a 3D texture to avoid accidental texture resizing.
- Add confirmation when resizing an active 3D texture-session canvas.
- [x] Keep the contextual toolbar compact by moving brush presets, recent sizes, alpha lock, brush head, touch-pixels, mirror mode, and canvas resizing into native menus/dialogs.
- Group settings into tabs:
  - Brush.
  - Grid/View.
  - Defaults.
  - 3D Paint.
  - Files.
- [x] Present Preferences as a native-themed surface covering the full dock workspace beneath the menu bar, with a clear close action and Escape support.
- Make the settings panel responsive:
  - Two columns when wide.
  - Single column when narrow.
  - Scroll if the dock is short.

### Navigation And Controls

- [x] Standardize the primary 3D mouse navigation controls with Godot's default editor conventions:
  - [x] Middle drag orbits.
  - [x] Shift+Middle drag pans.
  - [x] Right drag captures the pointer for freelook; `WASD` flies in camera space and `Q`/`E` moves vertically.
  - [x] Shift/Alt temporarily speeds/slows flight, and the wheel adjusts flight speed while freelooking.
  - [x] Mouse wheel zooms outside freelook and `F` frames the mesh.
- Decide and document any additional navigation beyond the primary scheme:
  - 2D canvas pan.
  - 2D canvas zoom.
  - 3D orbit.
  - 3D pan.
  - 3D zoom.
  - Frame/focus selected content.
- [x] Match the primary Godot viewport mouse shortcuts and frame shortcut.
- [x] Keep left-drag painting separate from middle/right-button navigation gestures.
- [x] Update the Help > Controls reference with the 3D bindings.
- Consider a navigation preset setting:
  - Godot-style.
  - Art-tool style.
  - Custom later.
- Keep controls consistent between 2D-only, 3D-only, and Split modes.
- Show temporary status hints for navigation actions:
  - Orbit.
  - Pan.
  - Zoom.
  - Painting.
- Add keyboard shortcut mapping support later if the plugin grows beyond fixed defaults.

### Canvas View Polish

- Add zoom-to-fit button.
- Add reset pan button.
- Add frame selected UV island later.
- Make the 2D canvas background less dominant in large empty areas.
- Improve checkerboard contrast options.
- Add optional UV overlay opacity/color settings.
- Add UV overlay labels or island highlighting later.
- Make 3D-to-2D hover marker more visible on busy textures:
  - Two-tone outline.
  - Inverted color.
  - Pulsing outline.
  - Optional crosshair.
- Make 2D brush preview respect square/circle/touch-pixels behavior visibly.

### 3D Preview Polish

- Add dedicated 3D toolbar overlay:
  - Frame mesh.
  - Reset camera.
  - Toggle grid.
  - Toggle UV wire.
  - Toggle brush cursor contrast.
- Add left/right mouse guidance through tooltips or status hints.
- Add optional turntable reset.
- Add camera projection toggle:
  - Perspective.
  - Orthographic.
- Add lighting/background controls only if flat preview is not enough for certain workflows.
- Keep paint preview flat/unshaded by default so color stays accurate.

## Godot Workflow Integration

- Add context action: "Edit in GDDraw" for selected `Texture2D` resources.
- Add context action: "Paint Texture in GDDraw" for selected `MeshInstance3D`.
- Support dragging:
  - MeshInstance3D from scene tree.
  - Mesh resource from filesystem.
  - Texture resource from filesystem.
  - Material resource from filesystem.
- Add resource save/reimport feedback after saving textures.
- Add optional auto-save active texture on project save.
- Add undo/redo integration for material/texture assignment.
- Add safer handling for imported texture paths and `.import` resources.
- Add warning when editing a generated/imported texture path that may be overwritten by reimport.
- Add "Save As New Texture" for non-destructive material iteration.
- Add "Duplicate material and texture for editing" workflow.
- Add support for packed scenes with inherited mesh/material setup.
- Add clear messaging when selected mesh has:
  - No mesh.
  - No UVs.
  - No editable material.
  - Multiple material slots.
  - Shared/mirrored UVs.

## File And Asset Workflow

- Add recent files/textures.
- Add recent meshes or sessions.
- Add default save naming templates.
- Add export options:
  - PNG.
  - WebP.
  - JPEG for opaque textures.
- Add import size presets for new 3D textures:
  - 256.
  - 512.
  - 1024.
  - 2048.
  - 4096.
- Add "create texture" options:
  - Transparent.
  - White.
  - Black.
  - Current color.
  - Checker/template.
- Add backup-before-save option.
- Add "open texture folder" or "show in FileSystem" convenience action.

## Performance And Robustness

- Avoid updating the full 3D texture every mouse-motion event if it becomes slow on large textures.
- Batch texture updates during strokes when useful.
- Profile 2048 and 4096 textures in Split mode.
- Add guardrails for huge brush sizes on huge textures.
- Cache UV lookup data for active mesh instead of scanning arrays repeatedly.
- Cache UV island/triangle data for hover preview.
- Add tests or script checks around:
  - UV barycentric lookup.
  - Brush footprint coverage.
  - Eraser restore behavior.
  - Undo/redo after 3D strokes.
- Keep plugin reload clean with editor logs checked after UI/script changes.
- Add fallbacks for meshes without UVs or with degenerate UV triangles.

## Documentation And Onboarding

- [x] Update README to describe:
  - 2D mode.
  - 3D mode.
  - Split mode.
  - Texture session saving.
  - Restore eraser behavior.
  - Shared UV warning.
- [x] Add a small "Quick Start: Paint a 3D Surface Texture" guide.
- [x] Add a "Known Limitations" section.
- Add a screenshot gallery once UI settles.
- [x] Document controls:
  - 2D pan/zoom.
  - 3D orbit/pan/zoom.
  - Brush/fill/eraser behavior.
- [x] Document safe texture workflow:
  - Duplicate texture/material if needed.
  - Save texture.
  - Reimport considerations.

## Open Design Questions

- Should GDDraw remain a single-canvas tool, or eventually support layers?
- Should 3D painting support surface-space brush strokes, or stay UV-texture based?
- Should a future explicit workflow allow resizing active 3D textures? Version 0.1.0 keeps the canvas size locked.
- Should Split mode become the default once a 3D session is active?
- Should UV overlay be shown on the 3D mesh, the 2D canvas, or both by default?
- How much material support is useful before the UI becomes too complex?
- Should GDDraw support tablet pressure later, or stay mouse-first?
