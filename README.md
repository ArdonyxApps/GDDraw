# GDDraw

GDDraw 0.2.0 is a Godot editor plugin for drawing prototype PNG assets and painting albedo textures on supported 3D surfaces without leaving the editor.

## Requirements

- Godot 4.4 or later. GDDraw 0.2.0 has been tested across Godot 4.4 through 4.7.
- A desktop editor build. Clipboard and native file-dialog behavior can vary by operating system.

## Installation

1. Copy the `GDDraw` folder to `res://addons/GDDraw` in your project.
2. Open **Project > Project Settings > Plugins**.
3. Enable **GDDraw**.
4. Open the **GDDraw** bottom panel.

For an Asset Store package, `addons/GDDraw` is the package boundary. Do not include the repository's `docs`, development files, `.godot` cache, generated `.import` files, or user-created content.

## What Is Included

- 2D drawing with brush, eraser, fill, line, rectangle, ellipse, raster text with installed/custom-directory fonts and text-box backgrounds, eyedropper, selection, lasso, transforms, crop, scale, mirror, grid, and tile preview tools.
- PNG new/open/save/save-as workflows plus `Sprite2D` and configurable textured `CSGBox3D`, `CSGSphere3D`, and `CSGCylinder3D` creation.
- Undo/redo and exact dirty-state tracking for independent 2D documents.
- Texture-painting sessions for `MeshInstance3D` and supported single-material CSG geometry with triangle UVs.
- 2D, 3D, and linked split views with UV overlays and editor-style 3D navigation.
- Protected session replacement, save/discard/cancel flows, 2D workspace restoration, and editor undo/redo for material or texture assignment.
- A staged stable-release updater in the Help menu with explicit download and Install and Restart consent.

## Quick Start: 2D

1. Open the GDDraw bottom panel and draw on the canvas.
2. Use **File > New**, **Open**, **Save**, or **Save As** for PNG documents.
3. Use **Godot > Create Sprite2D** to add the current saved image to the edited 2D scene.

The default save folder is `res://gddraw/images`, and it can be changed in Preferences.

## Asset Storage

GDDraw keeps the installed plugin replaceable by separating package files from project-owned content:

- `res://addons/GDDraw/` contains only plugin code, bundled icons and resources, licenses, and notices. Checks, downloads, validation, preferences, and asset workflows never write there; only the explicitly confirmed installation transaction may replace the complete package.
- `res://gddraw/images/` is the default folder for generated and saved PNGs.
- `res://gddraw/brushes/` is reserved for future file-backed brush assets. Current custom brush presets contain parameters only and remain in Godot's project-scoped editor metadata.
- `res://gddraw/fonts/` is the default project-specific custom-font folder. Fonts are discovered in place and are not copied.
- `user://gddraw/updates/downloads/` holds completed update archives and unique `.part` downloads, `staged/` holds validated packages and manifests, and `backups/` holds verified previous plugin packages. These locations are created only after an explicit update action.

These asset folders are lazy: installing or enabling the plugin, initializing the dock, opening Preferences, and scanning missing font or brush folders do not create them. A missing folder is created only immediately before an operation writes there; for example, the first PNG save creates its configured image folder. Existing project metadata always wins over the new defaults, so legacy choices such as `res://gddraw` and `res://fonts` remain unchanged. GDDraw does not migrate, copy, rename, or delete existing user assets.

## Safe Updates

For the repeatable maintainer release checklist and a step-by-step explanation of checking, staging, installation, rollback, restart, and activation, see the [GDDraw Updater Guide](docs/updater-guide.md).

GDDraw performs at most one lightweight HTTPS check per editor session against the latest stable release from the authoritative [ArdonyxApps/GDDraw GitHub repository](https://github.com/ArdonyxApps/GDDraw). Drafts, prereleases, non-semantic tags, branch archives, and releases without exactly one contracted update asset are ignored or rejected. Use **Help > Check for Updates…** to check again manually. If the installed development build is newer than the published release, the manual result says so explicitly instead of calling it up to date.

Manual checks reuse a dock-confined popup for checking, current, ahead-of-release, available, downloading, verifying, ready-to-install, installing, restart-required, and recoverable-failure states. When a newer version is available, a red exclamation badge appears on **Help** and the menu gains an **Update Available - vX.Y.Z...** entry. Automatic checks remain silent unless a safe newer release is available, and never download or install.

**Download Update** is explicit. It accepts only the release asset named `GDDraw-vX.Y.Z.zip`, downloads it over HTTPS to a unique `.part` file, enforces a 64 MiB archive limit, and renames the file only after a complete response. The asset URL must belong to the validated release, and the SHA-256 digest must come from GitHub's authenticated release-asset metadata. TLS and certificate validation remain enabled. GDDraw then inspects the complete ZIP entry list before extraction, confines every package file to `addons/GDDraw/`, rejects traversal, alternate roots, generated content, link-like names, and unexpected native payloads, and requires the tag, asset name, `GDDraw.gd` `PLUGIN_VERSION`, and `plugin.cfg` version to agree. Godot 4.4's ZIP API does not expose external attributes, so a specially encoded symlink that is not apparent from its path cannot be identified directly; exact extraction confinement and the external digest remain the defense at that boundary. The GitHub digest authenticates transport and publication metadata, but it is not maintainer code signing.

Validation only stages files under `user://gddraw/updates/`; it never changes the installed plugin. **Install and Restart** is a separate explicit action. It revalidates the staged bytes and versions, creates and verifies a complete backup, records a transaction, copies and verifies an exact replacement candidate, and uses a two-rename swap inside `res://addons/`. This removes obsolete package files without touching paths outside the GDDraw package. If copying, swapping, installed-file verification, or restart preparation fails, the verified backup is restored. Godot's supported editor restart API is requested only after successful verification. The update is not considered active until the next editor session loads and validates the target version; startup recovery completes that transaction or restores the verified backup. The immediately previous known-good backup is retained.

Checking, downloading, validation, installation, and activation are distinct phases. **Later** after validation leaves the staged package untouched. Canceling or failing a download removes only that operation's `.part` file. GDDraw sends a fixed generic User-Agent and no telemetry, project paths, project names, or user content.

## Create a Textured CSG Shape

1. Use **Godot > Create Textured CSG3D…** and choose **Box**, **Sphere**, or **Cylinder**.
2. Leave **Assign Current Image** enabled to save the visible canvas as a unique RGBA8 PNG in the configured project save folder and assign it through a local-to-scene, nearest-filtered `StandardMaterial3D`. Disable it to create an untextured shape even when the canvas is empty.
3. Choose whether to select the new node and whether to enable the CSG node's native collision support, then select **Create**.

Node creation, ownership, material/texture assignment, collision configuration, and optional selection are one editor undo/redo action. Undo leaves the generated PNG in place as a non-destructive project asset. The canvas, canvas history, dirty state, and any active 3D texture session are not changed. Created textured shapes can be opened through the normal 3D surface picker.

## Quick Start: Paint a 3D Surface Texture

1. Select a `MeshInstance3D`, a supported material-bearing CSG shape, or a parent containing one.
2. Switch GDDraw to 3D or Split view and choose **Use Selected 3D Surface**. You can also drag the Scene-tree node into the 3D pane.
3. Choose an editable material slot. Missing materials or textures are created only after explicit confirmation.
4. Paint the albedo texture. The eraser restores pixels from the texture loaded at session start.
5. Use **Save**, **Save As**, or **Stop Editing**. A successful Save As assigns the new PNG through Godot's editor undo/redo system.

Starting a 3D session preserves the independent 2D workspace. Unsaved 2D or 3D changes are guarded by save/discard/cancel prompts.

An active 3D session also survives editor scene-tab changes. GDDraw retains its private mesh snapshot, material, paint cache, and editable PNG when the source scene becomes inactive or is closed, so the model remains visible and paintable. **Scene Transform Link** is greyed out while no live source node is available and becomes usable again if the same source scene returns.

The 3D preview's lighting, perspective grid, transform gizmo, and transform reset controls affect only GDDraw's private preview. They never modify the source scene, mesh, material, or painted texture. **Scene Transform Link** is one-way from the live source transform into the private preview.

## Controls

- 2D: left drag uses the active tool, mouse wheel zooms, and middle drag pans.
- Shape tools provide **Corner to Corner**, **From Start Point**, and **From Canvas Center** origin modes; hold Shift for constrained lines, squares, and circles.
- 2D zoom starts at 10% and uses the visible 2D viewport to set its maximum, allowing detailed pixel inspection without unbounded zoom.
- 3D: left drag paints with Brush/Eraser or previews and commits Line, Rectangle, and Ellipse tools across compatible UV-connected surface triangles; middle drag orbits, Shift+middle drag pans, and the mouse wheel zooms.
- 3D freelook: hold right mouse and use WASD; Q/E move vertically; Shift/Alt adjust speed.
- Press F to frame the active 3D surface.
- Use **Help > Controls** in the plugin for selection shortcuts and the complete compact reference.

## Known Limitations

- Overlapping UV shells can make linked 2D-to-3D hover highlight a hidden or rear surface.
- 3D painting is limited to albedo textures on `StandardMaterial3D` targets and supported single-material CSG generated geometry with usable triangle UVs.
- `CSGTorus3D` creation is deferred: Godot's generated torus seam triangles wrap from near 1 back to 0 on both UV axes, causing interpolation across unrelated texture regions and unsafe deterministic paint hits at those seams.
- Unsupported shader materials, texture channels, and multi-material CSG results must be prepared outside GDDraw.
- Spatially distinct mirrored/shared UV pieces can be painted from a ray-selected 3D surface and may display the same pixels on every sharing piece; coincident mappings that cannot be ray-disambiguated are rejected.
- Split mode and Preferences can crowd narrow bottom-panel layouts.
- Active 3D texture sessions lock canvas resizing to protect the source texture.
- Independent 2D document Save/Save As output is PNG.

See [`docs/feature-backlog.md`](docs/feature-backlog.md) for non-blocking follow-up work and [`docs/architecture.md`](docs/architecture.md) for implementation boundaries.

## Release Packaging

Stable updater releases use this maintainer contract:

1. Update `GDDraw.gd` `PLUGIN_VERSION` to `X.Y.Z`.
2. Update `plugin.cfg` `version` to the same value.
3. Build a ZIP containing `addons/GDDraw/plugin.cfg` at that exact root-relative path. Ship only the `addons/GDDraw` package, keep source `.gd.uid` files, and exclude generated `.import` sidecars, editor caches, repository documentation/development metadata, native binaries, and project-owned `res://gddraw/` content.
4. Name the uploaded asset `GDDraw-vX.Y.Z.zip`.
5. Ensure GitHub publishes the asset's `sha256:<64 lowercase hex digits>` digest in the Release API metadata.
6. Create a non-draft, non-prerelease GitHub Release tagged exactly `vX.Y.Z`.
7. Verify that the tag, asset name, `PLUGIN_VERSION`, and `plugin.cfg` version agree.

Development occurs on the active development branch, while maintained lines may use version branches such as `0.2` or `0.3`. Branch names never establish stability and branch/source archives are never updater artifacts. Stable GitHub Releases and their contracted uploaded assets are the only public updater input.

## AI-Assisted Development

AI-assisted development tools were used during implementation, refactoring, documentation, and code review. All changes were directed, reviewed, tested, and approved by the maintainer.

## License

GDDraw is released under the MIT License. See [`LICENSE`](LICENSE) for the full license text.

The bundled icons are derived from Lucide and require Lucide's ISC license notice; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
