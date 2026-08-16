# GDDraw Feature Backlog

This document records shipped milestones, the planned `0.2.0` development
scope, known limitations, and work being considered for later releases.

## 0.2.0 Planned Work

The `0.2.0` theme is workflow depth: expand creation tools, improve 3D visual
feedback, and make common Godot asset-creation tasks faster without attempting
a major architectural rewrite.

### Toolbox

#### Text Tool

- [x] Add a text tool that creates a temporary editable text box.
- [x] Allow text entry, movement, and box resizing before rasterization.
- [x] Add font size, foreground color, alignment, and wrapping controls.
- [x] Commit by clicking outside, switching tools, `Ctrl+Enter`, or the explicit command.
- [x] Cancel with `Escape` without changing pixels or history.
- [x] Record committed text as one undoable image operation.
- [x] Keep the first version focused; defer rich text, curved text, and advanced
  effects while supporting selection-style draft rotation.

#### Paint Bucket Fill Styles

- [x] Add Solid, Dither, Pattern, and Custom fill styles to the 2D paint
  bucket without changing the existing region-discovery algorithms.
- [x] Include checkerboard, horizontal/vertical/diagonal line, dot, and ordered
  Bayer 25/50/75 percent presets with editable dither and pattern geometry.
- [x] Provide a bounded, staged Fill Settings overlay with Preferences-style
  options, a checkerboard-backed 64 × 64 live preview, Cancel, and Use.
- [x] Keep configuration changes pixel- and history-neutral; preserve the most
  recent settings for every fill tab while the GDDraw dock remains open.
- [x] Define exact foreground/background RGBA behavior for Solid, Dither, and
  Pattern fills, including Clicked Color and Restyle Previous Fill targeting.
- [x] Add Custom Image sources from project/external image selection, drag and
  drop, GDDraw copied/cut selections, the system clipboard, and clipboard image
  paths, with thumbnail, filename, paste, and clear actions.
- [x] Support Original RGBA, Alpha Mask, and thresholded Two-Color Mask custom
  color modes while preserving transparent-source no-paint behavior.
- [x] Support independent X/Y repetition, independent or aspect-locked scale,
  horizontal/vertical spacing, rotation, X/Y offsets, and Nearest or Bilinear
  source sampling.
- [x] Anchor Dither, Pattern, and Custom rendering to absolute canvas
  coordinates so separately filled neighboring regions align seamlessly.
- [x] Preserve tolerance, Contiguous/Global/Replace Color behavior, selections,
  alpha lock, clipping, compositing, Restyle Previous Fill, one-entry history,
  and no-op-safe history.
- [x] Keep styled fills scoped to the 2D Paint Bucket; 3D UV Paint Bucket
  behavior remains solid and other drawing/shape tools remain unchanged.

#### Shape Origin Modes

- [x] Replace the legacy shape-origin checkbox with an **Origin** mode.
- [x] Provide **Corner to Corner** for the default endpoint behavior.
- [x] Provide **From Start Point** for the center-at-initial-click
  behavior.
- [x] Add **From Canvas Center** so the shape remains centered on the canvas.
- [x] Keep Shift constraints and preview/commit geometry consistent across all
  origin modes.

### 3D Painting And Preview

#### Preview Depth And Readability

- [x] Add a neutral preview light so white or flat albedo textures retain
  visible surface depth while painting.
- [x] Keep the light isolated to GDDraw's private preview scene.
- [x] Provide a simple light enable/intensity control if the fixed default is
  not sufficient.
- [x] Preserve a color-accurate unshaded option.
- [x] Evaluate horizon haze/ground fade; retain the transparent grid stage
  because it improves orientation without obscuring texture colors.
- [x] Defer exact duplication of the main editor viewport environment.

#### Shape Tools On 3D Surfaces

- [x] Map the initial and current 3D shape surface hits into deterministic texture-pixel coordinates.
- [x] Preview 3D shape results nondestructively in both the 2D texture and private 3D live texture.
- [x] Commit rasterized 3D shape results to the shared 2D image on a compatible release.
- [x] Implement Line, Rectangle, and Ellipse by delegating preview and commit rasterization to their 2D paths with one-entry/no-op-safe history.
- [x] Break or reject a shape when its endpoints cross incompatible material
  surfaces, disconnected UV islands, or ambiguous seams.
- [x] Add Rectangle and Ellipse support after Line behavior is reliable.

### Godot Creation Options

- [x] Expand textured CSG creation beyond `CSGBox3D`.
- [x] Add `CSGSphere3D` and `CSGCylinder3D` creation.
- [x] Evaluate `CSGTorus3D`; keep it deferred because generated seam triangles
  wrap across both UV axes and produce unsafe interpolation/paint hits.
- [x] Add creation options for assigning the current image, selecting the new
  node, and enabling collision.
- [x] Prefer the CSG node's native collision support where applicable.
- [x] Keep the complete node/material/texture creation flow undoable.

### Plugin And Release Options

- [x] Standardize lazily created project asset defaults under
  `res://gddraw/images`, `res://gddraw/brushes`, and `res://gddraw/fonts` while
  keeping preferences in project-scoped editor metadata and temporary update
  staging reserved at `user://gddraw/updates`. Existing configured paths remain
  authoritative, missing folders are not created by initialization or scans,
  and `res://addons/GDDraw` remains an immutable package boundary.
- [x] Add a lightweight stable-release notification with a red **Help** badge
  and an **Update Available** Help-menu entry.
- [x] Show the installed and latest available versions in a dock-confined
  confirmation overlay.
- [x] Open the validated GitHub Release page only after confirmation.
- [x] Keep automatic checks notification-only; never download or install without
  explicit user actions.
- [x] Add explicitly confirmed, cancellable release-asset download and isolated
  staging beneath `user://gddraw/updates`.
- [x] Validate the GitHub-provided SHA-256 digest, exact ZIP root, every archive
  path, required plugin files, and agreement among release tag, asset name,
  `PLUGIN_VERSION`, and `plugin.cfg`.
- [x] Add explicit **Install and Restart**, verified package backups, a
  transaction descriptor, two-rename replacement, automatic rollback, startup
  recovery, and activation confirmation after restart.
- [ ] Add maintainer code signing in addition to GitHub release metadata and
  TLS transport integrity.
- [ ] Add alternate release channels or branch-based update artifacts.
- [ ] Add unattended/background installation.
- [ ] Add cross-project or global plugin management.

### 0.2.0 Validation

- [x] Add focused tests for text commit/cancel/history behavior.
- [x] Add deterministic Solid, Dither, Pattern, and Custom Image Fill tests,
  including settings UI, source workflows, transforms, region modes,
  compositing, selection/alpha-lock behavior, and history contracts.
- [x] Cover every shape-origin mode in preview and committed output.
- [x] Test preview lighting against white, black, and saturated textures.
- [x] Test 3D lines on simple, connected, seamed, mirrored/overlapping, disconnected, and multi-surface UV layouts.
- [x] Validate every supported CSG type with and without collision.

## 0.1.0 Completion Notes

Version `0.1.0-alpha` established the core GDDraw workflow as a functional
Godot 4.7 editor plugin.

### 2D Drawing And Editing

- [x] Create, open, edit, save, and save-as RGBA8 PNG documents.
- [x] Brush and eraser tools with square/circle heads, size, opacity,
  hardness, alpha lock, touch-pixels behavior, and pixel-perfect behavior.
- [x] Contiguous and global paint-bucket modes with deterministic tolerance.
- [x] Line, rectangle, and ellipse tools with fill options, Shift constraints,
  start-point-origin drawing, accurate previews, and no-op-safe history.
- [x] Eyedropper and selection-aware Replace Color workflows.
- [x] Rectangular and lasso selection with copy, cut, paste, delete, duplicate,
  move, flip, 90-degree rotation, keyboard nudging, and explicit commit/cancel.
- [x] Crop to selection, trim transparent bounds, and exact crop rectangles.
- [x] Image scaling with nearest-neighbor and premultiplied-alpha bilinear
  interpolation, optional aspect preservation, and undo/redo.
- [x] Mirror drawing across horizontal, vertical, or both axes.
- [x] Configurable grid, snapping, transparent checkerboard colors, and
  preview-only neighboring tiles for repeatable textures.
- [x] Compact brush presets and deduplicated recent brush sizes.
- [x] Equality-based clean/unsaved document tracking with protected file and
  session transitions.

### 3D Texture Painting

- [x] Paint albedo textures on supported `MeshInstance3D` surfaces and
  material-bearing, single-material CSG geometry with usable triangle UVs.
- [x] Select material slots through a read-only surface picker.
- [x] Start sessions from the selected Scene-tree node, a supported parent, or
  scene-tree drag and drop.
- [x] Create missing materials/textures only after explicit confirmation.
- [x] Use duplicated per-instance surface overrides for newly created or
  reassigned textures instead of mutating embedded mesh materials.
- [x] Save active textures and use Save As for readable non-file textures,
  with successful assignments recorded through Godot editor undo/redo.
- [x] Restore erased pixels from the originally loaded texture rather than
  forcing transparent pixels.
- [x] Prevent interpolated strokes from bridging unrelated visible surfaces,
  material surfaces, nonadjacent triangles, or large UV seams.
- [x] Show a brush footprint that reflects the active size and brush head.
- [x] Detect and warn about shared or mirrored UV conditions.
- [x] Lock canvas resizing and scaling while an imported 3D texture session is
  active.
- [x] Preserve the current session when a replacement load, save, or picker
  operation is canceled or fails.
- [x] Frame the active 3D surface with the `F` shortcut and support reset/zoom
  controls in the preview.

### Session And Split-View Workflow

- [x] Keep the 3D texture-session lifecycle independent from 2D/3D/Split view
  layout changes.
- [x] Preserve and restore the independent 2D document, history, selection,
  floating pixels, zoom, and pan around 3D sessions.
- [x] Protect unsaved 2D and 3D work with Save/Discard/Cancel transitions.
- [x] Provide 2D-only, 3D-only, Split Horizontal, and Split Vertical layouts.
- [x] Preserve independent split ratios and orientation.
- [x] Provide independent 2D zoom and 3D camera-distance controls/readouts.
- [x] Synchronize linked hover and UV-island previews in both directions.
- [x] Cache triangle and UV-island connectivity for the active preview mesh.
- [x] Provide a persistent linked-view toggle and a shared 2D/3D UV-overlay
  toggle.
- [x] Retain the private model, paint cache, and editable texture across editor
  scene-tab changes or source-scene closure; disable Scene Transform Link while
  its live source node is unavailable.

### Godot Editor Integration

- [x] Create a `Sprite2D` from the current saved image.
- [x] Create a textured `CSGBox3D` from the current image.
- [x] Assign created or saved textures through editor undo/redo.
- [x] Provide native File, Edit, Image, Select, Tool, View, Godot, and Help
  menus with contextual availability and synchronized checks.
- [x] Provide compact icon-based drawing and navigation controls with tooltips
  and consistent selected states.
- [x] Provide native-themed Preferences, Controls, Known Limitations, and About
  surfaces.
- [x] Follow Godot-style 3D navigation: middle-drag orbit, Shift+middle-drag
  pan, right-mouse freelook, WASD/QE movement, and wheel zoom/speed control.

### Documentation And Stabilization

- [x] Document installation, 2D drawing, 3D painting, Split View, controls,
  safe texture handling, and current limitations.
- [x] Add focused synthetic-image tests for crop, scaling, shapes, mirroring,
  selection transforms, history, and active-session restrictions.
- [x] Add release-ready promotional screenshots and Asset Store copy.

## Additional Work After 0.2.0

These items remain useful but are not committed to the `0.2.0` scope.

### 2D Drawing And Selection

- [ ] Add select-by-color or magic-wand selection.
- [ ] Consider named presets and optional dock-session/project persistence for
  Custom Image Fill configurations after the transient workflow has matured.
- [ ] Add an explicitly confirmed resize workflow for active 3D textures.
- [x] Add installed-font discovery, custom font-directory selection, and
  selection-style text transforms.
- [ ] Consider layer support while preserving a simple single-canvas workflow.
- [ ] Add tablet pressure if the plugin grows beyond mouse-first input.

### 3D Painting

- [ ] Resolve complex-mesh 2D-to-3D hover ambiguity with visibility or
  occlusion-aware UV candidate selection.
- [ ] Improve texture-footprint painting across dense seams and tiny islands.
- [ ] Add paint-scope modes for hovered triangle, UV footprint, and a possible
  visible-surface footprint.
- [ ] Add optional UV seam bleed/padding.
- [ ] Add configurable light, dark, two-tone, and brush-color cursor contrast.
- [ ] Add UV-island isolation or explicit hovered-island highlighting.
- [ ] Add normal, roughness, and emission channel editing where safe.
- [ ] Support common `ShaderMaterial` texture uniforms.
- [ ] Add perspective/orthographic preview switching and optional turntable
  controls.

### Godot Workflow Integration

- [ ] Add **Edit in GDDraw** for selected `Texture2D` resources.
- [ ] Add **Paint Texture in GDDraw** for selected `MeshInstance3D` nodes.
- [ ] Accept mesh, texture, and material resources dragged from the FileSystem.
- [ ] Add resource save/reimport feedback and warnings for imported paths that
  may be overwritten.
- [ ] Add **Save As New Texture** and duplicate-material-and-texture workflows.
- [ ] Improve inherited and packed-scene material handling.
- [ ] Add optional auto-save of the active texture on project save.

### File And Asset Workflow

- [ ] Add recent files, textures, meshes, and sessions.
- [ ] Add default save-name templates.
- [ ] Add WebP and opaque JPEG export where appropriate.
- [ ] Add common new-texture size and background presets.
- [ ] Add backup-before-save and show-in-FileSystem conveniences.

### UI And Navigation

- [ ] Improve narrow-dock and short-dock responsiveness.
- [ ] Separate global file actions, drawing tools, view tools, and session
  actions more clearly.
- [ ] Add zoom-to-fit and explicit reset-pan controls.
- [ ] Add an optional 3D grid toggle and compact orientation helper.
- [ ] Add UV overlay color/opacity settings and stronger linked-hover markers.
- [ ] Add remappable keyboard shortcuts if fixed defaults become limiting.
- [ ] Consider Godot-style and art-tool navigation presets.

### Performance And Robustness

- [ ] Profile 2048px and 4096px textures in 3D and Split View.
- [ ] Batch full-texture updates during strokes if profiling shows a need.
- [ ] Add guardrails for extreme texture and brush sizes.
- [ ] Expand tests around UV lookup, brush footprint coverage, eraser restore,
  3D stroke history, and degenerate triangles.
- [ ] Keep plugin reloads clean and verify editor logs after UI/script changes.

### Distribution

- [ ] Publish a workflow video closer to `1.0`, after the primary interface and
  workflows have stabilized.
- [x] Add a staged updater with download integrity, rollback, and editor restart;
  keep each download and installation explicitly confirmed.
- [ ] Define any future Asset Store interaction or global plugin-manager policy.

## Known Limitations

- Split View 2D-to-3D hover can select a hidden surface when complex meshes
  contain overlapping UV shells. Simple planes, cubes, and synthetic overlap
  cases work; the remaining ambiguity requires visibility-aware selection.
- 3D brush visibility varies with model and texture colors.
- Dense seams, mirrored UVs, tiny islands, and complex overlap need further
  touch-pixels and footprint validation.
- Split layouts and Preferences can crowd narrow bottom panels.
- The 3D-to-2D hover marker can be difficult to see on large or visually busy
  textures.
- 3D painting currently targets supported albedo textures on
  `StandardMaterial3D` surfaces with usable triangle UVs.
- Shader materials, additional texture channels, and multi-material generated
  CSG results are not currently editable.
- Active imported 3D texture sessions intentionally lock canvas resizing and
  image scaling.

## Open Design Questions

- Should GDDraw eventually support layers or remain a focused single-canvas
  tool?
- Should advanced 3D painting remain UV-texture based or gain a separate
  surface-space stroke system?
- Should Split View become the default after a 3D session starts?
- How much material and texture-channel support is useful before the session
  picker becomes too complex?
- What guarantees would be required before a self-updater is safer than an
  update notification and release-page link?
