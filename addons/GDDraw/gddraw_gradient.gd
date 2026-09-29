@tool
extends RefCounted
## Raster-only gradient helper. All coordinates are image pixels.

static func recipe(start: Vector2, end: Vector2, settings: Dictionary) -> Dictionary:
	var stops: Array = []
	for stop in settings.stops:
		var color: Color = stop.color
		stops.append({"position": stop.position, "color": [color.r, color.g, color.b, color.a]})
	return {"start": [start.x, start.y], "end": [end.x, end.y], "stops": stops, "radial": settings.radial, "reverse": settings.reverse, "opacity": settings.opacity}

static func valid_recipe(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in ["start", "end"]:
		if not value.get(key) is Array or value[key].size() != 2: return false
		for number in value[key]:
			if not (number is float or number is int) or not is_finite(number) or absf(number) > 1000000: return false
	if not value.get("radial") is bool or not value.get("reverse") is bool: return false
	var opacity: Variant = value.get("opacity")
	if not (opacity is float or opacity is int) or not is_finite(opacity) or opacity < 0 or opacity > 1: return false
	var stops: Variant = value.get("stops")
	if not stops is Array or stops.size() < 2 or stops.size() > 4096: return false
	var previous := -1.0
	for stop in stops:
		if not stop is Dictionary: return false
		var offset: Variant = stop.get("position")
		if not (offset is float or offset is int) or not is_finite(offset) or offset <= previous or offset < 0 or offset > 1: return false
		previous = offset
		if not stop.get("color") is Array or stop.color.size() != 4: return false
		for number in stop.color:
			if not (number is float or number is int) or not is_finite(number) or number < 0 or number > 1: return false
	return stops[0].position == 0 and stops[-1].position == 1

static func recipe_settings(value: Dictionary) -> Dictionary:
	var stops: Array = []
	for stop in value.stops:
		var c: Array = stop.color
		stops.append({"position": float(stop.position), "color": Color(c[0], c[1], c[2], c[3])})
	return {"stops": stops, "fg": stops[0].color, "bg": stops[-1].color, "transparent": false, "radial": value.radial, "reverse": value.reverse, "opacity": value.opacity, "alpha_lock": false}

static func render_recipe(value: Dictionary, size: Vector2i, mask: Image) -> Image:
	if not valid_recipe(value): return null
	var base := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	return render(base, Rect2i(Vector2i.ZERO, size), Vector2(value.start[0], value.start[1]), Vector2(value.end[0], value.end[1]), recipe_settings(value), mask)

static func render(base: Image, area: Rect2i, start: Vector2, end: Vector2, settings: Dictionary, mask: Image = null, mask_origin := Vector2i.ZERO, preview_limit := 0) -> Image:
	area = area.intersection(Rect2i(Vector2i.ZERO, base.get_size()))
	return blend(base, area, make_colors(area, start, end, settings, preview_limit), settings, mask, mask_origin)

static func make_ramp(settings: Dictionary) -> Gradient:
	var first: Color = settings.fg
	var last: Color = settings.bg
	if settings.transparent: last = Color(first.r, first.g, first.b, 0)
	var gradient := Gradient.new()
	var stops: Array = settings.get("stops", [])
	if stops.is_empty(): stops = [{"position": 0.0, "color": first}, {"position": 1.0, "color": last}]
	var colors := PackedColorArray()
	var offsets := PackedFloat32Array()
	for stop in stops:
		var color: Color = stop.color
		color.a *= float(settings.opacity)
		colors.append(color)
		offsets.append(float(stop.position))
	if settings.reverse:
		colors.reverse()
		offsets.reverse()
		for i in range(offsets.size()): offsets[i] = 1.0 - offsets[i]
	gradient.offsets = offsets
	gradient.colors = colors
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	return gradient

static func make_colors(area: Rect2i, start: Vector2, end: Vector2, settings: Dictionary, preview_limit := 0) -> Image:
	var delta := end - start
	if not area.has_area() or delta.length_squared() < 0.000001: return null
	var gradient := make_ramp(settings)
	var texture := GradientTexture2D.new()
	var dimensions := area.size
	if settings.radial: dimensions = Vector2i.ONE * maxi(dimensions.x, dimensions.y)
	texture.width = maxi(2, dimensions.x)
	texture.height = maxi(2, dimensions.y)
	var scale := Vector2(texture.width - 1, texture.height - 1)
	if preview_limit > 0 and maxi(texture.width, texture.height) > preview_limit:
		var ratio := float(preview_limit) / maxi(texture.width, texture.height)
		texture.width = maxi(2, roundi(texture.width * ratio))
		texture.height = maxi(2, roundi(texture.height * ratio))
	texture.fill_from = (start - Vector2(area.position)) / scale
	if settings.radial:
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_to = texture.fill_from + Vector2(delta.length() / scale.x, 0)
	else:
		# Correct normalized texture coordinates so non-square images keep the
		# same pixel-space projection and angle as square images.
		var weighted := delta * scale
		texture.fill_to = texture.fill_from + weighted * delta.length_squared() / weighted.length_squared()
	texture.gradient = gradient
	var colors := texture.get_image()
	colors.convert(Image.FORMAT_RGBA8)
	return colors

## Worker-safe: only private images/immutable inputs, no nodes or rendering calls.
static func blend(base: Image, area: Rect2i, colors: Image, settings: Dictionary, mask: Image = null, mask_origin := Vector2i.ZERO) -> Image:
	var result := base.duplicate()
	if not colors: return result
	var dimensions := area.size
	if settings.radial: dimensions = Vector2i.ONE * maxi(dimensions.x, dimensions.y)
	if colors.get_size() != Vector2i(maxi(2, dimensions.x), maxi(2, dimensions.y)):
		colors.resize(maxi(2, dimensions.x), maxi(2, dimensions.y), Image.INTERPOLATE_BILINEAR)
	var local := Rect2i(Vector2i.ZERO, area.size)
	var painted := base.get_region(area)
	if settings.alpha_lock:
		# Blend RGB against an opaque base, then restore original coverage.
		painted.convert(Image.FORMAT_RGB8)
		painted.convert(Image.FORMAT_RGBA8)
	painted.blend_rect(colors, local, Vector2i.ZERO)
	if settings.alpha_lock:
		var original := base.get_region(area).get_data()
		var bytes := painted.get_data()
		for i in range(0, bytes.size(), 4):
			bytes[i + 3] = original[i + 3]
			if original[i + 3] == 0:
				bytes[i] = original[i]
				bytes[i + 1] = original[i + 1]
				bytes[i + 2] = original[i + 2]
		painted.set_data(area.size.x, area.size.y, false, Image.FORMAT_RGBA8, bytes)
	if mask:
		var clipped_mask := mask.get_region(Rect2i(area.position - mask_origin, area.size))
		result.blit_rect_mask(painted, clipped_mask, local, area.position)
	else: result.blit_rect(painted, local, area.position)
	return result
