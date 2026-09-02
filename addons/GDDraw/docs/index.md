# Welcome to GDDraw

GDDraw 0.3.0 is a Godot editor plugin for layered 2D artwork and multi-object albedo texture painting. It is designed for fast iteration without leaving the editor.

> **Screenshot placeholder:** Add a wide overview of GDDraw in Split View. Show a layered texture in the 2D canvas, the painted model in the 3D preview, and the Layers panel with a small hierarchy expanded.

## What you can create

- Layered 2D drawings with paint layers, nested groups, opacity, visibility, locking, and non-destructive project files.
- PNG sprites and texture assets stored directly in the Godot project.
- Albedo texture edits painted directly on supported `MeshInstance3D` and CSG surfaces.
- Coordinated 3D painting sessions containing several objects, materials, and textures from one Scene hierarchy.
- Textured `Sprite2D` and supported CSG nodes created through editor-aware workflows with undo and redo.

## Start here

New users should begin with [Getting Started](getting-started.md), then read [Interface](interface.md) and [Tools](tools.md).

For layered artwork, continue with [Layers](layers.md). For model textures, see [Painting in 3D](3d-painting.md).

## Compatibility

GDDraw 0.3.0 supports Godot 4.4 and later and is tested through Godot 4.7. It requires a desktop editor build. Native clipboard and file-dialog details can vary by operating system.

## Documentation conventions

- Menu paths appear as **File > Save Layered Project**.
- Keyboard shortcuts appear as `Ctrl+S`.
- Godot node and resource types appear as `MeshInstance3D` or `StandardMaterial3D`.
- A note beginning with **Screenshot placeholder** describes an image that can be added during the documentation polishing pass.

> **Note:** This manual is installed with GDDraw. It describes the same plugin version you are currently running and remains available offline.
