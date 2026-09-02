# Painting in 3D

GDDraw paints UV-mapped albedo textures through an isolated preview of compatible Scene geometry. The source model remains part of the Godot Scene; editable pixels remain conventional image textures.

> **Screenshot placeholder:** Show Split View while painting a multi-object character. Include the brush preview on the model, the corresponding 2D texture location, and the Scene-like object hierarchy in Layers.

## Start a session

Select a `MeshInstance3D`, supported material-bearing CSG node, or a hierarchy root in Godot. Then choose **Godot > Use Selected 3D Object**, use the empty-state action, or drag Scene nodes into GDDraw.

The import window mirrors the Scene hierarchy and provides checkboxes for compatible textures. All compatible textures begin selected. Parent checkboxes include or exclude their compatible descendants, while indeterminate states indicate partial selection.

Missing supported materials or albedo textures are created only after confirmation.

## Imported hierarchy

GDDraw includes the selected compatible objects in one coordinated Layers hierarchy. Object rows use Godot node icons, and material rows use concise names such as `MAT_0 · Albedo`.

If several material slots or objects reference the same PNG, they share one paint target and layer stack. Painting it updates every bound preview and saving writes that destination once.

## Initial Scene state and Scene Sync

At import time, GDDraw copies the source hierarchy's transforms and authored visibility so the isolated preview initially matches the Scene.

**Scene Sync is disabled by default.** This means:

- Layers visibility controls work independently immediately.
- Later Scene transform or visibility edits do not unexpectedly change the painting preview.
- GDDraw preview rotation remains independent.

Enable Scene Sync from the 3D controls when the preview should continuously follow every imported source node's transforms and effective visibility. Synchronization is one-way from the Scene into GDDraw and does not edit the source Scene.

## Select a paint target

Select an object's texture layer in Layers or paint a visible supported object in the 3D preview. A paint hit can activate its owning texture target unless Target Lock is enabled internally for the workflow.

Selecting a Layers row does not force Godot's Scene selection, avoiding editor focus changes and unnecessary hierarchy refreshes. Explicit **Select in Scene** actions remain available where appropriate.

## Painting and UV behavior

Brush and Eraser strokes use ray hits against the visible preview geometry and convert them into texture coordinates. Shape tools operate across compatible UV-connected triangles.

- A stroke remains on the target where it began.
- Hidden objects are not paint targets.
- Locked paint layers reject 2D and 3D edits.
- Mirrored or shared UV regions display the same underlying pixels.
- Overlapping UV shells can be ambiguous when several surfaces map to the same texture location.

Use the UV overlay in 2D or Split View to understand the model's texture layout.

## Preview controls

The 3D preview provides:

- Orbit, pan, zoom, and freelook navigation.
- Frame active surface with `F`.
- A perspective grid.
- Neutral preview lighting with intensity and camera-link controls.
- A transform gizmo for private preview orientation.
- Reset preview orientation.
- Scene Sync for optional live source following.

These preview controls do not modify the source Scene, mesh resource, or material transforms.

## Texture resolution

Existing albedo textures retain their native dimensions. New textures use GDDraw's configured default until resized through the texture-target context menu.

Texture resizing is a target-level action, not a paint-layer property. It updates the complete texture stack and the texture applied to the model. Active imported texture sessions otherwise protect ordinary canvas-resize actions from accidentally changing UV texture dimensions.

## Save and stop editing

Use **Stop Editing** to open the consolidated save review for changed textures.

- **Save** writes to an existing texture destination.
- **Save As New** selects a new destination for an individual texture.
- Include checkboxes determine which changed textures are saved.
- Before and after previews help verify each output.
- **Save All** processes the selected changes without opening one popup per texture.

After saving or discarding, GDDraw restores the independent 2D workspace that existed before the 3D session.

Layered 3D projects preserve editable layers and target bindings while referencing their source Godot Scene. If that Scene is unavailable when reopened, GDDraw can relink it or open only the embedded layers without a 3D preview.
