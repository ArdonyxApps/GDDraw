# Gradients

Choose **Gradient** between Paint Bucket and Shapes in the left toolbar, press
**G**, or use **Tool > Gradient**. The same Gradient icon identifies its tool,
panel button, and editable layer type.

## Draw a gradient

1. Select the paint layer. Make a rectangular or lasso selection if desired;
   switching to Gradient preserves that selection.
   **Preferences > Tools > Gradients > Default output** chooses **New Gradient
   Layer** (default) or **Paint on Current Layer**.
2. Set the foreground/background colors using the existing color controls or
   palette. Choose the gradient options in the top bar.
3. Drag in the 2D canvas. The start and end handles show the transition. Hold
   **Shift** to constrain its angle to 45-degree increments.
4. Release to create the Gradient layer automatically (or apply pixels in raster
   mode). Its handles stay available. Dragging a handle updates that layer on release.
5. To create another Gradient layer, drag anywhere away from the existing control
   nodes. You can keep the current Gradient layer selected.

Each completed canvas drag is one undo step. **Escape** cancels an unfinished
gesture. A click without a drag creates nothing. Moving the pointer without
dragging does not change the gradient.

The tool fills the active selection or
the document area of the active layer. Drag length controls the transition,
not the area filled. Colors outside the transition continue at the nearest
endpoint. Gradients do not repeat or mirror with the brush mirror settings.

## Options

- **Linear:** foreground at the start, background at the end.
- **Radial:** the start is the center; drag distance sets the radius. The end
  color continues beyond that radius. Circles stay circular on rectangular images.
- **Reverse:** reverse the gradient colors without swapping the drawing colors.

New gradients start with the foreground/background drawing colors. Edit stops in
the right panel; set an endpoint's opacity to zero for a transparent fade. Overall
opacity belongs to the layer controls. The toolbar has no output, color-mode, or
overall-opacity dropdown/field.

Colors and options update the current draft live. Interpolation is linear
between the stored sRGB color components and alpha. The result uses ordinary
source-over blending: transparent portions leave existing pixels intact.
Use an empty layer for a separate gradient overlay. Alpha lock preserves the
existing alpha and leaves fully transparent pixels untouched. Layer and group
opacity remain part of the normal display composite.

## Color stops panel

Selecting the Gradient tool or a Gradient layer opens a temporary **Gradient** tab
on the right. It stays available when switching tools while a Gradient layer is
selected; interacting with a stop switches back to the tool and reopens its controls.
When neither the tool nor the selected layer is Gradient, the prior panel
arrangement and active tabs are restored. Temporary layout
changes are not saved over your Layers/Palettes layout.

Enable **Preferences > Tools > Gradients > Always show Gradient panel button**
to keep the button available with any tool or layer. In this mode, the panel's
placement and open state persist with the workspace. Enabling the preference
retains an already-open Gradient panel. Selecting Gradient or starting a gesture
reveals its helper; an ordinary layer shows the next-gradient preview from drawing colors.

The preview strip and editable rows select the same color stop as the canvas handles.
Each row contains a clickable Godot color swatch, position field, and opacity field.
Percent units appear inside the compact, equal-width text boxes. Press Enter or leave a field
to accept a value. Invalid input restores its previous value; opacity clamps to 0–100%.
Drag intermediate stops along the canvas line or preview strip, or enter a
position. Stops stay between their neighbors. Endpoint stops stay at 0% and 100%;
their canvas handles still move the gradient's start and end positions.

- The evenly spaced **Add**, **Duplicate**, and **Delete** icons sit at the bottom
  of the panel, with tooltips. **Add** inserts a stop between the selected stop and the next one, sampling the
  existing gradient so its appearance stays unchanged. At the final stop it uses
  the preceding interval.
- **Duplicate** inserts a stop in that interval with the selected stop's color.
- **Delete** removes an intermediate stop. Endpoints cannot be deleted.

Editing or adding a stop creates custom colors independent of the main drawing
colors. Reverse still affects every stop. Saved Gradient layers retain their own
stops. Switching to an ordinary layer resets the next-gradient preview to current
foreground/background colors; changing those colors updates the idle preview.
An active draft retains its edited stops. Changes to an existing layer's
controls apply automatically after a short pause, with undo support. Pending control
changes are saved before switching tools/layers or saving the layered document.
Editing an existing Gradient layer's controls switches back to Gradient. Selecting
the Gradient tool or starting a new gesture opens its helper without taking canvas focus.

## Editable Gradient layers

**New Gradient Layer** places an editable layer immediately above the selected
layer, in the same group. It stores the endpoints, color stops, shape, reverse,
opacity, and a fixed mask from the original selection. The original paint pixels
remain unchanged. A new layer has its own opacity and does not use paint alpha lock.

Select a Gradient layer to reopen its controls and handles. Handle drags update it
on release; panel changes apply automatically. There are no Apply/Cancel buttons.
Click a stop row or its controls to switch back from another tool. The layer context
menu also retains **Edit Gradient Layer**. The panel has no separate Edit or Reset button.
The fixed mask remains even if the canvas selection changes. Both creation and
editing support undo/redo. Locked layers cannot be edited.

Gradient layers support ordinary visibility, opacity, grouping, ordering, and
duplication. Their cached pixels are used for thumbnails, PNG output, and 3D
textures. Save a **Layered Project (.gddraw)** to retain editability after reopening;
a PNG only retains the rendered image.

Starting Brush, Fill, or a shape while a Gradient layer is selected creates a paint
layer above it. Creation and drawing share one undo step; the gradient stays editable.
To change the gradient's own pixels, right-click and choose **Rasterize Gradient
Layer** first. This is also required before erasing its pixels. Undo restores the
editable gradient. Merge operations produce ordinary paint layers.

**Paint on Current Layer** retains the original raster workflow and does not create
an editable layer. Its alpha-lock behavior remains unchanged.

## Layers and 3D

The output mode determines which layer receives the result. Effective layer/group
locks, selection masks, and document bounds apply. Locked and zero-length drafts
cannot be applied. Unchanged raster operations add no undo entry; creating a layer
retains its recipe even if its opacity is zero. Changing tools or layer
operations cancels an unfinished gradient. Losing window focus ends any endpoint
drag but preserves the draft for further adjustment.

Gradients work in the 2D texture canvas of a 3D session. Applying one updates
the 3D preview. Direct dragging on the model is not supported in this version;
the status bar directs you to the 2D canvas.

## Large canvases and future scope

Large previews use a bounded color ramp and background image blending, keeping
one job active and coalescing pointer changes. Handles move immediately while
the image preview catches up. Fine transitions on large canvases can be
approximate while editing; completed edits always render at full resolution.
Full-resolution application can briefly pause on large or alpha-locked images.

Presets, custom midpoint blending, dithering, repeat/mirror modes,
and direct 3D-surface gradients are reserved for later versions.
