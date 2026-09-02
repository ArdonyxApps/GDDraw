# Known Limitations

This page describes the intended boundaries of GDDraw 0.3.0 rather than unfinished behavior that should silently fail.

## 3D materials and channels

- 3D painting currently targets albedo textures on `StandardMaterial3D` surfaces.
- Shader materials and additional texture channels are not editable.
- Supported CSG painting is limited to generated geometry and material configurations that provide deterministic triangle UVs.
- Multi-material generated CSG results must be prepared outside GDDraw.
- `CSGTorus3D` creation is deferred because its generated seam triangles can interpolate across unrelated texture regions.

## UV ambiguity

- Overlapping UV shells can make linked 2D-to-3D hover choose a hidden or rear surface.
- Mirrored and shared UV pieces display the same texture pixels by design.
- Spatially separate shared pieces can often be disambiguated by the 3D ray hit, but coincident mappings may be rejected.
- Dense seams, tiny islands, and heavy overlap should be manually checked after painting.

## Texture and performance boundaries

- Very large textures require more memory and may pause briefly during first-time cache and preview initialization.
- Complex models and visually busy textures can make brush, hover, or UV previews harder to read.
- Active imported 3D texture sessions protect ordinary canvas resizing and image scaling. Use target-level texture resizing instead.

## Interface boundaries

- Split View and Preferences can feel crowded in narrow bottom-panel layouts.
- Native clipboard and file-dialog behavior can differ across desktop operating systems.
- In-app documentation supports the Markdown subset used by the packaged manual rather than every GitHub Markdown extension.

## File format boundaries

- PNG export is flattened by design.
- Use `.gddraw` layered projects to preserve editable layers, groups, target bindings, oversized layer content, and eraser baselines.
- Layered 3D documents reference their source Godot Scene; they do not embed a silent duplicate of the model geometry.

If behavior falls outside these documented boundaries without an explanation in the status bar, it may be a defect rather than a limitation.
