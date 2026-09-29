@tool
extends RefCounted
## A project collection, independent of panel placement and drawing history.
signal changed

const Parser := preload("res://addons/GDDraw/gddraw_palette_parser.gd")
const Paths := preload("res://addons/GDDraw/gddraw_storage_paths.gd")
const DEFAULT_STORAGE_PATH := Paths.PROJECT_ASSET_ROOT + "/palettes/collection.json"
const BUNDLED_FOLDER := "res://addons/GDDraw/resources/palettes"
const VERSION := 1
const MAX_STORE_BYTES := 64 * 1024 * 1024
const MAX_PALETTES := 256

var path: String
var palettes: Array = []
var active_id := ""
var load_error := ""
var load_warning := ""
var hidden_bundled: Array = []
var _next_id := 1
var _disk_bytes := PackedByteArray()
var _disk_exists := false
var _swatch_history := {}

func _init(storage_path: String = DEFAULT_STORAGE_PATH) -> void:
	path = storage_path
	reload()

func reload() -> bool:
	load_error = ""
	load_warning = ""
	_disk_exists = FileAccess.file_exists(path)
	if not _disk_exists:
		palettes = []
		_swatch_history.clear()
		hidden_bundled = []
		active_id = ""
		_next_id = 1
		_disk_bytes = PackedByteArray()
		return true
	var file := FileAccess.open(path, FileAccess.READ)
	if not file or file.get_length() > MAX_STORE_BYTES:
		load_error = "Cannot read palette collection, or it exceeds 64 MiB. Existing data was preserved."
		return false
	var bytes := file.get_buffer(MAX_STORE_BYTES + 1)
	var content := bytes.get_string_from_utf8()
	var json := JSON.new()
	if bytes.size() > MAX_STORE_BYTES or bytes.size() != file.get_length() or content.to_utf8_buffer() != bytes or json.parse(content) != OK:
		load_error = "Invalid palette collection JSON. Existing data was preserved."
		return false
	var error := _validate(json.data)
	if not error.is_empty():
		load_error = error + " Existing data was preserved."
		return false
	_disk_bytes = bytes
	_swatch_history.clear()
	palettes = json.data.palettes
	hidden_bundled = json.data.get("hidden_bundled", [])
	active_id = json.data.active_id
	_next_id = int(json.data.next_id)
	if not active_id.is_empty() and get_palette(active_id).is_empty():
		load_warning = "The saved active palette is missing; showing the first palette."
		active_id = str(palettes[0].id) if not palettes.is_empty() else ""
	elif active_id.is_empty() and not palettes.is_empty():
		active_id = palettes[0].id
	return true

func get_palette(id: String) -> Dictionary:
	for palette in palettes:
		if palette.id == id: return palette
	return {}

func import_file(source: String) -> Dictionary:
	var result := Parser.parse_file(source)
	if not result.ok: return result
	result.palette["source"] = canonical_source(source)
	result.palette["source_hash"] = FileAccess.get_sha256(source)
	result.palette["saved_swatches"] = result.palette.swatches.duplicate(true)
	return import_candidate(result.palette)

func import_candidate(candidate: Dictionary) -> Dictionary:
	var next := palettes.duplicate(true)
	var palette := candidate.duplicate(true)
	palette["id"] = "palette_%d" % _next_id
	var base_name: String = palette.get("name", "")
	var names: Array = []
	for existing in next: names.append(existing.name)
	var suffix := 2
	while palette.get("name") in names:
		palette.name = "%s (%d)" % [base_name, suffix]
		suffix += 1
	next.append(palette)
	return _commit(next, palette.id, _next_id + 1)

func select_palette(id: String) -> Dictionary:
	if get_palette(id).is_empty(): return Parser.failure("Palette no longer exists.")
	if id == active_id: return {"ok": true}
	return _commit(palettes.duplicate(true), id, _next_id)

func remove_palette(id: String) -> Dictionary:
	var next := palettes.duplicate(true)
	var index := -1
	for i in range(next.size()):
		if next[i].id == id: index = i
	if index < 0: return Parser.failure("Palette no longer exists.")
	var next_hidden := hidden_bundled.duplicate()
	var bundled_key: String = next[index].get("bundled_key", "")
	if bundled_key.is_empty() and is_bundled(next[index]): bundled_key = str(next[index].get("source", "")).get_file().to_lower()
	if not bundled_key.is_empty() and bundled_key not in next_hidden: next_hidden.append(bundled_key)
	next.remove_at(index)
	var next_active := active_id
	if id == active_id:
		next_active = str(next[mini(index, next.size() - 1)].id) if not next.is_empty() else ""
	return _commit(next, next_active, _next_id, next_hidden)

static func is_bundled(palette: Dictionary) -> bool:
	return not str(palette.get("bundled_key", "")).is_empty() or canonical_source(str(palette.get("source", ""))).to_lower().begins_with(canonical_source(BUNDLED_FOLDER).to_lower() + "/")

func restore_bundled() -> Dictionary:
	if hidden_bundled.is_empty(): return {"ok": true}
	return _commit(palettes.duplicate(true), active_id, _next_id, [])

static func attribution_url_allowed(url: String) -> bool:
	if url.contains(" ") or url.contains("\n") or url.contains("\r") or url.contains("\t"): return false
	return (url.begins_with("https://") and url.trim_prefix("https://").get_slice("/", 0) != "") or (url.begins_with("http://") and url.trim_prefix("http://").get_slice("/", 0) != "")

static func _attribution_error(value: Variant) -> String:
	if not value is Dictionary: return "Attribution must be an object."
	if not value.get("author") is String or value.author.strip_edges().is_empty() or value.author.length() > 256: return "Attribution requires an author (maximum 256 characters)."
	for key in ["url", "license"]:
		if value.has(key) and (not value[key] is String or value[key].length() > 2048): return "Invalid attribution " + key + "."
	if not value.get("url", "").is_empty() and not attribution_url_allowed(value.url): return "Attribution links must use HTTP or HTTPS."
	return ""

static func _read_attributions(folder: String) -> Dictionary:
	var source := folder.path_join("attribution.json")
	if not FileAccess.file_exists(source): return {"ok": true, "palettes": {}}
	var file := FileAccess.open(source, FileAccess.READ)
	if not file or file.get_length() > 1024 * 1024: return Parser.failure("Cannot read attribution.json, or it exceeds 1 MiB.")
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return Parser.failure("Invalid attribution.json: " + json.get_error_message())
	if not json.data is Dictionary or json.data.get("version") != 1 or not json.data.get("palettes") is Dictionary: return Parser.failure("attribution.json requires version 1 and a palettes object.")
	for filename in json.data.palettes:
		if not filename is String or filename.get_file() != filename or filename.get_extension().to_lower() != "hex": return Parser.failure("Attribution keys must be HEX filenames, including the extension.")
		var error := _attribution_error(json.data.palettes[filename])
		if not error.is_empty(): return Parser.failure("attribution.json, " + filename + ": " + error)
	return {"ok": true, "palettes": json.data.palettes}

func _validate(data: Variant) -> String:
	if not data is Dictionary or data.get("version") != VERSION: return "Unsupported palette collection version."
	if not data.get("palettes") is Array or data.palettes.size() > MAX_PALETTES: return "Invalid palette collection (maximum 256 palettes)."
	if not data.get("active_id") is String: return "Invalid active palette ID."
	if data.has("hidden_bundled"):
		if not data.hidden_bundled is Array or data.hidden_bundled.size() > MAX_PALETTES * 16: return "Invalid hidden bundled palettes."
		for key in data.hidden_bundled:
			if not key is String or key.is_empty() or key.length() > 256: return "Invalid hidden bundled palette identity."
	var serial: Variant = data.get("next_id")
	if not (serial is int or serial is float) or not is_finite(float(serial)) or serial < 1 or serial > 2147483647 or float(serial) != floor(float(serial)): return "Invalid palette ID counter."
	var ids := {}
	var names := {}
	var color_pattern := RegEx.new()
	color_pattern.compile("^[0-9a-fA-F]{8}$")
	for palette in data.palettes:
		if not palette is Dictionary: return "Invalid palette record."
		var id: Variant = palette.get("id")
		if not id is String or not id.begins_with("palette_") or not id.trim_prefix("palette_").is_valid_int(): return "Missing or invalid palette ID."
		var number: int = id.trim_prefix("palette_").to_int()
		if number < 1 or number >= serial or id != "palette_%d" % number or ids.has(id): return "Duplicate or invalid palette ID."
		ids[id] = true
		if not palette.get("name") is String or palette.name.strip_edges().is_empty() or names.has(palette.name): return "Invalid or duplicate palette name."
		names[palette.name] = true
		if not palette.get("swatches") is Array or palette.swatches.size() > Parser.MAX_SWATCHES: return "Invalid palette swatch count."
		for swatch in palette.swatches:
			if not swatch is Dictionary or not swatch.get("color") is String or not color_pattern.search(swatch.color) or not swatch.get("name") is String: return "Invalid stored swatch."
		for key in ["source", "source_hash", "native_id", "bundled_key"]:
			if palette.has(key) and not palette[key] is String: return "Invalid palette source metadata."
		if palette.has("attribution"):
			var error := _attribution_error(palette.attribution)
			if not error.is_empty(): return error
		for key in ["dirty", "unsaved", "attribution_derived"]:
			if palette.has(key) and not palette[key] is bool: return "Invalid palette draft metadata."
		if palette.has("import_sources"):
			if not palette.import_sources is Dictionary: return "Invalid import sources."
			for source in palette.import_sources:
				if not source is String or not palette.import_sources[source] is String: return "Invalid import sources."
		if palette.has("saved_swatches"):
			if not palette.saved_swatches is Array or palette.saved_swatches.size() > Parser.MAX_SWATCHES: return "Invalid palette draft snapshot."
			for swatch in palette.saved_swatches:
				if not swatch is Dictionary or not swatch.get("color") is String or not color_pattern.search(swatch.color) or not swatch.get("name") is String: return "Invalid palette draft snapshot."
	return ""

func _commit(next: Array, selected: String, serial: int, next_hidden: Variant = null, keep_history := false) -> Dictionary:
	if not load_error.is_empty(): return Parser.failure(load_error + " Repair or move the collection file before reopening GDDraw.")
	var data := {"version": VERSION, "palettes": next, "active_id": selected, "next_id": serial, "hidden_bundled": hidden_bundled if next_hidden == null else next_hidden}
	var error := _validate(data)
	if not error.is_empty(): return Parser.failure(error)
	var bytes := JSON.stringify(data).to_utf8_buffer()
	if bytes.size() > MAX_STORE_BYTES: return Parser.failure("Palette collection exceeds 64 MiB.")
	# Detect an external editor or another model before replacing its work.
	if FileAccess.file_exists(path) != _disk_exists: return Parser.failure("Palette collection changed on disk; reopen GDDraw before editing palettes.")
	if _disk_exists:
		var current := FileAccess.open(path, FileAccess.READ)
		if not current or current.get_length() != _disk_bytes.size() or current.get_buffer(_disk_bytes.size() + 1) != _disk_bytes:
			return Parser.failure("Palette collection changed on disk or cannot be read; reopen GDDraw before editing palettes.")
		current.close()
	var result := _write_transaction(bytes)
	if not result.ok: return result
	for id in _swatch_history.keys():
		var retained := false
		for record in next:
			if record.id == id:
				retained = keep_history or record.swatches == get_palette(id).get("swatches", [])
		if not retained: _swatch_history.erase(id)
	palettes = next
	hidden_bundled = data.hidden_bundled.duplicate()
	active_id = selected
	_next_id = serial
	_disk_bytes = bytes
	_disk_exists = true
	changed.emit()
	return {"ok": true}

func _write_transaction(bytes: PackedByteArray) -> Dictionary:
	var destination := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK: return Parser.failure("Cannot create palette storage directory.")
	var temporary := destination + ".pending-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file: return Parser.failure("Cannot write palette collection.")
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_bytes(temporary) != bytes:
		DirAccess.remove_absolute(temporary)
		return Parser.failure("Could not verify palette collection write.")
	# Same-directory rename replaces the destination atomically. Never remove the
	# previous file first; unsupported/failed replacement leaves both model and disk old.
	if _replace_file(temporary, destination) != OK:
		DirAccess.remove_absolute(temporary)
		return Parser.failure("Could not replace palette collection; previous collection preserved.")
	return {"ok": true}

func _replace_file(temporary: String, destination: String) -> Error:
	return DirAccess.rename_absolute(temporary, destination)

static func canonical_source(source: String) -> String:
	return ProjectSettings.globalize_path(source).replace("\\", "/").simplify_path()

func new_palette(palette_name: String) -> Dictionary:
	return import_candidate({"name": palette_name.strip_edges(), "swatches": [], "dirty": true, "unsaved": true})

func edit_swatch(index: int, color: Color, swatch_name := "", remove := false) -> Dictionary:
	var current := get_palette(active_id)
	if current.is_empty(): return Parser.failure("No palette selected.")
	var before: Array = current.swatches.duplicate(true)
	var next := palettes.duplicate(true)
	for palette in next:
		if palette.id != active_id: continue
		if index < 0 or index > palette.swatches.size(): return Parser.failure("Color no longer exists.")
		if not palette.has("saved_swatches"): palette["saved_swatches"] = palette.swatches.duplicate(true)
		if remove:
			if index >= palette.swatches.size(): return Parser.failure("Color no longer exists.")
			palette.swatches.remove_at(index)
		elif index == palette.swatches.size(): palette.swatches.append({"color": color.to_html(true), "name": swatch_name})
		else: palette.swatches[index] = {"color": color.to_html(true), "name": swatch_name}
		if palette.swatches == before: return {"ok": true}
		palette["dirty"] = palette.get("unsaved", false) or palette.swatches != palette.saved_swatches
	var result := _commit(next, active_id, _next_id, null, true)
	if result.ok:
		var history: Dictionary = _swatch_history.get(active_id, {"undo": [], "redo": []})
		history.undo.append(before)
		history.redo.clear()
		_swatch_history[active_id] = history
		_trim_swatch_history()
		changed.emit()
	return result

func can_undo_swatches() -> bool:
	return not _swatch_history.get(active_id, {}).get("undo", []).is_empty()

func can_redo_swatches() -> bool:
	return not _swatch_history.get(active_id, {}).get("redo", []).is_empty()

func undo_swatches() -> Dictionary:
	return _restore_swatch_history("undo", "redo")

func redo_swatches() -> Dictionary:
	return _restore_swatch_history("redo", "undo")

func _restore_swatch_history(from: String, to: String) -> Dictionary:
	var history: Dictionary = _swatch_history.get(active_id, {})
	if history.get(from, []).is_empty(): return {"ok": true}
	var before: Array = get_palette(active_id).swatches.duplicate(true)
	var next := palettes.duplicate(true)
	for palette in next:
		if palette.id == active_id:
			palette.swatches = history[from].back().duplicate(true)
			palette["dirty"] = palette.get("unsaved", false) or palette.swatches != palette.get("saved_swatches", [])
	var result := _commit(next, active_id, _next_id, null, true)
	if result.ok:
		history[from].pop_back()
		history[to].append(before)
		_trim_swatch_history()
		changed.emit()
	return result

func _trim_swatch_history() -> void:
	# Session-only history: bound both snapshot count and total memory payload.
	var count := 0
	for history in _swatch_history.values(): count += history.undo.size() + history.redo.size()
	while count > 64 or JSON.stringify(_swatch_history).to_utf8_buffer().size() > 8 * 1024 * 1024:
		var id: String = _swatch_history.keys()[0]
		var history: Dictionary = _swatch_history[id]
		if not history.undo.is_empty(): history.undo.pop_front()
		elif not history.redo.is_empty(): history.redo.pop_front()
		else:
			_swatch_history.erase(id)
			continue
		count -= 1

func discard_changes() -> Dictionary:
	var current := get_palette(active_id)
	if current.get("unsaved", false): return remove_palette(active_id)
	var next := palettes.duplicate(true)
	for palette in next:
		if palette.id == active_id:
			palette.swatches = palette.get("saved_swatches", palette.swatches).duplicate(true)
			palette["dirty"] = false
	var result := _commit(next, active_id, _next_id)
	if result.ok:
		_swatch_history.erase(active_id)
		changed.emit()
	return result

static func filename_for(palette_name: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("[^a-z0-9_-]+")
	var stem := pattern.sub(palette_name.to_lower(), "-", true).strip_edges().trim_prefix("-").trim_suffix("-").left(100)
	if stem.is_empty(): stem = "palette"
	# Prefix avoids Windows device filenames such as CON and AUX.
	if stem.to_upper() in ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]: stem = "palette-" + stem
	return stem + ".hex"

static func hex_bytes(swatches: Array, rgba := true) -> PackedByteArray:
	var lines := PackedStringArray()
	for swatch in swatches: lines.append(str(swatch.color).to_upper() if rgba else str(swatch.color).left(6).to_upper())
	return ("\n".join(lines) + "\n").to_utf8_buffer()

func export_hex(destination: String, rgba := true, overwrite := false) -> Dictionary:
	var current := get_palette(active_id)
	if current.is_empty() or current.swatches.is_empty(): return Parser.failure("Add at least one color before exporting.")
	if destination.get_extension().to_lower() != "hex": return Parser.failure("Export using the .hex extension.")
	var target := canonical_source(destination)
	var localized := ProjectSettings.localize_path(target).to_lower()
	if localized.begins_with("res://addons/gddraw/"): return Parser.failure("Export palettes outside addons/GDDraw.")
	for palette in palettes:
		if palette.get("source", "") == target or palette.get("import_sources", {}).has(target): return Parser.failure("Choose a separate export file. Use Save Changes to update a palette source.")
	if FileAccess.file_exists(target) and not overwrite: return Parser.failure("Export file already exists; confirm replacement first.")
	var collection_path := path
	path = destination
	var result := _write_transaction(hex_bytes(current.swatches, rgba))
	path = collection_path
	return result

func save_palette(destination: String, palette_name: String, as_new := false, overwrite := false) -> Dictionary:
	if not load_error.is_empty(): return Parser.failure(load_error)
	if destination.get_extension().to_lower() != "hex": return Parser.failure("Save using the .hex extension.")
	var current := get_palette(active_id)
	if current.is_empty(): return Parser.failure("No palette selected.")
	var bundled := is_bundled(current)
	if bundled: as_new = true
	if as_new and palettes.size() >= MAX_PALETTES: return Parser.failure("Maximum 256 palettes reached.")
	if current.swatches.is_empty(): return Parser.failure("Add at least one color before saving. Your empty draft is retained.")
	palette_name = palette_name.strip_edges()
	if palette_name.is_empty(): return Parser.failure("Enter a palette name.")
	for other in palettes:
		if other.name == palette_name and (as_new or other.id != active_id): return Parser.failure("A palette already uses that name.")
	var target := canonical_source(destination)
	var localized := ProjectSettings.localize_path(target).to_lower()
	if localized == "res://addons/gddraw" or localized.begins_with("res://addons/gddraw/"): return Parser.failure("Save palettes outside addons/GDDraw.")
	var same_source: bool = target == current.get("source", "")
	if as_new and same_source: return Parser.failure("Choose a different filename for a new palette.")
	for other in palettes:
		if other.id != active_id and other.get("source", "") == target: return Parser.failure("This file belongs to another palette in the collection. Select that palette to overwrite it, or choose a different name.")
	if FileAccess.file_exists(target):
		if not same_source and not overwrite: return {"ok": false, "needs_confirmation": true, "error": "Replace existing palette file?"}
		if same_source and FileAccess.get_sha256(target) != current.get("source_hash", ""): return Parser.failure("Palette changed on disk. Save as a new palette to preserve both versions.")
	var bytes := hex_bytes(current.swatches)
	if bytes.size() > Parser.MAX_FILE_BYTES: return Parser.failure("HEX palette exceeds 1 MiB.")
	if FileAccess.file_exists(path) != _disk_exists: return Parser.failure("Palette collection changed on disk; reopen GDDraw before saving.")
	if _disk_exists:
		var disk := FileAccess.open(path, FileAccess.READ)
		if not disk or disk.get_length() != _disk_bytes.size() or disk.get_buffer(_disk_bytes.size() + 1) != _disk_bytes: return Parser.failure("Palette collection changed on disk; reopen GDDraw before saving.")
		disk.close()
	var next := palettes.duplicate(true)
	var saved := current.duplicate(true)
	if not as_new and not same_source and current.has("source"):
		var imports: Dictionary = saved.get("import_sources", {})
		imports[current.source] = current.get("source_hash", "")
		saved["import_sources"] = imports
	elif as_new:
		saved.erase("import_sources")
	saved.erase("native_id")
	saved.erase("bundled_key")
	if saved.has("attribution") and (as_new or bundled): saved["attribution_derived"] = true
	saved.merge({"name": palette_name, "source": target, "source_hash": "", "dirty": false, "unsaved": false, "saved_swatches": current.swatches.duplicate(true)}, true)
	var serial := _next_id
	if as_new:
		saved.id = "palette_%d" % serial
		serial += 1
		next.append(saved)
		if bundled:
			# The edited colors now belong to the user copy; retain the starter
			# palette's original colors instead of leaving a second dirty draft.
			for palette in next:
				if palette.id == active_id:
					palette.swatches = palette.get("saved_swatches", palette.swatches).duplicate(true)
					palette["dirty"] = false
	else:
		for i in range(next.size()):
			if next[i].id == active_id: next[i] = saved
	var prospective := {"version": VERSION, "palettes": next, "active_id": saved.id, "next_id": serial}
	var validation := _validate(prospective)
	if not validation.is_empty(): return Parser.failure(validation)
	if JSON.stringify(prospective).to_utf8_buffer().size() + 64 > MAX_STORE_BYTES: return Parser.failure("Palette collection exceeds 64 MiB.")
	# Never clear the draft until both the HEX file and collection writes succeed.
	var collection_path := path
	path = destination
	var written := _write_transaction(bytes)
	path = collection_path
	if not written.ok: return written
	saved.source_hash = FileAccess.get_sha256(target)
	var result := _commit(next, saved.id, serial)
	if not result.ok: result.error = "HEX file saved to %s, but the collection could not be updated. Your draft is retained.\n%s" % [destination, result.error]
	return result

func scan_folder(folder: String, bundled := false) -> Dictionary:
	var warnings: Array[String] = []
	var selected := active_id
	if not DirAccess.dir_exists_absolute(folder): return {"ok": true, "warnings": warnings}
	var credits := _read_attributions(folder) if bundled else {"ok": true, "palettes": {}}
	if not credits.ok: warnings.append(credits.error + " Existing credits were preserved.")
	var files := DirAccess.get_files_at(folder)
	files.sort()
	for filename in files:
		if bundled and filename.get_extension().to_lower() != "hex": continue
		if filename.get_extension().to_lower() not in ["gddrawpalette", "gpl", "hex", "txt"]: continue
		var bundled_key := filename.to_lower() if bundled else ""
		if bundled and bundled_key in hidden_bundled: continue
		var source := folder.path_join(filename)
		var parsed := Parser.parse_file(source)
		if not parsed.ok:
			warnings.append(filename + ": " + parsed.error)
			continue
		var canonical := canonical_source(source)
		var digest := FileAccess.get_sha256(source)
		var existing := {}
		var converted_source := false
		for palette in palettes:
			if palette.get("import_sources", {}).has(canonical):
				converted_source = true
				if palette.import_sources[canonical] != digest: warnings.append(filename + ": original import changed; the saved palette was kept. Import manually to create a separate copy.")
			if (bundled and palette.get("bundled_key", "") == bundled_key) or palette.get("source", "") == canonical or (parsed.palette.has("native_id") and palette.get("native_id", "") == parsed.palette.native_id): existing = palette
		if converted_source and existing.is_empty(): continue
		# Credit-only changes apply even to dirty drafts, without touching colors.
		if bundled and credits.ok and not existing.is_empty():
			var attribution: Dictionary = credits.palettes.get(filename, {})
			if existing.get("attribution", {}) != attribution:
				var updated := palettes.duplicate(true)
				for record in updated:
					if record.id == existing.id:
						record.erase("attribution")
						if not attribution.is_empty(): record["attribution"] = attribution.duplicate(true)
				var credited := _commit(updated, active_id, _next_id)
				if not credited.ok:
					warnings.append(credited.error)
					continue
				existing = get_palette(existing.id)
		if not existing.is_empty() and existing.get("source_hash", "") == digest and existing.get("source", "") == canonical and (not bundled or existing.get("bundled_key", "") == bundled_key): continue
		if not existing.is_empty() and existing.get("dirty", false):
			warnings.append(filename + ": external changes skipped because this palette has unsaved edits.")
			continue
		var candidate: Dictionary = parsed.palette
		if existing.has("attribution"): candidate["attribution"] = existing.attribution.duplicate(true)
		if existing.has("attribution_derived"): candidate["attribution_derived"] = existing.attribution_derived
		if bundled and credits.ok and credits.palettes.has(filename): candidate["attribution"] = credits.palettes[filename].duplicate(true)
		if not existing.is_empty() and filename.get_extension().to_lower() in ["hex", "txt"]:
			# HEX has no names; preserve local labels for unchanged swatches.
			for i in range(mini(candidate.swatches.size(), existing.swatches.size())):
				if candidate.swatches[i].color == existing.swatches[i].color: candidate.swatches[i].name = existing.swatches[i].name
		candidate.merge({"source": canonical, "source_hash": digest, "saved_swatches": candidate.swatches.duplicate(true)}, true)
		if bundled: candidate["bundled_key"] = bundled_key
		elif existing.has("bundled_key"): candidate["bundled_key"] = existing.bundled_key
		var result: Dictionary
		if existing.is_empty(): result = import_candidate(candidate)
		else:
			var next := palettes.duplicate(true)
			candidate["id"] = existing.id
			if existing.has("import_sources"): candidate["import_sources"] = existing.import_sources.duplicate()
			# Keep the collection's unique display name on source updates.
			candidate.name = existing.name
			for i in range(next.size()):
				if next[i].id == existing.id: next[i] = candidate
			result = _commit(next, active_id, _next_id)
		if not result.ok: warnings.append(filename + ": " + result.error)
	if not selected.is_empty() and active_id != selected:
		var restored := select_palette(selected)
		if not restored.ok: warnings.append(restored.error)
	return {"ok": true, "warnings": warnings}
