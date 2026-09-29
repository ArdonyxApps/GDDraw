@tool
extends RefCounted
## Strict, bounded import. No filesystem writes or drawing state.

const MAX_FILE_BYTES := 1024 * 1024
const MAX_SWATCHES := 4096

static func failure(message: String, line := 0) -> Dictionary:
	return {"ok": false, "error": ("Line %d: " % line if line else "") + message}

static func parse_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return failure("Cannot open palette: %s." % error_string(FileAccess.get_open_error()))
	if file.get_length() > MAX_FILE_BYTES: return failure("Palette exceeds 1 MiB.")
	var bytes := file.get_buffer(MAX_FILE_BYTES + 1)
	if bytes.size() > MAX_FILE_BYTES: return failure("Palette exceeds 1 MiB.")
	if bytes.size() != file.get_length(): return failure("Could not read the complete palette file.")
	if bytes.slice(0, 3) == PackedByteArray([0xef, 0xbb, 0xbf]): bytes = bytes.slice(3)
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes: return failure("Palette must contain valid UTF-8 text.")
	return parse_text(text, path)

static func parse_text(text: String, path: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES: return failure("Palette exceeds 1 MiB.")
	var extension := path.get_extension().to_lower()
	if extension == "gddrawpalette": return parse_native(text)
	if extension not in ["gpl", "hex", "txt"]: return failure("Use a .gpl, .hex, or .txt palette.")
	text = text.trim_prefix(String.chr(0xfeff))
	var lines := text.split("\n")
	var palette_name := path.get_file().get_basename()
	var swatches: Array = []
	var hex := RegEx.new()
	hex.compile("^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$")
	var rgb := RegEx.new()
	rgb.compile("^(\\+?[0-9]+)[ \\t]+(\\+?[0-9]+)[ \\t]+(\\+?[0-9]+)(?:[ \\t]+(.*))?$")
	var metadata := {}
	if extension == "gpl" and lines[0].strip_edges() != "GIMP Palette":
		return failure("Expected GIMP Palette header.", 1)
	for index in range(1 if extension == "gpl" else 0, lines.size()):
		var line := lines[index].strip_edges()
		if line.is_empty(): continue
		if extension == "gpl":
			if line.begins_with("#"): continue
			if line.begins_with("Name:") or line.begins_with("Columns:"):
				var key := line.get_slice(":", 0)
				if not swatches.is_empty() or metadata.has(key): return failure("Misplaced or duplicate metadata.", index + 1)
				metadata[key] = true
				var value := line.substr(key.length() + 1).strip_edges()
				if key == "Name":
					if value.is_empty(): return failure("Palette name is empty.", index + 1)
					palette_name = value
				else:
					if not value.is_valid_int() or value.to_int() < 0 or value.to_int() > 255:
						return failure("Columns must be an integer from 0 to 255.", index + 1)
				continue
			if swatches.size() >= MAX_SWATCHES: return failure("Palette exceeds 4,096 swatches.", index + 1)
			var match_rgb := rgb.search(line)
			if not match_rgb: return failure("Expected three integer RGB channels and an optional name.", index + 1)
			var channels: Array[int] = []
			for channel in range(1, 4):
				var token := match_rgb.get_string(channel).trim_prefix("+").lstrip("0")
				if token.length() > 3 or token.to_int() > 255: return failure("RGB channels must be from 0 to 255.", index + 1)
				channels.append(token.to_int())
			swatches.append({"color": Color8(channels[0], channels[1], channels[2]).to_html(true), "name": match_rgb.get_string(4).strip_edges()})
		else:
			if line.begins_with(";") or line.begins_with("//"): continue
			if swatches.size() >= MAX_SWATCHES: return failure("Palette exceeds 4,096 swatches.", index + 1)
			if not hex.search(line): return failure("Expected exactly 6 or 8 hexadecimal digits (RRGGBB or RRGGBBAA), optionally prefixed with #.", index + 1)
			swatches.append({"color": Color("#" + line.trim_prefix("#")).to_html(true), "name": ""})
	if swatches.is_empty(): return failure("Palette contains no colors.")
	return {"ok": true, "palette": {"name": palette_name, "swatches": swatches}}

static func parse_native(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text.trim_prefix(String.chr(0xfeff))) != OK: return failure("Invalid native palette JSON.")
	var data: Variant = json.data
	if not data is Dictionary or data.get("version") != 1: return failure("Unsupported native palette version.")
	if not data.get("id") is String or data.id.is_empty(): return failure("Missing palette ID.")
	if not data.get("name") is String or data.name.strip_edges().is_empty(): return failure("Missing palette name.")
	if not data.get("swatches") is Array or data.swatches.size() > MAX_SWATCHES: return failure("Invalid native swatch count.")
	var pattern := RegEx.new()
	pattern.compile("^#[0-9a-fA-F]{8}$")
	var colors: Array = []
	for swatch in data.swatches:
		if not swatch is Dictionary or not swatch.get("color") is String or not pattern.search(swatch.color) or not swatch.get("name", "") is String: return failure("Invalid native swatch.")
		colors.append({"color": swatch.color.trim_prefix("#").to_lower(), "name": swatch.get("name", "")})
	return {"ok": true, "palette": {"name": data.name, "native_id": data.id, "swatches": colors}}
