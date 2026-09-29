@tool
extends RefCounted

static func render(recipe: Dictionary, size: Vector2i, mask: Image = null) -> Image:
	# Reuse the canvas text engine for document scaling, including its glyph
	# coverage and rotation rules. This temporary canvas never enters the tree.
	var renderer: Control = load("res://addons/GDDraw/gddraw_canvas.gd").new()
	renderer.set_image(Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8))
	renderer.load_text_layer(recipe, Vector2i.ZERO, mask)
	var pixels: Image = renderer._get_text_layer_payload().image
	renderer.free()
	return pixels

static func equivalent(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for key in a:
		if not b.has(key): return false
		if a[key] is Array:
			if not b[key] is Array or a[key].size() != b[key].size(): return false
			for i in range(a[key].size()):
				if not is_equal_approx(float(a[key][i]), float(b[key][i])): return false
		elif a[key] is float or a[key] is int:
			if not is_equal_approx(float(a[key]), float(b[key])): return false
		elif a[key] != b[key]: return false
	return true

# Font bytes are embedded separately in layered documents; no external font path
# is loaded when opening a document.
static func valid_recipe(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not value.get("text") is String or value.text.length() > 1000000: return false
	for key in ["box", "color", "background"]:
		var numbers: Variant = value.get(key)
		if not numbers is Array or numbers.size() != 4: return false
		for number in numbers:
			if not (number is float or number is int) or not is_finite(float(number)): return false
	if value.box[2] < 1 or value.box[3] < 1 or value.box[2] > 16384 or value.box[3] > 16384: return false
	if not value.get("font_data", "") is String: return false
	if value.get("font_data", "").length() > 48 * 1024 * 1024: return false
	for key in ["font_size", "rotation", "alignment", "wrapping", "fill"]:
		if not (value.get(key) is float or value.get(key) is int) or not is_finite(float(value[key])): return false
	return value.font_size >= 1 and value.font_size <= 512 and int(value.alignment) in [0, 1, 2] and int(value.wrapping) in [0, 1] and int(value.fill) in [0, 1]
