# Troubleshooting

## A Layers visibility button appears unavailable

Check whether Scene Sync is enabled. When live source visibility hides an object, the Scene is an additional visibility gate. Disable Scene Sync to manage the isolated preview entirely from Layers, or make the matching source Scene node visible.

New sessions start with Scene Sync disabled, so ordinary Layers visibility controls should be immediately interactive.

## The model moved after I changed the Scene

Scene Sync is enabled. Disable it to freeze the current private preview state. Reset Preview Orientation restores the session-start transform without modifying the source Scene.

## Painting appears on more than one model piece

The pieces may use mirrored or shared UV coordinates, or several material slots may reference the same PNG. They intentionally display the same underlying texture pixels.

## A 3D object cannot be imported

Verify that it has supported triangle geometry, usable UV coordinates, and a compatible material path. GDDraw 0.3.0 edits albedo textures on `StandardMaterial3D` and supported single-material generated CSG geometry.

Shader materials, unsupported texture channels, and unsupported generated geometry must be prepared outside GDDraw.

## A new material or texture is requested

The selected surface has no compatible albedo target. GDDraw asks before creating and assigning a `StandardMaterial3D` or PNG. This Scene modification integrates with Godot editor undo and redo.

## A large texture pauses on first selection

The first use may need to initialize image data, a GPU texture, thumbnails, and 3D paint caches. Subsequent target switches reuse cached preview resources. Extremely large textures still require more memory and processing than small pixel-art documents.

## My imported image extends outside the canvas

This is intentional. The image remains at its native size as layer content. The document outline shows the export boundary. Use Selection controls to move or scale the content, or resize the document canvas at the document level.

## Save is unavailable during a 3D hierarchy session

Use **Stop Editing**. The consolidated save window prevents one edited texture from being saved while other changed targets are missed.

## A layered 3D project opens without a model

The recorded source Scene may not be active or available. Use the relink workflow to open the source Scene or match compatible object paths. You can also open embedded layers without the 3D preview when only the pixel data is needed.

## Text fonts are missing

Open the Text font selector after placing supported fonts in the configured custom-font folder, or select an installed system font. The default project folder is `res://gddraw/fonts/`.

## The interface is cramped

Increase the bottom-panel height or editor width, collapse the Layers panel, or choose a single 2D or 3D view instead of Split View.

## Update installation fails

GDDraw keeps validation, staging, installation, and activation separate. A failed installation attempts to restore the verified previous package. Restart Godot, check the Help update status, and retry only from the authoritative stable release workflow.
