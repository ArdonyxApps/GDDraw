extends SceneTree
## Exercises an older storage helper and a fresh full dock. No addon files are
## rewritten; generated dependency copies live only under this test directory.

var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func write(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

func _run() -> void:
	var directory := "res://tests/.palette_startup_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var helper_path := directory + "/old_storage.gd"
	# This is the public constant used by the pre-palette storage helper. Keep
	# the script alive to exercise an already-loaded dependency without the new key.
	write(helper_path, "extends RefCounted\nconst PROJECT_ASSET_ROOT := \"res://gddraw\"\n")
	var helper: GDScript = load(helper_path)
	check(not helper.get_script_constant_map().has("PALETTE_COLLECTION_PATH"), "fixture retains an older storage helper")
	var source := FileAccess.get_file_as_string("res://addons/GDDraw/gddraw_palette_store.gd")
	source = source.replace("res://addons/GDDraw/gddraw_storage_paths.gd", helper_path)
	var store_path := directory + "/store.gd"
	write(store_path, source)
	var store_script: GDScript = load(store_path)
	check(store_script != null and store_script.can_instantiate(), "store compiles against older storage helper")
	if store_script and store_script.can_instantiate():
		var store = store_script.new()
		check(store.path == "res://gddraw/palettes/collection.json", "default constructor resolves canonical project palette path")
		var custom = store_script.new(directory + "/custom/collection.json")
		check(custom.path == directory + "/custom/collection.json", "explicit storage path remains supported")
		check(not DirAccess.dir_exists_absolute(directory + "/custom"), "startup does not create storage directories")
	var dock_script: GDScript = load("res://addons/GDDraw/gddraw_dock.gd")
	check(dock_script != null and dock_script.can_instantiate(), "full dock compiles")
	if dock_script and dock_script.can_instantiate():
		var dock = dock_script.new()
		root.add_child(dock)
		for i in range(6): await process_frame
		var host = dock._panel_host
		check(host.panels.has("layers") and host.panels.has("palettes"), "both panels register before restoration")
		check(not host.layout.is_empty(), "startup completes layout restoration")
		host.activate_panel("layers")
		check(host.is_panel_active("layers") and dock._layers_panel_content.is_visible_in_tree(), "Layers opens after startup")
		var palette_button: Button = host.panels.palettes.button
		check(palette_button.get_parent() == host.rail and palette_button.icon != null, "Palettes rail button is present with imported icon")
		host.activate_panel("palettes")
		check(host.is_panel_active("palettes") and dock._palette_panel.is_visible_in_tree(), "Palettes opens after startup")
		var commands: Dictionary = dock_script.get_script_constant_map().MenuCommand
		check(commands.has("VIEW_RESET_PANEL_LAYOUT"), "current dock exposes reset layout command")
		dock._on_menu_command(commands.VIEW_RESET_PANEL_LAYOUT)
		check(host.get_panel_groups().size() == 1, "reset command remains functional")
		dock.free()
	for i in range(4): await process_frame
	print("Palette startup: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
