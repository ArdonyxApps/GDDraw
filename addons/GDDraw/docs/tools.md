# Tools

This page describes every drawing and editing tool, its contextual options, and important differences between 2D and 3D use.

> **Screenshot placeholder:** Show the complete tool rail with each icon numbered. Place a second cropped image beside it showing the contextual options row for the Brush tool.

## Shared colors

Foreground and background colors appear in the options bar when the active tool uses them.

- **Foreground** is the primary drawing, outline, and text color.
- **Background** is used by selected shape fills, text-box fill, dithering, and patterns.
- **Swap Colors** exchanges the foreground and background values.
- Recent color swatches provide quick access to previously committed colors.

Both color controls support alpha. Transparent colors can therefore paint, fill, or rasterize partially transparent pixels.

## Brush

The Brush paints the foreground color while the primary mouse button or pen is dragged.

### Brush options

- **Size** controls the footprint in image pixels.
- **Square or Circle head** selects the footprint shape.
- **AA / Pixel** switches between antialiased soft coverage and crisp pixel coverage.
- **Hardness** adjusts the falloff of an antialiased brush.
- **Touch Pixels** includes every texture pixel touched by the brush footprint.
- **Stroke Overlap** allows repeated passes within one continuous stroke to build additional color. Disable it for consistent one-pass stroke opacity.
- **Lock Alpha** preserves destination alpha, preventing paint from appearing on fully transparent pixels.
- Brush presets store frequently used size and behavior combinations.

In 3D, the brush is projected through the model's UV mapping. A stroke stays on its initial paint target and does not silently cross into another object's texture.

> **Tip:** For crisp pixel art, use Pixel mode with a square head and integer brush sizes.

## Eraser

The Eraser uses the Brush footprint and most Brush options, but removes or restores pixels instead of adding the foreground color.

- In a normal 2D document, erasing makes affected pixels transparent.
- In a 3D texture session, erasing restores pixels from the texture baseline captured when the session began.
- Layer locking and inherited group locking prevent erasing just as they prevent painting.

## Paint Bucket

The Paint Bucket replaces an area based on the clicked pixel and the configured tolerance.

### Matching modes

- **Contiguous** fills only the connected region around the clicked pixel.
- **Global** fills every matching pixel in the active layer.
- **Replace Color** replaces the matching source color according to the selected fill settings.
- **Tolerance** controls the maximum per-channel difference. `0%` matches only the exact source color.

### Fill styles

- **Solid** uses the foreground color.
- **Dither** alternates foreground and background colors with a configurable ordered matrix.
- **Pattern** repeats checker, stripe, dot, or configured pattern arrangements.
- **Custom** repeats an imported or pasted image source.

Open Fill Settings to preview and configure fill colors, target behavior, matrix or pattern scale, offset, rotation, filtering, and custom-image color interpretation.

> **Screenshot placeholder:** Show Fill Settings with the Dither tab selected and its live preview visible. The image should make the distinction between foreground, background, target mode, and preview clear.

## Shapes

The Shapes tool contains Line, Rectangle, and Ellipse modes. Drag to preview a shape and release to commit it as one undoable action.

### Line

Uses the foreground color and current stroke size. Hold `Shift` to constrain the line angle.

### Rectangle and Ellipse

The outline uses the foreground color. The paint-bucket button matches the Text tool's compact fill control:

- **Off** leaves the interior unchanged.
- **On** uses the background color inside a foreground outline.

Use the shared Swap Colors button to reverse the outline and interior colors. Set foreground and background to the same value when a single solid color should cover both the outline and interior.

Shape origin modes are:

- **Corner to Corner** uses the initial and current pointer positions as opposite bounds.
- **From Start Point** treats the initial click as the center and expands symmetrically.
- **From Canvas Center** fixes the shape at the image canvas center.

Hold `Shift` to constrain rectangles to squares and ellipses to circles.

On supported 3D surfaces, Line, Rectangle, and Ellipse preview and commit across compatible UV-connected triangles.

## Text

The Text tool creates editable raster text before committing it to the selected paint layer.

1. Drag a text box or click to use the default box size.
2. Type and edit text while the draft remains active.
3. Choose a theme, installed, or project font.
4. Set font size, alignment, wrapping, rotation, text color, and optional box fill.
5. Press `Ctrl+Enter` or select Commit to rasterize the draft as one undoable action.

The paint-bucket icon in the Text options toggles the text-box background:

- **Off:** the text box remains transparent.
- **On:** the current background color fills the text box.

Press `Escape` to discard an uncommitted text draft. Copying highlighted characters copies text; copying with no highlighted characters copies the rendered text box as an image selection.

> **Screenshot placeholder:** Show an active text draft with its resize handles and the Text options row. Include the font selector, size, fill toggle, alignment, wrapping, rotation, Commit, and Cancel controls.

## Eyedropper

The Eyedropper samples the visible composited color beneath the pointer and assigns it to the foreground color.

While hovering the 2D canvas, a magnified loupe shows nearby pixels and the exact sampled color. The center pixel is outlined to make the sample location clear.

In linked Split View, hover synchronization can help locate the corresponding UV position before sampling the 2D texture.

## Selection

Selection provides rectangular and freeform Lasso modes. A selected area can be moved, transformed, copied, cut, duplicated, cropped, or deleted.

### Create and transform

- Drag with Rectangular Selection to define an axis-aligned area.
- Draw a closed boundary with Lasso Selection for an irregular area.
- Drag inside a floating selection to move it.
- Drag handles to resize it.
- Use rotation controls for exact-angle rotation.
- Arrow keys nudge one pixel; `Shift+Arrow` nudges ten pixels.
- Press `Enter` to commit or `Escape` to cancel the active floating transform.

### Selection actions

- Flip horizontally or vertically.
- Rotate clockwise or counterclockwise.
- Copy, cut, paste, and duplicate.
- Crop the canvas to the occupied selected bounds.
- Delete selected pixels.

Selections work with layer content that extends beyond the document canvas. This allows oversized imported images to be positioned and transformed while the canvas outline remains the export boundary.

## Pan and canvas navigation

Middle-drag pans the 2D canvas regardless of the active drawing tool. The dedicated Pan mode provides the same interaction through primary-button dragging.

The mouse wheel zooms around the pointer. **View > Reset View** restores the default framing. When zoomed or panned beyond the viewport, use the edge scrollbars or Navigator for precise movement.

In 3D:

- Middle-drag orbits.
- `Shift+Middle` pans.
- Mouse wheel zooms.
- Hold the secondary mouse button and use `W`, `A`, `S`, and `D` for freelook.
- `Q` and `E` move vertically.
- `Shift` increases freelook speed; `Alt` decreases it.
- `F` frames the active surface.
