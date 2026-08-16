@tool
extends VBoxContainer

class MeshDropHost:
	extends Control

	signal mesh_data_dropped(data: Variant)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return _might_contain_mesh(data)

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		mesh_data_dropped.emit(data)

	func _might_contain_mesh(data: Variant) -> bool:
		if data is Mesh or data is MeshInstance3D or data is CSGShape3D:
			return true
		if data is String:
			return data.strip_edges().begins_with("res://")
		if data is Dictionary:
			for key in ["nodes", "resource", "resource_path", "mesh", "files", "paths"]:
				if data.has(key):
					return true
		if data is Array:
			for item in data:
				if _might_contain_mesh(item):
					return true
		return false


class MeshDropViewport:
	extends SubViewportContainer

	signal mesh_data_dropped(data: Variant)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return _might_contain_mesh(data)

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		mesh_data_dropped.emit(data)

	func _might_contain_mesh(data: Variant) -> bool:
		if data is Mesh or data is MeshInstance3D or data is CSGShape3D:
			return true
		if data is String:
			return data.strip_edges().begins_with("res://")
		if data is Dictionary:
			for key in ["nodes", "resource", "resource_path", "mesh", "files", "paths"]:
				if data.has(key):
					return true
		if data is Array:
			for item in data:
				if _might_contain_mesh(item):
					return true
		return false


class ImageDropTarget:
	extends PanelContainer

	signal image_data_dropped(data: Variant)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return _might_contain_image(data)

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		image_data_dropped.emit(data)

	func _might_contain_image(data: Variant) -> bool:
		if data is Texture2D:
			return true
		if data is String:
			return data.strip_edges().get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"]
		if data is Resource:
			return data.resource_path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"]
		if data is PackedStringArray or data is Array:
			for item in data:
				if _might_contain_image(item):
					return true
		if data is Dictionary:
			for key in ["files", "paths", "path", "file", "resource_path", "resource", "nodes"]:
				if data.has(key) and _might_contain_image(data[key]):
					return true
		return false


const ICON_DIR := "res://addons/GDDraw/icons"
enum IconState { NORMAL, SELECTED, DISABLED }
const ICON_REFRESH_MAX_ATTEMPTS := 180
const ICON_REFRESH_RETRY_DELAY := 1.0
const ICON_REFRESH_MAX_DURATION_MSEC := 180000
const CANVAS_SCRIPT_PATH := "res://addons/GDDraw/gddraw_canvas.gd"
const HISTORY_SCRIPT_PATH := "res://addons/GDDraw/gddraw_history.gd"
const PNG_IO_SCRIPT_PATH := "res://addons/GDDraw/gddraw_png_io.gd"
const SHORTCUTS_SCRIPT_PATH := "res://addons/GDDraw/gddraw_shortcuts.gd"
const TEXTURE_3D_SESSION_SCRIPT_PATH := "res://addons/GDDraw/gddraw_3d_texture_session.gd"
const MESH_PAINT_CACHE_SCRIPT_PATH := "res://addons/GDDraw/gddraw_mesh_paint_cache.gd"
const SPRITE_CREATOR_SCRIPT_PATH := "res://addons/GDDraw/editor_integration/gddraw_sprite_creator.gd"
const UPDATE_CHECKER_SCRIPT_PATH := "res://addons/GDDraw/gddraw_update_checker.gd"
const UPDATER_SCRIPT_PATH := "res://addons/GDDraw/gddraw_updater.gd"
const GDDrawUpdater := preload("res://addons/GDDraw/gddraw_updater.gd")
const PLUGIN_SCRIPT_PATH := "res://addons/GDDraw/GDDraw.gd"
const StoragePaths := preload("res://addons/GDDraw/gddraw_storage_paths.gd")
const TOOL_BUTTON_SIZE := Vector2(28, 28)
const TOOL_ICON_MAX_WIDTH := 18
const COMPACT_ROTATION_BUTTON_SIZE := Vector2(20, 14)
const COMPACT_ROTATION_ICON_MAX_WIDTH := 12
const TOOLBAR_SEPARATION := 2
const TOOL_BUTTON_PANEL_COLOR := Color("#292929")
const TOOL_BUTTON_HOVER_COLOR := Color("#383838")
const TOOL_BUTTON_SELECTED_COLOR := Color("#424242")
const TOOL_BUTTON_SELECTED_HOVER_COLOR := Color("#424242")
const ICON_AUTHORED_COLOR := Color.WHITE
const ICON_DISABLED_FALLBACK_COLOR := Color(1.0, 1.0, 1.0, 0.4)
const TOOL_BUTTON_CORNER_RADIUS := 4
const DESTRUCTIVE_BUTTON_COLOR := Color("#B8323C")
const DESTRUCTIVE_BUTTON_HOVER_COLOR := Color("#D04751")
const DESTRUCTIVE_BUTTON_PRESSED_COLOR := Color("#8F222B")
const RECENT_COLOR_LIMIT := 10
const EMPTY_RECENT_SWATCH_COLOR := Color("#D6D8DA")
const PAINT_3D_BACKGROUND_COLOR := Color("#383C42")
const PAINT_3D_STAGE_MIN_SIZE := 8.0
const PAINT_3D_STAGE_PADDING := 1.8
const PAINT_3D_STAGE_GRID_LINES := 8
const PAINT_3D_STAGE_GRID_EXTENT_MULTIPLIER := 6
const PAINT_3D_TRANSFORM_POLL_INTERVAL := 0.05
const PAINT_3D_PREVIEW_LOD_BIAS := 128.0
const PAINT_3D_BRUSH_PREVIEW_SEGMENTS := 48
const PAINT_3D_PREVIEW_LIGHT_MIN := 0.0
const PAINT_3D_PREVIEW_LIGHT_MAX := 4.0
const PAINT_3D_PREVIEW_LIGHT_DEFAULT := 1.35
const PAINT_3D_PREVIEW_AMBIENT_ENERGY := 0.35
const PAINT_3D_PREVIEW_LIGHT_DEFAULT_ROTATION := Vector3(-45.0, 35.0, 0.0)
const PAINT_3D_GIZMO_RADIUS_PIXELS := 72.0
const PAINT_3D_GIZMO_HIT_PIXELS := 9.0
const PAINT_3D_GIZMO_SEGMENTS := 64
const PAINT_3D_GIZMO_RING_WIDTH_PIXELS := 2.6
const PAINT_3D_GIZMO_ARROW_LENGTH := 1.35
const PAINT_3D_GIZMO_ARROW_SHAFT_START := 0.16
const PAINT_3D_GIZMO_ARROW_HEAD_START := 1.08
const PAINT_3D_GIZMO_ARROW_SHAFT_RADIUS := 0.024
const PAINT_3D_GIZMO_ARROW_HEAD_RADIUS := 0.085
const PAINT_3D_GIZMO_ARROW_SIDES := 8
const PAINT_3D_GIZMO_SNAP_RADIANS := PI / 12.0
const GIZMO_CONTROL_NONE := 0
const GIZMO_CONTROL_ROTATION := 1
const GIZMO_CONTROL_TRANSLATION := 2
const PAINT_3D_GIZMO_AXIS_COLORS := [
	Color(0.96, 0.22, 0.22, 0.64),
	Color(0.25, 0.9, 0.35, 0.64),
	Color(0.25, 0.48, 1.0, 0.64),
]
const PAINT_3D_BLOCK_SHARED_UV_PAINT := false
const SHOW_2D_TO_3D_HOVER_MARKER := true
const DEBUG_2D_TO_3D_HOVER_DIAGNOSTICS := false
const DEBUG_MESH_PAINT_PERFORMANCE := false
const HOVER_2D_TO_3D_MARKER_COLOR := Color(0.35, 0.75, 1.0, 0.92)
const PAINT_3D_INITIAL_YAW := PI * 0.5
const PAINT_3D_INITIAL_PITCH := 0.35
const SETTINGS_SECTION := "GDDraw"
const DEFAULT_CANVAS_SIZE_KEY := "default_canvas_size"
const DEFAULT_FONT_DIRECTORY_KEY := "default_font_directory"
const CHECKER_LIGHT_KEY := "checker_light"
const CHECKER_DARK_KEY := "checker_dark"
const DEFAULT_CHECKER_LIGHT_COLOR := Color(0.68, 0.68, 0.68, 1.0)
const DEFAULT_CHECKER_DARK_COLOR := Color(0.48, 0.48, 0.48, 1.0)
const CUSTOM_BRUSH_PRESETS_KEY := "custom_brush_presets"
const BRUSH_PRESET_SAVE_ID := 900
const CUSTOM_BRUSH_PRESET_ID_BASE := 1000
const FILL_CUSTOM_PRESET_ID := 1000
const FILL_SETTINGS_PREVIEW_IMAGE_SIZE := 64
const FILL_SETTINGS_PREVIEW_DISPLAY_SIZE := 176
const CANVAS_RESIZE_DIALOG_SIZE := Vector2i(420, 300)
const CROP_RECTANGLE_DIALOG_SIZE := Vector2i(420, 320)
const SCALE_IMAGE_DIALOG_SIZE := Vector2i(420, 340)
const TEXT_FONT_DEFAULT_ID := 0
const TEXT_FONT_LOAD_ID := 100
const TEXT_FONT_CUSTOM_ID := 101
const TEXT_FONT_CUSTOM_ID_BASE := 1000
const TEXT_FONT_SYSTEM_ID_BASE := 100000
const DEFAULT_FONT_DIRECTORY := StoragePaths.DEFAULT_FONT_DIR
const DEFAULT_BRUSH_DIRECTORY := StoragePaths.DEFAULT_BRUSH_DIR
const UPDATE_STAGING_DIRECTORY := StoragePaths.UPDATE_STAGING_DIR
const FONT_PICKER_MAX_SIZE := Vector2i(460, 420)
const SPLIT_HORIZONTAL_RATIO_KEY := "split_horizontal_ratio_v2"
const SPLIT_VERTICAL_RATIO_KEY := "split_vertical_ratio_v2"
const SPLIT_VERTICAL_KEY := "split_vertical"
const LINKED_VIEW_KEY := "linked_view"
const PREVIEW_LIGHT_ENABLED_KEY := "preview_light_enabled"
const PREVIEW_LIGHT_INTENSITY_KEY := "preview_light_intensity"
const PREVIEW_LIGHT_CAMERA_LINKED_KEY := "preview_light_camera_linked"
const PREVIEW_TRANSFORM_GIZMO_VISIBLE_KEY := "preview_transform_gizmo_visible"
const PREVIEW_3D_GRID_VISIBLE_KEY := "preview_3d_grid_visible"
const SNAP_TO_GRID_KEY := "snap_to_grid"
const RECENT_BRUSH_SIZE_LIMIT := 6
const DEFAULT_CANVAS_SIZE := Vector2i(128, 128)
const CANVAS_MODE_2D := 0
const CANVAS_MODE_3D := 1
const CANVAS_MODE_SPLIT := 2
const NAVIGATION_3D_NONE := 0
const NAVIGATION_3D_ORBIT := 1
const NAVIGATION_3D_PAN := 2
const NAVIGATION_3D_FREELOOK := 3
const CANVAS_RESIZE_LOCK_TOOLTIP := "Canvas resizing is disabled to protect the active mesh texture."
const CANVAS_RESIZE_LOCK_STATUS := "Canvas resizing is disabled while a 3D texture session is active."
const CROP_LOCK_TOOLTIP := "Cropping is unavailable while a 3D texture session is active."
const CROP_LOCK_STATUS := "Cropping is unavailable while a 3D texture session is active."
const SCALE_LOCK_TOOLTIP := "Image scaling is unavailable while a 3D texture session is active."
const SCALE_LOCK_STATUS := "Image scaling is unavailable while a 3D texture session is active."
enum MenuCommand {
	FILE_NEW,
	FILE_OPEN,
	FILE_SAVE,
	FILE_SAVE_AS,
	FILE_STOP_3D_SESSION,
	FILE_CREATE_SPRITE,
	EDIT_UNDO,
	EDIT_REDO,
	EDIT_CUT,
	EDIT_COPY,
	EDIT_PASTE,
	EDIT_CLEAR,
	EDIT_PREFERENCES,
	IMAGE_SCALE,
	IMAGE_RESIZE_CANVAS,
	IMAGE_CROP_RECTANGLE,
	IMAGE_TRIM_TRANSPARENT,
	SELECT_ALL,
	SELECT_DESELECT,
	SELECT_DELETE,
	SELECT_FLIP_HORIZONTAL,
	SELECT_FLIP_VERTICAL,
	SELECT_ROTATE_CLOCKWISE,
	SELECT_ROTATE_COUNTERCLOCKWISE,
	SELECT_DUPLICATE,
	SELECT_COMMIT,
	SELECT_CANCEL,
	SELECT_CROP,
	TOOL_ALPHA_LOCK,
	TOOL_BRUSH_HEAD_HEADER,
	TOOL_BRUSH_HEAD_SQUARE,
	TOOL_BRUSH_HEAD_CIRCLE,
	TOOL_TOUCH_PIXELS,
	TOOL_BRUSH_MODE_HEADER,
	TOOL_BRUSH_MODE_PIXEL_PERFECT,
	TOOL_BRUSH_MODE_ANTIALIASING,
	TOOL_STROKE_OVERLAP,
	VIEW_MODE_2D,
	VIEW_MODE_3D,
	VIEW_MODE_SPLIT,
	VIEW_MODE_SPLIT_HORIZONTAL,
	VIEW_MODE_SPLIT_VERTICAL,
	VIEW_GRID_2D,
	VIEW_GRID_3D,
	VIEW_SNAP_TO_GRID,
	VIEW_UV_OVERLAY,
	VIEW_LINKED,
	VIEW_TILE_PREVIEW,
	VIEW_MIRROR_OFF,
	VIEW_MIRROR_HORIZONTAL,
	VIEW_MIRROR_VERTICAL,
	VIEW_MIRROR_BOTH,
	VIEW_ZOOM_IN,
	VIEW_ZOOM_OUT,
	VIEW_RESET,
	GODOT_USE_SELECTED_MESH,
	GODOT_SAVE_ACTIVE_TEXTURE,
	GODOT_CREATE_CSG_BOX,
	HELP_CONTROLS,
	HELP_KNOWN_LIMITATIONS,
	HELP_ABOUT,
	HELP_CHECK_UPDATES,
	HELP_UPDATE_AVAILABLE,
}
enum SessionTransition {
	NONE,
	LOAD_IMAGE_PATH,
	LOAD_IMAGE,
	LOAD_MESH,
	STOP_SESSION,
	START_3D_SESSION,
}
enum TextureSaveStage {
	IDLE,
	OPEN_SAVE_AS_DIALOG,
	AWAITING_SAVE_AS_PATH,
	NORMAL_WRITTEN,
	SAVE_AS_WRITTEN,
	WAITING_IMPORTED_TEXTURE,
}
var _plugin: EditorPlugin
var _menu_bar_background: PanelContainer
var _menu_bar: MenuBar
var _file_menu: PopupMenu
var _edit_menu: PopupMenu
var _image_menu: PopupMenu
var _select_menu: PopupMenu
var _tool_menu: PopupMenu
var _brush_preset_menu: PopupMenu
var _recent_brush_size_menu: PopupMenu
var _view_menu: PopupMenu
var _godot_menu: PopupMenu
var _help_menu: PopupMenu
var _help_dialog: AcceptDialog
var _help_content: VBoxContainer
var _help_update_badge: PanelContainer
var _update_available_overlay: PanelContainer
var _update_overlay_title: Label
var _update_overlay_message: Label
var _update_installed_version_label: Label
var _update_latest_version_label: Label
var _update_open_release_button: Button
var _update_retry_button: Button
var _update_later_button: Button
var _update_download_button: Button
var _update_install_button: Button
var _update_cancel_button: Button
var _update_progress: ProgressBar
var _update_progress_label: Label
var _workspace_region: Control
var _workspace_content: VBoxContainer
var _canvas_region: Control
var _canvas_area: Control
var _canvas_split: SplitContainer
var _canvas_2d_host: Control
var _canvas_3d_host: Control
var _canvas: Control
var _paint_3d_view: SubViewportContainer
var _paint_3d_viewport: SubViewport
var _paint_3d_root: Node3D
var _paint_3d_camera: Camera3D
var _paint_3d_preview_light: DirectionalLight3D
var _paint_3d_mesh: MeshInstance3D
var _paint_3d_wire_mesh: MeshInstance3D
var _paint_3d_brush_preview: MeshInstance3D
var _paint_3d_hover_debug_marker: MeshInstance3D
var _paint_3d_hover_triangle: MeshInstance3D
var _paint_3d_rotation_gizmo: Node3D
var _paint_3d_gizmo_rings: Array[MeshInstance3D] = []
var _paint_3d_gizmo_materials: Array[StandardMaterial3D] = []
var _paint_3d_gizmo_translation_axes: Array[MeshInstance3D] = []
var _paint_3d_gizmo_translation_materials: Array[StandardMaterial3D] = []
var _paint_3d_model_center := Vector3.ZERO
var _paint_3d_gizmo_visible := false
var _paint_3d_gizmo_hover_control := GIZMO_CONTROL_NONE
var _paint_3d_gizmo_hover_axis := -1
var _paint_3d_gizmo_active_control := GIZMO_CONTROL_NONE
var _paint_3d_gizmo_active_axis := -1
var _paint_3d_gizmo_dragging := false
var _paint_3d_gizmo_drag_start_adjustment := Transform3D.IDENTITY
var _paint_3d_gizmo_drag_start_vector := Vector3.ZERO
var _paint_3d_gizmo_drag_center := Vector3.ZERO
var _paint_3d_gizmo_drag_axis_world := Vector3.ZERO
var _paint_3d_gizmo_drag_axis_preview_local := Vector3.ZERO
var _paint_3d_gizmo_drag_start_axis_parameter := 0.0
var _paint_3d_gizmo_drag_use_screen_fallback := false
var _paint_3d_gizmo_drag_screen_axis := Vector2.RIGHT
var _paint_3d_gizmo_drag_world_per_pixel := 1.0
var _paint_3d_gizmo_drag_start_mouse := Vector2.ZERO
var _paint_3d_gizmo_drag_fallback_tangent := Vector2.ZERO
var _paint_3d_gizmo_drag_fallback_radius := 1.0
var _paint_3d_stage_root: Node3D
var _paint_3d_stage_floor: MeshInstance3D
var _paint_3d_stage_grid: MeshInstance3D
var _preview_3d_grid_visible := true
var _paint_3d_texture: ImageTexture
var _paint_3d_material: StandardMaterial3D
var _paint_3d_target := Vector3.ZERO
var _paint_3d_distance := 4.0
var _paint_3d_yaw := 0.65
var _paint_3d_pitch := -0.35
var _paint_3d_camera_basis_override := Basis.IDENTITY
var _paint_3d_camera_basis_override_active := false
var _paint_3d_orbiting := false
var _paint_3d_panning := false
var _paint_3d_freelooking := false
var _paint_3d_freelook_speed_multiplier := 1.0
var _paint_3d_previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _paint_3d_drawing := false
var _paint_3d_last_stroke_hit: Dictionary = {}
var _paint_3d_surface_shape_state: Dictionary = {}
var _paint_3d_triangle_cache: Dictionary = {}
var _paint_3d_island_cache: Dictionary = {}
var _paint_3d_mesh_cache
var _paint_3d_observed_mesh: Mesh
var _paint_3d_geometry_dirty := false
var _paint_3d_source_available := false
var _paint_3d_pending_motion := false
var _paint_3d_pending_motion_position := Vector2.ZERO
var _paint_3d_pending_2d_hover := false
var _paint_3d_pending_2d_hover_uv := Vector2.ZERO
var _paint_3d_pending_2d_hover_visible := false
var _paint_3d_saved_pixel_perfect := true
var _paint_3d_soft_brush_active := false
var _paint_3d_last_uv_overlap_warning := ""
var _paint_3d_hover_debug_state := ""
var _paint_3d_last_2d_hover_pixel := Vector2i(-1, -1)
var _paint_3d_last_mouse_position := Vector2.ZERO
var _icon_buttons: Array[Button] = []
var _static_icons: Array[TextureRect] = []
var _icon_resource_filesystem: Object
var _icon_resource_filesystem_override: Object
var _icon_exists_override := Callable()
var _icon_load_override := Callable()
var _icon_clock_override := Callable()
var _icon_scheduler_override := Callable()
var _icon_recovery_cycle := {
	"generation": 0,
	"active": false,
	"start_msec": 0,
	"deadline_msec": 0,
	"attempts": 0,
	"callback_scheduled": false,
	"callback_token": 0,
	"scheduled_due_msec": 0,
	"pending_count": 0,
}
var _icon_import_recovery_torn_down := false
var _brush_button: Button
var _fill_button: Button
var _shape_button: Button
var _text_button: Button
var _line_button: Button
var _rectangle_button: Button
var _ellipse_button: Button
var _eyedropper_button: Button
var _selection_mode_button: Button
var _selection_button: Button
var _lasso_selection_button: Button
var _pan_button: Button
var _brush_size: SpinBox
var _brush_preset: OptionButton
var _recent_brush_size_selector: OptionButton
var _brush_hardness_row: HBoxContainer
var _brush_hardness: SpinBox
var _alpha_lock: CheckBox
var _brush_head: OptionButton
var _brush_head_separator: Control
var _pixel_perfect_mode: HBoxContainer
var _pixel_perfect_aa_label: Label
var _pixel_perfect: CheckButton
var _pixel_perfect_pixel_label: Label
var _tool_brush_hardness_label: Label
var _tool_brush_hardness: SpinBox
var _brush_touch_pixels: CheckBox
var _tool_stroke_overlap: CheckBox
var _fill_tolerance_label: Label
var _fill_tolerance: SpinBox
var _fill_mode: OptionButton
var _fill_style: OptionButton
var _fill_settings_button: Button
var _fill_settings_overlay: PanelContainer
var _fill_settings_tabs: TabContainer
var _fill_settings_preview: TextureRect
var _fill_settings_preview_size_label: Label
var _fill_settings_foreground: ColorPickerButton
var _fill_settings_background: ColorPickerButton
var _fill_settings_target: OptionButton
var _dither_settings_preset: OptionButton
var _dither_settings_matrix: OptionButton
var _dither_settings_density: SpinBox
var _dither_settings_scale: SpinBox
var _pattern_settings_preset: OptionButton
var _pattern_settings_kind: OptionButton
var _pattern_settings_angle: SpinBox
var _pattern_settings_thickness: SpinBox
var _pattern_settings_gap: SpinBox
var _pattern_settings_cell_width: SpinBox
var _pattern_settings_cell_height: SpinBox
var _pattern_settings_dot_size: SpinBox
var _pattern_settings_thickness_row: Control
var _pattern_settings_gap_row: Control
var _pattern_settings_cell_width_row: Control
var _pattern_settings_cell_height_row: Control
var _pattern_settings_dot_size_row: Control
var _custom_fill_source_button: Button
var _custom_fill_paste_button: Button
var _custom_fill_clear_button: Button
var _custom_fill_drop_target: ImageDropTarget
var _custom_fill_thumbnail: TextureRect
var _custom_fill_filename: Label
var _custom_fill_color_mode: OptionButton
var _custom_fill_repeat_x: CheckBox
var _custom_fill_repeat_y: CheckBox
var _custom_fill_scale_x: SpinBox
var _custom_fill_scale_y: SpinBox
var _custom_fill_lock_aspect: CheckBox
var _custom_fill_spacing_x: SpinBox
var _custom_fill_spacing_y: SpinBox
var _custom_fill_rotation: SpinBox
var _custom_fill_offset_x: SpinBox
var _custom_fill_offset_y: SpinBox
var _custom_fill_filtering: OptionButton
var _custom_fill_threshold: SpinBox
var _custom_fill_threshold_row: Control
var _custom_fill_staged_image: Image
var _custom_fill_staged_name := ""
var _custom_fill_aspect_ratio := 1.0
var _custom_fill_image_dialog: FileDialog
var _syncing_fill_settings := false
var _fill_settings_style := GDDrawCanvasControl.FillStyle.SOLID
var _mirror_mode: OptionButton
var _mirror_options: HBoxContainer
var _shape_fill_mode: OptionButton
var _shape_origin_mode: OptionButton
var _canvas_width: SpinBox
var _canvas_height: SpinBox
var _resize_link_button: Button
var _keep_pixels: CheckBox
var _resize_canvas_button: Button
var _load_selected_mesh_button: Button
var _uv_overlay_toggle: Button
var _preview_orientation_button: Button
var _preview_orientation_reset_button: Button
var _preview_scene_orientation_button: Button
var _preview_3d_grid_button: Button
var _preview_orientation_controls: VBoxContainer
var _preview_light_controls_row: HBoxContainer
var _preview_transform_controls_row: HBoxContainer
var _preview_grid_controls_row: HBoxContainer
var _preview_light_toggle: Button
var _preview_light_intensity: SpinBox
var _preview_light_link_toggle: Button
var _preview_light_reset_button: Button
var _settings_overlay: PanelContainer
var _settings_panel: VBoxContainer
var _brush_mode_selector: OptionButton
var _stroke_overlap: CheckBox
var _grid_button: Button
var _snap_to_grid_button: Button
var _show_grid: CheckBox
var _snap_to_grid: CheckBox
var _grid_size: LineEdit
var _grid_min_cell_size: LineEdit
var _grid_color_picker: ColorPickerButton
var _checker_light_picker: ColorPickerButton
var _checker_dark_picker: ColorPickerButton
var _default_canvas_width: SpinBox
var _default_canvas_height: SpinBox
var _zoom_label: Label
var _zoom_3d_label: Label
var _view_mode_selector: OptionButton
var _linked_view_toggle: Button
var _zoom_3d_in_button: Button
var _zoom_3d_out_button: Button
var _zoom_in_button: Button
var _zoom_out_button: Button
var _color_set: HBoxContainer
var _foreground_color_picker: ColorPickerButton
var _swap_colors_button: Button
var _background_color_picker: ColorPickerButton
var _color_set_separator: Control
var _paint_size_separator: Control
var _fill_end_separator: Control
var _brush_size_label: Label
var _eraser_button: Button
var _status_label: Label
var _session_status_label: Label
var _stop_3d_session_button: Button
var _empty_3d_state: Control
var _session_picker_dialog: ConfirmationDialog
var _session_picker_target_label: Label
var _session_picker_options: ItemList
var _session_picker_reason_label: Label
var _recent_colors_row: HBoxContainer
var _brush_options: HBoxContainer
var _shape_options: HBoxContainer
var _text_options: HBoxContainer
var _text_font_selector: OptionButton
var _text_font_size: SpinBox
var _text_alignment_buttons: Array[Button] = []
var _text_wrap_button: Button
var _text_rotate_left_button: Button
var _text_rotate_amount: SpinBox
var _text_rotate_right_button: Button
var _text_commit_button: Button
var _text_cancel_button: Button
var _text_font_dialog: FileDialog
var _text_custom_font_path := ""
var _text_font_sources: Dictionary = {}
var _text_font_selected_id := TEXT_FONT_DEFAULT_ID
var _shape_tool_separator: Control
var _shape_origin_separator: Control
var _selection_options: HBoxContainer
var _selection_action_separator: Control
var _selection_flip_horizontal_button: Button
var _selection_flip_vertical_button: Button
var _selection_crop_button: Button
var _selection_copy_button: Button
var _selection_paste_button: Button
var _selection_cut_button: Button
var _selection_rotate_left_button: Button
var _selection_rotate_amount: SpinBox
var _selection_rotate_right_button: Button
var _selection_commit_separator: Control
var _selection_commit_button: Button
var _selection_cancel_button: Button
var _eyedropper_options: HBoxContainer
var _view_controls_separator: Control
var _view_link_separator: Control
var _tool_options_corner_icon: TextureRect
var _tool_options_vertical_separator: VSeparator
var _tool_options_horizontal_separator: HSeparator
var _recent_colors: Array[Color] = []
var _recent_brush_sizes: Array[int] = []
var _custom_brush_presets: Array[Dictionary] = []
var _applying_brush_preset := false
var _open_dialog: FileDialog
var _save_dialog: FileDialog
var _save_3d_as_dialog: FileDialog
var _brush_preset_dialog: ConfirmationDialog
var _brush_preset_name: LineEdit
var _save_location: LineEdit
var _save_location_dialog: FileDialog
var _font_location: LineEdit
var _font_location_dialog: FileDialog
var _drop_replace_dialog: ConfirmationDialog
var _create_textured_csg_overlay: PanelContainer
var _create_textured_csg_shape: OptionButton
var _create_textured_csg_assign_image: CheckBox
var _create_textured_csg_select_node: CheckBox
var _create_textured_csg_enable_collision: CheckBox
var _create_textured_csg_validation: Label
var _create_textured_csg_create_button: Button
var _create_textured_csg_cancel_button: Button
var _create_3d_texture_dialog: ConfirmationDialog
var _save_3d_texture_dialog: ConfirmationDialog
var _session_replace_dialog: ConfirmationDialog
var _document_session_dialog: ConfirmationDialog
var _document_session_preview: TextureRect
var _document_session_preview_label: Label
var _clipboard_paste_resize_dialog: ConfirmationDialog
var _canvas_resize_dialog: ConfirmationDialog
var _crop_rectangle_dialog: ConfirmationDialog
var _crop_x: SpinBox
var _crop_y: SpinBox
var _crop_width: SpinBox
var _crop_height: SpinBox
var _scale_image_dialog: ConfirmationDialog
var _scale_width: SpinBox
var _scale_height: SpinBox
var _scale_preserve_aspect: CheckBox
var _scale_interpolation: OptionButton
var _clipboard_poll_timer: Timer
var _file_drop_window: Window
var _history
var _png_io
var _shortcuts
var _texture_3d_session
var _sprite_creator
var _update_checker
var _updater
var _latest_available_version := ""
var _latest_release_url := ""
var _latest_release_descriptor: Dictionary = {}
var _update_retry_mode := "check"
var _release_url_opener := Callable()
var _canvas_mode := CANVAS_MODE_2D
var _canvas_mode_3d := false
var _split_vertical := false
var _split_horizontal_ratio := 0.5
var _split_vertical_ratio := 0.5
var _linked_view_enabled := true
var _preview_light_enabled := true
var _preview_light_intensity_value := PAINT_3D_PREVIEW_LIGHT_DEFAULT
var _preview_light_camera_linked := true
var _current_2d_zoom_percent := 100
var _resize_aspect_ratio := 1.0
var _syncing_canvas_dimensions := false
var _syncing_default_canvas_size := false
var _active_shape_tool := GDDrawCanvasControl.ToolMode.RECTANGLE
var _active_selection_tool := GDDrawCanvasControl.ToolMode.SELECT
var _foreground_color_picker_has_pending_recent_color := false
var _pending_drop_image_path := ""
var _pending_drop_image: Image
var _pending_drop_label := ""
var _load_after_save_path := ""
var _load_after_save_image: Image
var _load_after_save_label := ""
var _pending_clipboard_paste_image: Image
var _pending_clipboard_paste_label := ""
var _pending_3d_mesh: Node3D
var _pending_3d_session_candidate
var _pending_3d_material_slot := 0
var _session_picker_mesh: Node3D
var _session_picker_choices: Array[Dictionary] = []
var _saved_2d_workspace: Dictionary = {}
var _saved_2d_history: Dictionary = {}
var _document_path := ""
var _document_baseline_image: Image
var _save_2d_for_3d_transition := false
var _texture_save_stage := TextureSaveStage.IDLE
var _texture_save_context: Dictionary = {}
var _pending_session_transition := SessionTransition.NONE
var _pending_session_path := ""
var _pending_session_image: Image
var _pending_session_label := ""
var _pending_session_mesh: Node3D
var _active_target_refresh_elapsed := 0.0
var _active_target_transform_refresh_elapsed := 0.0
var _editor_selection: EditorSelection
var _ui_built := false
var _crop_workflow_active := false
var _syncing_crop_controls := false
var _scale_workflow_active := false
var _syncing_scale_controls := false
var _scale_source_size := Vector2i.ONE
var _canvas_has_visible_pixels := false


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_setup_icon_import_recovery()


func _ready() -> void:
	if not _plugin and has_meta("gddraw_plugin"):
		var plugin_meta := get_meta("gddraw_plugin")
		if plugin_meta is EditorPlugin:
			_plugin = plugin_meta
	initialize()


func initialize() -> void:
	_setup_icon_import_recovery()
	if _ui_built:
		return
	_ui_built = true
	name = "GDDraw"
	_ensure_helpers()
	_load_split_view_preferences()
	_load_custom_brush_presets()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_CLICK
	add_theme_constant_override("separation", 8)
	_build_ui()
	_start_icon_recovery_cycle()
	_set_2d_document_baseline("", _canvas.get_image_copy())
	call_deferred("_recover_update_transaction")


func _load_split_view_preferences() -> void:
	var editor_settings := _get_editor_settings()
	if not editor_settings:
		return
	_split_horizontal_ratio = clampf(float(editor_settings.get_project_metadata(SETTINGS_SECTION, SPLIT_HORIZONTAL_RATIO_KEY, 0.5)), 0.2, 0.8)
	_split_vertical_ratio = clampf(float(editor_settings.get_project_metadata(SETTINGS_SECTION, SPLIT_VERTICAL_RATIO_KEY, 0.5)), 0.2, 0.8)
	_split_vertical = bool(editor_settings.get_project_metadata(SETTINGS_SECTION, SPLIT_VERTICAL_KEY, false))
	_linked_view_enabled = bool(editor_settings.get_project_metadata(SETTINGS_SECTION, LINKED_VIEW_KEY, true))
	_preview_light_enabled = bool(editor_settings.get_project_metadata(SETTINGS_SECTION, PREVIEW_LIGHT_ENABLED_KEY, true))
	_preview_light_intensity_value = _clamp_preview_light_intensity(float(editor_settings.get_project_metadata(
		SETTINGS_SECTION,
		PREVIEW_LIGHT_INTENSITY_KEY,
		PAINT_3D_PREVIEW_LIGHT_DEFAULT
	)))
	_preview_light_camera_linked = bool(editor_settings.get_project_metadata(SETTINGS_SECTION, PREVIEW_LIGHT_CAMERA_LINKED_KEY, true))
	_paint_3d_gizmo_visible = bool(editor_settings.get_project_metadata(SETTINGS_SECTION, PREVIEW_TRANSFORM_GIZMO_VISIBLE_KEY, false))
	_preview_3d_grid_visible = bool(editor_settings.get_project_metadata(SETTINGS_SECTION, PREVIEW_3D_GRID_VISIBLE_KEY, true))


func _save_split_view_preferences() -> void:
	var editor_settings := _get_editor_settings()
	if not editor_settings:
		return
	editor_settings.set_project_metadata(SETTINGS_SECTION, SPLIT_HORIZONTAL_RATIO_KEY, _split_horizontal_ratio)
	editor_settings.set_project_metadata(SETTINGS_SECTION, SPLIT_VERTICAL_RATIO_KEY, _split_vertical_ratio)
	editor_settings.set_project_metadata(SETTINGS_SECTION, SPLIT_VERTICAL_KEY, _split_vertical)
	editor_settings.set_project_metadata(SETTINGS_SECTION, LINKED_VIEW_KEY, _linked_view_enabled)


func _save_preview_light_preferences() -> void:
	var editor_settings := _get_editor_settings()
	if not editor_settings:
		return
	editor_settings.set_project_metadata(SETTINGS_SECTION, PREVIEW_LIGHT_ENABLED_KEY, _preview_light_enabled)
	editor_settings.set_project_metadata(SETTINGS_SECTION, PREVIEW_LIGHT_INTENSITY_KEY, _preview_light_intensity_value)
	editor_settings.set_project_metadata(SETTINGS_SECTION, PREVIEW_LIGHT_CAMERA_LINKED_KEY, _preview_light_camera_linked)


func _save_preview_transform_gizmo_preference() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings:
		editor_settings.set_project_metadata(SETTINGS_SECTION, PREVIEW_TRANSFORM_GIZMO_VISIBLE_KEY, _paint_3d_gizmo_visible)


func _save_preview_3d_grid_preference() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings:
		editor_settings.set_project_metadata(SETTINGS_SECTION, PREVIEW_3D_GRID_VISIBLE_KEY, _preview_3d_grid_visible)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		call_deferred("_reposition_help_update_badge")
		_resize_3d_paint_viewport()
		if _canvas_mode == CANVAS_MODE_SPLIT:
			call_deferred("_apply_split_ratio")
	elif what == NOTIFICATION_EXIT_TREE:
		_cancel_3d_rotation_gizmo_drag(false)
		_stop_3d_freelook()


func _process(delta: float) -> void:
	_refresh_icon_button_states()
	_advance_3d_texture_save_workflow()
	_process_pending_3d_pointer_motion()
	_process_pending_2d_hover()
	_active_target_transform_refresh_elapsed += delta
	if _active_target_transform_refresh_elapsed >= PAINT_3D_TRANSFORM_POLL_INTERVAL:
		_active_target_transform_refresh_elapsed = 0.0
		_poll_active_3d_target_transform()
	_active_target_refresh_elapsed += delta
	if _active_target_refresh_elapsed >= 0.5:
		_active_target_refresh_elapsed = 0.0
		_poll_active_3d_target_geometry()
	if not _paint_3d_freelooking:
		return
	var forward_axis := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var right_axis := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var vertical_axis := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	var speed_modifier := 3.0 if Input.is_key_pressed(KEY_SHIFT) else (0.25 if Input.is_key_pressed(KEY_ALT) else 1.0)
	_move_3d_freelook_camera(forward_axis, right_axis, vertical_axis, delta, speed_modifier)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), TOOL_BUTTON_PANEL_COLOR, true)


func _input(event: InputEvent) -> void:
	_ensure_helpers()
	var action: String = _shortcuts.get_action(event)
	if action.is_empty() or not _shortcut_is_scoped_to_gddraw():
		return

	if action == GDDrawShortcutMap.ACTION_COPY:
		if _canvas and _canvas.has_text_draft():
			_copy_text_draft_contextual()
		else:
			_copy_selection()
	elif action == GDDrawShortcutMap.ACTION_CUT:
		_cut_selection()
	elif action == GDDrawShortcutMap.ACTION_PASTE:
		_paste_selection()
	elif action == GDDrawShortcutMap.ACTION_DELETE:
		_delete_selection()
	elif action == GDDrawShortcutMap.ACTION_CANCEL:
		if _scale_workflow_active:
			_cancel_scale_image()
		elif _crop_workflow_active:
			_cancel_crop_rectangle()
		elif _update_available_overlay and _update_available_overlay.visible:
			_close_update_available_overlay()
		elif _create_textured_csg_overlay and _create_textured_csg_overlay.visible:
			_close_create_textured_csg_overlay()
		elif _fill_settings_overlay and _fill_settings_overlay.visible:
			_on_fill_settings_cancel_pressed()
		elif _settings_overlay and _settings_overlay.visible:
			_close_preferences()
		else:
			_cancel_selection_or_preview()
	elif action == GDDrawShortcutMap.ACTION_SELECT_ALL:
		_select_all()
	elif action == GDDrawShortcutMap.ACTION_DUPLICATE:
		_duplicate_selection()
	elif action == GDDrawShortcutMap.ACTION_COMMIT:
		_commit_selection_transform()
	else:
		return

	get_viewport().set_input_as_handled()


func _ensure_helpers() -> void:
	if not _history:
		_history = _make_script_instance(HISTORY_SCRIPT_PATH, RefCounted.new())
	if not _png_io:
		_png_io = _make_script_instance(PNG_IO_SCRIPT_PATH, RefCounted.new())
	if not _shortcuts:
		_shortcuts = _make_script_instance(SHORTCUTS_SCRIPT_PATH, RefCounted.new())
	if not _texture_3d_session:
		_texture_3d_session = _make_script_instance(TEXTURE_3D_SESSION_SCRIPT_PATH, RefCounted.new())
	if not _sprite_creator:
		_sprite_creator = _make_script_instance(SPRITE_CREATOR_SCRIPT_PATH, RefCounted.new())
	if not _update_checker:
		var checker_script = load(UPDATE_CHECKER_SCRIPT_PATH)
		if checker_script and checker_script.has_method("new"):
			_update_checker = checker_script.call("new")
			if _update_checker:
				_update_checker.name = "GDDraw Update Checker"
				add_child(_update_checker)
				_update_checker.check_completed.connect(_on_update_check_completed)
	if not _updater:
		var updater_script = load(UPDATER_SCRIPT_PATH)
		if updater_script and updater_script.has_method("new"):
			_updater = updater_script.call("new")
			if _updater:
				_updater.name = "GDDraw Updater"
				add_child(_updater)
				_updater.state_changed.connect(_on_updater_state_changed)
				_updater.progress_changed.connect(_on_updater_progress_changed)
				if _plugin:
					_updater.set_editor_interface(_plugin.get_editor_interface())


func _make_script_instance(script_path: String, fallback: Object) -> Object:
	var script = load(script_path)
	if script and script.has_method("new"):
		var instance = script.call("new")
		if instance:
			return instance
	return fallback


func _build_ui() -> void:
	_build_menu_bar()
	_build_workspace()
	_build_options_bar()

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	_workspace_content.add_child(body)

	_build_tool_rail(body)
	_build_canvas_region(body)
	_build_settings_menu()
	_build_update_available_overlay()
	_build_status_bar()

	_build_open_dialog()
	_build_custom_fill_image_dialog()
	_build_text_font_dialog()
	_build_save_dialog()
	_build_save_3d_as_dialog()
	_build_brush_preset_dialog()
	_build_save_location_dialog()
	_build_font_location_dialog()
	_build_drop_replace_dialog()
	_build_create_textured_csg_dialog()
	_build_3d_session_picker()
	_build_create_3d_texture_dialog()
	_build_save_3d_texture_dialog()
	_build_session_replace_dialog()
	_build_document_session_dialog()
	_build_clipboard_paste_resize_dialog()
	_build_canvas_resize_dialog()
	_build_crop_rectangle_dialog()
	_build_scale_image_dialog()
	_build_help_dialog()
	_build_clipboard_poll_timer()
	_on_canvas_size_changed(_canvas.get_canvas_size())
	_on_view_changed(_canvas.get_zoom_percent())
	_update_history_buttons()
	_update_selection_action_buttons()
	_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)
	_record_recent_color(Color.BLACK)
	call_deferred("_connect_window_file_drop")
	if Engine.is_editor_hint() and _plugin:
		call_deferred("_check_for_updates", true)


func _build_workspace() -> void:
	_workspace_region = Control.new()
	_workspace_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workspace_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workspace_region.clip_contents = true
	add_child(_workspace_region)

	_workspace_content = VBoxContainer.new()
	_workspace_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_workspace_content.add_theme_constant_override("separation", 8)
	_workspace_region.add_child(_workspace_content)


func _build_menu_bar() -> void:
	_menu_bar_background = PanelContainer.new()
	_menu_bar_background.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = TOOL_BUTTON_PANEL_COLOR
	_menu_bar_background.add_theme_stylebox_override("panel", background_style)
	add_child(_menu_bar_background)

	_menu_bar = MenuBar.new()
	_menu_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_bar.prefer_global_menu = false
	_menu_bar.flat = false
	_apply_menu_bar_style(_menu_bar)
	_menu_bar_background.add_child(_menu_bar)

	_file_menu = _add_menu("File")
	_file_menu.add_item("New", MenuCommand.FILE_NEW, KEY_MASK_CTRL | KEY_N)
	_file_menu.add_item("Open…", MenuCommand.FILE_OPEN, KEY_MASK_CTRL | KEY_O)
	_file_menu.add_separator()
	_file_menu.add_item("Save", MenuCommand.FILE_SAVE, KEY_MASK_CTRL | KEY_S)
	_file_menu.add_item("Save As…", MenuCommand.FILE_SAVE_AS, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_S)

	_edit_menu = _add_menu("Edit")
	_edit_menu.add_item("Undo", MenuCommand.EDIT_UNDO, KEY_MASK_CTRL | KEY_Z)
	_edit_menu.add_item("Redo", MenuCommand.EDIT_REDO, KEY_MASK_CTRL | KEY_Y)
	_edit_menu.add_separator()
	_edit_menu.add_item("Cut", MenuCommand.EDIT_CUT, KEY_MASK_CTRL | KEY_X)
	_edit_menu.add_item("Copy", MenuCommand.EDIT_COPY, KEY_MASK_CTRL | KEY_C)
	_edit_menu.add_item("Paste", MenuCommand.EDIT_PASTE, KEY_MASK_CTRL | KEY_V)
	_edit_menu.add_item("Clear", MenuCommand.EDIT_CLEAR)
	_edit_menu.add_separator()
	_edit_menu.add_item("Preferences…", MenuCommand.EDIT_PREFERENCES)

	_image_menu = _add_menu("Image")
	_image_menu.add_item("Scale Image…", MenuCommand.IMAGE_SCALE)
	_image_menu.add_item("Resize Canvas…", MenuCommand.IMAGE_RESIZE_CANVAS)
	_image_menu.add_item("Crop Rectangle…", MenuCommand.IMAGE_CROP_RECTANGLE)
	_image_menu.add_item("Trim Transparent Bounds", MenuCommand.IMAGE_TRIM_TRANSPARENT)

	_select_menu = _add_menu("Select")
	_select_menu.add_item("Select All", MenuCommand.SELECT_ALL, KEY_MASK_CTRL | KEY_A)
	_select_menu.add_item("Deselect", MenuCommand.SELECT_DESELECT, KEY_ESCAPE)
	_select_menu.add_separator()
	_select_menu.add_item("Delete Selection", MenuCommand.SELECT_DELETE, KEY_DELETE)
	_select_menu.add_separator()
	_select_menu.add_item("Flip Horizontal", MenuCommand.SELECT_FLIP_HORIZONTAL)
	_select_menu.add_item("Flip Vertical", MenuCommand.SELECT_FLIP_VERTICAL)
	_select_menu.add_item("Rotate 90° Clockwise", MenuCommand.SELECT_ROTATE_CLOCKWISE)
	_select_menu.add_item("Rotate 90° Counterclockwise", MenuCommand.SELECT_ROTATE_COUNTERCLOCKWISE)
	_select_menu.add_item("Duplicate Selection", MenuCommand.SELECT_DUPLICATE, KEY_MASK_CTRL | KEY_D)
	_select_menu.add_item("Commit Floating Selection", MenuCommand.SELECT_COMMIT, KEY_ENTER)
	_select_menu.add_item("Cancel Floating Selection", MenuCommand.SELECT_CANCEL, KEY_ESCAPE)
	_select_menu.add_separator()
	_select_menu.add_item("Crop to Selection", MenuCommand.SELECT_CROP)

	_tool_menu = _add_menu("Tool")
	_brush_preset_menu = PopupMenu.new()
	_brush_preset_menu.name = "Brush Presets"
	_brush_preset_menu.id_pressed.connect(_on_brush_preset_menu_selected)
	_tool_menu.add_child(_brush_preset_menu)
	_rebuild_brush_preset_menu()
	_tool_menu.add_submenu_node_item("Brush Preset", _brush_preset_menu)
	_recent_brush_size_menu = PopupMenu.new()
	_recent_brush_size_menu.name = "Recent Brush Sizes"
	_recent_brush_size_menu.add_item("No recent sizes")
	_recent_brush_size_menu.set_item_disabled(0, true)
	_recent_brush_size_menu.id_pressed.connect(_on_recent_brush_size_menu_selected)
	_tool_menu.add_child(_recent_brush_size_menu)
	_tool_menu.add_submenu_node_item("Recent Brush Size", _recent_brush_size_menu)
	_tool_menu.add_separator()
	_tool_menu.add_check_item("Lock Alpha", MenuCommand.TOOL_ALPHA_LOCK)
	_tool_menu.add_check_item("Touch Pixels", MenuCommand.TOOL_TOUCH_PIXELS)
	_tool_menu.add_check_item("Allow Stroke Overlap", MenuCommand.TOOL_STROKE_OVERLAP)
	_tool_menu.add_separator()
	_tool_menu.add_item("Brush Head", MenuCommand.TOOL_BRUSH_HEAD_HEADER)
	_tool_menu.set_item_disabled(_tool_menu.get_item_index(MenuCommand.TOOL_BRUSH_HEAD_HEADER), true)
	_tool_menu.add_radio_check_item("Square Brush Head", MenuCommand.TOOL_BRUSH_HEAD_SQUARE)
	_tool_menu.add_radio_check_item("Circle Brush Head", MenuCommand.TOOL_BRUSH_HEAD_CIRCLE)
	_tool_menu.add_separator()
	_tool_menu.add_item("Brush Mode", MenuCommand.TOOL_BRUSH_MODE_HEADER)
	_tool_menu.set_item_disabled(_tool_menu.get_item_index(MenuCommand.TOOL_BRUSH_MODE_HEADER), true)
	_tool_menu.add_radio_check_item("Pixel Perfect", MenuCommand.TOOL_BRUSH_MODE_PIXEL_PERFECT)
	_tool_menu.add_radio_check_item("Antialiasing", MenuCommand.TOOL_BRUSH_MODE_ANTIALIASING)

	_view_menu = _add_menu("View")
	_view_menu.add_radio_check_item("2D Mode", MenuCommand.VIEW_MODE_2D)
	_view_menu.add_radio_check_item("3D Mode", MenuCommand.VIEW_MODE_3D)
	_view_menu.add_radio_check_item("Split Horizontal", MenuCommand.VIEW_MODE_SPLIT_HORIZONTAL)
	_view_menu.add_radio_check_item("Split Vertical", MenuCommand.VIEW_MODE_SPLIT_VERTICAL)
	_view_menu.add_separator()
	_view_menu.add_check_item("Show 2D Grid", MenuCommand.VIEW_GRID_2D)
	_view_menu.add_check_item("Show 3D Grid", MenuCommand.VIEW_GRID_3D)
	_view_menu.add_check_item("Snap to Grid", MenuCommand.VIEW_SNAP_TO_GRID)
	_view_menu.add_check_item("Show UV Overlay", MenuCommand.VIEW_UV_OVERLAY)
	_view_menu.add_check_item("Link Split Hover", MenuCommand.VIEW_LINKED)
	_view_menu.add_check_item("Tile Preview", MenuCommand.VIEW_TILE_PREVIEW)
	_view_menu.add_separator()
	_view_menu.add_radio_check_item("Mirror: Off", MenuCommand.VIEW_MIRROR_OFF)
	_view_menu.add_radio_check_item("Mirror: Horizontal (Top to Bottom)", MenuCommand.VIEW_MIRROR_HORIZONTAL)
	_view_menu.add_radio_check_item("Mirror: Vertical (Left to Right)", MenuCommand.VIEW_MIRROR_VERTICAL)
	_view_menu.add_radio_check_item("Mirror: Both Axes", MenuCommand.VIEW_MIRROR_BOTH)
	_view_menu.add_separator()
	_view_menu.add_item("Zoom In", MenuCommand.VIEW_ZOOM_IN, KEY_MASK_CTRL | KEY_EQUAL)
	_view_menu.add_item("Zoom Out", MenuCommand.VIEW_ZOOM_OUT, KEY_MASK_CTRL | KEY_MINUS)
	_view_menu.add_item("Reset View", MenuCommand.VIEW_RESET, KEY_MASK_CTRL | KEY_0)

	_godot_menu = _add_menu("Godot")
	_godot_menu.add_item("Create Sprite2D", MenuCommand.FILE_CREATE_SPRITE)
	_godot_menu.add_item("Create Textured CSG3D…", MenuCommand.GODOT_CREATE_CSG_BOX)
	_godot_menu.add_separator()
	_godot_menu.add_item("Use Selected Mesh", MenuCommand.GODOT_USE_SELECTED_MESH)
	_godot_menu.add_item("Save Active Texture", MenuCommand.GODOT_SAVE_ACTIVE_TEXTURE)

	_help_menu = _add_menu("Help")
	_populate_help_menu()
	_build_help_update_badge()
	_sync_menu_state()
	call_deferred("_match_menu_bar_to_popup_background")
	call_deferred("_reposition_help_update_badge")


func _match_menu_bar_to_popup_background() -> void:
	if not _menu_bar_background or not _file_menu:
		return
	var popup_style := _file_menu.get_theme_stylebox("panel")
	var popup_background := TOOL_BUTTON_PANEL_COLOR
	if popup_style is StyleBoxFlat:
		popup_background = (popup_style as StyleBoxFlat).bg_color
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = popup_background
	_menu_bar_background.add_theme_stylebox_override("panel", background_style)


func _add_menu(title: String) -> PopupMenu:
	var popup := PopupMenu.new()
	popup.name = title
	popup.id_pressed.connect(_on_menu_command)
	popup.about_to_popup.connect(_sync_menu_state)
	_menu_bar.add_child(popup)
	return popup


func _populate_help_menu(show_update := false) -> void:
	if not _help_menu:
		return
	_help_menu.clear()
	if show_update and not _latest_available_version.is_empty():
		_help_menu.add_icon_item(
			_make_update_warning_icon(),
			"Update Available - v%s..." % _latest_available_version,
			MenuCommand.HELP_UPDATE_AVAILABLE
		)
		_help_menu.set_item_tooltip(0, "Open details for GDDraw v%s" % _latest_available_version)
		_help_menu.add_separator()
	_help_menu.add_item("Check for Updates...", MenuCommand.HELP_CHECK_UPDATES)
	_help_menu.add_separator()
	_help_menu.add_item("Controls", MenuCommand.HELP_CONTROLS)
	_help_menu.add_item("Known Limitations", MenuCommand.HELP_KNOWN_LIMITATIONS)
	_help_menu.add_separator()
	_help_menu.add_item("About GDDraw", MenuCommand.HELP_ABOUT)


func _build_help_update_badge() -> void:
	if _help_update_badge or not _menu_bar:
		return
	_menu_bar_background.clip_contents = true
	_help_update_badge = PanelContainer.new()
	_help_update_badge.name = "Help Update Badge"
	_help_update_badge.visible = false
	_help_update_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_update_badge.custom_minimum_size = Vector2(14.0, 14.0)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("#D93643")
	badge_style.set_corner_radius_all(20)
	_help_update_badge.add_theme_stylebox_override("panel", badge_style)
	var badge_label := Label.new()
	badge_label.name = "Badge Label"
	badge_label.text = "!"
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_color_override("font_color", Color.WHITE)
	badge_label.add_theme_font_size_override("font_size", 10)
	_help_update_badge.add_child(badge_label)
	_menu_bar.add_child(_help_update_badge)
	_menu_bar.move_child(_help_update_badge, _menu_bar.get_child_count() - 1)


func _reposition_help_update_badge() -> void:
	if not _help_update_badge or not _menu_bar or not _help_update_badge.visible:
		return
	var badge_size := Vector2(14.0, 14.0)
	_help_update_badge.size = badge_size
	var menus_width := _menu_bar.get_combined_minimum_size().x
	if menus_width <= 0.0:
		_set_help_menu_update_fallback(true)
		return
	_set_help_menu_update_fallback(false)
	_help_update_badge.position = Vector2(
		clampf(menus_width - 8.0, 0.0, maxf(0.0, _menu_bar_background.size.x - badge_size.x)),
		maxf(0.0, (_menu_bar_background.size.y - badge_size.y) * 0.5 - 4.0)
	)


func _set_help_menu_update_fallback(enabled: bool) -> void:
	if not _menu_bar or not _help_menu:
		return
	for menu_index in range(_menu_bar.get_menu_count()):
		if _menu_bar.get_menu_popup(menu_index) == _help_menu:
			_menu_bar.set_menu_title(menu_index, "Help (!)" if enabled else "Help")
			if _help_update_badge:
				_help_update_badge.visible = not enabled and not _latest_available_version.is_empty()
			return


func _on_menu_command(command_id: int) -> void:
	match command_id:
		MenuCommand.FILE_NEW:
			_new_canvas()
		MenuCommand.FILE_OPEN:
			_show_load_png_dialog()
		MenuCommand.FILE_SAVE:
			_save_png()
		MenuCommand.FILE_SAVE_AS:
			_save_as()
		MenuCommand.FILE_STOP_3D_SESSION:
			_stop_3d_texture_session()
		MenuCommand.FILE_CREATE_SPRITE:
			_create_sprite()
		MenuCommand.GODOT_CREATE_CSG_BOX:
			_show_create_textured_csg_dialog()
		MenuCommand.EDIT_UNDO:
			_undo()
		MenuCommand.EDIT_REDO:
			_redo()
		MenuCommand.EDIT_CUT:
			_cut_selection()
		MenuCommand.EDIT_COPY:
			if _canvas and _canvas.has_text_draft():
				_copy_text_draft_contextual()
			else:
				_copy_selection()
		MenuCommand.EDIT_PASTE:
			_paste_selection()
		MenuCommand.EDIT_CLEAR:
			_clear_canvas()
		MenuCommand.EDIT_PREFERENCES:
			_open_preferences()
		MenuCommand.IMAGE_SCALE:
			_start_scale_image()
		MenuCommand.IMAGE_RESIZE_CANVAS:
			_start_resize_canvas()
		MenuCommand.IMAGE_CROP_RECTANGLE:
			_start_crop_rectangle()
		MenuCommand.IMAGE_TRIM_TRANSPARENT:
			_trim_transparent_bounds()
		MenuCommand.SELECT_ALL:
			_select_all()
		MenuCommand.SELECT_DESELECT:
			_cancel_selection_or_preview()
		MenuCommand.SELECT_DELETE:
			_delete_selection()
		MenuCommand.SELECT_FLIP_HORIZONTAL:
			_flip_selection_horizontal()
		MenuCommand.SELECT_FLIP_VERTICAL:
			_flip_selection_vertical()
		MenuCommand.SELECT_ROTATE_CLOCKWISE:
			_rotate_selection(true)
		MenuCommand.SELECT_ROTATE_COUNTERCLOCKWISE:
			_rotate_selection(false)
		MenuCommand.SELECT_DUPLICATE:
			_duplicate_selection()
		MenuCommand.SELECT_COMMIT:
			_commit_selection_transform()
		MenuCommand.SELECT_CANCEL:
			_cancel_selection_or_preview()
		MenuCommand.SELECT_CROP:
			_crop_to_selection()
		MenuCommand.TOOL_ALPHA_LOCK:
			var alpha_lock_enabled := not _alpha_lock.button_pressed
			_alpha_lock.set_pressed_no_signal(alpha_lock_enabled)
			_on_alpha_lock_toggled(alpha_lock_enabled)
		MenuCommand.TOOL_BRUSH_HEAD_SQUARE:
			_select_brush_head(GDDrawCanvasControl.BrushHead.SQUARE)
		MenuCommand.TOOL_BRUSH_HEAD_CIRCLE:
			_select_brush_head(GDDrawCanvasControl.BrushHead.CIRCLE)
		MenuCommand.TOOL_TOUCH_PIXELS:
			var touch_pixels_enabled := not _brush_touch_pixels.button_pressed
			_brush_touch_pixels.set_pressed_no_signal(touch_pixels_enabled)
			_on_brush_touch_pixels_toggled(touch_pixels_enabled)
		MenuCommand.TOOL_BRUSH_MODE_PIXEL_PERFECT:
			_on_pixel_perfect_toggled(true)
		MenuCommand.TOOL_BRUSH_MODE_ANTIALIASING:
			_on_pixel_perfect_toggled(false)
		MenuCommand.TOOL_STROKE_OVERLAP:
			var stroke_overlap_enabled := not bool(_canvas.stroke_overlap_enabled)
			if _stroke_overlap:
				_stroke_overlap.set_pressed_no_signal(stroke_overlap_enabled)
			_on_stroke_overlap_toggled(stroke_overlap_enabled)
		MenuCommand.VIEW_MODE_2D:
			_select_canvas_mode(CANVAS_MODE_2D)
		MenuCommand.VIEW_MODE_3D:
			_select_canvas_mode(CANVAS_MODE_3D)
		MenuCommand.VIEW_MODE_SPLIT:
			_select_canvas_mode(CANVAS_MODE_SPLIT)
		MenuCommand.VIEW_MODE_SPLIT_HORIZONTAL:
			_set_split_layout(false)
		MenuCommand.VIEW_MODE_SPLIT_VERTICAL:
			_set_split_layout(true)
		MenuCommand.VIEW_GRID_2D:
			_on_grid_button_toggled(not _canvas.show_grid)
		MenuCommand.VIEW_GRID_3D:
			_set_3d_preview_grid_visible(not _preview_3d_grid_visible, true)
		MenuCommand.VIEW_SNAP_TO_GRID:
			_on_snap_to_grid_toggled(not _canvas.snap_to_grid)
		MenuCommand.VIEW_UV_OVERLAY:
			_set_uv_overlay_enabled(not _uv_overlay_toggle.button_pressed)
		MenuCommand.VIEW_LINKED:
			_set_linked_view_enabled(not _linked_view_enabled)
		MenuCommand.VIEW_TILE_PREVIEW:
			_canvas.tile_preview_enabled = not _canvas.tile_preview_enabled
			_set_status("Tile preview %s." % ("enabled" if _canvas.tile_preview_enabled else "disabled"))
		MenuCommand.VIEW_MIRROR_OFF:
			_set_mirror_mode(GDDrawCanvasControl.MirrorMode.OFF)
		MenuCommand.VIEW_MIRROR_HORIZONTAL:
			_set_mirror_mode(GDDrawCanvasControl.MirrorMode.HORIZONTAL)
		MenuCommand.VIEW_MIRROR_VERTICAL:
			_set_mirror_mode(GDDrawCanvasControl.MirrorMode.VERTICAL)
		MenuCommand.VIEW_MIRROR_BOTH:
			_set_mirror_mode(GDDrawCanvasControl.MirrorMode.BOTH)
		MenuCommand.VIEW_ZOOM_IN:
			_zoom_in()
		MenuCommand.VIEW_ZOOM_OUT:
			_zoom_out()
		MenuCommand.VIEW_RESET:
			_reset_view()
		MenuCommand.GODOT_USE_SELECTED_MESH:
			_load_selected_3d_mesh_texture()
		MenuCommand.GODOT_SAVE_ACTIVE_TEXTURE:
			_save_3d_texture()
		MenuCommand.HELP_CHECK_UPDATES:
			_check_for_updates(false)
		MenuCommand.HELP_UPDATE_AVAILABLE:
			_show_update_available_overlay()
		MenuCommand.HELP_CONTROLS:
			_show_help_dialog(
				"GDDraw Controls",
				"Tools and 2D canvas:\n"
				+ "• Use the left rail for Brush, Eraser, Fill, Shape, Eyedropper, Selection, Lasso, and Pan.\n"
				+ "• Left drag uses the active tool. Mouse wheel zooms. Middle drag pans.\n"
				+ "• Shape Origin supports Corner to Corner, From Start Point, and From Canvas Center; hold Shift to constrain angles, squares, and circles.\n"
				+ "• Ctrl+Z/Y undo and redo. Ctrl+S saves. Ctrl+Shift+S opens Save As.\n"
				+ "• Ctrl+A/X/C/V select all, cut, copy, and paste.\n"
				+ "• While editing text, Ctrl+C copies highlighted characters; with none highlighted, it copies the rendered text box as an image selection.\n"
				+ "• Ctrl+D duplicates the selection. Enter commits a floating selection.\n"
				+ "• Arrow keys nudge a selection. Shift+Arrow nudges 10 pixels.\n"
				+ "• Delete removes a selection. Escape deselects or cancels the active transform.\n\n"
				+ "3D texture sessions:\n"
				+ "• Switch to 3D or Split to show the 3D workspace; it will not load a mesh automatically.\n"
				+ "• Choose Godot > Use Selected Mesh, click Use Selected Mesh, or drag a MeshInstance3D, supported CSG shape, or parent from the Scene tree.\n"
				+ "• The material picker opens before editing. Missing albedo textures are created only after confirmation.\n"
				+ "• Unsaved 2D changes are protected before a 3D session starts.\n"
				+ "• Left drag paints the active albedo texture. Eraser restores pixels from the texture loaded at session start.\n"
				+ "• Middle drag orbits. Shift+Middle drag pans. Mouse wheel zooms.\n"
				+ "• Hold Right Mouse with WASD to freelook; Q/E move down/up; Shift speeds up; Alt slows down.\n"
				+ "• Press F to frame the active surface.\n"
				+ "• Stop Editing restores the independent 2D workspace. Unsaved 3D sessions offer Save, Save As, Discard, or Cancel.\n\n"
				+ "Split View:\n"
				+ "• Use the View selector or View menu to choose 2D, 3D, Split Horizontal, or Split Vertical.\n"
				+ "• Link Split Hover keeps 2D hover points and 3D UV island previews in sync."
			)
		MenuCommand.HELP_KNOWN_LIMITATIONS:
			_show_help_dialog(
				"Known Limitations",
				"Current scope:\n"
				+ "• GDDraw paints PNG images and StandardMaterial3D albedo textures. Other material types or texture channels should be prepared in the Inspector.\n"
				+ "• 3D editing supports MeshInstance3D targets and supported single-material CSG geometry with usable triangle UVs.\n"
				+ "• Missing materials, unsupported CSG output, or multi-material CSG results are disabled with an explanation instead of being changed automatically.\n"
				+ "\n"
				+ "Things to double-check:\n"
				+ "• Overlapping UV shells can make linked 2D-to-3D hover previews choose a hidden or rear surface.\n"
				+ "• Dense seams, mirrored UVs, tiny UV islands, and heavy UV overlap may need manual checking after paint strokes.\n"
				+ "• Very busy textures or models can make the 3D brush and hover previews harder to read.\n"
				+ "• Split View and Preferences can feel cramped in narrow bottom-panel docks; widening the dock helps."
			)
		MenuCommand.HELP_ABOUT:
			_show_help_dialog(
				"About GDDraw",
				"GDDraw v%s\n\n" % _get_installed_plugin_version()
				+ "Overview:\n"
				+ "GDDraw is a Godot 4.4+ editor plugin for quick pixel-art and texture-painting work inside the editor.\n\n"
				+ "Use it for:\n"
				+ "Use it to sketch prototype sprites, make small PNG edits, block out texture ideas, and paint albedo textures directly on supported 3D meshes or CSG surfaces. It is built for fast iteration without leaving Godot, with save prompts around the places where scene or texture data can change."
			)
	_sync_menu_state()


func _sync_menu_state() -> void:
	if not _menu_bar or not _canvas:
		return
	_update_canvas_resize_control_availability()
	var has_selection: bool = _canvas.has_active_selection()
	var has_active_texture: bool = _texture_3d_session != null and _texture_3d_session.has_active_session()
	var has_uv_data: bool = (
		has_active_texture
		and not _texture_3d_session.uv_vertices.is_empty()
		and _canvas_mode_3d
	)
	_set_menu_item_disabled(_file_menu, MenuCommand.FILE_NEW, has_active_texture)
	_set_menu_item_disabled(_file_menu, MenuCommand.FILE_SAVE_AS, false)
	_sync_stop_3d_file_menu_item(has_active_texture)
	_set_menu_item_tooltip(
		_file_menu,
		MenuCommand.FILE_SAVE_AS,
		"Save the current texture to a new PNG and assign it to the active material."
		if has_active_texture
		else "Save the current 2D canvas to a new PNG."
	)
	_set_menu_item_disabled(_edit_menu, MenuCommand.EDIT_UNDO, not _history.can_undo())
	_set_menu_item_disabled(_edit_menu, MenuCommand.EDIT_REDO, not _history.can_redo())
	_set_menu_item_disabled(_edit_menu, MenuCommand.EDIT_CUT, not has_selection)
	_set_menu_item_disabled(_edit_menu, MenuCommand.EDIT_COPY, not has_selection)
	_set_menu_item_disabled(_edit_menu, MenuCommand.EDIT_PASTE, not _has_paste_available())
	_set_menu_item_disabled(_image_menu, MenuCommand.IMAGE_SCALE, has_active_texture)
	_set_menu_item_disabled(_image_menu, MenuCommand.IMAGE_RESIZE_CANVAS, has_active_texture)
	_set_menu_item_disabled(_image_menu, MenuCommand.IMAGE_CROP_RECTANGLE, has_active_texture)
	_set_menu_item_disabled(_image_menu, MenuCommand.IMAGE_TRIM_TRANSPARENT, has_active_texture)
	_set_menu_item_tooltip(_image_menu, MenuCommand.IMAGE_SCALE, SCALE_LOCK_TOOLTIP if has_active_texture else "Resample the image to exact pixel dimensions.")
	_set_menu_item_tooltip(_image_menu, MenuCommand.IMAGE_RESIZE_CANVAS, CANVAS_RESIZE_LOCK_TOOLTIP if has_active_texture else "Change the canvas bounds with optional pixel preservation.")
	_set_menu_item_tooltip(_image_menu, MenuCommand.IMAGE_CROP_RECTANGLE, CROP_LOCK_TOOLTIP if has_active_texture else "Preview and apply an exact crop rectangle.")
	_set_menu_item_tooltip(_image_menu, MenuCommand.IMAGE_TRIM_TRANSPARENT, CROP_LOCK_TOOLTIP if has_active_texture else "Remove fully transparent outer rows and columns.")
	_set_menu_item_disabled(_select_menu, MenuCommand.SELECT_DESELECT, not has_selection)
	_set_menu_item_disabled(_select_menu, MenuCommand.SELECT_DELETE, not has_selection)
	_set_menu_item_disabled(_select_menu, MenuCommand.SELECT_FLIP_HORIZONTAL, not has_selection)
	_set_menu_item_disabled(_select_menu, MenuCommand.SELECT_FLIP_VERTICAL, not has_selection)
	_set_menu_item_disabled(_select_menu, MenuCommand.SELECT_ROTATE_CLOCKWISE, not has_selection)
	_set_menu_item_disabled(_select_menu, MenuCommand.SELECT_ROTATE_COUNTERCLOCKWISE, not has_selection)
	_set_menu_item_disabled(_select_menu, MenuCommand.SELECT_DUPLICATE, not has_selection)
	_set_menu_item_disabled(_select_menu, MenuCommand.SELECT_COMMIT, not _canvas.has_floating_selection())
	_set_menu_item_disabled(_select_menu, MenuCommand.SELECT_CANCEL, not _canvas.has_floating_selection())
	_set_menu_item_disabled(_select_menu, MenuCommand.SELECT_CROP, not has_selection or has_active_texture)
	_set_menu_item_tooltip(_select_menu, MenuCommand.SELECT_CROP, CROP_LOCK_TOOLTIP if has_active_texture else "Crop to the occupied selection bounds.")
	_set_menu_item_checked(_tool_menu, MenuCommand.TOOL_ALPHA_LOCK, _canvas.alpha_lock)
	_set_menu_item_checked(_tool_menu, MenuCommand.TOOL_BRUSH_HEAD_SQUARE, _canvas.brush_head == GDDrawCanvasControl.BrushHead.SQUARE)
	_set_menu_item_checked(_tool_menu, MenuCommand.TOOL_BRUSH_HEAD_CIRCLE, _canvas.brush_head == GDDrawCanvasControl.BrushHead.CIRCLE)
	_set_menu_item_checked(_tool_menu, MenuCommand.TOOL_TOUCH_PIXELS, _canvas.brush_touch_pixels)
	_set_menu_item_checked(_tool_menu, MenuCommand.TOOL_BRUSH_MODE_PIXEL_PERFECT, _canvas.pixel_perfect)
	_set_menu_item_checked(_tool_menu, MenuCommand.TOOL_BRUSH_MODE_ANTIALIASING, not _canvas.pixel_perfect)
	_set_menu_item_checked(_tool_menu, MenuCommand.TOOL_STROKE_OVERLAP, _canvas.stroke_overlap_enabled)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_MODE_2D, _canvas_mode == CANVAS_MODE_2D)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_MODE_3D, _canvas_mode == CANVAS_MODE_3D)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_MODE_SPLIT_HORIZONTAL, _canvas_mode == CANVAS_MODE_SPLIT and not _split_vertical)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_MODE_SPLIT_VERTICAL, _canvas_mode == CANVAS_MODE_SPLIT and _split_vertical)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_GRID_2D, _canvas.show_grid)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_GRID_3D, _preview_3d_grid_visible)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_SNAP_TO_GRID, _canvas.snap_to_grid)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_UV_OVERLAY, _canvas.uv_overlay_visible)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_LINKED, _linked_view_enabled)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_TILE_PREVIEW, _canvas.tile_preview_enabled)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_MIRROR_OFF, _canvas.mirror_mode == GDDrawCanvasControl.MirrorMode.OFF)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_MIRROR_HORIZONTAL, _canvas.mirror_mode == GDDrawCanvasControl.MirrorMode.HORIZONTAL)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_MIRROR_VERTICAL, _canvas.mirror_mode == GDDrawCanvasControl.MirrorMode.VERTICAL)
	_set_menu_item_checked(_view_menu, MenuCommand.VIEW_MIRROR_BOTH, _canvas.mirror_mode == GDDrawCanvasControl.MirrorMode.BOTH)
	_set_menu_item_disabled(_view_menu, MenuCommand.VIEW_UV_OVERLAY, not has_uv_data)
	_set_menu_item_disabled(_view_menu, MenuCommand.VIEW_LINKED, _canvas_mode != CANVAS_MODE_SPLIT)
	_set_menu_item_disabled(_view_menu, MenuCommand.VIEW_ZOOM_IN, not _canvas.can_zoom_in())
	_set_menu_item_disabled(_view_menu, MenuCommand.VIEW_ZOOM_OUT, not _canvas.can_zoom_out())
	_set_menu_item_disabled(_godot_menu, MenuCommand.FILE_CREATE_SPRITE, not _canvas_has_visible_pixels)
	_set_menu_item_tooltip(
		_godot_menu,
		MenuCommand.FILE_CREATE_SPRITE,
		"Create a Sprite2D from the current canvas."
		if _canvas_has_visible_pixels
		else "Draw or load visible pixels before creating a Sprite2D."
	)
	_set_menu_item_disabled(_godot_menu, MenuCommand.GODOT_CREATE_CSG_BOX, false)
	_set_menu_item_tooltip(
		_godot_menu,
		MenuCommand.GODOT_CREATE_CSG_BOX,
		"Create a Box, Sphere, or Cylinder, optionally textured from the current canvas."
	)
	_set_menu_item_disabled(_godot_menu, MenuCommand.GODOT_USE_SELECTED_MESH, not _canvas_mode_3d)
	_set_menu_item_disabled(_godot_menu, MenuCommand.GODOT_SAVE_ACTIVE_TEXTURE, not has_active_texture)


func _set_menu_item_disabled(menu: PopupMenu, command_id: int, disabled: bool) -> void:
	if not menu:
		return
	var index := menu.get_item_index(command_id)
	if index >= 0:
		menu.set_item_disabled(index, disabled)


func _sync_stop_3d_file_menu_item(has_active_texture: bool) -> void:
	if not _file_menu:
		return
	var index := _file_menu.get_item_index(MenuCommand.FILE_STOP_3D_SESSION)
	if not has_active_texture:
		if index >= 0:
			_file_menu.remove_item(index)
		return
	if index < 0:
		_file_menu.add_item("Stop Editing 3D Texture…", MenuCommand.FILE_STOP_3D_SESSION)
		index = _file_menu.get_item_index(MenuCommand.FILE_STOP_3D_SESSION)
	if index < 0:
		return

	_file_menu.set_item_tooltip(index, "Stop the active 3D texture session and restore the complete 2D workspace.")


func _set_menu_item_checked(menu: PopupMenu, command_id: int, checked: bool) -> void:
	if not menu:
		return
	var index := menu.get_item_index(command_id)
	if index >= 0:
		menu.set_item_checked(index, checked)


func _set_menu_item_tooltip(menu: PopupMenu, command_id: int, tooltip: String) -> void:
	if not menu:
		return
	var index := menu.get_item_index(command_id)
	if index >= 0:
		menu.set_item_tooltip(index, tooltip)


func _exit_tree() -> void:
	_teardown_icon_import_recovery()
	_disconnect_window_file_drop()
	_disconnect_editor_selection_changed()


func _build_tool_rail(parent: Container) -> void:
	var tool_rail := VBoxContainer.new()
	tool_rail.name = "Tool Rail"
	tool_rail.custom_minimum_size.x = 30
	tool_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tool_rail.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	parent.add_child(tool_rail)
	_tool_options_horizontal_separator = HSeparator.new()
	_tool_options_horizontal_separator.name = "Tool Rail Top Divider"
	_tool_options_horizontal_separator.custom_minimum_size.y = 6
	tool_rail.add_child(_tool_options_horizontal_separator)

	_brush_button = _make_icon_button("pencil_0.svg", "Brush", true)
	_brush_button.button_pressed = true
	_update_toggle_button_icon(_brush_button)
	_brush_button.toggled.connect(_on_brush_toggled)
	tool_rail.add_child(_brush_button)

	_eraser_button = _make_icon_button("eraser_0.svg", "Eraser", true)
	_eraser_button.toggled.connect(_on_eraser_toggled)
	tool_rail.add_child(_eraser_button)

	_fill_button = _make_icon_button("paint-bucket_0.svg", "Paint bucket", true)
	_fill_button.toggled.connect(_on_fill_toggled)
	tool_rail.add_child(_fill_button)

	_shape_button = _make_icon_button("shapes_0.svg", "Shapes", true)
	_shape_button.toggled.connect(_on_shape_toggled)
	tool_rail.add_child(_shape_button)

	_text_button = _make_icon_button("type-outline_0.svg", "Text box", true, "type-outline_1.svg")
	_text_button.toggled.connect(_on_text_toggled)
	tool_rail.add_child(_text_button)

	_eyedropper_button = _make_icon_button("pipette_0.svg", "Eyedropper", true)
	_eyedropper_button.toggled.connect(_on_eyedropper_toggled)
	tool_rail.add_child(_eyedropper_button)

	_add_toolbar_separator(tool_rail)

	_selection_mode_button = _make_icon_button("square-dashed-mouse-pointer_0.svg", "Selection", true)
	_selection_mode_button.toggled.connect(_on_selection_mode_toggled)
	tool_rail.add_child(_selection_mode_button)


func _build_options_bar() -> void:
	var options_bar := HBoxContainer.new()
	options_bar.name = "Tool Options Bar"
	options_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_bar.add_theme_constant_override("separation", 6)
	_workspace_content.add_child(options_bar)

	var options_corner := Control.new()
	options_corner.name = "Tool Options Corner"
	options_corner.custom_minimum_size = Vector2(30, TOOL_BUTTON_SIZE.y)
	options_bar.add_child(options_corner)
	var options_corner_icon_host := CenterContainer.new()
	options_corner_icon_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options_corner.add_child(options_corner_icon_host)
	_tool_options_corner_icon = _make_static_icon("toolbox_2.svg", "Tool options")
	options_corner_icon_host.add_child(_tool_options_corner_icon)
	_tool_options_vertical_separator = VSeparator.new()
	_tool_options_vertical_separator.name = "Tool Options Vertical Divider"
	_tool_options_vertical_separator.custom_minimum_size.x = 6
	options_bar.add_child(_tool_options_vertical_separator)

	_brush_options = HBoxContainer.new()
	_brush_options.add_theme_constant_override("separation", 6)
	options_bar.add_child(_brush_options)

	_color_set = HBoxContainer.new()
	_color_set.name = "Shared Color Set"
	_color_set.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	_brush_options.add_child(_color_set)

	_foreground_color_picker = ColorPickerButton.new()
	_foreground_color_picker.name = "Foreground Color Picker"
	_foreground_color_picker.color = Color.BLACK
	_foreground_color_picker.edit_alpha = true
	_foreground_color_picker.custom_minimum_size = Vector2(32, 28)
	_foreground_color_picker.tooltip_text = "Foreground color"
	_foreground_color_picker.color_changed.connect(_on_foreground_color_changed)
	_foreground_color_picker.popup_closed.connect(_on_foreground_color_picker_popup_closed)
	_color_set.add_child(_foreground_color_picker)

	_swap_colors_button = _make_icon_button("arrow-right-left_0.svg", "Swap foreground and background colors")
	_swap_colors_button.name = "Swap Colors Button"
	_apply_flat_icon_button_style(_swap_colors_button)
	_swap_colors_button.pressed.connect(_on_swap_colors_pressed)
	_color_set.add_child(_swap_colors_button)

	_background_color_picker = ColorPickerButton.new()
	_background_color_picker.name = "Background Color Picker"
	_background_color_picker.color = Color.WHITE
	_background_color_picker.edit_alpha = true
	_background_color_picker.custom_minimum_size = Vector2(32, 28)
	_background_color_picker.tooltip_text = "Background color"
	_background_color_picker.color_changed.connect(_on_background_color_changed)
	_color_set.add_child(_background_color_picker)

	_color_set_separator = _add_tool_options_separator(_brush_options, "Color Set Separator")

	_brush_preset = OptionButton.new()
	for preset_name in ["Pencil 1", "Pixel 4", "Ink 12", "Soft 24", "Custom"]:
		_brush_preset.add_item(preset_name)
	_brush_preset.selected = 4
	_brush_preset.tooltip_text = "Built-in brush presets"
	_brush_preset.item_selected.connect(_on_brush_preset_selected)
	_brush_options.add_child(_brush_preset)
	_brush_preset.visible = false

	_brush_size_label = Label.new()
	_brush_size_label.text = "Size"
	_brush_options.add_child(_brush_size_label)

	_brush_size = SpinBox.new()
	_brush_size.min_value = 1
	_brush_size.max_value = 96
	_brush_size.step = 1
	_brush_size.value = 12
	_brush_size.custom_minimum_size.x = 76
	_brush_size.tooltip_text = "Brush size"
	_brush_size.value_changed.connect(_on_brush_size_changed)
	_brush_options.add_child(_brush_size)

	_paint_size_separator = _add_tool_options_separator(_brush_options, "Paint Size Separator")

	_recent_brush_size_selector = OptionButton.new()
	_recent_brush_size_selector.add_item("Recent")
	_recent_brush_size_selector.disabled = true
	_recent_brush_size_selector.tooltip_text = "Recently used brush sizes"
	_recent_brush_size_selector.item_selected.connect(_on_recent_brush_size_selected)
	_brush_options.add_child(_recent_brush_size_selector)
	_recent_brush_size_selector.visible = false

	_alpha_lock = CheckBox.new()
	_alpha_lock.text = "Lock alpha"
	_alpha_lock.button_pressed = false
	_alpha_lock.tooltip_text = "Preserve destination alpha while painting; transparent pixels stay transparent"
	_alpha_lock.toggled.connect(_on_alpha_lock_toggled)
	_brush_options.add_child(_alpha_lock)
	_alpha_lock.visible = false

	_brush_head = OptionButton.new()
	_brush_head.add_item("Square", GDDrawCanvasControl.BrushHead.SQUARE)
	_brush_head.add_item("Circle", GDDrawCanvasControl.BrushHead.CIRCLE)
	_brush_head.selected = 0
	_brush_head.custom_minimum_size.x = 92
	_brush_head.tooltip_text = "Brush head"
	_brush_head.item_selected.connect(_on_brush_head_selected)
	_brush_options.add_child(_brush_head)
	_brush_head.visible = false

	_brush_head_separator = _add_tool_options_separator(_brush_options, "Brush Head Separator")
	_brush_head_separator.visible = false

	_pixel_perfect_mode = HBoxContainer.new()
	_pixel_perfect_mode.add_theme_constant_override("separation", 0)
	_pixel_perfect_mode.tooltip_text = "Switch between antialiased soft edges and crisp pixel-perfect brush coverage"
	_brush_options.add_child(_pixel_perfect_mode)
	_pixel_perfect_mode.visible = false

	_pixel_perfect_aa_label = Label.new()
	_pixel_perfect_aa_label.text = "AA"
	_pixel_perfect_aa_label.tooltip_text = _pixel_perfect_mode.tooltip_text
	_pixel_perfect_mode.add_child(_pixel_perfect_aa_label)

	_pixel_perfect = CheckButton.new()
	_pixel_perfect.button_pressed = true
	_pixel_perfect.tooltip_text = _pixel_perfect_mode.tooltip_text
	_pixel_perfect.toggled.connect(_on_pixel_perfect_toggled)
	_pixel_perfect_mode.add_child(_pixel_perfect)

	_pixel_perfect_pixel_label = Label.new()
	_pixel_perfect_pixel_label.text = "Pixel"
	_pixel_perfect_pixel_label.tooltip_text = _pixel_perfect_mode.tooltip_text
	_pixel_perfect_mode.add_child(_pixel_perfect_pixel_label)
	_update_pixel_perfect_mode_colors(true)

	_tool_brush_hardness_label = Label.new()
	_tool_brush_hardness_label.text = "Hardness"
	_tool_brush_hardness_label.tooltip_text = "Antialiased brush hardness"
	_brush_options.add_child(_tool_brush_hardness_label)
	_tool_brush_hardness_label.visible = false

	_tool_brush_hardness = SpinBox.new()
	_tool_brush_hardness.min_value = 0
	_tool_brush_hardness.max_value = 100
	_tool_brush_hardness.suffix = "%"
	_tool_brush_hardness.value = 75
	_tool_brush_hardness.custom_minimum_size.x = 76
	_tool_brush_hardness.tooltip_text = "Antialiased brush hardness"
	_apply_preferences_spinbox_style(_tool_brush_hardness)
	_tool_brush_hardness.value_changed.connect(_on_brush_hardness_changed)
	_brush_options.add_child(_tool_brush_hardness)
	_tool_brush_hardness.visible = false

	_brush_touch_pixels = CheckBox.new()
	_brush_touch_pixels.text = "Touch pixels"
	_brush_touch_pixels.button_pressed = true
	_brush_touch_pixels.tooltip_text = "Paint every texture pixel touched by the brush footprint"
	_brush_touch_pixels.toggled.connect(_on_brush_touch_pixels_toggled)
	_brush_options.add_child(_brush_touch_pixels)
	_brush_touch_pixels.visible = false

	_tool_stroke_overlap = CheckBox.new()
	_tool_stroke_overlap.text = "Overlap"
	_tool_stroke_overlap.button_pressed = true
	_tool_stroke_overlap.tooltip_text = "Allow repeated passes within one brush stroke to build up color; disable for one-pass stroke opacity"
	_tool_stroke_overlap.toggled.connect(_on_stroke_overlap_toggled)
	_brush_options.add_child(_tool_stroke_overlap)
	_tool_stroke_overlap.visible = false

	_fill_tolerance_label = Label.new()
	_fill_tolerance_label.text = "Tol"
	_brush_options.add_child(_fill_tolerance_label)

	_fill_tolerance = SpinBox.new()
	_fill_tolerance.min_value = 0
	_fill_tolerance.max_value = 255
	_fill_tolerance.step = 1
	_fill_tolerance.value = 0
	_fill_tolerance.custom_minimum_size.x = 70
	_fill_tolerance.tooltip_text = "Maximum RGBA8 difference per channel (0 matches exact color only)"
	_fill_tolerance.value_changed.connect(_on_fill_tolerance_changed)
	_brush_options.add_child(_fill_tolerance)

	_fill_end_separator = _add_tool_options_separator(_brush_options, "Fill Mode Separator")
	_fill_end_separator.visible = false

	_fill_mode = OptionButton.new()
	_fill_mode.add_item("Contiguous", GDDrawCanvasControl.FillMode.CONTIGUOUS)
	_fill_mode.add_item("Global", GDDrawCanvasControl.FillMode.GLOBAL)
	_fill_mode.add_item("Replace Color", GDDrawCanvasControl.FillMode.REPLACE_COLOR)
	_fill_mode.selected = 0
	_fill_mode.custom_minimum_size.x = 104
	_fill_mode.tooltip_text = "Fill one connected region or all matching pixels"
	_fill_mode.item_selected.connect(_on_fill_mode_selected)
	_brush_options.add_child(_fill_mode)

	_fill_style = OptionButton.new()
	_fill_style.name = "Fill Style"
	_fill_style.add_item("Solid", GDDrawCanvasControl.FillStyle.SOLID)
	_fill_style.add_item("Dither", GDDrawCanvasControl.FillStyle.DITHER)
	_fill_style.add_item("Pattern", GDDrawCanvasControl.FillStyle.PATTERN)
	_fill_style.add_item("Custom", GDDrawCanvasControl.FillStyle.CUSTOM)
	_fill_style.selected = 0
	_fill_style.custom_minimum_size.x = 72
	_fill_style.fit_to_longest_item = false
	_fill_style.item_selected.connect(_on_fill_style_selected)
	_brush_options.add_child(_fill_style)

	_fill_settings_button = _make_icon_button("settings_0.svg", "Open Fill Settings")
	_fill_settings_button.name = "Fill Settings Button"
	_fill_settings_button.custom_minimum_size = Vector2(34, 28)
	_fill_settings_button.pressed.connect(_on_fill_settings_button_pressed)
	_brush_options.add_child(_fill_settings_button)

	_fill_settings_overlay = PanelContainer.new()
	_fill_settings_overlay.name = "Fill Settings Overlay"
	_fill_settings_overlay.visible = false
	_fill_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_fill_settings_overlay.clip_contents = true
	_fill_settings_overlay.anchor_left = 0.0
	_fill_settings_overlay.anchor_top = 0.0
	_fill_settings_overlay.anchor_right = 1.0
	_fill_settings_overlay.anchor_bottom = 1.0
	_fill_settings_overlay.offset_left = 0.0
	_fill_settings_overlay.offset_top = 0.0
	_fill_settings_overlay.offset_right = 0.0
	_fill_settings_overlay.offset_bottom = 0.0
	var fill_settings_background := StyleBoxFlat.new()
	fill_settings_background.bg_color = _get_preferences_background_color()
	_fill_settings_overlay.add_theme_stylebox_override("panel", fill_settings_background)
	var fill_settings_host: Control = _workspace_region if _workspace_region else self
	fill_settings_host.add_child(_fill_settings_overlay)
	var settings_scroll := ScrollContainer.new()
	settings_scroll.name = "Fill Settings Scroll"
	settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	settings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_fill_settings_overlay.add_child(settings_scroll)
	var settings_margin := MarginContainer.new()
	settings_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_margin.add_theme_constant_override("margin_left", 12)
	settings_margin.add_theme_constant_override("margin_top", 12)
	settings_margin.add_theme_constant_override("margin_right", 12)
	settings_margin.add_theme_constant_override("margin_bottom", 12)
	settings_scroll.add_child(settings_margin)
	var settings_root := VBoxContainer.new()
	settings_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_root.add_theme_constant_override("separation", 10)
	settings_margin.add_child(settings_root)

	var settings_header := HBoxContainer.new()
	settings_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_root.add_child(settings_header)
	var settings_title := Label.new()
	settings_title.text = "Fill Settings"
	settings_title.add_theme_font_size_override("font_size", 16)
	settings_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_header.add_child(settings_title)
	var settings_close := Button.new()
	settings_close.text = "Close"
	settings_close.tooltip_text = "Close Fill Settings without using staged changes"
	_apply_preferences_close_button_style(settings_close)
	settings_close.pressed.connect(_on_fill_settings_cancel_pressed)
	settings_header.add_child(settings_close)
	settings_root.add_child(HSeparator.new())

	var shared_section := PanelContainer.new()
	shared_section.add_theme_stylebox_override("panel", _make_preferences_section_style())
	settings_root.add_child(shared_section)
	var shared_content := VBoxContainer.new()
	shared_content.add_theme_constant_override("separation", 8)
	shared_section.add_child(shared_content)
	var shared_title := Label.new()
	shared_title.text = "Fill colors and target"
	shared_title.add_theme_color_override("font_color", Color("#D8D8D8"))
	shared_title.add_theme_font_size_override("font_size", 14)
	shared_content.add_child(shared_title)
	shared_content.add_child(HSeparator.new())
	var settings_colors := HBoxContainer.new()
	settings_colors.add_theme_constant_override("separation", 6)
	shared_content.add_child(settings_colors)
	var settings_colors_label := Label.new()
	settings_colors_label.text = "Colors"
	settings_colors.add_child(settings_colors_label)
	_fill_settings_foreground = ColorPickerButton.new()
	_fill_settings_foreground.custom_minimum_size = Vector2(44, 28)
	_fill_settings_foreground.edit_alpha = true
	_fill_settings_foreground.tooltip_text = "Foreground color for this fill configuration"
	_fill_settings_foreground.color_changed.connect(_on_fill_settings_value_changed)
	settings_colors.add_child(_fill_settings_foreground)
	var settings_swap := _make_icon_button("arrow-right-left_0.svg", "Swap staged foreground and background colors")
	settings_swap.name = "Fill Settings Swap Colors Button"
	_apply_flat_icon_button_style(settings_swap)
	settings_swap.pressed.connect(_on_fill_settings_swap_pressed)
	settings_colors.add_child(settings_swap)
	_fill_settings_background = ColorPickerButton.new()
	_fill_settings_background.custom_minimum_size = Vector2(44, 28)
	_fill_settings_background.edit_alpha = true
	_fill_settings_background.tooltip_text = "Background color for dither and pattern fills"
	_fill_settings_background.color_changed.connect(_on_fill_settings_value_changed)
	settings_colors.add_child(_fill_settings_background)

	_fill_settings_target = OptionButton.new()
	_fill_settings_target.add_item("Clicked Color", GDDrawCanvasControl.FillTargetMode.CLICKED_COLOR)
	_fill_settings_target.add_item("Restyle Previous Fill", GDDrawCanvasControl.FillTargetMode.PREVIOUS_FILL_COLORS)
	_fill_settings_target.tooltip_text = "Choose normal color matching or treat the previous foreground/background pair as one connected source region"
	_fill_settings_target.item_selected.connect(_on_fill_settings_value_changed)
	shared_content.add_child(_make_fill_setting_row("Target", _fill_settings_target))

	var settings_content := HBoxContainer.new()
	settings_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_content.add_theme_constant_override("separation", 14)
	settings_root.add_child(settings_content)
	_fill_settings_tabs = TabContainer.new()
	_fill_settings_tabs.custom_minimum_size = Vector2(330, 300)
	_fill_settings_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_settings_tabs.tab_changed.connect(_on_fill_settings_tab_changed)
	settings_content.add_child(_fill_settings_tabs)
	_build_fill_settings_tabs()

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size.x = 260
	preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	preview_panel.add_theme_stylebox_override("panel", _make_preferences_section_style())
	settings_content.add_child(preview_panel)
	var preview_column := VBoxContainer.new()
	preview_column.custom_minimum_size.x = 180
	preview_column.add_theme_constant_override("separation", 6)
	preview_panel.add_child(preview_column)
	var preview_label := Label.new()
	preview_label.text = "Live Preview"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_column.add_child(preview_label)
	_fill_settings_preview = TextureRect.new()
	_fill_settings_preview.name = "Fill Settings Live Preview"
	_fill_settings_preview.custom_minimum_size = Vector2(FILL_SETTINGS_PREVIEW_DISPLAY_SIZE, FILL_SETTINGS_PREVIEW_DISPLAY_SIZE)
	# The preview card may expand with the dock, but the pixel preview itself must
	# remain square instead of inheriting the column's wider horizontal bounds.
	_fill_settings_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fill_settings_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fill_settings_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fill_settings_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_fill_settings_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_column.add_child(_fill_settings_preview)
	_fill_settings_preview_size_label = Label.new()
	_fill_settings_preview_size_label.text = "Anchored to canvas pixels • %d × %d px" % [FILL_SETTINGS_PREVIEW_IMAGE_SIZE, FILL_SETTINGS_PREVIEW_IMAGE_SIZE]
	_fill_settings_preview_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fill_settings_preview_size_label.tooltip_text = "The preview currently renders a fixed %d × %d canvas-pixel area" % [FILL_SETTINGS_PREVIEW_IMAGE_SIZE, FILL_SETTINGS_PREVIEW_IMAGE_SIZE]
	preview_column.add_child(_fill_settings_preview_size_label)

	var settings_actions := HBoxContainer.new()
	settings_actions.alignment = BoxContainer.ALIGNMENT_END
	settings_actions.add_theme_constant_override("separation", 6)
	settings_root.add_child(settings_actions)
	var cancel_settings := Button.new()
	cancel_settings.text = "Cancel"
	_apply_preferences_close_button_style(cancel_settings)
	cancel_settings.pressed.connect(_on_fill_settings_cancel_pressed)
	settings_actions.add_child(cancel_settings)
	var use_settings := Button.new()
	use_settings.text = "Use"
	_apply_preferences_small_button_style(use_settings)
	use_settings.tooltip_text = "Use these settings for future Paint Bucket fills without changing the image"
	use_settings.pressed.connect(_on_fill_settings_use_pressed)
	settings_actions.add_child(use_settings)
	_update_fill_settings_button()

	_shape_options = HBoxContainer.new()
	_shape_options.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	options_bar.add_child(_shape_options)

	_line_button = _make_icon_button("slash_0.svg", "Line", true)
	_line_button.toggled.connect(_on_line_toggled)
	_shape_options.add_child(_line_button)

	_rectangle_button = _make_icon_button("square_0.svg", "Rectangle", true)
	_rectangle_button.button_pressed = true
	_update_toggle_button_icon(_rectangle_button)
	_rectangle_button.toggled.connect(_on_rectangle_toggled)
	_shape_options.add_child(_rectangle_button)

	_ellipse_button = _make_icon_button("circle_0.svg", "Ellipse", true)
	_ellipse_button.toggled.connect(_on_ellipse_toggled)
	_shape_options.add_child(_ellipse_button)

	_shape_tool_separator = _add_tool_options_separator(_shape_options, "Shape Tool Separator")

	_shape_fill_mode = OptionButton.new()
	_shape_fill_mode.add_item("No fill", GDDrawCanvasControl.ShapeFillMode.NONE)
	_shape_fill_mode.add_item("Background fill", GDDrawCanvasControl.ShapeFillMode.BACKGROUND)
	_shape_fill_mode.add_item("Foreground fill", GDDrawCanvasControl.ShapeFillMode.FOREGROUND)
	_shape_fill_mode.selected = 0
	_shape_fill_mode.custom_minimum_size.x = 124
	_shape_fill_mode.fit_to_longest_item = false
	_update_shape_fill_tooltip(GDDrawCanvasControl.ShapeFillMode.NONE)
	_shape_fill_mode.item_selected.connect(_on_shape_fill_mode_selected)
	_shape_options.add_child(_shape_fill_mode)

	_shape_origin_separator = _add_tool_options_separator(_shape_options, "Shape Origin Separator")
	_shape_origin_separator.visible = false

	_shape_origin_mode = OptionButton.new()
	_shape_origin_mode.add_item("Corner to Corner", GDDrawCanvasControl.ShapeOriginMode.CORNER_TO_CORNER)
	_shape_origin_mode.add_item("From Start Point", GDDrawCanvasControl.ShapeOriginMode.FROM_START_POINT)
	_shape_origin_mode.add_item("From Canvas Center", GDDrawCanvasControl.ShapeOriginMode.FROM_CANVAS_CENTER)
	_shape_origin_mode.selected = 0
	_shape_origin_mode.custom_minimum_size.x = 148
	_update_shape_origin_tooltip(GDDrawCanvasControl.ShapeOriginMode.CORNER_TO_CORNER)
	_shape_origin_mode.item_selected.connect(_on_shape_origin_mode_selected)
	_shape_options.add_child(_shape_origin_mode)

	_text_options = HBoxContainer.new()
	_text_options.name = "Text Options"
	_text_options.add_theme_constant_override("separation", 6)
	options_bar.add_child(_text_options)

	var text_font_icon := _make_static_icon("type_0.svg", "Font")
	text_font_icon.name = "Text Font Icon"
	_text_options.add_child(text_font_icon)

	_text_font_selector = OptionButton.new()
	_text_font_selector.custom_minimum_size.x = 168
	_text_font_selector.fit_to_longest_item = false
	_text_font_selector.tooltip_text = "Choose a custom font or any font family installed on this computer"
	_text_font_selector.item_selected.connect(_on_text_font_selected)
	var text_font_popup := _text_font_selector.get_popup()
	text_font_popup.allow_search = true
	text_font_popup.max_size = FONT_PICKER_MAX_SIZE
	text_font_popup.about_to_popup.connect(_refresh_text_font_selector)
	_refresh_text_font_selector()
	_text_options.add_child(_text_font_selector)

	var text_size_icon := _make_static_icon("a-large-small_0.svg", "Font size")
	text_size_icon.name = "Text Font Size Icon"
	_text_options.add_child(text_size_icon)

	_text_font_size = SpinBox.new()
	_text_font_size.min_value = 1
	_text_font_size.max_value = 512
	_text_font_size.step = 1
	_text_font_size.value = 16
	_text_font_size.suffix = " px"
	_text_font_size.custom_minimum_size.x = 82
	_text_font_size.tooltip_text = "Text font size in image pixels"
	_text_font_size.value_changed.connect(_on_text_font_size_changed)
	_text_font_size.get_line_edit().text_submitted.connect(_on_text_option_text_submitted)
	_text_options.add_child(_text_font_size)


	_add_tool_options_separator(_text_options, "Text Alignment Separator")
	var alignment_group := ButtonGroup.new()
	var alignment_definitions := [
		["text-align-start_0.svg", "Align text to the start of the text box", GDDrawCanvasControl.TextAlignment.LEFT],
		["text-align-center_0.svg", "Center text within the text box", GDDrawCanvasControl.TextAlignment.CENTER],
		["text-align-end_0.svg", "Align text to the end of the text box", GDDrawCanvasControl.TextAlignment.RIGHT],
	]
	for definition in alignment_definitions:
		var alignment_button := _make_icon_button(str(definition[0]), str(definition[1]), true)
		alignment_button.name = "Text Alignment %s" % str(definition[2])
		alignment_button.button_group = alignment_group
		alignment_button.set_pressed_no_signal(int(definition[2]) == GDDrawCanvasControl.TextAlignment.LEFT)
		_update_toggle_button_icon(alignment_button)
		alignment_button.toggled.connect(_on_text_alignment_toggled.bind(int(definition[2])))
		_text_alignment_buttons.append(alignment_button)
		_text_options.add_child(alignment_button)

	_text_wrap_button = _make_icon_button(
		"text-wrap_0.svg",
		"Wrap words to the text-box width; disable to preserve only manual line breaks",
		true
	)
	_text_wrap_button.name = "Text Word Wrap"
	_text_wrap_button.set_pressed_no_signal(true)
	_update_toggle_button_icon(_text_wrap_button)
	_text_wrap_button.toggled.connect(_on_text_wrap_toggled)
	_text_options.add_child(_text_wrap_button)

	_add_tool_options_separator(_text_options, "Text Rotate Separator")
	var text_rotation_controls := _make_compact_rotation_controls(
		"Text Rotation Controls",
		"Rotate text counterclockwise by the angle field",
		"Rotate text clockwise by the angle field",
		"Text rotation amount in degrees"
	)
	_text_rotate_left_button = text_rotation_controls["left_button"] as Button
	_text_rotate_right_button = text_rotation_controls["right_button"] as Button
	_text_rotate_amount = text_rotation_controls["amount"] as SpinBox
	_text_rotate_left_button.pressed.connect(_rotate_text_by_amount.bind(false))
	_text_rotate_amount.get_line_edit().text_submitted.connect(_on_text_option_text_submitted)
	_text_rotate_right_button.pressed.connect(_rotate_text_by_amount.bind(true))
	_text_options.add_child(text_rotation_controls["control"] as Control)
	_add_tool_options_separator(_text_options, "Text Commit Separator")

	_text_commit_button = _make_icon_button("check_0.svg", "Rasterize this text as one undoable operation (Ctrl+Enter)")
	_text_commit_button.name = "Commit Text"
	_text_commit_button.pressed.connect(_commit_text_draft)
	_text_options.add_child(_text_commit_button)

	_text_cancel_button = _make_icon_button("x_0.svg", "Discard the uncommitted text box (Escape)")
	_text_cancel_button.name = "Cancel Text"
	_text_cancel_button.pressed.connect(_cancel_text_draft)
	_text_options.add_child(_text_cancel_button)

	_selection_options = HBoxContainer.new()
	_selection_options.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	options_bar.add_child(_selection_options)

	_selection_button = _make_icon_button("square-dashed-mouse-pointer_0.svg", "Rectangular selection", true)
	_selection_button.button_pressed = true
	_update_toggle_button_icon(_selection_button)
	_selection_button.toggled.connect(_on_selection_toggled)
	_lasso_selection_button = _make_icon_button("lasso-select_0.svg", "Lasso selection", true)
	_lasso_selection_button.toggled.connect(_on_lasso_selection_toggled)
	_selection_options.add_child(_selection_button)
	_selection_options.add_child(_lasso_selection_button)
	_selection_action_separator = _add_tool_options_separator(_selection_options, "Selection Action Separator")

	_selection_flip_horizontal_button = _make_icon_button("square-centerline-dashed-horizontal_0.svg", "Flip selection horizontally")
	_selection_flip_horizontal_button.pressed.connect(_flip_selection_horizontal)
	_selection_options.add_child(_selection_flip_horizontal_button)

	_selection_flip_vertical_button = _make_icon_button("square-centerline-dashed-vertical_0.svg", "Flip selection vertically")
	_selection_flip_vertical_button.pressed.connect(_flip_selection_vertical)
	_selection_options.add_child(_selection_flip_vertical_button)

	_selection_crop_button = _make_icon_button("crop_0.svg", "Crop the canvas to the occupied selection bounds")
	_selection_crop_button.name = "Crop Selection"
	_selection_crop_button.pressed.connect(_crop_to_selection)
	_selection_options.add_child(_selection_crop_button)

	_add_tool_options_separator(_selection_options, "Selection Clipboard Separator")

	_selection_copy_button = _make_icon_button("copy_0.svg", "Copy selection (Ctrl+C)")
	_selection_copy_button.pressed.connect(_copy_selection)
	_selection_options.add_child(_selection_copy_button)

	_selection_paste_button = _make_icon_button("clipboard-paste_0.svg", "Paste selection (Ctrl+V)")
	_selection_paste_button.pressed.connect(_paste_selection)
	_selection_options.add_child(_selection_paste_button)

	_selection_cut_button = _make_icon_button("scissors_0.svg", "Cut selection (Ctrl+X)")
	_selection_cut_button.pressed.connect(_cut_selection)
	_selection_options.add_child(_selection_cut_button)

	_add_tool_options_separator(_selection_options, "Selection Rotate Separator")
	var selection_rotation_controls := _make_compact_rotation_controls(
		"Selection Rotation Controls",
		"Rotate selection counterclockwise by the angle field",
		"Rotate selection clockwise by the angle field",
		"Selection rotation amount in degrees"
	)
	_selection_rotate_left_button = selection_rotation_controls["left_button"] as Button
	_selection_rotate_right_button = selection_rotation_controls["right_button"] as Button
	_selection_rotate_amount = selection_rotation_controls["amount"] as SpinBox
	_selection_rotate_left_button.pressed.connect(_rotate_selection_by_amount.bind(false))
	_selection_rotate_right_button.pressed.connect(_rotate_selection_by_amount.bind(true))
	_selection_options.add_child(selection_rotation_controls["control"] as Control)

	_selection_commit_separator = _add_tool_options_separator(_selection_options, "Selection Commit Separator")

	_selection_commit_button = Button.new()
	_selection_commit_button.text = "Commit"
	_selection_commit_button.tooltip_text = "Commit floating selection (Enter)"
	_selection_commit_button.pressed.connect(_commit_selection_transform)
	_selection_options.add_child(_selection_commit_button)
	_selection_cancel_button = Button.new()
	_selection_cancel_button.text = "Cancel"
	_selection_cancel_button.tooltip_text = "Cancel floating selection or transform (Escape)"
	_selection_cancel_button.pressed.connect(_cancel_selection_or_preview)
	_selection_options.add_child(_selection_cancel_button)

	_eyedropper_options = HBoxContainer.new()
	_eyedropper_options.add_theme_constant_override("separation", 6)
	options_bar.add_child(_eyedropper_options)

	var eyedropper_label := Label.new()
	eyedropper_label.text = "Click the canvas to sample a color"
	_eyedropper_options.add_child(eyedropper_label)

	_mirror_mode = OptionButton.new()
	_mirror_mode.add_item("Off", GDDrawCanvasControl.MirrorMode.OFF)
	_mirror_mode.add_item("Horizontal", GDDrawCanvasControl.MirrorMode.HORIZONTAL)
	_mirror_mode.add_item("Vertical", GDDrawCanvasControl.MirrorMode.VERTICAL)
	_mirror_mode.add_item("Both", GDDrawCanvasControl.MirrorMode.BOTH)
	_mirror_mode.selected = 0
	_mirror_mode.custom_minimum_size.x = 112
	_mirror_mode.tooltip_text = "Off disables symmetry. Horizontal mirrors top-to-bottom. Vertical mirrors left-to-right. Both enables both axes."
	_mirror_mode.item_selected.connect(_on_mirror_mode_selected)
	_mirror_mode.visible = false
	options_bar.add_child(_mirror_mode)

	var options_spacer := Control.new()
	options_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_bar.add_child(options_spacer)

	_stop_3d_session_button = Button.new()
	_stop_3d_session_button.name = "Stop 3D Texture Editing"
	_stop_3d_session_button.text = "Stop Editing"
	_stop_3d_session_button.visible = false
	_stop_3d_session_button.tooltip_text = "Stop the active 3D texture session and restore the previous 2D workspace"
	_apply_destructive_button_style(_stop_3d_session_button)
	_stop_3d_session_button.pressed.connect(_stop_3d_texture_session)
	options_bar.add_child(_stop_3d_session_button)

	_view_controls_separator = _add_tool_options_separator(options_bar, "View Controls Separator")

	_view_mode_selector = OptionButton.new()
	_view_mode_selector.name = "View Mode Selector"
	_view_mode_selector.add_item("2D", 0)
	_view_mode_selector.add_item("3D", 1)
	_view_mode_selector.add_item("Split Horizontal", 2)
	_view_mode_selector.add_item("Split Vertical", 3)
	_view_mode_selector.custom_minimum_size.x = 120
	_view_mode_selector.tooltip_text = "Choose the 2D, 3D, or Split View layout"
	_view_mode_selector.item_selected.connect(_on_view_mode_selected)
	options_bar.add_child(_view_mode_selector)

	_view_link_separator = _add_tool_options_separator(options_bar, "View Link Separator")

	_linked_view_toggle = _make_icon_button("unlink_0.svg", "Link 2D and 3D hover previews", true, "link_1.svg")
	_linked_view_toggle.set_pressed_no_signal(_linked_view_enabled)
	_update_toggle_button_icon(_linked_view_toggle)
	_update_linked_view_tooltip()
	_linked_view_toggle.toggled.connect(_on_linked_view_toggled)
	options_bar.add_child(_linked_view_toggle)


func _build_canvas_region(parent: Container) -> void:
	_canvas_region = Control.new()
	_canvas_region.custom_minimum_size = Vector2(360, 220)
	_canvas_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_region.clip_contents = true
	parent.add_child(_canvas_region)

	_canvas_area = VSplitContainer.new() if _split_vertical else HSplitContainer.new()
	_canvas_area.focus_mode = Control.FOCUS_CLICK
	_canvas_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas_region.add_child(_canvas_area)
	_canvas_split = _canvas_area as SplitContainer
	_canvas_split.split_offset = 0
	_canvas_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_canvas_split.dragged.connect(_on_split_dragged)

	_canvas_2d_host = Control.new()
	_canvas_2d_host.custom_minimum_size = Vector2(240, 110) if _split_vertical else Vector2(240, 220)
	_canvas_2d_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_2d_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_2d_host.focus_mode = Control.FOCUS_CLICK
	_canvas_area.add_child(_canvas_2d_host)

	_canvas_3d_host = MeshDropHost.new()
	_canvas_3d_host.name = "3D Canvas Host"
	_canvas_3d_host.tooltip_text = "Drop a mesh to choose its texture; unsaved 2D pixel changes are protected before the session starts"
	_canvas_3d_host.custom_minimum_size = Vector2(240, 110) if _split_vertical else Vector2(240, 220)
	_canvas_3d_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_3d_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_3d_host.focus_mode = Control.FOCUS_CLICK
	_canvas_3d_host.mouse_filter = Control.MOUSE_FILTER_PASS
	(_canvas_3d_host as MeshDropHost).mesh_data_dropped.connect(_on_3d_mesh_drop_requested)
	_canvas_3d_host.visible = false
	_canvas_area.add_child(_canvas_3d_host)

	_canvas = _make_canvas_control()
	var editor_settings := _get_editor_settings()
	if editor_settings:
		_canvas.checker_color_light = editor_settings.get_project_metadata(SETTINGS_SECTION, CHECKER_LIGHT_KEY, _canvas.checker_color_light)
		_canvas.checker_color_dark = editor_settings.get_project_metadata(SETTINGS_SECTION, CHECKER_DARK_KEY, _canvas.checker_color_dark)
		_canvas.snap_to_grid = bool(editor_settings.get_project_metadata(SETTINGS_SECTION, SNAP_TO_GRID_KEY, false))
	_canvas.focus_mode = Control.FOCUS_CLICK
	var default_canvas_size := _get_default_canvas_size()
	if default_canvas_size != _canvas.get_canvas_size():
		_canvas.resize_canvas(default_canvas_size, false)
	_refresh_canvas_visible_pixels_state()
	_canvas.active_tool = GDDrawCanvasControl.ToolMode.BRUSH
	_canvas.stroke_committed.connect(_on_stroke_committed)
	_canvas.canvas_size_changed.connect(_on_canvas_size_changed)
	_canvas.view_changed.connect(_on_view_changed)
	_canvas.color_picked.connect(_on_color_picked)
	_canvas.selection_committed.connect(_on_selection_committed)
	_canvas.selection_cleared.connect(_on_selection_cleared)
	_canvas.image_drop_requested.connect(_on_canvas_image_drop_requested)
	_canvas.image_changed.connect(_on_canvas_image_changed)
	_canvas.hover_uv_changed.connect(_on_canvas_hover_uv_changed)
	_canvas.text_draft_started.connect(_on_text_draft_started)
	_canvas.text_draft_finished.connect(_on_text_draft_finished)
	_canvas.text_draft_copied.connect(_on_text_draft_copied)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas_2d_host.add_child(_canvas)

	_paint_3d_view = _create_3d_paint_view()
	if _paint_3d_view:
		_paint_3d_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_canvas_3d_host.add_child(_paint_3d_view)
	_build_3d_empty_state()
	_build_canvas_view_controls()


func _make_canvas_control() -> Control:
	return _make_script_instance(CANVAS_SCRIPT_PATH, Control.new()) as Control


func _create_3d_paint_view() -> SubViewportContainer:
	var view := MeshDropViewport.new()
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.focus_mode = Control.FOCUS_CLICK
	view.mouse_default_cursor_shape = Control.CURSOR_CROSS
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(360, 220)
	view.gui_input.connect(_on_3d_paint_view_gui_input)
	view.mouse_exited.connect(_hide_3d_brush_preview)
	view.mouse_exited.connect(_on_3d_paint_view_mouse_exited)
	view.mesh_data_dropped.connect(_on_3d_mesh_drop_requested)

	_paint_3d_viewport = SubViewport.new()
	_paint_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_paint_3d_viewport.transparent_bg = false
	view.add_child(_paint_3d_viewport)

	var world := World3D.new()
	_paint_3d_viewport.world_3d = world
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = PAINT_3D_BACKGROUND_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = PAINT_3D_PREVIEW_AMBIENT_ENERGY
	world.environment.fog_enabled = false

	_paint_3d_root = Node3D.new()
	_paint_3d_viewport.add_child(_paint_3d_root)
	_create_3d_paint_stage()

	_paint_3d_camera = Camera3D.new()
	_paint_3d_camera.fov = 42.0
	_paint_3d_camera.near = 0.01
	_paint_3d_camera.far = 500.0
	_paint_3d_root.add_child(_paint_3d_camera)

	_paint_3d_preview_light = DirectionalLight3D.new()
	_paint_3d_preview_light.name = "Neutral Preview Light"
	_paint_3d_preview_light.light_color = Color.WHITE
	_paint_3d_preview_light.light_energy = _clamp_preview_light_intensity(_preview_light_intensity_value)
	_paint_3d_preview_light.shadow_enabled = false
	_paint_3d_preview_light.rotation_degrees = PAINT_3D_PREVIEW_LIGHT_DEFAULT_ROTATION
	_paint_3d_preview_light.visible = _preview_light_enabled
	_paint_3d_root.add_child(_paint_3d_preview_light)
	_create_3d_rotation_gizmo()
	return view


func _create_3d_paint_stage() -> void:
	_paint_3d_stage_root = Node3D.new()
	_paint_3d_stage_root.name = "Paint Stage"
	_paint_3d_root.add_child(_paint_3d_stage_root)

	_paint_3d_stage_floor = MeshInstance3D.new()
	_paint_3d_stage_floor.name = "Floor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(PAINT_3D_STAGE_MIN_SIZE, PAINT_3D_STAGE_MIN_SIZE)
	_paint_3d_stage_floor.mesh = floor_mesh
	_paint_3d_stage_floor.material_override = _make_3d_stage_floor_material()
	_paint_3d_stage_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_paint_3d_stage_root.add_child(_paint_3d_stage_floor)

	_paint_3d_stage_grid = MeshInstance3D.new()
	_paint_3d_stage_grid.name = "Grid"
	_paint_3d_stage_grid.material_override = _make_3d_stage_grid_material()
	_paint_3d_stage_root.add_child(_paint_3d_stage_grid)
	_update_3d_paint_stage(AABB(), PAINT_3D_STAGE_MIN_SIZE)
	_apply_3d_preview_grid_state()


func _make_3d_stage_floor_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.205, 0.21, 0.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_3d_stage_grid_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform float camera_fade_near = 6.0;
uniform float camera_fade_far = 20.0;
uniform float edge_fade_near = 3.0;
uniform float edge_fade_far = 4.0;
varying vec3 grid_world_position;
varying vec3 grid_local_position;

void vertex() {
	grid_local_position = VERTEX;
	grid_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float camera_distance = distance(grid_world_position, CAMERA_POSITION_WORLD);
	float camera_alpha = 1.0 - smoothstep(camera_fade_near, camera_fade_far, camera_distance);
	float edge_alpha = 1.0 - smoothstep(edge_fade_near, edge_fade_far, length(grid_local_position.xz));
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * min(camera_alpha, edge_alpha);
}
"""
	material.shader = shader
	_configure_3d_stage_grid_fade(material, PAINT_3D_STAGE_MIN_SIZE)
	return material


func _configure_3d_stage_grid_fade(material: ShaderMaterial, stage_size: float) -> void:
	material.set_shader_parameter("camera_fade_near", stage_size * 0.8)
	material.set_shader_parameter("camera_fade_far", stage_size * 2.5)
	material.set_shader_parameter("edge_fade_near", stage_size * 0.35)
	material.set_shader_parameter("edge_fade_far", stage_size * 0.5)


func _create_3d_rotation_gizmo() -> void:
	if _paint_3d_rotation_gizmo or not _paint_3d_root:
		return
	_paint_3d_rotation_gizmo = Node3D.new()
	_paint_3d_rotation_gizmo.name = "Preview Rotation Gizmo"
	_paint_3d_rotation_gizmo.visible = false
	_paint_3d_root.add_child(_paint_3d_rotation_gizmo)
	_paint_3d_gizmo_rings.clear()
	_paint_3d_gizmo_materials.clear()
	_paint_3d_gizmo_translation_axes.clear()
	_paint_3d_gizmo_translation_materials.clear()
	for axis_index in range(3):
		var ring := MeshInstance3D.new()
		ring.name = ["X Rotation Ring", "Y Rotation Ring", "Z Rotation Ring"][axis_index]
		ring.mesh = _make_3d_rotation_gizmo_ring_mesh(axis_index)
		var material := _make_3d_rotation_gizmo_material(PAINT_3D_GIZMO_AXIS_COLORS[axis_index])
		ring.material_override = material
		_paint_3d_rotation_gizmo.add_child(ring)
		_paint_3d_gizmo_rings.push_back(ring)
		_paint_3d_gizmo_materials.push_back(material)
		var arrow := MeshInstance3D.new()
		arrow.name = ["X Translation Handle", "Y Translation Handle", "Z Translation Handle"][axis_index]
		arrow.mesh = _make_3d_translation_gizmo_mesh(axis_index)
		var arrow_material := _make_3d_rotation_gizmo_material(PAINT_3D_GIZMO_AXIS_COLORS[axis_index])
		arrow_material.resource_name = "GDDraw Preview Translation Handle"
		arrow.material_override = arrow_material
		_paint_3d_rotation_gizmo.add_child(arrow)
		_paint_3d_gizmo_translation_axes.push_back(arrow)
		_paint_3d_gizmo_translation_materials.push_back(arrow_material)


func _make_3d_rotation_gizmo_ring_mesh(axis_index: int) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var tube_radius := PAINT_3D_GIZMO_RING_WIDTH_PIXELS / PAINT_3D_GIZMO_RADIUS_PIXELS * 0.5
	var ring_axis := _get_3d_gizmo_axis(axis_index)
	var tube_sides := 6
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(PAINT_3D_GIZMO_SEGMENTS):
		var angle_a := TAU * float(segment) / float(PAINT_3D_GIZMO_SEGMENTS)
		var angle_b := TAU * float(segment + 1) / float(PAINT_3D_GIZMO_SEGMENTS)
		var center_a := _get_3d_gizmo_ring_point(axis_index, angle_a)
		var center_b := _get_3d_gizmo_ring_point(axis_index, angle_b)
		for tube_side in range(tube_sides):
			var tube_angle_a := TAU * float(tube_side) / float(tube_sides)
			var tube_angle_b := TAU * float(tube_side + 1) / float(tube_sides)
			var offset_aa := (ring_axis * cos(tube_angle_a) + center_a * sin(tube_angle_a)) * tube_radius
			var offset_ab := (ring_axis * cos(tube_angle_b) + center_a * sin(tube_angle_b)) * tube_radius
			var offset_ba := (ring_axis * cos(tube_angle_a) + center_b * sin(tube_angle_a)) * tube_radius
			var offset_bb := (ring_axis * cos(tube_angle_b) + center_b * sin(tube_angle_b)) * tube_radius
			mesh.surface_add_vertex(center_a + offset_aa)
			mesh.surface_add_vertex(center_a + offset_ab)
			mesh.surface_add_vertex(center_b + offset_bb)
			mesh.surface_add_vertex(center_a + offset_aa)
			mesh.surface_add_vertex(center_b + offset_bb)
			mesh.surface_add_vertex(center_b + offset_ba)
	mesh.surface_end()
	return mesh


func _make_3d_translation_gizmo_mesh(axis_index: int) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var axis := _get_3d_gizmo_axis(axis_index)
	var radial_a := axis.cross(Vector3.UP)
	if radial_a.length_squared() <= 0.000001:
		radial_a = axis.cross(Vector3.RIGHT)
	radial_a = radial_a.normalized()
	var radial_b := axis.cross(radial_a).normalized()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in range(PAINT_3D_GIZMO_ARROW_SIDES):
		var angle_a := TAU * float(side) / float(PAINT_3D_GIZMO_ARROW_SIDES)
		var angle_b := TAU * float(side + 1) / float(PAINT_3D_GIZMO_ARROW_SIDES)
		var radial_direction_a := radial_a * cos(angle_a) + radial_b * sin(angle_a)
		var radial_direction_b := radial_a * cos(angle_b) + radial_b * sin(angle_b)
		var shaft_a0 := axis * PAINT_3D_GIZMO_ARROW_SHAFT_START + radial_direction_a * PAINT_3D_GIZMO_ARROW_SHAFT_RADIUS
		var shaft_b0 := axis * PAINT_3D_GIZMO_ARROW_SHAFT_START + radial_direction_b * PAINT_3D_GIZMO_ARROW_SHAFT_RADIUS
		var shaft_a1 := axis * PAINT_3D_GIZMO_ARROW_HEAD_START + radial_direction_a * PAINT_3D_GIZMO_ARROW_SHAFT_RADIUS
		var shaft_b1 := axis * PAINT_3D_GIZMO_ARROW_HEAD_START + radial_direction_b * PAINT_3D_GIZMO_ARROW_SHAFT_RADIUS
		mesh.surface_add_vertex(shaft_a0)
		mesh.surface_add_vertex(shaft_a1)
		mesh.surface_add_vertex(shaft_b1)
		mesh.surface_add_vertex(shaft_a0)
		mesh.surface_add_vertex(shaft_b1)
		mesh.surface_add_vertex(shaft_b0)
		var head_a := axis * PAINT_3D_GIZMO_ARROW_HEAD_START + radial_direction_a * PAINT_3D_GIZMO_ARROW_HEAD_RADIUS
		var head_b := axis * PAINT_3D_GIZMO_ARROW_HEAD_START + radial_direction_b * PAINT_3D_GIZMO_ARROW_HEAD_RADIUS
		var tip := axis * PAINT_3D_GIZMO_ARROW_LENGTH
		mesh.surface_add_vertex(head_a)
		mesh.surface_add_vertex(tip)
		mesh.surface_add_vertex(head_b)
	mesh.surface_end()
	return mesh


func _make_3d_rotation_gizmo_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "GDDraw Preview Rotation Ring"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.disable_fog = true
	material.render_priority = 1
	return material


func _get_3d_gizmo_ring_point(axis_index: int, angle: float) -> Vector3:
	var cosine := cos(angle)
	var sine := sin(angle)
	match axis_index:
		0:
			return Vector3(0.0, cosine, sine)
		1:
			return Vector3(cosine, 0.0, sine)
		_:
			return Vector3(cosine, sine, 0.0)


func _get_3d_gizmo_axis(axis_index: int) -> Vector3:
	match axis_index:
		0:
			return Vector3.RIGHT
		1:
			return Vector3.UP
		_:
			return Vector3.BACK


func _update_3d_rotation_gizmo_visibility() -> void:
	if not _paint_3d_rotation_gizmo:
		return
	var has_session: bool = _texture_3d_session != null and _texture_3d_session.has_active_session()
	_paint_3d_rotation_gizmo.visible = (
		_paint_3d_gizmo_visible
		and _canvas_mode_3d
		and has_session
		and _paint_3d_mesh != null
		and _paint_3d_mesh.mesh != null
	)
	if not _paint_3d_rotation_gizmo.visible:
		_cancel_3d_rotation_gizmo_drag(false)
		_set_3d_transform_gizmo_hover(GIZMO_CONTROL_NONE, -1)
	_update_3d_transform_gizmo_component_visibility()


func _update_3d_transform_gizmo_component_visibility() -> void:
	for axis_index in range(3):
		if axis_index < _paint_3d_gizmo_rings.size():
			_paint_3d_gizmo_rings[axis_index].visible = (
				not _paint_3d_gizmo_dragging
				or (_paint_3d_gizmo_active_control == GIZMO_CONTROL_ROTATION and axis_index == _paint_3d_gizmo_active_axis)
			)
		if axis_index < _paint_3d_gizmo_translation_axes.size():
			_paint_3d_gizmo_translation_axes[axis_index].visible = (
				not _paint_3d_gizmo_dragging
				or (_paint_3d_gizmo_active_control == GIZMO_CONTROL_TRANSLATION and axis_index == _paint_3d_gizmo_active_axis)
			)


func _update_3d_rotation_gizmo_transform() -> void:
	if not _paint_3d_rotation_gizmo or not _paint_3d_mesh or not _paint_3d_mesh.mesh:
		return
	var preview_transform: Transform3D = _paint_3d_mesh.transform
	var transformed_aabb := _get_transformed_3d_aabb(_paint_3d_mesh.mesh.get_aabb(), preview_transform)
	_paint_3d_model_center = transformed_aabb.get_center()
	var world_scale := _get_3d_rotation_gizmo_world_scale()
	_paint_3d_rotation_gizmo.transform = Transform3D(
		Basis.IDENTITY.scaled(Vector3.ONE * world_scale),
		_paint_3d_model_center
	)


func _get_3d_rotation_gizmo_world_scale(distance_override := -1.0, viewport_height_override := -1.0) -> float:
	if not _paint_3d_camera:
		return 1.0
	var distance: float = distance_override
	if distance <= 0.0:
		var camera_to_center := _paint_3d_model_center - _paint_3d_camera.global_position
		distance = absf(camera_to_center.dot(-_paint_3d_camera.global_transform.basis.z.normalized()))
	var viewport_height: float = viewport_height_override
	if viewport_height <= 0.0 and _paint_3d_view:
		viewport_height = _paint_3d_view.size.y
	if viewport_height <= 0.0 and _paint_3d_viewport:
		viewport_height = float(_paint_3d_viewport.size.y)
	viewport_height = maxf(1.0, viewport_height)
	var world_height := 2.0 * maxf(distance, _paint_3d_camera.near) * tan(deg_to_rad(_paint_3d_camera.fov) * 0.5)
	return maxf(0.0001, world_height * PAINT_3D_GIZMO_RADIUS_PIXELS / viewport_height)


func _set_3d_transform_gizmo_hover(control_type: int, axis_index: int) -> void:
	if _paint_3d_gizmo_hover_control == control_type and _paint_3d_gizmo_hover_axis == axis_index and not _paint_3d_gizmo_dragging:
		return
	_paint_3d_gizmo_hover_control = control_type
	_paint_3d_gizmo_hover_axis = axis_index
	_update_3d_rotation_gizmo_materials()


func _set_3d_rotation_gizmo_hover_axis(axis_index: int) -> void:
	_set_3d_transform_gizmo_hover(GIZMO_CONTROL_ROTATION if axis_index >= 0 else GIZMO_CONTROL_NONE, axis_index)


func _update_3d_rotation_gizmo_materials() -> void:
	for axis_index in range(_paint_3d_gizmo_materials.size()):
		var color: Color = PAINT_3D_GIZMO_AXIS_COLORS[axis_index]
		if _paint_3d_gizmo_active_control == GIZMO_CONTROL_ROTATION and axis_index == _paint_3d_gizmo_active_axis:
			color = color.lerp(Color.WHITE, 0.42)
			color.a = 1.0
		elif _paint_3d_gizmo_hover_control == GIZMO_CONTROL_ROTATION and axis_index == _paint_3d_gizmo_hover_axis:
			color = color.lerp(Color.WHITE, 0.25)
			color.a = 0.84
		_paint_3d_gizmo_materials[axis_index].albedo_color = color
	for axis_index in range(_paint_3d_gizmo_translation_materials.size()):
		var color: Color = PAINT_3D_GIZMO_AXIS_COLORS[axis_index]
		if _paint_3d_gizmo_active_control == GIZMO_CONTROL_TRANSLATION and axis_index == _paint_3d_gizmo_active_axis:
			color = color.lerp(Color.WHITE, 0.42)
			color.a = 1.0
		elif _paint_3d_gizmo_hover_control == GIZMO_CONTROL_TRANSLATION and axis_index == _paint_3d_gizmo_hover_axis:
			color = color.lerp(Color.WHITE, 0.25)
			color.a = 0.84
		_paint_3d_gizmo_translation_materials[axis_index].albedo_color = color


func _build_canvas_view_controls() -> void:
	var view_controls := HBoxContainer.new()
	view_controls.name = "2D View Tools"
	view_controls.anchor_left = 1.0
	view_controls.anchor_right = 1.0
	view_controls.offset_left = -112.0
	view_controls.offset_top = 8.0
	view_controls.offset_right = -8.0
	view_controls.offset_bottom = 36.0
	view_controls.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	_canvas_2d_host.add_child(view_controls)

	_preview_orientation_controls = VBoxContainer.new()
	_preview_orientation_controls.name = "3D Preview Controls"
	_preview_orientation_controls.anchor_left = 1.0
	_preview_orientation_controls.anchor_right = 1.0
	_preview_orientation_controls.offset_left = -312.0
	_preview_orientation_controls.offset_top = 8.0
	_preview_orientation_controls.offset_right = -8.0
	_preview_orientation_controls.offset_bottom = 96.0
	_preview_orientation_controls.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	_preview_orientation_controls.visible = false
	_canvas_3d_host.add_child(_preview_orientation_controls)
	_preview_light_controls_row = HBoxContainer.new()
	_preview_light_controls_row.name = "Preview Lighting Row"
	_preview_light_controls_row.alignment = BoxContainer.ALIGNMENT_END
	_preview_light_controls_row.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	_preview_orientation_controls.add_child(_preview_light_controls_row)
	_preview_transform_controls_row = HBoxContainer.new()
	_preview_transform_controls_row.name = "Preview Transform Row"
	_preview_transform_controls_row.alignment = BoxContainer.ALIGNMENT_END
	_preview_transform_controls_row.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	_preview_orientation_controls.add_child(_preview_transform_controls_row)
	_preview_grid_controls_row = HBoxContainer.new()
	_preview_grid_controls_row.name = "Preview Grid Row"
	_preview_grid_controls_row.alignment = BoxContainer.ALIGNMENT_END
	_preview_grid_controls_row.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	_preview_orientation_controls.add_child(_preview_grid_controls_row)

	_preview_light_toggle = _make_icon_button("sun_0.svg", "Toggle neutral lighting in the 3D preview.", true)
	_preview_light_toggle.name = "Neutral Preview Light"
	_preview_light_toggle.set_pressed_no_signal(_preview_light_enabled)
	_update_toggle_button_icon(_preview_light_toggle)
	_preview_light_toggle.toggled.connect(_on_preview_light_toggled)
	_preview_light_controls_row.add_child(_preview_light_toggle)

	_preview_light_intensity = SpinBox.new()
	_preview_light_intensity.name = "Neutral Preview Light Intensity"
	_preview_light_intensity.min_value = PAINT_3D_PREVIEW_LIGHT_MIN
	_preview_light_intensity.max_value = PAINT_3D_PREVIEW_LIGHT_MAX
	_preview_light_intensity.step = 0.05
	_preview_light_intensity.custom_minimum_size = Vector2(72, TOOL_BUTTON_SIZE.y)
	_preview_light_intensity.update_on_text_changed = true
	_preview_light_intensity.tooltip_text = "Adjust the neutral light intensity in the 3D preview."
	_preview_light_intensity.set_value_no_signal(_clamp_preview_light_intensity(_preview_light_intensity_value))
	_apply_preferences_spinbox_style(_preview_light_intensity)
	_preview_light_intensity.value_changed.connect(_on_preview_light_intensity_changed)
	_preview_light_controls_row.add_child(_preview_light_intensity)

	_preview_light_link_toggle = _make_icon_button(
		"unlink_0.svg",
		"Link the neutral light direction to the 3D preview camera.",
		true,
		"link_1.svg"
	)
	_preview_light_link_toggle.name = "Link Preview Light to Camera"
	_preview_light_link_toggle.set_pressed_no_signal(_preview_light_camera_linked)
	_update_toggle_button_icon(_preview_light_link_toggle)
	_preview_light_link_toggle.toggled.connect(_on_preview_light_camera_link_toggled)
	_preview_light_controls_row.add_child(_preview_light_link_toggle)

	_preview_light_reset_button = _make_icon_button(
		"refresh-ccw_0.svg",
		"Unlink and reset the neutral light direction."
	)
	_preview_light_reset_button.name = "Reset Preview Light Direction"
	_preview_light_reset_button.pressed.connect(_reset_preview_light_orientation)
	_preview_light_controls_row.add_child(_preview_light_reset_button)

	_preview_orientation_button = _make_icon_button(
		"rotate-3d_0.svg",
		"Show the X/Y/Z transform gizmo in the 3D preview.",
		true,
		"rotate-3d_1.svg"
	)
	_preview_orientation_button.name = "Show Preview Transform Gizmo"
	_preview_orientation_button.set_pressed_no_signal(_paint_3d_gizmo_visible)
	_update_toggle_button_icon(_preview_orientation_button)
	_preview_orientation_button.visible = false
	_preview_orientation_button.toggled.connect(_on_preview_rotation_gizmo_toggled)
	_preview_transform_controls_row.add_child(_preview_orientation_button)

	_preview_scene_orientation_button = _make_icon_button(
		"unlink_0.svg",
		"Link the source scene transform to the 3D preview.",
		true,
		"link_1.svg"
	)
	_preview_scene_orientation_button.name = "Link Preview to Scene Transform"
	_preview_scene_orientation_button.set_pressed_no_signal(false)
	_apply_scene_transform_link_control_state(false)
	_preview_scene_orientation_button.toggled.connect(_on_scene_transform_link_toggled)
	_preview_transform_controls_row.add_child(_preview_scene_orientation_button)

	_preview_3d_grid_button = _make_icon_button(
		"grid-3x3_0.svg",
		"Show or hide the perspective grid in the 3D preview.",
		true,
		"grid-3x3_1.svg"
	)
	_preview_3d_grid_button.name = "Show 3D Preview Grid"
	_preview_3d_grid_button.set_pressed_no_signal(_preview_3d_grid_visible)
	_update_toggle_button_icon(_preview_3d_grid_button)
	_preview_3d_grid_button.toggled.connect(_on_preview_3d_grid_toggled)
	_preview_grid_controls_row.add_child(_preview_3d_grid_button)
	_apply_3d_preview_grid_state()

	_preview_orientation_reset_button = _make_icon_button(
		"refresh-ccw_0.svg",
		"Reset the 3D preview transform and disable scene linking."
	)
	_preview_orientation_reset_button.name = "Reset Preview Transform"
	_preview_orientation_reset_button.pressed.connect(_on_reset_preview_orientation_pressed)
	_preview_transform_controls_row.add_child(_preview_orientation_reset_button)
	_apply_preview_lighting_state()

	_pan_button = _make_icon_button("move_0.svg", "Pan", true, "move_1.svg")
	_pan_button.toggled.connect(_on_pan_toggled)
	view_controls.add_child(_pan_button)

	_grid_button = _make_icon_button("grid-3x3_0.svg", "Show grid", true)
	_grid_button.toggled.connect(_on_grid_button_toggled)
	view_controls.add_child(_grid_button)

	_snap_to_grid_button = _make_icon_button("magnet_0.svg", "Snap drawing, shapes, and selections to the current grid cell boundaries; works even when the grid overlay is hidden", true)
	_snap_to_grid_button.set_pressed_no_signal(_canvas.snap_to_grid)
	_update_toggle_button_icon(_snap_to_grid_button)
	_snap_to_grid_button.toggled.connect(_on_snap_to_grid_toggled)
	view_controls.add_child(_snap_to_grid_button)

	var zoom_2d_controls := HBoxContainer.new()
	zoom_2d_controls.name = "2D Zoom Controls"
	zoom_2d_controls.anchor_left = 1.0
	zoom_2d_controls.anchor_top = 1.0
	zoom_2d_controls.anchor_right = 1.0
	zoom_2d_controls.anchor_bottom = 1.0
	zoom_2d_controls.offset_left = -190.0
	zoom_2d_controls.offset_top = -36.0
	zoom_2d_controls.offset_right = -8.0
	zoom_2d_controls.offset_bottom = -8.0
	zoom_2d_controls.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	_canvas_2d_host.add_child(zoom_2d_controls)

	_zoom_out_button = _make_icon_button("zoom-out_0.svg", "Zoom out 2D canvas")
	_zoom_out_button.pressed.connect(_canvas.zoom_out)
	zoom_2d_controls.add_child(_zoom_out_button)
	_zoom_label = Label.new()
	_zoom_label.custom_minimum_size.x = 58
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_zoom_readout_style(_zoom_label)
	zoom_2d_controls.add_child(_zoom_label)
	_zoom_in_button = _make_icon_button("zoom-in_0.svg", "Zoom in 2D canvas")
	_zoom_in_button.pressed.connect(_canvas.zoom_in)
	zoom_2d_controls.add_child(_zoom_in_button)
	var reset_2d_button := _make_icon_button("refresh-ccw_0.svg", "Reset 2D view")
	reset_2d_button.name = "Reset 2D View"
	reset_2d_button.pressed.connect(_canvas.reset_view)
	zoom_2d_controls.add_child(reset_2d_button)

	var zoom_3d_controls := HBoxContainer.new()
	zoom_3d_controls.name = "3D Zoom Controls"
	zoom_3d_controls.anchor_left = 1.0
	zoom_3d_controls.anchor_top = 1.0
	zoom_3d_controls.anchor_right = 1.0
	zoom_3d_controls.anchor_bottom = 1.0
	zoom_3d_controls.offset_left = -190.0
	zoom_3d_controls.offset_top = -36.0
	zoom_3d_controls.offset_right = -8.0
	zoom_3d_controls.offset_bottom = -8.0
	zoom_3d_controls.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	_canvas_3d_host.add_child(zoom_3d_controls)

	_zoom_3d_out_button = _make_icon_button("zoom-out_0.svg", "Zoom out 3D preview")
	_zoom_3d_out_button.pressed.connect(_zoom_3d_out)
	zoom_3d_controls.add_child(_zoom_3d_out_button)
	_zoom_3d_label = Label.new()
	_zoom_3d_label.custom_minimum_size.x = 72
	_zoom_3d_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_3d_label.tooltip_text = "3D camera distance"
	_apply_zoom_readout_style(_zoom_3d_label)
	zoom_3d_controls.add_child(_zoom_3d_label)
	_zoom_3d_in_button = _make_icon_button("zoom-in_0.svg", "Zoom in 3D preview")
	_zoom_3d_in_button.pressed.connect(_zoom_3d_in)
	zoom_3d_controls.add_child(_zoom_3d_in_button)
	var frame_3d_button := _make_icon_button("refresh-ccw_0.svg", "Frame 3D mesh")
	frame_3d_button.name = "Frame 3D Mesh"
	frame_3d_button.pressed.connect(_frame_active_3d_mesh)
	zoom_3d_controls.add_child(frame_3d_button)


func _apply_zoom_readout_style(label: Label) -> void:
	label.custom_minimum_size.y = TOOL_BUTTON_SIZE.y
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _make_tool_button_style(TOOL_BUTTON_PANEL_COLOR))
	label.add_theme_color_override("font_color", Color("#C4C4C4"))


func _build_canvas_size_controls(parent: Container) -> void:
	var description := Label.new()
	description.text = "Change the canvas bounds with optional pixel preservation."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(description)

	var fields := GridContainer.new()
	fields.columns = 2
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("h_separation", 12)
	fields.add_theme_constant_override("v_separation", 8)
	parent.add_child(fields)

	var width_label := Label.new()
	width_label.text = "Width"
	fields.add_child(width_label)

	_canvas_width = _make_dimension_spinbox()
	_canvas_width.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_width.tooltip_text = "Canvas width in pixels"
	_canvas_width.value_changed.connect(_on_canvas_width_changed)
	fields.add_child(_canvas_width)

	var height_label := Label.new()
	height_label.text = "Height"
	fields.add_child(height_label)

	_canvas_height = _make_dimension_spinbox()
	_canvas_height.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_height.tooltip_text = "Canvas height in pixels"
	_canvas_height.value_changed.connect(_on_canvas_height_changed)
	fields.add_child(_canvas_height)

	var aspect_label := Label.new()
	aspect_label.text = "Preserve Aspect"
	fields.add_child(aspect_label)

	_resize_link_button = CheckBox.new()
	_resize_link_button.button_pressed = true
	_update_resize_link_tooltip()
	_resize_link_button.toggled.connect(_on_resize_link_toggled)
	fields.add_child(_resize_link_button)

	var keep_label := Label.new()
	keep_label.text = "Keep Existing Pixels"
	fields.add_child(keep_label)

	_keep_pixels = CheckBox.new()
	_keep_pixels.button_pressed = true
	_keep_pixels.tooltip_text = "Keep existing pixels when resizing"
	fields.add_child(_keep_pixels)
	_update_canvas_resize_control_availability()


func _build_canvas_resize_dialog() -> void:
	_canvas_resize_dialog = ConfirmationDialog.new()
	_canvas_resize_dialog.name = "Canvas Resize Dialog"
	_canvas_resize_dialog.title = "Resize Canvas"
	_canvas_resize_dialog.ok_button_text = "Resize"
	_canvas_resize_dialog.min_size = CANVAS_RESIZE_DIALOG_SIZE
	_canvas_resize_dialog.max_size = CANVAS_RESIZE_DIALOG_SIZE
	_canvas_resize_dialog.unresizable = true
	_canvas_resize_dialog.confirmed.connect(_resize_canvas)
	add_child(_canvas_resize_dialog)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(372.0, 128.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_theme_constant_override("separation", 12)
	_canvas_resize_dialog.add_child(content)
	_build_canvas_size_controls(content)


func _start_resize_canvas() -> void:
	if _reject_locked_canvas_resize():
		return
	_on_canvas_size_changed(_canvas.get_canvas_size())
	_canvas_resize_dialog.size = CANVAS_RESIZE_DIALOG_SIZE
	_canvas_resize_dialog.popup_centered(CANVAS_RESIZE_DIALOG_SIZE)


func _build_settings_menu() -> void:
	_settings_overlay = PanelContainer.new()
	_settings_overlay.visible = false
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.anchor_left = 0.0
	_settings_overlay.anchor_top = 0.0
	_settings_overlay.anchor_right = 1.0
	_settings_overlay.anchor_bottom = 1.0
	_settings_overlay.offset_left = 0.0
	_settings_overlay.offset_top = 0.0
	_settings_overlay.offset_right = 0.0
	_settings_overlay.offset_bottom = 0.0
	var settings_background := StyleBoxFlat.new()
	settings_background.bg_color = _get_preferences_background_color()
	_settings_overlay.add_theme_stylebox_override("panel", settings_background)
	_workspace_region.add_child(_settings_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_settings_overlay.add_child(margin)

	_settings_panel = VBoxContainer.new()
	_settings_panel.add_theme_constant_override("separation", 8)
	margin.add_child(_settings_panel)

	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_panel.add_child(header_row)

	var title_label := Label.new()
	title_label.text = "Preferences"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.tooltip_text = "Close Preferences (Escape)"
	_apply_preferences_close_button_style(close_button)
	close_button.pressed.connect(_close_preferences)
	header_row.add_child(close_button)

	var header_separator := HSeparator.new()
	_settings_panel.add_child(header_separator)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_panel.add_child(tabs)

	var brush_tab := _add_preferences_tab(tabs, "Brush")

	var brush_section := _add_preferences_section(
		brush_tab,
		"Brush mode",
		"Brush mode controls how strokes are applied while drawing. Pixel perfect keeps marks aligned to exact image pixels; stroke overlap allows repeated passes during one stroke to build opacity."
	)
	var brush_mode_row := _add_preferences_control_row(brush_section)
	var brush_mode_label := Label.new()
	brush_mode_label.text = "Draw mode"
	brush_mode_label.custom_minimum_size.x = 90
	brush_mode_row.add_child(brush_mode_label)

	_brush_mode_selector = OptionButton.new()
	_brush_mode_selector.add_item("Pixel Perfect", 0)
	_brush_mode_selector.add_item("Antialiasing", 1)
	_brush_mode_selector.selected = 0
	_brush_mode_selector.custom_minimum_size.x = 150
	_brush_mode_selector.tooltip_text = "Choose exact pixel drawing or smoother antialiased brush edges"
	_brush_mode_selector.item_selected.connect(_on_brush_mode_selected)
	brush_mode_row.add_child(_brush_mode_selector)

	var brush_mode_spacer := Control.new()
	brush_mode_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brush_mode_row.add_child(brush_mode_spacer)

	_brush_hardness_row = _add_preferences_control_row(brush_section)
	var brush_hardness_label := Label.new()
	brush_hardness_label.text = "Hardness"
	brush_hardness_label.custom_minimum_size.x = 90
	_brush_hardness_row.add_child(brush_hardness_label)

	_brush_hardness = SpinBox.new()
	_brush_hardness.min_value = 0
	_brush_hardness.max_value = 100
	_brush_hardness.suffix = "%"
	_brush_hardness.value = 75
	_brush_hardness.custom_minimum_size.x = 76
	_brush_hardness.tooltip_text = "Antialiased brush hardness; hidden when Pixel Perfect mode is active"
	_apply_preferences_spinbox_style(_brush_hardness)
	_brush_hardness.value_changed.connect(_on_brush_hardness_changed)
	_brush_hardness_row.add_child(_brush_hardness)

	var brush_hardness_spacer := Control.new()
	brush_hardness_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brush_hardness_row.add_child(brush_hardness_spacer)

	var brush_row := _add_preferences_control_row(brush_section)

	_stroke_overlap = CheckBox.new()
	_stroke_overlap.text = "Allow stroke overlap"
	_stroke_overlap.button_pressed = true
	_stroke_overlap.tooltip_text = "Allow repeated passes within one brush stroke to build up color; disable for consistent color-picker opacity"
	_stroke_overlap.toggled.connect(_on_stroke_overlap_toggled)
	brush_row.add_child(_stroke_overlap)

	var brush_spacer := Control.new()
	brush_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brush_row.add_child(brush_spacer)
	_sync_brush_mode_controls()

	var view_tab := _add_preferences_tab(tabs, "View")

	var grid_section := _add_preferences_section(
		view_tab,
		"Grid",
		"Grid settings control the 2D canvas pixel grid overlay. The grid only becomes useful once the canvas is zoomed in far enough for individual cells to be visible."
	)
	var grid_row := _add_preferences_control_row(grid_section)

	_show_grid = CheckBox.new()
	_show_grid.text = "Show"
	_show_grid.tooltip_text = "Show the image pixel grid when zoomed enough"
	_show_grid.toggled.connect(_on_show_grid_toggled)
	grid_row.add_child(_show_grid)

	_snap_to_grid = CheckBox.new()
	_snap_to_grid.text = "Snap"
	_snap_to_grid.set_pressed_no_signal(_canvas.snap_to_grid)
	_snap_to_grid.tooltip_text = "Snap brush strokes, shape endpoints, and selection geometry to the current grid cell boundaries; works even when the grid overlay is hidden"
	_snap_to_grid.toggled.connect(_on_snap_to_grid_toggled)
	grid_row.add_child(_snap_to_grid)

	var grid_size_label := Label.new()
	grid_size_label.text = "Size"
	grid_row.add_child(grid_size_label)

	_grid_size = _make_integer_line_edit("1", "Grid cell size in image pixels")
	_grid_size.tooltip_text = "Grid cell size in image pixels"
	_grid_size.custom_minimum_size.x = 48
	_grid_size.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid_size.text_submitted.connect(_on_grid_size_submitted)
	_grid_size.focus_exited.connect(_on_grid_size_focus_exited)
	grid_row.add_child(_grid_size)

	var grid_min_label := Label.new()
	grid_min_label.text = "Min px"
	grid_row.add_child(grid_min_label)

	_grid_min_cell_size = _make_integer_line_edit("6", "Minimum displayed grid cell size")
	_grid_min_cell_size.tooltip_text = "Minimum displayed grid cell size"
	_grid_min_cell_size.custom_minimum_size.x = 48
	_grid_min_cell_size.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid_min_cell_size.text_submitted.connect(_on_grid_min_cell_size_submitted)
	_grid_min_cell_size.focus_exited.connect(_on_grid_min_cell_size_focus_exited)
	grid_row.add_child(_grid_min_cell_size)

	var grid_color_label := Label.new()
	grid_color_label.text = "Color"
	grid_row.add_child(grid_color_label)

	_grid_color_picker = ColorPickerButton.new()
	_grid_color_picker.color = Color(0.1, 0.45, 0.9, 0.55)
	_grid_color_picker.edit_alpha = true
	_grid_color_picker.custom_minimum_size = Vector2(36, 28)
	_grid_color_picker.tooltip_text = "Grid line color"
	_grid_color_picker.color_changed.connect(_on_grid_color_changed)
	grid_row.add_child(_grid_color_picker)

	var grid_spacer := Control.new()
	grid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_row.add_child(grid_spacer)

	var checker_section := _add_preferences_section(
		view_tab,
		"Transparency",
		"Transparency settings control the checkerboard colors shown behind transparent pixels. These are display colors only and do not change image pixels."
	)
	var checker_row := _add_preferences_control_row(checker_section)
	var checker_light_label := Label.new()
	checker_light_label.text = "Light"
	checker_row.add_child(checker_light_label)
	_checker_light_picker = ColorPickerButton.new()
	_checker_light_picker.color = _canvas.checker_color_light
	_checker_light_picker.edit_alpha = false
	_checker_light_picker.custom_minimum_size = Vector2(42, 28)
	_checker_light_picker.tooltip_text = "Light checkerboard display color"
	_checker_light_picker.color_changed.connect(_on_checker_light_changed)
	checker_row.add_child(_checker_light_picker)

	var checker_dark_label := Label.new()
	checker_dark_label.text = "Dark"
	checker_row.add_child(checker_dark_label)
	_checker_dark_picker = ColorPickerButton.new()
	_checker_dark_picker.color = _canvas.checker_color_dark
	_checker_dark_picker.edit_alpha = false
	_checker_dark_picker.custom_minimum_size = Vector2(42, 28)
	_checker_dark_picker.tooltip_text = "Dark checkerboard display color"
	_checker_dark_picker.color_changed.connect(_on_checker_dark_changed)
	checker_row.add_child(_checker_dark_picker)

	var checker_reset_button := Button.new()
	checker_reset_button.text = "Reset"
	checker_reset_button.tooltip_text = "Restore the default neutral light and dark checkerboard colors"
	_apply_preferences_small_button_style(checker_reset_button)
	checker_reset_button.pressed.connect(_reset_checker_colors)
	checker_row.add_child(checker_reset_button)

	var files_tab := _add_preferences_tab(tabs, "Files")

	var canvas_section := _add_preferences_section(
		files_tab,
		"Default canvas",
		"Default canvas controls the starting image size used when GDDraw creates a fresh blank document."
	)
	var canvas_row := _add_preferences_control_row(canvas_section)

	var default_canvas_size := _get_default_canvas_size()
	var default_width_label := Label.new()
	default_width_label.text = "W"
	canvas_row.add_child(default_width_label)

	_default_canvas_width = _make_dimension_spinbox()
	_default_canvas_width.value = default_canvas_size.x
	_default_canvas_width.tooltip_text = "Default canvas width for new GDDraw docks"
	_apply_preferences_spinbox_style(_default_canvas_width)
	_default_canvas_width.value_changed.connect(_on_default_canvas_width_changed)
	canvas_row.add_child(_default_canvas_width)

	var default_height_label := Label.new()
	default_height_label.text = "H"
	canvas_row.add_child(default_height_label)

	_default_canvas_height = _make_dimension_spinbox()
	_default_canvas_height.value = default_canvas_size.y
	_default_canvas_height.tooltip_text = "Default canvas height for new GDDraw docks"
	_apply_preferences_spinbox_style(_default_canvas_height)
	_default_canvas_height.value_changed.connect(_on_default_canvas_height_changed)
	canvas_row.add_child(_default_canvas_height)

	var canvas_spacer := Control.new()
	canvas_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_row.add_child(canvas_spacer)

	var file_section := _add_preferences_section(
		files_tab,
		"Default save location",
		"New PNG files default to res://gddraw/images. GDDraw remembers project overrides and creates a missing folder only when an image is written."
	)
	var file_row := _add_preferences_control_row(file_section)

	_save_location = LineEdit.new()
	_save_location.text = _get_default_save_dir()
	_save_location.placeholder_text = GDDrawPngIOHelper.DEFAULT_SAVE_DIR
	_save_location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_preferences_line_edit_style(_save_location)
	_save_location.text_submitted.connect(_on_save_location_submitted)
	_save_location.focus_exited.connect(_on_save_location_focus_exited)
	file_row.add_child(_save_location)

	var browse_button := _make_icon_button("folder-open_0.svg", "Choose the default PNG save folder")
	browse_button.pressed.connect(_show_save_location_dialog)
	file_row.add_child(browse_button)

	var font_section := _add_preferences_section(
		files_tab,
		"Fonts",
		"Project fonts default to res://gddraw/fonts. Existing project or external folder overrides are preserved; missing folders are never created while scanning. TTF, OTF, WOFF, and WOFF2 files are supported."
	)
	var font_row := _add_preferences_control_row(font_section)

	_font_location = LineEdit.new()
	_font_location.text = _get_default_font_dir()
	_font_location.placeholder_text = DEFAULT_FONT_DIRECTORY
	_font_location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_location.tooltip_text = "Project or filesystem folder containing custom fonts"
	_apply_preferences_line_edit_style(_font_location)
	_font_location.text_submitted.connect(_on_font_location_submitted)
	_font_location.focus_exited.connect(_on_font_location_focus_exited)
	font_row.add_child(_font_location)

	var font_browse_button := _make_icon_button("folder-open_0.svg", "Choose the default custom-font folder")
	font_browse_button.pressed.connect(_show_font_location_dialog)
	font_row.add_child(font_browse_button)


func _add_preferences_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = tab_name
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	tabs.add_child(margin)
	return content


func _add_preferences_section(parent: Container, title_text: String, info_text: String) -> VBoxContainer:
	var section := PanelContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_stylebox_override("panel", _make_preferences_section_style())
	parent.add_child(section)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	section.add_child(content)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 6)
	content.add_child(header)

	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", Color("#D8D8D8"))
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var info_button := _make_info_button(info_text)
	header.add_child(info_button)

	var separator := HSeparator.new()
	content.add_child(separator)

	return content


func _add_preferences_control_row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row


func _make_info_button(tooltip: String) -> Button:
	var button := _make_icon_button("circle-question-mark_0.svg", tooltip)
	button.custom_minimum_size = Vector2(22, 22)
	button.add_theme_constant_override("icon_max_width", 14)
	button.tooltip_text = tooltip
	return button


func _make_preferences_section_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.105, 0.105, 1.0)
	style.border_color = Color(0.22, 0.22, 0.22, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	return style


func _get_preferences_background_color() -> Color:
	var background := _get_editor_background_color()
	return background.lightened(0.08)


func _get_editor_background_color() -> Color:
	var editor_base: Control = null
	if _plugin:
		editor_base = _plugin.get_editor_interface().get_base_control()
	if editor_base and editor_base.has_theme_color("base_color", "Editor"):
		return editor_base.get_theme_color("base_color", "Editor")
	if has_theme_color("base_color", "Editor"):
		return get_theme_color("base_color", "Editor")
	return TOOL_BUTTON_PANEL_COLOR


func _build_status_bar() -> void:
	var status_bar := HBoxContainer.new()
	status_bar.name = "Context Bar"
	status_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.custom_minimum_size.y = 28.0
	status_bar.add_theme_constant_override("separation", 4)
	_workspace_content.add_child(status_bar)

	var context_spacer := Control.new()
	context_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(context_spacer)

	_recent_colors_row = HBoxContainer.new()
	_recent_colors_row.add_theme_constant_override("separation", 2)
	status_bar.add_child(_recent_colors_row)

	_load_selected_mesh_button = _make_icon_button(
		"mouse-pointer-2_0.svg",
		"Choose a material texture from the selected MeshInstance3D or supported CSG shape; unsaved 2D pixels are protected before loading"
	)
	_load_selected_mesh_button.visible = false
	_load_selected_mesh_button.pressed.connect(_load_selected_3d_mesh_texture)
	status_bar.add_child(_load_selected_mesh_button)

	_uv_overlay_toggle = _make_icon_button("network_0.svg", "Show mesh UV edges", true)
	_uv_overlay_toggle.visible = false
	_uv_overlay_toggle.toggled.connect(_on_uv_overlay_toggled)
	status_bar.add_child(_uv_overlay_toggle)

	_update_split_view_controls()


func _build_3d_empty_state() -> void:
	_empty_3d_state = Control.new()
	_empty_3d_state.name = "Empty 3D State"
	_empty_3d_state.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_3d_state.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas_3d_host.add_child(_empty_3d_state)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_empty_3d_state.add_child(center)
	var card := PanelContainer.new()
	card.name = "Empty 3D State Panel"
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.075, 0.085, 0.105, 0.94)
	card_style.border_color = Color(0.32, 0.38, 0.48, 0.9)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 24.0
	card_style.content_margin_top = 18.0
	card_style.content_margin_right = 24.0
	card_style.content_margin_bottom = 18.0
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	var title := Label.new()
	title.text = "No 3D texture session"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)
	var instructions := Label.new()
	instructions.text = "Select a mesh or supported CSG shape and choose Use Selected Mesh,\nor drag the node (or a parent) from the Scene tree."
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(instructions)
	var use_selected := Button.new()
	use_selected.text = "Use Selected Mesh"
	use_selected.tooltip_text = "Use Selected 3D Surface: open the session picker for the selected MeshInstance3D or supported CSG shape; parent selection and unsaved 2D protection are supported"
	use_selected.pressed.connect(_load_selected_3d_mesh_texture)
	content.add_child(use_selected)


func _make_icon_button(icon_name: String, tooltip: String, toggle := false, selected_icon_name := "") -> Button:
	var button := Button.new()
	button.custom_minimum_size = TOOL_BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = tooltip
	button.toggle_mode = toggle
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = false
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", TOOL_ICON_MAX_WIDTH)
	button.add_theme_constant_override("h_separation", 0)
	_apply_icon_button_style(button)
	button.set_meta("inactive_icon_name", icon_name)
	button.set_meta("active_icon_name", _get_active_icon_name(icon_name, selected_icon_name))
	_icon_buttons.append(button)
	_update_icon_button_icon(button)
	if toggle:
		_apply_selected_tool_style(button)
		button.toggled.connect(_on_toggle_button_icon_toggled.bind(button))
	return button


func _make_icon_menu_button(icon_name: String, tooltip: String) -> MenuButton:
	var button := MenuButton.new()
	# MenuButton defaults to a flat appearance, unlike the regular GDDraw
	# icon buttons. Draw the shared normal/hover/pressed styleboxes so this
	# contextual control remains visually consistent with the viewport UI.
	button.flat = false
	button.custom_minimum_size = TOOL_BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = false
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", TOOL_ICON_MAX_WIDTH)
	button.add_theme_constant_override("h_separation", 0)
	_apply_icon_button_style(button)
	button.set_meta("inactive_icon_name", icon_name)
	button.set_meta("active_icon_name", icon_name)
	_icon_buttons.append(button)
	_update_icon_button_icon(button)
	return button


func _make_static_icon(icon_name: String, tooltip: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, TOOL_BUTTON_SIZE.y)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = tooltip
	icon.set_meta("gddraw_icon_name", icon_name)
	_static_icons.append(icon)
	_update_static_icon(icon)
	return icon


func _setup_icon_import_recovery() -> void:
	_icon_import_recovery_torn_down = false
	var filesystem := _icon_resource_filesystem_override
	if not filesystem and _plugin:
		var editor_interface = _plugin.get_editor_interface()
		if editor_interface:
			filesystem = editor_interface.get_resource_filesystem()
	if filesystem == _icon_resource_filesystem:
		_connect_icon_import_signals()
		return
	_disconnect_icon_import_signals()
	_icon_resource_filesystem = filesystem
	_connect_icon_import_signals()


func _connect_icon_import_signals() -> void:
	if not is_instance_valid(_icon_resource_filesystem):
		return
	var filesystem_changed := Callable(self, "_on_icon_filesystem_changed")
	if _icon_resource_filesystem.has_signal("filesystem_changed") and not _icon_resource_filesystem.is_connected("filesystem_changed", filesystem_changed):
		_icon_resource_filesystem.connect("filesystem_changed", filesystem_changed)
	var resources_reimported := Callable(self, "_on_icon_resources_reimported")
	if _icon_resource_filesystem.has_signal("resources_reimported") and not _icon_resource_filesystem.is_connected("resources_reimported", resources_reimported):
		_icon_resource_filesystem.connect("resources_reimported", resources_reimported)
	var resources_reload := Callable(self, "_on_icon_resources_reloaded")
	if _icon_resource_filesystem.has_signal("resources_reload") and not _icon_resource_filesystem.is_connected("resources_reload", resources_reload):
		_icon_resource_filesystem.connect("resources_reload", resources_reload)


func _disconnect_icon_import_signals() -> void:
	if not is_instance_valid(_icon_resource_filesystem):
		return
	for connection in [
		["filesystem_changed", Callable(self, "_on_icon_filesystem_changed")],
		["resources_reimported", Callable(self, "_on_icon_resources_reimported")],
		["resources_reload", Callable(self, "_on_icon_resources_reloaded")],
	]:
		var signal_name: StringName = connection[0]
		var callback: Callable = connection[1]
		if _icon_resource_filesystem.has_signal(signal_name) and _icon_resource_filesystem.is_connected(signal_name, callback):
			_icon_resource_filesystem.disconnect(signal_name, callback)


func _teardown_icon_import_recovery() -> void:
	_icon_import_recovery_torn_down = true
	_icon_recovery_cycle.generation = int(_icon_recovery_cycle.generation) + 1
	_icon_recovery_cycle.active = false
	_icon_recovery_cycle.callback_scheduled = false
	_icon_recovery_cycle.callback_token = int(_icon_recovery_cycle.callback_token) + 1
	_icon_recovery_cycle.pending_count = 0
	_disconnect_icon_import_signals()
	_icon_resource_filesystem = null


func set_icon_import_adapters_for_tests(
	filesystem: Object,
	exists_adapter := Callable(),
	load_adapter := Callable(),
	clock_adapter := Callable(),
	scheduler_adapter := Callable()
) -> void:
	_disconnect_icon_import_signals()
	_icon_resource_filesystem = null
	_icon_resource_filesystem_override = filesystem
	_icon_exists_override = exists_adapter
	_icon_load_override = load_adapter
	_icon_clock_override = clock_adapter
	_icon_scheduler_override = scheduler_adapter
	_setup_icon_import_recovery()


func _on_icon_filesystem_changed() -> void:
	# This signal has no paths, so keep it relevant throughout the bounded cycle
	# whenever a registered icon is still pending.
	if _icon_recovery_is_pending():
		_schedule_icon_refresh()


func _on_icon_resources_reimported(paths: PackedStringArray) -> void:
	_on_icon_resource_paths_changed(paths)


func _on_icon_resources_reloaded(paths: PackedStringArray) -> void:
	_on_icon_resource_paths_changed(paths)


func _on_icon_resource_paths_changed(paths: PackedStringArray) -> void:
	if not _icon_recovery_is_pending() or not _contains_gddraw_icon_path(paths):
		return
	_schedule_icon_refresh()


func _contains_gddraw_icon_path(paths: PackedStringArray) -> bool:
	var icon_prefix := ICON_DIR + "/"
	if paths.is_empty():
		return true
	for path in paths:
		var normalized := str(path).replace("\\", "/")
		if normalized.begins_with(icon_prefix):
			return true
		# Godot may report the generated cache artifact rather than its SVG
		# source. Match only cache entries whose basename identifies a family
		# currently registered by this dock.
		if normalized.contains("/.godot/imported/"):
			for family_name in _registered_icon_family_names():
				if normalized.get_file().begins_with("%s_" % family_name):
					return true
	return false


func _registered_icon_family_names() -> PackedStringArray:
	var families := PackedStringArray()
	for button in _icon_buttons:
		if not is_instance_valid(button):
			continue
		for key in ["inactive_icon_name", "active_icon_name"]:
			var family := _get_icon_family_name(str(button.get_meta(key, "")))
			if not family.is_empty() and not families.has(family):
				families.append(family)
	for icon in _static_icons:
		if not is_instance_valid(icon):
			continue
		var family := _get_icon_family_name(str(icon.get_meta("gddraw_icon_name", "")))
		if not family.is_empty() and not families.has(family):
			families.append(family)
	return families


func _start_icon_recovery_cycle() -> void:
	if _icon_import_recovery_torn_down:
		return
	var now := _icon_recovery_now_msec()
	_icon_recovery_cycle.generation = int(_icon_recovery_cycle.generation) + 1
	_icon_recovery_cycle.active = true
	_icon_recovery_cycle.start_msec = now
	_icon_recovery_cycle.deadline_msec = now + ICON_REFRESH_MAX_DURATION_MSEC
	_icon_recovery_cycle.attempts = 0
	_icon_recovery_cycle.callback_scheduled = false
	_icon_recovery_cycle.callback_token = int(_icon_recovery_cycle.callback_token) + 1
	_icon_recovery_cycle.scheduled_due_msec = now
	_icon_recovery_cycle.pending_count = _count_pending_icon_controls()
	_schedule_icon_refresh()


func _schedule_icon_refresh() -> void:
	if _icon_import_recovery_torn_down or not bool(_icon_recovery_cycle.active):
		return
	_queue_icon_refresh_callback(0.0)


func _run_icon_refresh_attempt(generation: int, callback_token := -1) -> void:
	if (
		generation != int(_icon_recovery_cycle.generation)
		or (callback_token >= 0 and callback_token != int(_icon_recovery_cycle.callback_token))
		or _icon_import_recovery_torn_down
		or not is_instance_valid(self)
	):
		return
	_icon_recovery_cycle.callback_scheduled = false
	if not bool(_icon_recovery_cycle.active):
		return
	var now := _icon_recovery_now_msec()
	if int(_icon_recovery_cycle.attempts) >= ICON_REFRESH_MAX_ATTEMPTS or now >= int(_icon_recovery_cycle.deadline_msec):
		_end_icon_recovery_cycle()
		return
	_icon_recovery_cycle.attempts = int(_icon_recovery_cycle.attempts) + 1
	if _icon_filesystem_is_busy():
		_icon_recovery_cycle.pending_count = _count_pending_icon_controls()
	else:
		_icon_recovery_cycle.pending_count = _refresh_registered_icons(true)
	if int(_icon_recovery_cycle.pending_count) <= 0:
		_end_icon_recovery_cycle()
		return
	if int(_icon_recovery_cycle.attempts) >= ICON_REFRESH_MAX_ATTEMPTS:
		_end_icon_recovery_cycle()
		return
	_queue_icon_refresh_callback(ICON_REFRESH_RETRY_DELAY)


func _queue_icon_refresh_callback(delay_seconds: float) -> void:
	if _icon_import_recovery_torn_down or not bool(_icon_recovery_cycle.active):
		return
	var due_msec := _icon_recovery_now_msec() + int(round(delay_seconds * 1000.0))
	if bool(_icon_recovery_cycle.callback_scheduled):
		if due_msec >= int(_icon_recovery_cycle.scheduled_due_msec):
			return
		# The prior timer cannot always be cancelled, so invalidate its token and
		# leave it as a harmless no-op while scheduling this earlier pass.
	_icon_recovery_cycle.callback_scheduled = true
	_icon_recovery_cycle.callback_token = int(_icon_recovery_cycle.callback_token) + 1
	_icon_recovery_cycle.scheduled_due_msec = due_msec
	var callback := Callable(self, "_run_icon_refresh_attempt").bind(
		int(_icon_recovery_cycle.generation),
		int(_icon_recovery_cycle.callback_token)
	)
	if _icon_scheduler_override.is_valid():
		_icon_scheduler_override.call(callback, delay_seconds)
	elif delay_seconds <= 0.0:
		callback.call_deferred()
	elif is_inside_tree() and get_tree():
		get_tree().create_timer(delay_seconds).timeout.connect(
			callback,
			CONNECT_ONE_SHOT
		)
	else:
		callback.call_deferred()


func _end_icon_recovery_cycle() -> void:
	_icon_recovery_cycle.generation = int(_icon_recovery_cycle.generation) + 1
	_icon_recovery_cycle.active = false
	_icon_recovery_cycle.callback_scheduled = false
	_icon_recovery_cycle.callback_token = int(_icon_recovery_cycle.callback_token) + 1


func _icon_recovery_now_msec() -> int:
	if _icon_clock_override.is_valid():
		return int(_icon_clock_override.call())
	return Time.get_ticks_msec()


func _icon_recovery_is_pending() -> bool:
	return (
		not _icon_import_recovery_torn_down
		and bool(_icon_recovery_cycle.active)
		and int(_icon_recovery_cycle.pending_count) > 0
	)


func _icon_filesystem_is_busy() -> bool:
	if not is_instance_valid(_icon_resource_filesystem):
		return false
	if _icon_resource_filesystem.has_method("is_scanning") and bool(_icon_resource_filesystem.call("is_scanning")):
		return true
	# is_importing() is absent in Godot 4.4 and available in newer releases.
	return _icon_resource_filesystem.has_method("is_importing") and bool(_icon_resource_filesystem.call("is_importing"))


func _refresh_registered_icons(force_replace: bool) -> int:
	var pending := 0
	var live_buttons: Array[Button] = []
	for button in _icon_buttons:
		if not is_instance_valid(button):
			continue
		live_buttons.append(button)
		if not _update_icon_button_icon(button, force_replace):
			pending += 1
	_icon_buttons = live_buttons
	var live_static_icons: Array[TextureRect] = []
	for icon in _static_icons:
		if not is_instance_valid(icon):
			continue
		live_static_icons.append(icon)
		if not _update_static_icon(icon, force_replace):
			pending += 1
	_static_icons = live_static_icons
	return pending


func _has_pending_icon_controls() -> bool:
	return _count_pending_icon_controls() > 0


func _count_pending_icon_controls() -> int:
	var pending := 0
	for button in _icon_buttons:
		if is_instance_valid(button) and not bool(button.get_meta("gddraw_icon_ready", false)):
			pending += 1
	for icon in _static_icons:
		if is_instance_valid(icon) and not bool(icon.get_meta("gddraw_icon_ready", false)):
			pending += 1
	return pending


func _get_active_icon_name(icon_name: String, selected_icon_name: String) -> String:
	if not selected_icon_name.is_empty():
		return selected_icon_name
	if icon_name.ends_with("_0.svg"):
		return _get_icon_state_name(icon_name, IconState.SELECTED)
	return icon_name


func _get_icon_family_name(icon_name: String) -> String:
	var family_name := icon_name.get_file().trim_suffix(".svg")
	for state_suffix in ["_0", "_1", "_2"]:
		if family_name.ends_with(state_suffix):
			return family_name.trim_suffix(state_suffix)
	return family_name


func _get_icon_state_name(icon_name: String, state: int) -> String:
	return "%s_%d.svg" % [_get_icon_family_name(icon_name), state]


func _get_icon_path(icon_name: String) -> String:
	var family_name := _get_icon_family_name(icon_name)
	return "%s/%s/%s" % [ICON_DIR, family_name, icon_name.get_file()]


func _resolve_icon_path(icon_name: String, state_override := -1) -> String:
	var resolved_name := icon_name.get_file()
	if state_override >= IconState.NORMAL:
		resolved_name = _get_icon_state_name(resolved_name, state_override)
	var icon_path := _get_icon_path(resolved_name)
	if _icon_resource_exists(icon_path):
		return icon_path
	if state_override != IconState.NORMAL:
		var fallback_name := _get_icon_state_name(resolved_name, IconState.NORMAL)
		var fallback_path := _get_icon_path(fallback_name)
		if _icon_resource_exists(fallback_path):
			return fallback_path
	return icon_path


func _icon_resource_exists(path: String) -> bool:
	if _icon_exists_override.is_valid():
		return bool(_icon_exists_override.call(path, "Texture2D"))
	return ResourceLoader.exists(path, "Texture2D")


func _load_icon_texture(path: String, replace_cache: bool) -> Texture2D:
	if not _icon_resource_exists(path):
		return null
	var cache_mode := ResourceLoader.CACHE_MODE_REPLACE if replace_cache else ResourceLoader.CACHE_MODE_REUSE
	var resource
	if _icon_load_override.is_valid():
		resource = _icon_load_override.call(path, "Texture2D", cache_mode)
	else:
		resource = ResourceLoader.load(path, "Texture2D", cache_mode)
	return resource as Texture2D


func _load_icon_for_state(icon_name: String, state_override: int, replace_cache: bool) -> Dictionary:
	var resolved_name := icon_name.get_file()
	if state_override >= IconState.NORMAL:
		resolved_name = _get_icon_state_name(resolved_name, state_override)
	var intended_path := _get_icon_path(resolved_name)
	var texture := _load_icon_texture(intended_path, replace_cache)
	if texture:
		return {"texture": texture, "path": intended_path, "ready": true, "authored_state": true}
	if state_override != IconState.NORMAL:
		var fallback_name := _get_icon_state_name(resolved_name, IconState.NORMAL)
		var fallback_path := _get_icon_path(fallback_name)
		if fallback_path != intended_path:
			var fallback_texture := _load_icon_texture(fallback_path, replace_cache)
			if fallback_texture:
				return {"texture": fallback_texture, "path": fallback_path, "ready": not _icon_resource_exists(intended_path), "authored_state": false}
	return {"texture": null, "path": intended_path, "ready": false, "authored_state": false}


func _on_toggle_button_icon_toggled(_enabled: bool, button: Button) -> void:
	_update_toggle_button_icon(button)


func _update_toggle_button_icon(button: Button) -> void:
	_update_icon_button_icon(button)


func _update_icon_button_icon(button: Button, force_replace := false) -> bool:
	if not button:
		return true
	var icon_name := str(button.get_meta("active_icon_name" if button.button_pressed else "inactive_icon_name", ""))
	if icon_name.is_empty():
		return true
	var state_override := IconState.DISABLED if button.disabled else -1
	var intent := "%s:%d" % [icon_name, state_override]
	if not force_replace and str(button.get_meta("gddraw_icon_intent", "")) == intent:
		return bool(button.get_meta("gddraw_icon_ready", false))
	var loaded := _load_icon_for_state(icon_name, state_override, force_replace)
	var texture := loaded.get("texture") as Texture2D
	var ready := bool(loaded.get("ready", false))
	if texture:
		button.icon = texture
		button.text = ""
		button.set_meta("applied_icon_path", str(loaded.get("path", "")))
	elif button.text.is_empty():
		button.text = button.tooltip_text.substr(0, 1)
	if button.disabled:
		var disabled_icon_color := ICON_AUTHORED_COLOR if bool(loaded.get("authored_state", false)) else ICON_DISABLED_FALLBACK_COLOR
		if button.get_theme_color("icon_disabled_color") != disabled_icon_color:
			button.add_theme_color_override("icon_disabled_color", disabled_icon_color)
	button.set_meta("gddraw_icon_intent", intent)
	button.set_meta("gddraw_icon_ready", ready)
	return ready


func _update_static_icon(icon: TextureRect, force_replace := false) -> bool:
	if not icon:
		return true
	var icon_name := str(icon.get_meta("gddraw_icon_name", ""))
	if icon_name.is_empty():
		return true
	if not force_replace and icon.has_meta("gddraw_icon_ready"):
		return bool(icon.get_meta("gddraw_icon_ready", false))
	var loaded := _load_icon_for_state(icon_name, -1, force_replace)
	var texture := loaded.get("texture") as Texture2D
	if texture:
		icon.texture = texture
	var ready := bool(loaded.get("ready", false))
	icon.set_meta("applied_icon_path", str(loaded.get("path", "")))
	icon.set_meta("gddraw_icon_ready", ready)
	return ready


func _refresh_icon_button_states() -> void:
	var live_buttons: Array[Button] = []
	for button in _icon_buttons:
		if not is_instance_valid(button):
			continue
		live_buttons.append(button)
		_update_icon_button_icon(button)
	_icon_buttons = live_buttons


func _make_compact_rotation_controls(
	control_name: String,
	counterclockwise_tooltip: String,
	clockwise_tooltip: String,
	amount_tooltip: String
) -> Dictionary:
	var control := HBoxContainer.new()
	control.name = control_name
	control.custom_minimum_size.y = TOOL_BUTTON_SIZE.y
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.add_theme_constant_override("separation", TOOLBAR_SEPARATION)

	var direction_buttons := VBoxContainer.new()
	direction_buttons.name = "Rotation Direction Buttons"
	direction_buttons.custom_minimum_size = Vector2(COMPACT_ROTATION_BUTTON_SIZE.x, TOOL_BUTTON_SIZE.y)
	direction_buttons.add_theme_constant_override("separation", 0)
	control.add_child(direction_buttons)

	var left_button := _make_icon_button("undo_0.svg", counterclockwise_tooltip)
	left_button.name = "Rotate Counterclockwise"
	left_button.custom_minimum_size = COMPACT_ROTATION_BUTTON_SIZE
	left_button.add_theme_constant_override("icon_max_width", COMPACT_ROTATION_ICON_MAX_WIDTH)
	direction_buttons.add_child(left_button)

	var right_button := _make_icon_button("redo_0.svg", clockwise_tooltip)
	right_button.name = "Rotate Clockwise"
	right_button.custom_minimum_size = COMPACT_ROTATION_BUTTON_SIZE
	right_button.add_theme_constant_override("icon_max_width", COMPACT_ROTATION_ICON_MAX_WIDTH)
	direction_buttons.add_child(right_button)

	var amount := SpinBox.new()
	amount.name = "Rotation Amount"
	amount.min_value = 1
	amount.max_value = 359
	amount.step = 1
	amount.value = 90
	amount.custom_minimum_size = Vector2(62, TOOL_BUTTON_SIZE.y)
	amount.tooltip_text = amount_tooltip
	control.add_child(amount)

	return {
		"control": control,
		"left_button": left_button,
		"right_button": right_button,
		"amount": amount,
	}


func _make_dimension_spinbox() -> SpinBox:
	var spinbox := SpinBox.new()
	spinbox.min_value = 16
	spinbox.max_value = 4096
	spinbox.step = 1
	spinbox.value = DEFAULT_CANVAS_SIZE.x
	spinbox.custom_minimum_size.x = 54
	return spinbox


func _make_integer_line_edit(text: String, tooltip: String) -> LineEdit:
	var line_edit := LineEdit.new()
	line_edit.text = text
	line_edit.tooltip_text = tooltip
	line_edit.custom_minimum_size.x = 72
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_preferences_line_edit_style(line_edit)
	return line_edit


func _make_settings_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 96
	row.add_child(label)
	return row


func _parse_bounded_int(value: String, minimum: int, maximum: int, fallback: int) -> int:
	var normalized_value := value.strip_edges()
	if not normalized_value.is_valid_int():
		return fallback
	return clampi(int(normalized_value), minimum, maximum)


func _add_toolbar_separator(parent: Container) -> void:
	if parent is VBoxContainer:
		var separator := HSeparator.new()
		separator.custom_minimum_size.y = 6
		parent.add_child(separator)
	else:
		var separator := VSeparator.new()
		separator.custom_minimum_size.x = 6
		parent.add_child(separator)


func _add_tool_options_separator(parent: Container, separator_name: String) -> Control:
	var separator := CenterContainer.new()
	separator.name = separator_name
	separator.custom_minimum_size = Vector2(10, 24)
	separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var rule := ColorRect.new()
	rule.color = Color("#151515")
	rule.custom_minimum_size = Vector2(2, 24)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	separator.add_child(rule)

	parent.add_child(separator)
	return separator


func _add_section_label(parent: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)


func _build_open_dialog() -> void:
	_open_dialog = FileDialog.new()
	_open_dialog.access = FileDialog.ACCESS_RESOURCES
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga, *.svg ; Image files"])
	_open_dialog.title = "Load Image"
	_open_dialog.file_selected.connect(_load_png)
	add_child(_open_dialog)


func _build_custom_fill_image_dialog() -> void:
	_custom_fill_image_dialog = FileDialog.new()
	_custom_fill_image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_custom_fill_image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_custom_fill_image_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga, *.svg ; Image files"])
	_custom_fill_image_dialog.title = "Select Custom Fill Image"
	_custom_fill_image_dialog.file_selected.connect(_on_custom_fill_file_selected)
	add_child(_custom_fill_image_dialog)


func _build_text_font_dialog() -> void:
	_text_font_dialog = FileDialog.new()
	_text_font_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_text_font_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_text_font_dialog.filters = PackedStringArray(["*.ttf, *.otf, *.woff, *.woff2 ; Font files"])
	_text_font_dialog.title = "Load Text Font"
	_text_font_dialog.file_selected.connect(_on_text_font_file_selected)
	_text_font_dialog.canceled.connect(_on_text_font_dialog_canceled)
	add_child(_text_font_dialog)


func _build_save_dialog() -> void:
	_save_dialog = FileDialog.new()
	_save_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.filters = PackedStringArray(["*.png ; PNG images"])
	_save_dialog.title = "Save PNG"
	_save_dialog.file_selected.connect(_save_png_to_path)
	_save_dialog.canceled.connect(_cancel_2d_save_as)
	add_child(_save_dialog)


func _build_save_3d_as_dialog() -> void:
	_save_3d_as_dialog = FileDialog.new()
	_save_3d_as_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_3d_as_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_3d_as_dialog.filters = PackedStringArray(["*.png ; PNG images"])
	_save_3d_as_dialog.title = "Save 3D Texture As"
	_save_3d_as_dialog.file_selected.connect(_save_3d_texture_as_to_path)
	_save_3d_as_dialog.canceled.connect(_cancel_3d_texture_save_as)
	add_child(_save_3d_as_dialog)


func _build_save_location_dialog() -> void:
	_save_location_dialog = FileDialog.new()
	_save_location_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_location_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_save_location_dialog.title = "Default Save Location"
	_save_location_dialog.dir_selected.connect(_on_save_location_selected)
	add_child(_save_location_dialog)


func _build_font_location_dialog() -> void:
	_font_location_dialog = FileDialog.new()
	_font_location_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_font_location_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_font_location_dialog.title = "Default Font Location"
	_font_location_dialog.dir_selected.connect(_on_font_location_selected)
	add_child(_font_location_dialog)


func _build_brush_preset_dialog() -> void:
	_brush_preset_dialog = ConfirmationDialog.new()
	_brush_preset_dialog.title = "Save Brush Preset"
	_brush_preset_dialog.dialog_text = ""
	_brush_preset_dialog.min_size = Vector2i(500, 420)
	_brush_preset_dialog.max_size = Vector2i(600, 460)
	_brush_preset_dialog.unresizable = true
	_brush_preset_dialog.get_ok_button().visible = false
	_brush_preset_dialog.get_cancel_button().visible = false
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_TOP_WIDE)
	content.offset_left = 24.0
	content.offset_top = 24.0
	content.offset_right = -24.0
	content.offset_bottom = -36.0
	content.custom_minimum_size.y = 330.0
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_theme_constant_override("separation", 12)
	_brush_preset_dialog.add_child(content)
	var description := Label.new()
	description.text = (
		"Save the current brush configuration as a brush preset.\n\n"
		+ "The following will be saved:\n"
		+ "• Brush size\n"
		+ "• Brush head\n"
		+ "• Draw mode (Pixel Perfect or Antialiasing)\n"
		+ "• Hardness\n"
		+ "• Lock alpha\n"
		+ "• Touch pixels\n"
		+ "• Allow stroke overlap\n\n"
		+ "Color is not included yet."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	_brush_preset_name = LineEdit.new()
	_brush_preset_name.placeholder_text = "Preset name"
	_brush_preset_name.tooltip_text = "Name for the custom brush preset"
	_apply_preferences_line_edit_style(_brush_preset_name)
	content.add_child(_brush_preset_name)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 8)
	button_row.add_theme_constant_override("margin_top", 8)
	content.add_child(button_row)
	var save_button := Button.new()
	save_button.text = "Save Preset"
	save_button.tooltip_text = "Save the named custom brush preset"
	_apply_light_dialog_button_style(save_button)
	save_button.pressed.connect(_save_current_brush_preset)
	button_row.add_child(save_button)
	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.tooltip_text = "Close without saving a preset"
	_apply_light_dialog_button_style(cancel_button)
	cancel_button.pressed.connect(_brush_preset_dialog.hide)
	button_row.add_child(cancel_button)
	var button_bottom_spacer := Control.new()
	button_bottom_spacer.custom_minimum_size.y = 14.0
	content.add_child(button_bottom_spacer)
	add_child(_brush_preset_dialog)


func _build_drop_replace_dialog() -> void:
	_drop_replace_dialog = ConfirmationDialog.new()
	_drop_replace_dialog.title = "Replace Canvas?"
	_drop_replace_dialog.dialog_text = "Save the current canvas before opening the dropped image?"
	_drop_replace_dialog.ok_button_text = "Replace"
	_drop_replace_dialog.cancel_button_text = "Cancel"
	_drop_replace_dialog.confirmed.connect(_replace_canvas_with_pending_drop)
	_drop_replace_dialog.custom_action.connect(_on_drop_replace_custom_action)
	_drop_replace_dialog.add_button("Save & Replace", false, "save_replace")
	add_child(_drop_replace_dialog)


func _build_create_textured_csg_dialog() -> void:
	_create_textured_csg_overlay = PanelContainer.new()
	_create_textured_csg_overlay.name = "Create Textured CSG3D Overlay"
	_create_textured_csg_overlay.visible = false
	_create_textured_csg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_create_textured_csg_overlay.clip_contents = true
	_create_textured_csg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay_background := StyleBoxFlat.new()
	overlay_background.bg_color = _get_preferences_background_color()
	_create_textured_csg_overlay.add_theme_stylebox_override("panel", overlay_background)
	var overlay_host: Control = _workspace_region if _workspace_region else self
	overlay_host.add_child(_create_textured_csg_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_create_textured_csg_overlay.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(header_row)
	var title_label := Label.new()
	title_label.text = "Create Textured CSG3D"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.tooltip_text = "Close Create Textured CSG3D (Escape)"
	_apply_preferences_close_button_style(close_button)
	close_button.pressed.connect(_close_create_textured_csg_overlay)
	header_row.add_child(close_button)
	content.add_child(HSeparator.new())

	var options_section := PanelContainer.new()
	options_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_section.add_theme_stylebox_override("panel", _make_preferences_section_style())
	content.add_child(options_section)
	var options_content := VBoxContainer.new()
	options_content.add_theme_constant_override("separation", 8)
	options_section.add_child(options_content)

	var shape_row := HBoxContainer.new()
	shape_row.add_theme_constant_override("separation", 10)
	options_content.add_child(shape_row)
	var shape_label := Label.new()
	shape_label.text = "Shape"
	shape_label.custom_minimum_size.x = 150.0
	shape_row.add_child(shape_label)
	_create_textured_csg_shape = OptionButton.new()
	_create_textured_csg_shape.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_textured_csg_shape.add_item("Box", GDDrawSpriteCreatorHelper.CSGShape.BOX)
	_create_textured_csg_shape.add_item("Sphere", GDDrawSpriteCreatorHelper.CSGShape.SPHERE)
	_create_textured_csg_shape.add_item("Cylinder", GDDrawSpriteCreatorHelper.CSGShape.CYLINDER)
	_create_textured_csg_shape.item_selected.connect(_update_create_textured_csg_validation)
	shape_row.add_child(_create_textured_csg_shape)

	_create_textured_csg_assign_image = CheckBox.new()
	_create_textured_csg_assign_image.text = "Assign Current Image"
	_create_textured_csg_assign_image.button_pressed = true
	_create_textured_csg_assign_image.tooltip_text = "Save an RGBA8 PNG and assign it as a nearest-filtered albedo texture."
	_create_textured_csg_assign_image.toggled.connect(_update_create_textured_csg_validation)
	options_content.add_child(_create_textured_csg_assign_image)

	_create_textured_csg_select_node = CheckBox.new()
	_create_textured_csg_select_node.text = "Select Created Node"
	_create_textured_csg_select_node.button_pressed = true
	_create_textured_csg_select_node.tooltip_text = "Select the new node in the editor Scene tree."
	options_content.add_child(_create_textured_csg_select_node)

	_create_textured_csg_enable_collision = CheckBox.new()
	_create_textured_csg_enable_collision.text = "Enable Collision"
	_create_textured_csg_enable_collision.button_pressed = false
	_create_textured_csg_enable_collision.tooltip_text = "Use the CSG node's native static collision support."
	options_content.add_child(_create_textured_csg_enable_collision)

	_create_textured_csg_validation = Label.new()
	_create_textured_csg_validation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_create_textured_csg_validation.custom_minimum_size.y = 42.0
	options_content.add_child(_create_textured_csg_validation)

	var vertical_spacer := Control.new()
	vertical_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(vertical_spacer)
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 8)
	content.add_child(button_row)
	_create_textured_csg_create_button = Button.new()
	_create_textured_csg_create_button.name = "Create Textured CSG3D"
	_create_textured_csg_create_button.text = "Create"
	_create_textured_csg_create_button.tooltip_text = "Create the configured CSG3D node"
	_apply_light_dialog_button_style(_create_textured_csg_create_button)
	_create_textured_csg_create_button.pressed.connect(_confirm_create_textured_csg)
	button_row.add_child(_create_textured_csg_create_button)
	_create_textured_csg_cancel_button = Button.new()
	_create_textured_csg_cancel_button.name = "Cancel Textured CSG3D"
	_create_textured_csg_cancel_button.text = "Cancel"
	_create_textured_csg_cancel_button.tooltip_text = "Close without creating a CSG3D node"
	_apply_preferences_small_button_style(_create_textured_csg_cancel_button)
	_create_textured_csg_cancel_button.pressed.connect(_close_create_textured_csg_overlay)
	button_row.add_child(_create_textured_csg_cancel_button)


func _build_3d_session_picker() -> void:
	_session_picker_dialog = ConfirmationDialog.new()
	_session_picker_dialog.title = "Choose 3D Texture Session"
	_session_picker_dialog.dialog_text = ""
	_session_picker_dialog.ok_button_text = "Open"
	_session_picker_dialog.cancel_button_text = "Cancel"
	_session_picker_dialog.min_size = Vector2i(600, 340)
	_session_picker_dialog.max_size = Vector2i(720, 420)
	_session_picker_dialog.unresizable = true
	_session_picker_dialog.confirmed.connect(_confirm_3d_session_picker)
	_session_picker_dialog.canceled.connect(_clear_3d_session_picker)
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_TOP_WIDE)
	content.offset_left = 24.0
	content.offset_top = 24.0
	content.offset_right = -24.0
	content.custom_minimum_size.y = 150.0
	content.add_theme_constant_override("separation", 12)
	_session_picker_dialog.add_child(content)
	var description := Label.new()
	description.text = "Choose a material slot and editable texture. This step does not change the scene."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	_session_picker_target_label = Label.new()
	_session_picker_target_label.name = "3D Session Target"
	_session_picker_target_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.94))
	content.add_child(_session_picker_target_label)
	_session_picker_options = ItemList.new()
	_session_picker_options.name = "3D Session Texture Choices"
	_session_picker_options.tooltip_text = "Safe editable mesh/CSG material slots; unsupported and multi-material CSG configurations are disabled with an explanation"
	_session_picker_options.custom_minimum_size.y = 120.0
	_session_picker_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_session_picker_options.select_mode = ItemList.SELECT_SINGLE
	_session_picker_options.item_selected.connect(_on_3d_session_picker_choice_selected)
	content.add_child(_session_picker_options)
	_session_picker_reason_label = Label.new()
	_session_picker_reason_label.name = "3D Session Choice Explanation"
	_session_picker_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_session_picker_reason_label)
	add_child(_session_picker_dialog)


func _build_create_3d_texture_dialog() -> void:
	_create_3d_texture_dialog = ConfirmationDialog.new()
	_create_3d_texture_dialog.title = "Create Albedo Texture?"
	_create_3d_texture_dialog.dialog_text = "Create and assign a new PNG albedo texture for this material slot? This scene change is explicit and undoable."
	_create_3d_texture_dialog.ok_button_text = "Create"
	_create_3d_texture_dialog.cancel_button_text = "Cancel"
	_create_3d_texture_dialog.confirmed.connect(_create_missing_3d_texture)
	_create_3d_texture_dialog.canceled.connect(_cancel_missing_3d_texture)
	add_child(_create_3d_texture_dialog)


func _build_save_3d_texture_dialog() -> void:
	_save_3d_texture_dialog = ConfirmationDialog.new()
	_save_3d_texture_dialog.title = "Save Texture?"
	_save_3d_texture_dialog.dialog_text = "Save the current canvas back to the active material texture?"
	_save_3d_texture_dialog.ok_button_text = "Save"
	_save_3d_texture_dialog.cancel_button_text = "Cancel"
	_save_3d_texture_dialog.confirmed.connect(_save_3d_texture_confirmed)
	add_child(_save_3d_texture_dialog)


func _build_session_replace_dialog() -> void:
	_session_replace_dialog = ConfirmationDialog.new()
	_session_replace_dialog.title = "Unsaved 3D Texture"
	_session_replace_dialog.dialog_text = "Save the active 3D texture before replacing this session?"
	_session_replace_dialog.ok_button_text = "Save"
	_session_replace_dialog.cancel_button_text = "Cancel"
	_session_replace_dialog.confirmed.connect(_save_pending_session_transition)
	_session_replace_dialog.custom_action.connect(_on_session_replace_custom_action)
	_session_replace_dialog.canceled.connect(_cancel_pending_session_transition)
	_session_replace_dialog.add_button("Save As…", false, "save_as")
	_session_replace_dialog.add_button("Discard", false, "discard")
	add_child(_session_replace_dialog)


func _build_document_session_dialog() -> void:
	_document_session_dialog = ConfirmationDialog.new()
	_document_session_dialog.title = "Unsaved 2D Image"
	_document_session_dialog.dialog_text = ""
	_document_session_dialog.ok_button_text = "Save"
	_document_session_dialog.cancel_button_text = "Cancel"
	_document_session_dialog.min_size = Vector2i(420, 360)
	_document_session_dialog.max_size = Vector2i(560, 480)
	_document_session_dialog.confirmed.connect(_save_2d_before_3d_session)
	_document_session_dialog.custom_action.connect(_on_document_session_custom_action)
	_document_session_dialog.canceled.connect(_cancel_2d_to_3d_transition)
	_document_session_dialog.add_button("Continue Without Saving", false, "continue_without_saving")

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	var prompt := Label.new()
	prompt.text = "Save this independent 2D image before starting the 3D texture session?"
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(prompt)
	var preview_panel := PanelContainer.new()
	preview_panel.name = "Unsaved 2D Preview Panel"
	preview_panel.custom_minimum_size = Vector2(320, 200)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.08, 0.085, 0.095, 1.0)
	preview_style.border_color = Color(0.3, 0.32, 0.36, 1.0)
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(4)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	content.add_child(preview_panel)
	_document_session_preview = TextureRect.new()
	_document_session_preview.name = "Unsaved 2D Document Preview"
	_document_session_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_document_session_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_document_session_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_document_session_preview.tooltip_text = "The unsaved 2D image that will be preserved or saved before 3D editing"
	preview_panel.add_child(_document_session_preview)
	_document_session_preview_label = Label.new()
	_document_session_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_document_session_preview_label)
	_document_session_dialog.add_child(content)
	add_child(_document_session_dialog)


func _build_clipboard_paste_resize_dialog() -> void:
	_clipboard_paste_resize_dialog = ConfirmationDialog.new()
	_clipboard_paste_resize_dialog.title = "Resize Canvas?"
	_clipboard_paste_resize_dialog.ok_button_text = "Resize & Paste"
	_clipboard_paste_resize_dialog.cancel_button_text = "Cancel"
	_clipboard_paste_resize_dialog.confirmed.connect(_paste_pending_clipboard_image_with_resize)
	_clipboard_paste_resize_dialog.custom_action.connect(_on_clipboard_paste_resize_custom_action)
	_clipboard_paste_resize_dialog.add_button("Paste", false, "paste_keep_size")
	add_child(_clipboard_paste_resize_dialog)


func _build_crop_rectangle_dialog() -> void:
	_crop_rectangle_dialog = ConfirmationDialog.new()
	_crop_rectangle_dialog.title = "Crop Rectangle"
	_crop_rectangle_dialog.ok_button_text = "Apply"
	_crop_rectangle_dialog.cancel_button_text = "Cancel"
	_crop_rectangle_dialog.min_size = CROP_RECTANGLE_DIALOG_SIZE
	_crop_rectangle_dialog.max_size = CROP_RECTANGLE_DIALOG_SIZE
	_crop_rectangle_dialog.unresizable = true
	_crop_rectangle_dialog.confirmed.connect(_apply_crop_rectangle)
	_crop_rectangle_dialog.canceled.connect(_cancel_crop_rectangle)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(372.0, 148.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_theme_constant_override("separation", 12)
	var description := Label.new()
	description.text = "Choose the exact pixel rectangle. The canvas preview is non-destructive."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	var fields := GridContainer.new()
	fields.columns = 2
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("h_separation", 12)
	fields.add_theme_constant_override("v_separation", 8)
	content.add_child(fields)
	_crop_x = _add_crop_field(fields, "X")
	_crop_y = _add_crop_field(fields, "Y")
	_crop_width = _add_crop_field(fields, "Width")
	_crop_height = _add_crop_field(fields, "Height")
	_crop_rectangle_dialog.add_child(content)
	add_child(_crop_rectangle_dialog)


func _add_crop_field(parent: GridContainer, label_text: String) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var field := SpinBox.new()
	field.min_value = 0.0 if label_text == "X" or label_text == "Y" else 1.0
	field.max_value = GDDrawCanvasControl.MAX_IMAGE_SIZE
	field.step = 1.0
	field.allow_greater = false
	field.allow_lesser = false
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.tooltip_text = (
		"Crop rectangle %s in pixels"
		if label_text == "Width" or label_text == "Height"
		else "Crop rectangle %s position in pixels"
	) % label_text.to_lower()
	field.value_changed.connect(_on_crop_rectangle_value_changed)
	parent.add_child(field)
	return field


func _build_scale_image_dialog() -> void:
	_scale_image_dialog = ConfirmationDialog.new()
	_scale_image_dialog.title = "Scale Image"
	_scale_image_dialog.ok_button_text = "Apply"
	_scale_image_dialog.cancel_button_text = "Cancel"
	_scale_image_dialog.min_size = SCALE_IMAGE_DIALOG_SIZE
	_scale_image_dialog.max_size = SCALE_IMAGE_DIALOG_SIZE
	_scale_image_dialog.unresizable = true
	_scale_image_dialog.confirmed.connect(_apply_scale_image)
	_scale_image_dialog.canceled.connect(_cancel_scale_image)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(372.0, 156.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_theme_constant_override("separation", 12)
	var description := Label.new()
	description.text = "Resample the image to exact pixel dimensions."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	var fields := GridContainer.new()
	fields.columns = 2
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("h_separation", 12)
	fields.add_theme_constant_override("v_separation", 8)
	content.add_child(fields)
	_scale_width = _add_scale_dimension_field(fields, "Width")
	_scale_height = _add_scale_dimension_field(fields, "Height")
	var preserve_label := Label.new()
	preserve_label.text = "Preserve Aspect"
	fields.add_child(preserve_label)
	_scale_preserve_aspect = CheckBox.new()
	_scale_preserve_aspect.button_pressed = true
	_scale_preserve_aspect.tooltip_text = "Keep the current width-to-height ratio while changing either dimension"
	_scale_preserve_aspect.toggled.connect(_on_scale_preserve_aspect_toggled)
	fields.add_child(_scale_preserve_aspect)
	var interpolation_label := Label.new()
	interpolation_label.text = "Interpolation"
	fields.add_child(interpolation_label)
	_scale_interpolation = OptionButton.new()
	_scale_interpolation.add_item("Nearest-neighbor", GDDrawCanvasControl.ScaleInterpolation.NEAREST)
	_scale_interpolation.add_item("Bilinear", GDDrawCanvasControl.ScaleInterpolation.BILINEAR)
	_scale_interpolation.select(0)
	_scale_interpolation.tooltip_text = "Choose the resampling method used for the scaled image"
	_scale_interpolation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(_scale_interpolation)
	_scale_image_dialog.add_child(content)
	add_child(_scale_image_dialog)


func _add_scale_dimension_field(parent: GridContainer, label_text: String) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var field := _make_dimension_spinbox()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.tooltip_text = "Scaled image %s in pixels" % label_text.to_lower()
	if label_text == "Width":
		field.value_changed.connect(_on_scale_width_changed)
	else:
		field.value_changed.connect(_on_scale_height_changed)
	parent.add_child(field)
	return field


func _build_update_available_overlay() -> void:
	_update_available_overlay = PanelContainer.new()
	_update_available_overlay.name = "Update Available Overlay"
	_update_available_overlay.visible = false
	_update_available_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_update_available_overlay.clip_contents = true
	_update_available_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay_background := StyleBoxFlat.new()
	overlay_background.bg_color = Color(0.035, 0.035, 0.035, 0.96)
	_update_available_overlay.add_theme_stylebox_override("panel", overlay_background)
	var overlay_host: Control = _workspace_region if _workspace_region else self
	overlay_host.add_child(_update_available_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_available_overlay.add_child(center)
	var card := PanelContainer.new()
	card.name = "Update Details Card"
	card.custom_minimum_size = Vector2(440.0, 230.0)
	card.add_theme_stylebox_override("panel", _make_help_description_style())
	center.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	_update_overlay_title = Label.new()
	_update_overlay_title.name = "Update Status Title"
	_update_overlay_title.add_theme_font_size_override("font_size", 18)
	content.add_child(_update_overlay_title)
	_update_installed_version_label = Label.new()
	_update_installed_version_label.name = "Installed Version"
	content.add_child(_update_installed_version_label)
	_update_latest_version_label = Label.new()
	_update_latest_version_label.name = "Latest Version"
	_update_latest_version_label.add_theme_color_override("font_color", Color("#FF9AA2"))
	content.add_child(_update_latest_version_label)
	_update_overlay_message = Label.new()
	_update_overlay_message.name = "Update Status Message"
	_update_overlay_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_overlay_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_update_overlay_message)
	_update_progress_label = Label.new()
	_update_progress_label.name = "Update Progress Label"
	_update_progress_label.visible = false
	content.add_child(_update_progress_label)
	_update_progress = ProgressBar.new()
	_update_progress.name = "Update Progress"
	_update_progress.visible = false
	_update_progress.min_value = 0.0
	_update_progress.max_value = 100.0
	_update_progress.show_percentage = true
	content.add_child(_update_progress)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	_update_retry_button = Button.new()
	_update_retry_button.name = "Try Again"
	_update_retry_button.text = "Try Again"
	_update_retry_button.visible = false
	_update_retry_button.pressed.connect(_retry_update_check)
	actions.add_child(_update_retry_button)
	_update_cancel_button = Button.new()
	_update_cancel_button.name = "Cancel Download"
	_update_cancel_button.text = "Cancel"
	_update_cancel_button.visible = false
	_update_cancel_button.pressed.connect(_cancel_update_download)
	actions.add_child(_update_cancel_button)
	_update_later_button = Button.new()
	_update_later_button.name = "Later"
	_update_later_button.text = "Later"
	_update_later_button.pressed.connect(_close_update_available_overlay)
	actions.add_child(_update_later_button)
	_update_download_button = Button.new()
	_update_download_button.name = "Download Update"
	_update_download_button.text = "Download Update"
	_update_download_button.visible = false
	_update_download_button.pressed.connect(_download_update)
	actions.add_child(_update_download_button)
	_update_install_button = Button.new()
	_update_install_button.name = "Install and Restart"
	_update_install_button.text = "Install and Restart"
	_update_install_button.visible = false
	_update_install_button.pressed.connect(_install_update_and_restart)
	actions.add_child(_update_install_button)
	_update_open_release_button = Button.new()
	_update_open_release_button.name = "Open Release Page"
	_update_open_release_button.text = "Open Release Page"
	_update_open_release_button.pressed.connect(_open_latest_release_page)
	actions.add_child(_update_open_release_button)


func _check_for_updates(automatic := false) -> bool:
	_ensure_helpers()
	if not _update_checker or _update_checker.is_request_active() or (_updater and _updater.is_busy()):
		return false
	var installed_version := _get_installed_plugin_version()
	if installed_version.is_empty():
		if not automatic:
			_show_update_error_overlay("Could not determine the installed GDDraw version.")
		return false
	if not automatic:
		_show_update_checking_overlay()
	if _updater:
		_updater.mark_checking(automatic)
	_set_update_checking_state(true)
	var started: bool = _update_checker.check_for_updates(installed_version, automatic)
	if not started:
		_set_update_checking_state(false)
	return started


func _on_update_check_completed(result: Dictionary) -> void:
	if not is_inside_tree():
		return
	_set_update_checking_state(false)
	var automatic := bool(result.get("automatic", false))
	var status := str(result.get("status", "error"))
	if status == "update_available":
		var latest_version := str(result.get("latest_version", ""))
		var release_url := str(result.get("release_url", ""))
		if latest_version.is_empty() or not _update_checker.is_valid_release_url(release_url):
			if not automatic:
				_show_update_error_overlay("The update response did not contain a safe release link.")
			return
		if not _updater or not _updater.prepare_release(result, _get_installed_plugin_version()):
			if not automatic:
				_show_update_error_overlay("The stable release does not contain one unambiguous, digest-protected GDDraw update asset.")
			return
		_latest_release_descriptor = result.duplicate(true)
		_latest_available_version = latest_version
		_latest_release_url = release_url
		_show_update_available_indicator()
		if not automatic:
			_show_update_available_overlay()
	elif status == "up_to_date":
		if _updater:
			_updater.mark_current(str(result.get("latest_version", "")), automatic)
		if not automatic:
			_show_update_current_overlay(str(result.get("latest_version", "")))
	elif status == "installed_ahead_of_release":
		if _updater:
			_updater.mark_installed_ahead(str(result.get("latest_version", "")), automatic)
		if not automatic:
			_show_update_ahead_overlay(str(result.get("latest_version", "")))
	elif not automatic:
		var error_kind := str(result.get("error_kind", ""))
		if error_kind.begins_with("release_asset"):
			_latest_release_url = str(result.get("release_url", ""))
			_show_update_error_overlay("The release is newer, but its required GDDraw ZIP or SHA-256 metadata is missing or ambiguous.")
		else:
			_show_update_error_overlay("Could not check for GDDraw updates. Try again when online.")


func _set_update_checking_state(checking: bool) -> void:
	if not _help_menu:
		return
	var index := _help_menu.get_item_index(MenuCommand.HELP_CHECK_UPDATES)
	if index < 0:
		return
	_help_menu.set_item_text(index, "Checking for Updates..." if checking else "Check for Updates...")
	_help_menu.set_item_disabled(index, checking)


func _show_update_available_indicator() -> void:
	if _latest_available_version.is_empty() or not _help_menu:
		return
	_populate_help_menu(true)
	if _help_update_badge:
		_help_update_badge.tooltip_text = "GDDraw v%s is available" % _latest_available_version
		_help_update_badge.visible = true
		for menu_index in range(_menu_bar.get_menu_count()):
			if _menu_bar.get_menu_popup(menu_index) == _help_menu:
				_menu_bar.set_menu_tooltip(menu_index, _help_update_badge.tooltip_text)
				break
		call_deferred("_reposition_help_update_badge")


func _make_update_warning_icon() -> ImageTexture:
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(16):
		for x in range(16):
			var offset := Vector2(float(x) - 7.5, float(y) - 7.5)
			if offset.length_squared() <= 49.0:
				image.set_pixel(x, y, Color("#D93643"))
	for y in range(3, 10):
		image.set_pixel(7, y, Color.WHITE)
		image.set_pixel(8, y, Color.WHITE)
	for y in range(12, 14):
		image.set_pixel(7, y, Color.WHITE)
		image.set_pixel(8, y, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _show_update_available_overlay() -> void:
	if _updater and _updater.state in [
		GDDrawUpdater.State.DOWNLOADING,
		GDDrawUpdater.State.VERIFYING,
		GDDrawUpdater.State.READY_TO_INSTALL,
		GDDrawUpdater.State.INSTALLING,
		GDDrawUpdater.State.RESTART_REQUIRED,
		GDDrawUpdater.State.FAILED,
	]:
		_on_updater_state_changed(_updater.state, _updater.details)
		return
	if (
		not _update_available_overlay
		or _latest_available_version.is_empty()
		or not _update_checker
		or not _update_checker.is_valid_release_url(_latest_release_url)
	):
		return
	_present_update_overlay(
		"GDDraw Update Available",
		"Download the digest-protected stable release to user data. Nothing is downloaded or installed until you choose it.",
		_latest_available_version,
		Color("#FF7A85"),
		true,
		false,
		"Later"
	)
	_update_download_button.visible = true
	_update_download_button.disabled = false


func _show_update_checking_overlay() -> void:
	_present_update_overlay(
		"Checking for Updates...",
		"GDDraw is checking the latest stable GitHub release.",
		"",
		Color("#D8E8FF"),
		false,
		false,
		"Close"
	)


func _show_update_current_overlay(latest_version: String) -> void:
	_present_update_overlay(
		"GDDraw Is Up to Date!",
		"You have the latest stable version of GDDraw.",
		latest_version,
		Color("#7ED99A"),
		false,
		false,
		"Close"
	)


func _show_update_ahead_overlay(latest_version: String) -> void:
	_present_update_overlay(
		"GDDraw Build Ahead of Release",
		"This GDDraw build is newer than the latest published release.",
		latest_version,
		Color("#8FCBFF"),
		false,
		false,
		"Close"
	)


func _show_update_error_overlay(message: String) -> void:
	_update_retry_mode = "check"
	_present_update_overlay(
		"Update Check Unavailable",
		message,
		"",
		Color("#FFB36B"),
		false,
		true,
		"Close"
	)


func _present_update_overlay(
	title: String,
	message: String,
	latest_version: String,
	title_color: Color,
	show_open_release: bool,
	show_retry: bool,
	close_text: String
) -> void:
	if not _update_available_overlay:
		return
	if _settings_overlay:
		_settings_overlay.visible = false
	if _fill_settings_overlay:
		_fill_settings_overlay.visible = false
	if _create_textured_csg_overlay:
		_create_textured_csg_overlay.visible = false
	_update_overlay_title.text = title
	_update_overlay_title.add_theme_color_override("font_color", title_color)
	_update_overlay_message.text = message
	_update_installed_version_label.text = "Installed version: v%s" % _get_installed_plugin_version()
	_update_latest_version_label.visible = not latest_version.is_empty()
	_update_latest_version_label.text = "Latest version: v%s" % latest_version
	_update_open_release_button.visible = show_open_release
	_update_retry_button.visible = show_retry
	_update_later_button.text = close_text
	_update_later_button.visible = true
	_update_later_button.disabled = false
	_update_download_button.visible = false
	_update_download_button.disabled = false
	_update_install_button.visible = false
	_update_install_button.disabled = false
	_update_cancel_button.visible = false
	_update_cancel_button.disabled = false
	_update_progress.visible = false
	_update_progress_label.visible = false
	var overlay_parent := _update_available_overlay.get_parent()
	if overlay_parent:
		overlay_parent.move_child(_update_available_overlay, overlay_parent.get_child_count() - 1)
	_update_available_overlay.visible = true


func _close_update_available_overlay() -> void:
	if _updater and _updater.state == GDDrawUpdater.State.INSTALLING:
		return
	if _update_available_overlay:
		_update_available_overlay.visible = false


func _retry_update_check() -> void:
	if _update_retry_mode == "download" and _updater and not _latest_release_descriptor.is_empty():
		if _updater.prepare_release(_latest_release_descriptor, _get_installed_plugin_version()):
			_updater.download_update()
		return
	_check_for_updates(false)


func _download_update() -> void:
	if not _updater or _latest_release_descriptor.is_empty():
		_show_update_error_overlay("The validated release metadata is no longer available.")
		return
	_updater.download_update()


func _cancel_update_download() -> void:
	if _updater:
		_updater.cancel_download()


func _install_update_and_restart() -> void:
	if not _updater:
		return
	_update_install_button.disabled = true
	_update_later_button.disabled = true
	_updater.install_and_restart()


func _on_updater_progress_changed(downloaded_bytes: int, total_bytes: int) -> void:
	if not _update_progress or not _update_progress_label:
		return
	_update_progress_label.visible = true
	_update_progress_label.text = "%s downloaded%s" % [
		_format_update_bytes(downloaded_bytes),
		" of %s" % _format_update_bytes(total_bytes) if total_bytes > 0 else "",
	]
	if total_bytes > 0:
		_update_progress.indeterminate = false
		_update_progress.value = clampf(float(downloaded_bytes) / float(total_bytes) * 100.0, 0.0, 100.0)
	else:
		_update_progress.indeterminate = true


func _on_updater_state_changed(updater_state: int, updater_details: Dictionary) -> void:
	if not _update_available_overlay:
		return
	_set_update_operation_busy(updater_state in [
		GDDrawUpdater.State.DOWNLOADING,
		GDDrawUpdater.State.VERIFYING,
		GDDrawUpdater.State.INSTALLING,
		GDDrawUpdater.State.RECOVERING,
	])
	var target_version := str(updater_details.get("target_version", _latest_available_version))
	match updater_state:
		GDDrawUpdater.State.DOWNLOADING:
			_present_update_overlay(
				"Downloading GDDraw v%s" % target_version,
				"The stable release archive is downloading to user://gddraw/updates/downloads/.",
				target_version, Color("#D8E8FF"), false, false, "Later"
			)
			_update_later_button.visible = false
			_update_cancel_button.visible = true
			_update_progress.visible = true
			_update_progress.indeterminate = int(updater_details.get("total_bytes", -1)) <= 0
			_on_updater_progress_changed(int(updater_details.get("downloaded_bytes", 0)), int(updater_details.get("total_bytes", -1)))
		GDDrawUpdater.State.VERIFYING:
			_present_update_overlay(
				"Validating GDDraw v%s" % target_version,
				"GDDraw is checking the external SHA-256 digest, every archive path, package layout, and internal versions.",
				target_version, Color("#D8E8FF"), false, false, "Later"
			)
			_update_later_button.visible = false
		GDDrawUpdater.State.READY_TO_INSTALL:
			_present_update_overlay(
				"GDDraw v%s Is Ready" % target_version,
				"Install and Restart backs up the complete current plugin, transactionally replaces it, verifies every file, and asks Godot to restart. The update is not installed yet.",
				target_version, Color("#7ED99A"), true, false, "Later"
			)
			_update_install_button.visible = true
		GDDrawUpdater.State.INSTALLING:
			_present_update_overlay(
				"Installing GDDraw v%s" % target_version,
				"GDDraw is backing up and replacing the plugin package. Do not interact with the dock.",
				target_version, Color("#FFB36B"), false, false, "Later"
			)
			_update_later_button.visible = false
		GDDrawUpdater.State.RESTART_REQUIRED:
			_present_update_overlay(
				"Restart Requested",
				str(updater_details.get("message", "Restart Godot manually. The update becomes active only after the restarted editor validates it.")),
				target_version, Color("#7ED99A"), false, false, "Close"
			)
		GDDrawUpdater.State.FAILED:
			_update_retry_mode = "download" if bool(updater_details.get("retry_safe", false)) and not _latest_release_descriptor.is_empty() else "check"
			var release_url := str(updater_details.get("release_url", ""))
			if not release_url.is_empty():
				_latest_release_url = release_url
			_present_update_overlay(
				"GDDraw Update Failed",
				str(updater_details.get("message", "The update could not be completed.")),
				target_version, Color("#FF7A85"), not _latest_release_url.is_empty(), bool(updater_details.get("retry_safe", false)), "Close"
			)


func _set_update_operation_busy(busy: bool) -> void:
	if not _help_menu:
		return
	var check_index := _help_menu.get_item_index(MenuCommand.HELP_CHECK_UPDATES)
	if check_index >= 0:
		_help_menu.set_item_disabled(check_index, busy)
	var available_index := _help_menu.get_item_index(MenuCommand.HELP_UPDATE_AVAILABLE)
	if available_index >= 0:
		_help_menu.set_item_disabled(available_index, busy)


func _recover_update_transaction() -> void:
	if not _updater:
		return
	var recovery: Dictionary = _updater.recover_incomplete_transaction()
	var recovery_status := str(recovery.get("status", "none"))
	if recovery_status == "rolled_back":
		_present_update_overlay(
			"GDDraw Update Rolled Back",
			str(recovery.get("message", "The previous verified package was restored.")),
			"", Color("#FFB36B"), false, false, "Close"
		)
	elif recovery_status == "manual_recovery":
		_present_update_overlay(
			"Manual Update Recovery Required",
			str(recovery.get("message", "Update recovery data was preserved under user://gddraw/updates/.")),
			"", Color("#FF7A85"), false, false, "Close"
		)


func _format_update_bytes(byte_count: int) -> String:
	if byte_count < 1024:
		return "%d B" % byte_count
	if byte_count < 1024 * 1024:
		return "%.1f KiB" % (float(byte_count) / 1024.0)
	return "%.1f MiB" % (float(byte_count) / (1024.0 * 1024.0))


func _open_latest_release_page() -> void:
	if not _update_checker or not _update_checker.is_valid_release_url(_latest_release_url):
		_show_update_error_overlay("The configured GDDraw release page is not valid.")
		return
	var error := OK
	if _release_url_opener.is_valid():
		var opener_result = _release_url_opener.call(_latest_release_url)
		if opener_result is int:
			error = opener_result
	else:
		error = OS.shell_open(_latest_release_url)
	if error == OK:
		_close_update_available_overlay()
	else:
		_show_update_error_overlay("Could not open the GDDraw release page.")


func set_release_url_opener_for_tests(opener: Callable) -> void:
	_release_url_opener = opener


func _get_installed_plugin_version() -> String:
	var plugin_script = load(PLUGIN_SCRIPT_PATH)
	if not plugin_script or not plugin_script.has_method("get_script_constant_map"):
		return ""
	var constants: Dictionary = plugin_script.call("get_script_constant_map")
	return str(constants.get("PLUGIN_VERSION", ""))


func _build_help_dialog() -> void:
	_help_dialog = AcceptDialog.new()
	_help_dialog.min_size = Vector2i(560, 320)
	_help_dialog.dialog_text = ""

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	_help_dialog.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 300)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_help_content = VBoxContainer.new()
	_help_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_help_content)

	add_child(_help_dialog)


func _show_help_dialog(title: String, message: String) -> void:
	if not _help_dialog:
		return
	_help_dialog.title = title
	_help_dialog.dialog_text = ""
	_populate_help_dialog(message)
	_help_dialog.popup_centered(Vector2i(640, 420))


func _populate_help_dialog(message: String) -> void:
	if not _help_content:
		return
	for child in _help_content.get_children():
		_help_content.remove_child(child)
		child.queue_free()

	var pending_lines: PackedStringArray = []
	var lines := message.split("\n")
	for raw_line in lines:
		var line := raw_line.strip_edges()
		if line.is_empty():
			_flush_help_description(pending_lines)
			pending_lines = PackedStringArray()
		elif line.ends_with(":"):
			_flush_help_description(pending_lines)
			pending_lines = PackedStringArray()
			_add_help_header(line)
		else:
			pending_lines.push_back(line)
	_flush_help_description(pending_lines)


func _flush_help_description(lines: PackedStringArray) -> void:
	if lines.is_empty() or not _help_content:
		return
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_help_description_style())
	_help_content.add_child(panel)

	var label := Label.new()
	label.text = "\n".join(lines)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("#D6D6D6"))
	label.add_theme_font_size_override("font_size", 13)
	panel.add_child(label)


func _add_help_header(text: String) -> void:
	if not _help_content:
		return
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("#F0F0F0"))
	label.add_theme_font_size_override("font_size", 15)
	_help_content.add_child(label)


func _make_help_description_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.085, 0.085, 1.0)
	style.border_color = Color(0.18, 0.18, 0.18, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


func _build_clipboard_poll_timer() -> void:
	_clipboard_poll_timer = Timer.new()
	_clipboard_poll_timer.wait_time = 0.5
	_clipboard_poll_timer.timeout.connect(_update_selection_action_buttons)
	add_child(_clipboard_poll_timer)
	_clipboard_poll_timer.start()


func _on_brush_toggled(enabled: bool) -> void:
	if enabled:
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _open_preferences() -> void:
	if _fill_settings_overlay:
		_fill_settings_overlay.visible = false
	if _create_textured_csg_overlay:
		_create_textured_csg_overlay.visible = false
	if _update_available_overlay:
		_update_available_overlay.visible = false
	if _settings_overlay:
		var overlay_parent := _settings_overlay.get_parent()
		if overlay_parent:
			overlay_parent.move_child(_settings_overlay, overlay_parent.get_child_count() - 1)
		_settings_overlay.visible = true


func _close_preferences() -> void:
	if _settings_overlay:
		_settings_overlay.visible = false


func _select_canvas_mode(mode_id: int) -> void:
	if mode_id < CANVAS_MODE_2D or mode_id > CANVAS_MODE_SPLIT:
		return
	if mode_id != _canvas_mode:
		_cancel_3d_surface_shape("Canceled 3D shape preview because the view changed.", true)
	if _canvas_mode == CANVAS_MODE_SPLIT and mode_id != CANVAS_MODE_SPLIT:
		_capture_split_ratio()
	if mode_id != CANVAS_MODE_SPLIT:
		_hide_3d_hover_debug_marker("canvas mode changed")
		_hide_3d_hover_triangle()
		if _canvas:
			_canvas.clear_external_hover_uv()
			_canvas.clear_external_hover_triangle()
	_canvas_mode = mode_id
	_canvas_mode_3d = mode_id == CANVAS_MODE_3D or mode_id == CANVAS_MODE_SPLIT
	if not _canvas_mode_3d:
		_stop_3d_freelook()
	_update_canvas_resize_control_availability()
	var split_mode := mode_id == CANVAS_MODE_SPLIT
	_update_3d_context_control_visibility()
	if _canvas_2d_host:
		_canvas_2d_host.visible = mode_id != CANVAS_MODE_3D or not _paint_3d_view
	if _canvas_3d_host:
		_canvas_3d_host.visible = _canvas_mode_3d
	if _canvas:
		_canvas.uv_overlay_visible = _canvas_mode_3d and _uv_overlay_toggle and _uv_overlay_toggle.button_pressed
	_update_3d_wire_overlay_visibility()
	if _paint_3d_view:
		_paint_3d_view.visible = _canvas_mode_3d
	if _canvas_mode_3d:
		_connect_editor_selection_changed()
		if _texture_3d_session and _texture_3d_session.has_active_session():
			_sync_3d_paint_view()
			_set_active_3d_session_status(split_mode)
		else:
			_clear_3d_paint_mesh()
			_update_3d_selection_status()
	else:
		_disconnect_editor_selection_changed()
		if _canvas:
			_canvas.uv_overlay_visible = false
			_canvas.clear_uv_overlay_data()
		if _paint_3d_view:
			_clear_3d_paint_mesh()
		_set_status("2D canvas mode active.")
	if split_mode:
		call_deferred("_apply_split_ratio")
	_update_split_view_controls()
	_update_tool_options_visibility()
	_sync_menu_state()


func _set_active_3d_session_status(split_mode: bool) -> void:
	var mode_name := "Split" if split_mode else "3D"
	_update_3d_session_status()
	_set_status("%s mode active." % mode_name)


func _update_3d_session_status(image: Image = null) -> void:
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		if _session_status_label:
			_session_status_label.visible = false
			_session_status_label.text = ""
		if _stop_3d_session_button:
			_stop_3d_session_button.visible = false
			_stop_3d_session_button.tooltip_text = "Stop the active 3D texture session and restore the previous 2D workspace"
		if _empty_3d_state:
			_empty_3d_state.visible = _canvas_mode_3d
		return
	var current_image := image
	if not current_image and _canvas:
		current_image = _canvas.get_image_copy()
	var state := "Unsaved" if _texture_3d_session.is_dirty(current_image) else "Clean"
	var identity := "%s · %s" % [_texture_3d_session.get_identity_text(), state]
	if _session_status_label:
		_session_status_label.text = identity
		_session_status_label.visible = false
	if _stop_3d_session_button:
		_stop_3d_session_button.visible = true
		_stop_3d_session_button.tooltip_text = "Editing %s\nClick to stop and restore the previous 2D workspace." % identity
	if _empty_3d_state:
		_empty_3d_state.visible = false


func _update_split_view_controls() -> void:
	if _view_mode_selector:
		var selected_index := 0
		if _canvas_mode == CANVAS_MODE_3D:
			selected_index = 1
		elif _canvas_mode == CANVAS_MODE_SPLIT:
			selected_index = 3 if _split_vertical else 2
		_view_mode_selector.select(selected_index)
	if _linked_view_toggle:
		_linked_view_toggle.visible = _canvas_mode == CANVAS_MODE_SPLIT
		_linked_view_toggle.set_pressed_no_signal(_linked_view_enabled)
		_update_toggle_button_icon(_linked_view_toggle)
	if _zoom_label:
		_zoom_label.visible = true
		_zoom_label.text = "%d%%" % _current_2d_zoom_percent
	if _zoom_3d_label:
		_zoom_3d_label.visible = true
		_update_3d_view_readout()


func _on_view_mode_selected(index: int) -> void:
	match index:
		0:
			_select_canvas_mode(CANVAS_MODE_2D)
		1:
			_select_canvas_mode(CANVAS_MODE_3D)
		2:
			_set_split_layout(false)
		3:
			_set_split_layout(true)


func _on_linked_view_toggled(enabled: bool) -> void:
	_linked_view_enabled = enabled
	_update_linked_view_tooltip()
	if not enabled:
		_hide_3d_hover_debug_marker("linked view disabled")
		_hide_3d_hover_triangle()
		if _canvas:
			_canvas.clear_external_hover_uv()
			_canvas.clear_external_hover_triangle()
	_save_split_view_preferences()
	_sync_menu_state()


func _set_linked_view_enabled(enabled: bool) -> void:
	if _linked_view_toggle:
		_linked_view_toggle.set_pressed_no_signal(enabled)
		_update_toggle_button_icon(_linked_view_toggle)
		_update_linked_view_tooltip()
	_on_linked_view_toggled(enabled)


func _update_linked_view_tooltip() -> void:
	if not _linked_view_toggle:
		return
	_linked_view_toggle.tooltip_text = "Unlink 2D and 3D hover previews" if _linked_view_enabled else "Link 2D and 3D hover previews"


func _update_3d_view_readout() -> void:
	if not _zoom_3d_label:
		return
	_zoom_3d_label.text = "%.2f" % _paint_3d_distance
	_zoom_3d_label.tooltip_text = "3D camera distance: %.2f; freelook speed: %.2fx" % [_paint_3d_distance, _paint_3d_freelook_speed_multiplier]


func _update_3d_context_control_visibility() -> void:
	var has_active_session: bool = _texture_3d_session != null and _texture_3d_session.has_active_session()
	if _load_selected_mesh_button:
		_load_selected_mesh_button.visible = _canvas_mode_3d and not has_active_session
	if _uv_overlay_toggle:
		var has_uv_data: bool = (
			has_active_session
			and not _texture_3d_session.uv_vertices.is_empty()
		)
		_uv_overlay_toggle.visible = _canvas_mode_3d and has_uv_data
	if _preview_orientation_button:
		_preview_orientation_button.visible = _canvas_mode_3d and has_active_session
	if _preview_orientation_controls:
		_preview_orientation_controls.visible = _canvas_mode_3d and has_active_session
	if _preview_scene_orientation_button:
		var linked: bool = (
			has_active_session
			and _texture_3d_session.has_method("is_scene_transform_linked")
			and _texture_3d_session.is_scene_transform_linked()
		)
		_apply_scene_transform_link_control_state(linked)
	_update_3d_rotation_gizmo_visibility()
	if _empty_3d_state:
		_empty_3d_state.visible = _canvas_mode_3d and not has_active_session
	_sync_menu_state()


func _on_preview_light_toggled(enabled: bool) -> void:
	_set_preview_light_enabled(enabled, true)


func _on_preview_light_intensity_changed(value: float) -> void:
	_set_preview_light_intensity(value, true)


func _on_preview_light_camera_link_toggled(linked: bool) -> void:
	_set_preview_light_camera_linked(linked, true)


func _set_preview_light_enabled(enabled: bool, save_preference := false) -> void:
	_preview_light_enabled = enabled
	_apply_preview_lighting_state()
	if save_preference:
		_save_preview_light_preferences()


func _set_preview_light_intensity(value: float, save_preference := false) -> void:
	_preview_light_intensity_value = _clamp_preview_light_intensity(value)
	if _paint_3d_preview_light:
		_paint_3d_preview_light.light_energy = _preview_light_intensity_value
	if _preview_light_intensity:
		_preview_light_intensity.set_value_no_signal(_preview_light_intensity_value)
	if save_preference:
		_save_preview_light_preferences()


func _clamp_preview_light_intensity(value: float) -> float:
	return clampf(value, PAINT_3D_PREVIEW_LIGHT_MIN, PAINT_3D_PREVIEW_LIGHT_MAX)


func _set_preview_light_camera_linked(linked: bool, save_preference := false) -> void:
	_preview_light_camera_linked = linked
	_update_preview_light_transform()
	_apply_preview_light_control_state()
	if save_preference:
		_save_preview_light_preferences()


func _reset_preview_light_orientation() -> void:
	_preview_light_camera_linked = false
	if _paint_3d_preview_light:
		_paint_3d_preview_light.rotation_degrees = PAINT_3D_PREVIEW_LIGHT_DEFAULT_ROTATION
	_apply_preview_light_control_state()
	_save_preview_light_preferences()


func _update_preview_light_transform() -> void:
	if not _preview_light_camera_linked or not _paint_3d_preview_light or not _paint_3d_camera:
		return
	# The camera and light are siblings in the private preview root, so copying
	# the camera basis creates a neutral headlight without touching scene nodes.
	var light_transform := _paint_3d_preview_light.transform
	light_transform.basis = _paint_3d_camera.transform.basis
	_paint_3d_preview_light.transform = light_transform


func _apply_preview_lighting_state() -> void:
	if _paint_3d_preview_light:
		_paint_3d_preview_light.visible = _preview_light_enabled
		_paint_3d_preview_light.light_energy = _clamp_preview_light_intensity(_preview_light_intensity_value)
	if _paint_3d_material:
		_paint_3d_material.shading_mode = (
			BaseMaterial3D.SHADING_MODE_PER_PIXEL
			if _preview_light_enabled
			else BaseMaterial3D.SHADING_MODE_UNSHADED
		)
	if _preview_light_toggle:
		_preview_light_toggle.set_pressed_no_signal(_preview_light_enabled)
		_update_toggle_button_icon(_preview_light_toggle)
		_preview_light_toggle.tooltip_text = (
			"Neutral lighting is enabled. Disable it for a color-accurate unshaded preview."
			if _preview_light_enabled
			else "Neutral lighting is disabled for a color-accurate unshaded preview."
		)
	if _preview_light_intensity:
		_preview_light_intensity.editable = _preview_light_enabled
		_preview_light_intensity.tooltip_text = (
			"Adjust the neutral light intensity in the 3D preview."
			if _preview_light_enabled
			else "Enable neutral lighting to adjust its intensity."
		)
	_update_preview_light_transform()
	_apply_preview_light_control_state()


func _apply_preview_light_control_state() -> void:
	if _preview_light_link_toggle:
		_preview_light_link_toggle.disabled = not _preview_light_enabled
		_preview_light_link_toggle.set_pressed_no_signal(_preview_light_camera_linked)
		_update_toggle_button_icon(_preview_light_link_toggle)
		_preview_light_link_toggle.tooltip_text = (
			"The neutral light follows the 3D preview camera. Disable linking to hold its direction."
			if _preview_light_camera_linked
			else "Link the neutral light direction to the 3D preview camera."
		)
	if _preview_light_reset_button:
		_preview_light_reset_button.disabled = not _preview_light_enabled
		_preview_light_reset_button.tooltip_text = "Unlink and reset the neutral light direction."


func _on_preview_rotation_gizmo_toggled(enabled: bool) -> void:
	if _paint_3d_gizmo_dragging:
		_cancel_3d_rotation_gizmo_drag(true)
	_paint_3d_gizmo_visible = enabled
	_update_3d_rotation_gizmo_visibility()
	if _preview_orientation_button:
		_preview_orientation_button.set_pressed_no_signal(enabled)
		_update_toggle_button_icon(_preview_orientation_button)
	_save_preview_transform_gizmo_preference()


func _on_reset_preview_orientation_pressed() -> void:
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		return
	_cancel_3d_rotation_gizmo_drag(false)
	_texture_3d_session.reset_preview_transform()
	_apply_scene_transform_link_control_state(false)
	_apply_3d_preview_transform(false)
	_set_status("Restored GDDraw's isolated preview to its session-start transform; the source scene is unchanged.")


func _on_scene_transform_link_toggled(linked: bool) -> void:
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		_apply_scene_transform_link_control_state(false)
		return
	_cancel_3d_rotation_gizmo_drag(false)
	var source := _get_active_3d_source_node()
	if linked and (not is_instance_valid(source) or not source.is_inside_tree()):
		_texture_3d_session.set_scene_transform_linked(false)
		_apply_scene_transform_link_control_state(false)
		_update_3d_context_control_visibility()
		_set_status("Scene Transform Link is unavailable while the source scene is inactive; the private 3D preview remains editable.")
		return
	var preview_changed: bool = _texture_3d_session.set_scene_transform_linked(
		linked,
		source.global_transform if linked else Transform3D.IDENTITY
	)
	if preview_changed:
		_apply_3d_preview_transform(false)
	_apply_scene_transform_link_control_state(linked)
	_set_status(
		"Source transforms now update GDDraw's isolated preview one-way."
		if linked
		else "Scene transform linking disabled; GDDraw's isolated preview transform is retained."
	)


func _apply_scene_transform_link_control_state(linked: bool) -> void:
	if not _preview_scene_orientation_button:
		return
	var source_available := _is_active_3d_source_available()
	_preview_scene_orientation_button.disabled = not source_available
	_preview_scene_orientation_button.set_pressed_no_signal(linked)
	_update_toggle_button_icon(_preview_scene_orientation_button)
	_preview_scene_orientation_button.tooltip_text = (
		"Scene transform linking is unavailable while the source scene is inactive or closed. The 3D preview remains editable."
		if not source_available
		else
		"The source scene transform is linked to the 3D preview."
		if linked
		else "Link the source scene transform to the 3D preview."
	)


func _is_active_3d_source_available() -> bool:
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		return false
	var source := _get_active_3d_source_node()
	return is_instance_valid(source) and source.is_inside_tree()


func _get_active_3d_source_node() -> Node3D:
	if not _texture_3d_session:
		return null
	var has_source_property := false
	for property in _texture_3d_session.get_property_list():
		if str(property.get("name", "")) == "source_node":
			has_source_property = true
			break
	if not has_source_property:
		return null
	var candidate = _texture_3d_session.get("source_node")
	return candidate as Node3D if is_instance_valid(candidate) and candidate is Node3D else null


func _on_preview_3d_grid_toggled(enabled: bool) -> void:
	_set_3d_preview_grid_visible(enabled, true)


func _set_3d_preview_grid_visible(enabled: bool, save_preference := false) -> void:
	_preview_3d_grid_visible = enabled
	_apply_3d_preview_grid_state()
	if save_preference:
		_save_preview_3d_grid_preference()


func _apply_3d_preview_grid_state() -> void:
	if _paint_3d_stage_floor:
		# Retain the compatibility node, but do not render an opaque floor behind
		# the perspective grid. Godot's editor grid is lines over the environment.
		_paint_3d_stage_floor.visible = false
	if _paint_3d_stage_grid:
		_paint_3d_stage_grid.visible = _preview_3d_grid_visible
	if _preview_3d_grid_button:
		_preview_3d_grid_button.set_pressed_no_signal(_preview_3d_grid_visible)
		_update_toggle_button_icon(_preview_3d_grid_button)
		_preview_3d_grid_button.tooltip_text = (
			"Hide the perspective grid in the 3D preview."
			if _preview_3d_grid_visible
			else "Show the perspective grid in the 3D preview."
		)


func _on_use_scene_orientation_pressed() -> void:
	# Compatibility entry point for older integrations; the action is now an
	# explicit one-way toggle instead of a destructive one-shot import.
	_on_scene_transform_link_toggled(true)


func _set_canvas_mode_3d(enabled: bool) -> void:
	var mode_id := CANVAS_MODE_3D if enabled else CANVAS_MODE_2D
	_select_canvas_mode(mode_id)


func _set_split_layout(vertical: bool) -> void:
	if _canvas_mode == CANVAS_MODE_SPLIT:
		_capture_split_ratio()
	if _split_vertical != vertical:
		_split_vertical = vertical
		_rebuild_split_container()
	_save_split_view_preferences()
	_select_canvas_mode(CANVAS_MODE_SPLIT)


func _rebuild_split_container() -> void:
	if not _canvas_region or not _canvas_area or not _canvas_2d_host or not _canvas_3d_host:
		return
	var old_area := _canvas_area
	old_area.remove_child(_canvas_2d_host)
	old_area.remove_child(_canvas_3d_host)
	_canvas_area = VSplitContainer.new() if _split_vertical else HSplitContainer.new()
	_canvas_area.focus_mode = Control.FOCUS_CLICK
	_canvas_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas_region.add_child(_canvas_area)
	_canvas_region.move_child(_canvas_area, old_area.get_index())
	_canvas_split = _canvas_area as SplitContainer
	_canvas_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_canvas_split.dragged.connect(_on_split_dragged)
	_canvas_2d_host.custom_minimum_size = Vector2(240, 110) if _split_vertical else Vector2(240, 220)
	_canvas_3d_host.custom_minimum_size = Vector2(240, 110) if _split_vertical else Vector2(240, 220)
	_canvas_area.add_child(_canvas_2d_host)
	_canvas_area.add_child(_canvas_3d_host)
	old_area.queue_free()
	call_deferred("_apply_split_ratio")


func _on_split_dragged(_offset: int) -> void:
	_capture_split_ratio()
	_save_split_view_preferences()


func _capture_split_ratio() -> void:
	if not _canvas_split:
		return
	var available := _canvas_split.size.y if _split_vertical else _canvas_split.size.x
	if available <= 0.0:
		return
	# SplitContainer offsets are relative to the centered divider: zero is 50/50.
	var ratio := clampf(0.5 + float(_canvas_split.split_offset) / available, 0.2, 0.8)
	if _split_vertical:
		_split_vertical_ratio = ratio
	else:
		_split_horizontal_ratio = ratio


func _apply_split_ratio() -> void:
	if not _canvas_split or not _canvas_2d_host or not _canvas_3d_host:
		return
	if _canvas_mode != CANVAS_MODE_SPLIT:
		return
	var available := _canvas_split.size.y if _split_vertical else _canvas_split.size.x
	if available <= 0.0:
		return
	var ratio := _split_vertical_ratio if _split_vertical else _split_horizontal_ratio
	_canvas_split.split_offset = roundi(available * (ratio - 0.5))


func _on_shape_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_select_tool(_active_shape_tool)
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_text_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_select_tool(GDDrawCanvasControl.ToolMode.TEXT)
		_set_status("Drag to create a text box, then type. Ctrl+Enter commits; Escape cancels.")
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_text_font_selected(index: int) -> void:
	if not _canvas or not _text_font_selector:
		return
	var font_id := _text_font_selector.get_item_id(index)
	if font_id == TEXT_FONT_LOAD_ID:
		var previous_index := _text_font_selector.get_item_index(_text_font_selected_id)
		if previous_index >= 0:
			_text_font_selector.select(previous_index)
		if _text_font_dialog:
			var font_dir := _get_default_font_dir()
			if _font_directory_exists(font_dir):
				_text_font_dialog.current_dir = _font_directory_dialog_path(font_dir)
			_text_font_dialog.popup_centered_ratio(0.7)
		return
	var selected_font: Font
	if font_id == TEXT_FONT_DEFAULT_ID:
		selected_font = ThemeDB.fallback_font
	elif _text_font_sources.has(font_id):
		var font_source: Variant = _text_font_sources[font_id]
		if font_source is Font:
			selected_font = font_source
		elif font_source is Dictionary:
			selected_font = _load_text_font(str(font_source.get("path", "")))
	else:
		selected_font = ThemeDB.fallback_font
		font_id = TEXT_FONT_DEFAULT_ID
	if not selected_font:
		selected_font = ThemeDB.fallback_font
		font_id = TEXT_FONT_DEFAULT_ID
	_text_font_selected_id = font_id
	_canvas.text_font = selected_font
	call_deferred("_refocus_text_editor")


func _refresh_text_font_selector() -> void:
	if not _text_font_selector:
		return
	var previous_id := _text_font_selected_id
	_text_font_selector.clear()
	_text_font_sources.clear()
	_text_font_selector.add_item("Theme Default", TEXT_FONT_DEFAULT_ID)

	var custom_paths := _get_custom_font_paths(_get_default_font_dir())
	if not _text_custom_font_path.is_empty() and not custom_paths.has(_text_custom_font_path):
		custom_paths.push_back(_text_custom_font_path)
	custom_paths.sort_custom(func(left: String, right: String) -> bool: return left.naturalnocasecmp_to(right) < 0)
	var custom_id := TEXT_FONT_CUSTOM_ID_BASE
	for path in custom_paths:
		var font := _load_text_font(path)
		if not font:
			continue
		var item_id := TEXT_FONT_CUSTOM_ID if path == _text_custom_font_path else custom_id
		if item_id != TEXT_FONT_CUSTOM_ID:
			custom_id += 1
		_text_font_sources[item_id] = font
		_text_font_selector.add_item(path.get_file().get_basename(), item_id)

	_text_font_selector.add_item("Load Font…", TEXT_FONT_LOAD_ID)
	_text_font_selector.add_separator()
	var system_paths := _get_system_font_paths()
	for custom_path in custom_paths:
		system_paths.erase(custom_path)
	system_paths.sort_custom(func(left: String, right: String) -> bool: return left.get_file().naturalnocasecmp_to(right.get_file()) < 0)
	var system_id := TEXT_FONT_SYSTEM_ID_BASE
	for path in system_paths:
		# Load the exact system font file only when selected; eagerly parsing every
		# installed face can stall machines with large font collections.
		_text_font_sources[system_id] = {"path": path}
		_text_font_selector.add_item(path.get_file().get_basename(), system_id)
		_text_font_selector.set_item_tooltip(_text_font_selector.item_count - 1, path)
		system_id += 1

	var selected_index := _text_font_selector.get_item_index(previous_id)
	if selected_index < 0:
		_text_font_selected_id = TEXT_FONT_DEFAULT_ID
		selected_index = _text_font_selector.get_item_index(TEXT_FONT_DEFAULT_ID)
		if _canvas:
			_canvas.text_font = ThemeDB.fallback_font
	_text_font_selector.select(selected_index)


func _get_custom_font_paths(directory: String) -> Array[String]:
	var paths: Array[String] = []
	if not _font_directory_exists(directory):
		return paths
	_collect_custom_font_paths(directory, paths, 0)
	return paths


func _get_system_font_paths() -> Array[String]:
	var paths: Array[String] = []
	for directory in _get_system_font_directories():
		if _font_directory_exists(directory):
			_collect_custom_font_paths(directory, paths, 0)
	var unique_paths: Array[String] = []
	var seen := {}
	for path in paths:
		var key := path.to_lower()
		if not seen.has(key):
			seen[key] = true
			unique_paths.push_back(path)
	return unique_paths


func _get_system_font_directories() -> Array[String]:
	var directories: Array[String] = []
	match OS.get_name():
		"Windows":
			var windows_dir := OS.get_environment("WINDIR")
			directories.push_back((windows_dir if not windows_dir.is_empty() else "C:/Windows").path_join("Fonts"))
			var local_app_data := OS.get_environment("LOCALAPPDATA")
			if not local_app_data.is_empty():
				directories.push_back(local_app_data.path_join("Microsoft/Windows/Fonts"))
		"macOS":
			directories.assign(["/System/Library/Fonts", "/Library/Fonts"])
			var mac_home := OS.get_environment("HOME")
			if not mac_home.is_empty():
				directories.push_back(mac_home.path_join("Library/Fonts"))
		_:
			directories.assign(["/usr/share/fonts", "/usr/local/share/fonts"])
			var unix_home := OS.get_environment("HOME")
			if not unix_home.is_empty():
				directories.push_back(unix_home.path_join(".fonts"))
				directories.push_back(unix_home.path_join(".local/share/fonts"))
	return directories


func _collect_custom_font_paths(directory: String, paths: Array[String], depth: int) -> void:
	if depth > 16:
		return
	var dir := DirAccess.open(directory)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != ".." and not entry.begins_with("."):
			var path := directory.path_join(entry)
			if dir.current_is_dir():
				_collect_custom_font_paths(path, paths, depth + 1)
			elif _is_supported_font_path(path):
				paths.push_back(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _is_supported_font_path(path: String) -> bool:
	return path.get_extension().to_lower() in ["ttf", "ttc", "otf", "otc", "woff", "woff2"]


func _load_text_font(path: String) -> FontFile:
	var font := FontFile.new()
	var load_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	return font if font.load_dynamic_font(load_path) == OK else null


func _on_text_font_file_selected(path: String) -> void:
	var font := _load_text_font(path)
	if not font:
		_set_status("Could not load font " + path.get_file() + ".")
		_on_text_font_dialog_canceled()
		return
	_text_custom_font_path = path
	_refresh_text_font_selector()
	var custom_index := _text_font_selector.get_item_index(TEXT_FONT_CUSTOM_ID)
	_text_font_selector.select(custom_index)
	_on_text_font_selected(custom_index)
	_set_status("Loaded text font " + path.get_file() + ".")


func _on_text_font_dialog_canceled() -> void:
	if not _text_font_selector:
		return
	var previous_index := _text_font_selector.get_item_index(_text_font_selected_id)
	if previous_index >= 0:
		_text_font_selector.select(previous_index)
	call_deferred("_refocus_text_editor")


func _on_text_font_size_changed(value: float) -> void:
	if _canvas:
		_canvas.text_font_size = int(value)


func _on_text_alignment_toggled(enabled: bool, alignment: int) -> void:
	if enabled and _canvas:
		_canvas.text_alignment = alignment
		call_deferred("_refocus_text_editor")


func _on_text_wrap_toggled(enabled: bool) -> void:
	if _canvas:
		_canvas.text_wrapping = (
			GDDrawCanvasControl.TextWrapping.WORD_WRAP
			if enabled
			else GDDrawCanvasControl.TextWrapping.NO_WRAP
		)
		call_deferred("_refocus_text_editor")


func _on_text_option_text_submitted(_text: String) -> void:
	call_deferred("_refocus_text_editor")


func _rotate_text_by_amount(clockwise: bool) -> void:
	if not _canvas:
		return
	var amount := 90.0
	if _text_rotate_amount:
		amount = clampf(float(_text_rotate_amount.value), 1.0, 359.0)
	var signed_amount := amount if clockwise else -amount
	if _canvas.rotate_text_draft_degrees(signed_amount):
		_set_status("Rotated text %s° %s." % [int(amount), "clockwise" if clockwise else "counterclockwise"])
	else:
		_set_status("Create a text box before rotating.")
	_update_text_rotation_controls()
	call_deferred("_refocus_text_editor")


func _refocus_text_editor() -> void:
	if _canvas and _canvas.active_tool == GDDrawCanvasControl.ToolMode.TEXT:
		_canvas.focus_text_editor()


func _commit_text_draft() -> void:
	if _canvas and _canvas.commit_text_draft():
		_set_status("Committed text to the image.")
	else:
		_set_status("No visible text to commit.")


func _cancel_text_draft() -> void:
	if _canvas and _canvas.cancel_text_draft():
		_set_status("Canceled the text draft.")
	else:
		_set_status("No text draft to cancel.")


func _on_text_draft_started() -> void:
	_update_text_rotation_controls()
	_set_status("Editing text. Drag the border or handles to move or resize the box.")


func _on_text_draft_finished(committed: bool) -> void:
	_update_text_rotation_controls()
	_set_status("Committed text to the image." if committed else "Canceled the text draft.")


func _on_text_draft_copied(as_image: bool) -> void:
	_set_status("Copied text box image. Paste it as a selection." if as_image else "Copied selected text.")


func _copy_text_draft_contextual() -> void:
	if not _canvas or not _canvas.copy_text_draft_contextual():
		_set_status("No visible text box content to copy.")


func _update_text_rotation_controls() -> void:
	var has_draft: bool = _canvas != null and _canvas.has_text_draft()
	for button: Button in [
		_text_rotate_left_button,
		_text_rotate_right_button,
		_text_commit_button,
		_text_cancel_button,
	]:
		if button:
			button.disabled = not has_draft
			_update_icon_button_icon(button)
	if _text_rotate_amount:
		_text_rotate_amount.editable = has_draft


func _on_selection_mode_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_select_tool(_active_selection_tool)
		_set_status("Drag to create a selection.")
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_foreground_color_changed(color: Color) -> void:
	_set_foreground_color(color, false)
	_foreground_color_picker_has_pending_recent_color = true


func _on_background_color_changed(color: Color) -> void:
	_set_background_color(color, false)


func _on_swap_colors_pressed() -> void:
	var foreground := Color.BLACK
	var background := Color.WHITE
	if _canvas:
		foreground = _canvas.brush_color
		background = _canvas.background_color
	else:
		if _foreground_color_picker:
			foreground = _foreground_color_picker.color
		if _background_color_picker:
			background = _background_color_picker.color
	_set_foreground_color(background)
	_set_background_color(foreground)


func _set_foreground_color(color: Color, synchronize_picker := true) -> void:
	if synchronize_picker and _foreground_color_picker:
		_foreground_color_picker.set_block_signals(true)
		_foreground_color_picker.color = color
		_foreground_color_picker.set_block_signals(false)
	if _canvas:
		_canvas.brush_color = color
	_update_fill_settings_button()
	_refresh_3d_brush_preview_color()


func _set_background_color(color: Color, synchronize_picker := true) -> void:
	if synchronize_picker and _background_color_picker:
		_background_color_picker.set_block_signals(true)
		_background_color_picker.color = color
		_background_color_picker.set_block_signals(false)
	if _canvas:
		_canvas.background_color = color
	_update_fill_settings_button()


func _on_foreground_color_picker_popup_closed() -> void:
	if not _foreground_color_picker_has_pending_recent_color or not _foreground_color_picker:
		return
	_foreground_color_picker_has_pending_recent_color = false
	_record_recent_color(_foreground_color_picker.color)


func _on_brush_size_changed(value: float) -> void:
	if not _canvas:
		return
	_canvas.brush_size = int(value)
	_record_recent_brush_size(int(value))
	_mark_brush_custom()


func _record_recent_brush_size(size_value: int) -> void:
	_recent_brush_sizes.erase(size_value)
	_recent_brush_sizes.push_front(size_value)
	if _recent_brush_sizes.size() > RECENT_BRUSH_SIZE_LIMIT:
		_recent_brush_sizes.resize(RECENT_BRUSH_SIZE_LIMIT)
	if _recent_brush_size_selector:
		_recent_brush_size_selector.clear()
		for recent_size in _recent_brush_sizes:
			_recent_brush_size_selector.add_item("%s px" % recent_size, recent_size)
		_recent_brush_size_selector.disabled = _recent_brush_sizes.is_empty()
	if _recent_brush_size_menu:
		_recent_brush_size_menu.clear()
		for recent_size in _recent_brush_sizes:
			_recent_brush_size_menu.add_item("%s px" % recent_size, recent_size)


func _rebuild_brush_preset_menu() -> void:
	if not _brush_preset_menu:
		return
	_brush_preset_menu.clear()
	_brush_preset_menu.add_item("Save Current Brush as Preset…", BRUSH_PRESET_SAVE_ID)
	_brush_preset_menu.add_separator()
	var builtins := _get_builtin_brush_presets()
	for index in builtins.size():
		_brush_preset_menu.add_item(str(builtins[index].get("name", "Brush Preset")), index)
	if not _custom_brush_presets.is_empty():
		_brush_preset_menu.add_separator()
		for custom_index in _custom_brush_presets.size():
			var preset := _custom_brush_presets[custom_index]
			_brush_preset_menu.add_item(str(preset.get("name", "Custom Brush")), CUSTOM_BRUSH_PRESET_ID_BASE + custom_index)


func _get_builtin_brush_presets() -> Array[Dictionary]:
	return [
		{"name": "Pencil 1", "size": 1, "head": GDDrawCanvasControl.BrushHead.SQUARE, "pixel": true, "touch": true, "hardness": 100},
		{"name": "Pixel 4", "size": 4, "head": GDDrawCanvasControl.BrushHead.SQUARE, "pixel": true, "touch": true, "hardness": 100},
		{"name": "Ink 12", "size": 12, "head": GDDrawCanvasControl.BrushHead.CIRCLE, "pixel": false, "touch": true, "hardness": 75},
		{"name": "Soft 24", "size": 24, "head": GDDrawCanvasControl.BrushHead.CIRCLE, "pixel": false, "touch": true, "hardness": 35},
	]


func _load_custom_brush_presets() -> void:
	_custom_brush_presets.clear()
	var editor_settings := _get_editor_settings()
	if not editor_settings:
		return
	var stored_presets: Variant = StoragePaths.get_custom_brush_presets(editor_settings)
	if not (stored_presets is Array):
		return
	for preset in stored_presets:
		if preset is Dictionary:
			var normalized_preset := _normalize_custom_brush_preset(preset)
			if not normalized_preset.is_empty():
				_custom_brush_presets.append(normalized_preset)


func _save_custom_brush_presets() -> void:
	StoragePaths.set_custom_brush_presets(_get_editor_settings(), _custom_brush_presets)


func _normalize_custom_brush_preset(preset: Dictionary) -> Dictionary:
	var preset_name := str(preset.get("name", "")).strip_edges()
	if preset_name.is_empty():
		return {}
	return {
		"name": preset_name,
		"size": _parse_bounded_int(str(preset.get("size", 1)), 1, 96, 1),
		"head": clampi(int(preset.get("head", GDDrawCanvasControl.BrushHead.SQUARE)), GDDrawCanvasControl.BrushHead.SQUARE, GDDrawCanvasControl.BrushHead.CIRCLE),
		"pixel": bool(preset.get("pixel", true)),
		"touch": bool(preset.get("touch", true)),
		"hardness": _parse_bounded_int(str(preset.get("hardness", 75)), 0, 100, 75),
		"alpha_lock": bool(preset.get("alpha_lock", false)),
		"stroke_overlap": bool(preset.get("stroke_overlap", true)),
	}


func _show_brush_preset_dialog() -> void:
	if not _brush_preset_dialog or not _brush_preset_name:
		return
	_brush_preset_name.text = _make_default_custom_brush_preset_name()
	_brush_preset_name.select_all()
	_brush_preset_dialog.popup_centered(Vector2i(600, 460))
	_brush_preset_name.call_deferred("grab_focus")


func _make_default_custom_brush_preset_name() -> String:
	return "Brush %d" % (_custom_brush_presets.size() + 1)


func _save_current_brush_preset() -> void:
	if not _canvas or not _brush_preset_name:
		return
	var preset_name := _brush_preset_name.text.strip_edges()
	if preset_name.is_empty():
		_set_status("Brush preset needs a name.")
		call_deferred("_show_brush_preset_dialog")
		return
	var preset := _normalize_custom_brush_preset({
		"name": preset_name,
		"size": int(_canvas.brush_size),
		"head": int(_canvas.brush_head),
		"pixel": bool(_canvas.pixel_perfect),
		"touch": bool(_canvas.brush_touch_pixels),
		"hardness": int(roundf(_canvas.brush_hardness * 100.0)),
		"alpha_lock": bool(_canvas.alpha_lock),
		"stroke_overlap": bool(_canvas.stroke_overlap_enabled),
	})
	if preset.is_empty():
		return
	_custom_brush_presets.append(preset)
	_save_custom_brush_presets()
	_rebuild_brush_preset_menu()
	if _brush_preset:
		_brush_preset.select(4)
	if _brush_preset_dialog:
		_brush_preset_dialog.hide()
	_set_status("Saved brush preset: %s." % preset_name)


func _on_recent_brush_size_menu_selected(size_value: int) -> void:
	if _brush_size:
		_brush_size.value = size_value


func _on_brush_preset_menu_selected(index: int) -> void:
	if index == BRUSH_PRESET_SAVE_ID:
		_show_brush_preset_dialog()
		return
	if index >= CUSTOM_BRUSH_PRESET_ID_BASE:
		var custom_index := index - CUSTOM_BRUSH_PRESET_ID_BASE
		if custom_index >= 0 and custom_index < _custom_brush_presets.size():
			var custom_preset := _custom_brush_presets[custom_index]
			if _brush_preset:
				_brush_preset.select(4)
			_apply_brush_preset(custom_preset, str(custom_preset.get("name", "Custom Brush")))
		return
	if _brush_preset:
		_brush_preset.select(index)
	_on_brush_preset_selected(index)


func _on_recent_brush_size_selected(index: int) -> void:
	if _recent_brush_size_selector and _brush_size:
		_brush_size.value = _recent_brush_size_selector.get_item_id(index)


func _on_brush_preset_selected(index: int) -> void:
	if not _canvas or index == 4:
		return
	var presets := _get_builtin_brush_presets()
	if index < 0 or index >= presets.size():
		return
	var preset: Dictionary = presets[index]
	_apply_brush_preset(preset, str(preset.get("name", "Brush Preset")))


func _apply_brush_preset(preset: Dictionary, preset_name: String) -> void:
	if not _canvas:
		return
	_applying_brush_preset = true
	var size_value := _parse_bounded_int(str(preset.get("size", 1)), 1, 96, 1)
	var head_value := int(preset.get("head", GDDrawCanvasControl.BrushHead.SQUARE))
	var touch_enabled := bool(preset.get("touch", true))
	var pixel_enabled := bool(preset.get("pixel", true))
	var hardness_value := _parse_bounded_int(str(preset.get("hardness", 75)), 0, 100, 75)
	var alpha_lock_enabled := bool(preset.get("alpha_lock", _canvas.alpha_lock))
	var stroke_overlap_enabled := bool(preset.get("stroke_overlap", _canvas.stroke_overlap_enabled))
	if _brush_size:
		_brush_size.value = size_value
	if _brush_head:
		_brush_head.select(head_value)
	if _brush_touch_pixels:
		_brush_touch_pixels.set_pressed_no_signal(touch_enabled)
	if _pixel_perfect:
		_pixel_perfect.set_pressed_no_signal(pixel_enabled)
	if _brush_hardness:
		_brush_hardness.set_value_no_signal(hardness_value)
	if _tool_brush_hardness:
		_tool_brush_hardness.set_value_no_signal(hardness_value)
	if _alpha_lock:
		_alpha_lock.set_pressed_no_signal(alpha_lock_enabled)
	if _stroke_overlap:
		_stroke_overlap.set_pressed_no_signal(stroke_overlap_enabled)
	if _tool_stroke_overlap:
		_tool_stroke_overlap.set_pressed_no_signal(stroke_overlap_enabled)
	_canvas.brush_size = size_value
	_canvas.brush_head = head_value
	_canvas.brush_touch_pixels = touch_enabled
	_canvas.pixel_perfect = pixel_enabled
	_canvas.brush_hardness = float(hardness_value) / 100.0
	_canvas.alpha_lock = alpha_lock_enabled
	_canvas.stroke_overlap_enabled = stroke_overlap_enabled
	_sync_brush_mode_controls()
	_applying_brush_preset = false
	_record_recent_brush_size(size_value)
	_sync_menu_state()
	_set_status("Brush preset: %s." % preset_name)


func _mark_brush_custom() -> void:
	if not _applying_brush_preset and _brush_preset:
		_brush_preset.select(4)


func _on_brush_hardness_changed(value: float) -> void:
	if _canvas:
		_canvas.brush_hardness = value / 100.0
	if _brush_hardness:
		_brush_hardness.set_value_no_signal(value)
	if _tool_brush_hardness:
		_tool_brush_hardness.set_value_no_signal(value)
	_mark_brush_custom()


func _on_brush_mode_selected(index: int) -> void:
	_on_pixel_perfect_toggled(index == 0)


func _sync_brush_mode_controls() -> void:
	if not _canvas:
		return
	var pixel_perfect_enabled := bool(_canvas.pixel_perfect)
	var tool: int = _canvas.active_tool
	var is_stroke_tool := tool == GDDrawCanvasControl.ToolMode.BRUSH or tool == GDDrawCanvasControl.ToolMode.ERASER
	if _brush_mode_selector:
		_brush_mode_selector.select(0 if pixel_perfect_enabled else 1)
	if _pixel_perfect:
		_pixel_perfect.set_pressed_no_signal(pixel_perfect_enabled)
	var hardness_value := int(roundf(_canvas.brush_hardness * 100.0))
	if _brush_hardness:
		_brush_hardness.set_value_no_signal(hardness_value)
	if _tool_brush_hardness:
		_tool_brush_hardness.set_value_no_signal(hardness_value)
	_update_pixel_perfect_mode_colors(pixel_perfect_enabled)
	if _brush_hardness_row:
		_brush_hardness_row.visible = not pixel_perfect_enabled
	if _tool_brush_hardness_label:
		_tool_brush_hardness_label.visible = is_stroke_tool and not pixel_perfect_enabled
	if _tool_brush_hardness:
		_tool_brush_hardness.visible = is_stroke_tool and not pixel_perfect_enabled


func _update_pixel_perfect_mode_colors(pixel_perfect_enabled: bool) -> void:
	var aa_color := Color("#64D982")
	var pixel_color := Color("#5E9CFF")
	var inactive_color := Color("#9A9A9A")
	if _pixel_perfect_aa_label:
		_pixel_perfect_aa_label.add_theme_color_override("font_color", inactive_color if pixel_perfect_enabled else aa_color)
	if _pixel_perfect_pixel_label:
		_pixel_perfect_pixel_label.add_theme_color_override("font_color", pixel_color if pixel_perfect_enabled else inactive_color)
	if _pixel_perfect:
		_pixel_perfect.self_modulate = pixel_color if pixel_perfect_enabled else aa_color


func _on_alpha_lock_toggled(enabled: bool) -> void:
	if _canvas:
		_canvas.alpha_lock = enabled
	if _alpha_lock:
		_alpha_lock.set_pressed_no_signal(enabled)
	_sync_menu_state()


func _on_brush_head_selected(index: int) -> void:
	if not _canvas or not _brush_head:
		return
	_canvas.brush_head = _brush_head.get_item_id(index)
	_hide_3d_brush_preview()
	_mark_brush_custom()


func _select_brush_head(head: int) -> void:
	if not _brush_head:
		return
	for index in range(_brush_head.item_count):
		if _brush_head.get_item_id(index) == head:
			_brush_head.select(index)
			_on_brush_head_selected(index)
			return


func _on_brush_touch_pixels_toggled(enabled: bool) -> void:
	if _canvas:
		_canvas.brush_touch_pixels = enabled
	_mark_brush_custom()


func _on_fill_tolerance_changed(value: float) -> void:
	if _canvas:
		_canvas.fill_tolerance = int(value)


func _on_fill_mode_selected(index: int) -> void:
	if not _canvas or not _fill_mode:
		return
	_canvas.fill_mode = _fill_mode.get_item_id(index)


func _on_fill_style_selected(index: int) -> void:
	if not _fill_style:
		return
	if _canvas:
		_canvas.fill_style = _fill_style.get_item_id(index)
	_update_fill_settings_button()


func _make_fill_setting_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 112
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _make_fill_setting_compact_row(label_text: String, control: Control, control_width: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 112
	row.add_child(label)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, control_width)
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(control)
	return row


func _make_fill_setting_pair_row(
	label_text: String,
	first_label_text: String,
	first_control: Control,
	second_label_text: String,
	second_control: Control,
	trailing_control: Control = null,
	first_width: float = 220.0,
	second_width: float = 180.0,
	sublabel_width: float = 56.0
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 112
	row.add_child(label)
	var first_label := Label.new()
	first_label.text = first_label_text
	first_label.custom_minimum_size.x = sublabel_width
	first_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(first_label)
	first_control.custom_minimum_size.x = maxf(first_control.custom_minimum_size.x, first_width)
	first_control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(first_control)
	var pair_spacer := Control.new()
	pair_spacer.custom_minimum_size.x = 8
	row.add_child(pair_spacer)
	var second_label := Label.new()
	second_label.text = second_label_text
	second_label.custom_minimum_size.x = sublabel_width
	second_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(second_label)
	second_control.custom_minimum_size.x = maxf(second_control.custom_minimum_size.x, second_width)
	second_control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(second_control)
	if trailing_control:
		var trailing_spacer := Control.new()
		trailing_spacer.custom_minimum_size.x = 8
		row.add_child(trailing_spacer)
		row.add_child(trailing_control)
	return row


func _make_fill_setting_spin(minimum: float, maximum: float, step: float, suffix: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.suffix = suffix
	_apply_preferences_spinbox_style(spin)
	spin.value_changed.connect(_on_fill_settings_value_changed)
	return spin


func _build_fill_settings_tabs() -> void:
	var solid_tab := _add_preferences_tab(_fill_settings_tabs, "Solid")
	var solid_section := _add_preferences_section(
		solid_tab,
		"Solid fill",
		"Solid fill uses only the foreground color across the discovered bucket region."
	)
	var solid_help := Label.new()
	solid_help.text = "Fills the discovered region with the foreground color.\nThe background color is ignored."
	solid_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	solid_section.add_child(solid_help)

	var dither_tab := _add_preferences_tab(_fill_settings_tabs, "Dither")
	var dither_section := _add_preferences_section(
		dither_tab,
		"Ordered dither",
		"Configure a deterministic Bayer matrix, foreground density, and canvas-pixel sample scale."
	)
	_dither_settings_preset = OptionButton.new()
	for preset_name in ["Bayer 2x2 25%", "Bayer 2x2 50%", "Bayer 2x2 75%", "Bayer 4x4 25%", "Bayer 4x4 50%", "Bayer 4x4 75%"]:
		_dither_settings_preset.add_item(preset_name)
	_dither_settings_preset.add_item("Custom", FILL_CUSTOM_PRESET_ID)
	_dither_settings_preset.item_selected.connect(_on_dither_settings_preset_selected)
	dither_section.add_child(_make_fill_setting_row("Preset", _dither_settings_preset))
	_dither_settings_matrix = OptionButton.new()
	_dither_settings_matrix.add_item("2x2", 2)
	_dither_settings_matrix.add_item("4x4", 4)
	_dither_settings_matrix.add_item("8x8", 8)
	_dither_settings_matrix.item_selected.connect(_on_dither_settings_custom_changed)
	_dither_settings_density = _make_fill_setting_spin(0.0, 100.0, 0.1, "%")
	_dither_settings_density.value_changed.disconnect(_on_fill_settings_value_changed)
	_dither_settings_density.value_changed.connect(_on_dither_settings_custom_changed)
	dither_section.add_child(_make_fill_setting_pair_row("Dither", "Matrix", _dither_settings_matrix, "Density", _dither_settings_density, null, 220.0, 180.0, 58.0))
	_dither_settings_scale = _make_fill_setting_spin(1.0, 8.0, 1.0, " px")
	_dither_settings_scale.value_changed.disconnect(_on_fill_settings_value_changed)
	_dither_settings_scale.value_changed.connect(_on_dither_settings_custom_changed)
	dither_section.add_child(_make_fill_setting_compact_row("Sample scale", _dither_settings_scale, 180.0))
	var dither_help := Label.new()
	dither_help.text = "Density is quantized to the selected Bayer matrix."
	dither_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dither_section.add_child(dither_help)

	var pattern_tab := _add_preferences_tab(_fill_settings_tabs, "Pattern")
	var pattern_section := _add_preferences_section(
		pattern_tab,
		"Repeating pattern",
		"Configure canvas-anchored checker, stripe, or dot geometry with editable rotation and dimensions."
	)
	_pattern_settings_preset = OptionButton.new()
	for preset_name in ["Checker 2x2", "Horizontal Stripes", "Vertical Stripes", "Diagonal Stripes", "Dots 4x4"]:
		_pattern_settings_preset.add_item(preset_name)
	_pattern_settings_preset.add_item("Custom", FILL_CUSTOM_PRESET_ID)
	_pattern_settings_preset.item_selected.connect(_on_pattern_settings_preset_selected)
	pattern_section.add_child(_make_fill_setting_row("Preset", _pattern_settings_preset))
	_pattern_settings_kind = OptionButton.new()
	_pattern_settings_kind.add_item("Checker", GDDrawCanvasControl.PatternKind.CHECKER)
	_pattern_settings_kind.add_item("Stripes", GDDrawCanvasControl.PatternKind.STRIPES)
	_pattern_settings_kind.add_item("Dots", GDDrawCanvasControl.PatternKind.DOTS)
	_pattern_settings_kind.item_selected.connect(_on_pattern_settings_custom_changed)
	_pattern_settings_angle = _make_fill_setting_spin(0.0, 359.0, 1.0, "°")
	_pattern_settings_angle.value_changed.disconnect(_on_fill_settings_value_changed)
	_pattern_settings_angle.value_changed.connect(_on_pattern_settings_custom_changed)
	pattern_section.add_child(_make_fill_setting_pair_row("Geometry", "Type", _pattern_settings_kind, "Rotation", _pattern_settings_angle, null, 220.0, 180.0, 58.0))
	_pattern_settings_thickness = _make_fill_setting_spin(1.0, 32.0, 1.0, " px")
	_pattern_settings_thickness.value_changed.disconnect(_on_fill_settings_value_changed)
	_pattern_settings_thickness.value_changed.connect(_on_pattern_settings_custom_changed)
	_pattern_settings_gap = _make_fill_setting_spin(0.0, 32.0, 1.0, " px")
	_pattern_settings_gap.value_changed.disconnect(_on_fill_settings_value_changed)
	_pattern_settings_gap.value_changed.connect(_on_pattern_settings_custom_changed)
	_pattern_settings_thickness_row = _make_fill_setting_pair_row("Stripes", "Width", _pattern_settings_thickness, "Gap", _pattern_settings_gap, null, 220.0, 180.0, 58.0)
	_pattern_settings_gap_row = _pattern_settings_thickness_row
	pattern_section.add_child(_pattern_settings_gap_row)
	_pattern_settings_cell_width = _make_fill_setting_spin(1.0, 32.0, 1.0, " px")
	_pattern_settings_cell_width.value_changed.disconnect(_on_fill_settings_value_changed)
	_pattern_settings_cell_width.value_changed.connect(_on_pattern_settings_custom_changed)
	_pattern_settings_cell_height = _make_fill_setting_spin(1.0, 32.0, 1.0, " px")
	_pattern_settings_cell_height.value_changed.disconnect(_on_fill_settings_value_changed)
	_pattern_settings_cell_height.value_changed.connect(_on_pattern_settings_custom_changed)
	_pattern_settings_cell_width_row = _make_fill_setting_pair_row("Cell size", "W", _pattern_settings_cell_width, "H", _pattern_settings_cell_height, null, 220.0, 180.0, 58.0)
	_pattern_settings_cell_height_row = _pattern_settings_cell_width_row
	pattern_section.add_child(_pattern_settings_cell_height_row)
	_pattern_settings_dot_size = _make_fill_setting_spin(1.0, 32.0, 1.0, " px")
	_pattern_settings_dot_size.value_changed.disconnect(_on_fill_settings_value_changed)
	_pattern_settings_dot_size.value_changed.connect(_on_pattern_settings_custom_changed)
	_pattern_settings_dot_size_row = _make_fill_setting_compact_row("Dot size", _pattern_settings_dot_size, 180.0)
	pattern_section.add_child(_pattern_settings_dot_size_row)

	var custom_tab := _add_preferences_tab(_fill_settings_tabs, "Custom")
	var custom_top_grid := GridContainer.new()
	custom_top_grid.columns = 2
	custom_top_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_top_grid.add_theme_constant_override("h_separation", 10)
	custom_tab.add_child(custom_top_grid)
	var source_section := _add_preferences_section(
		custom_top_grid,
		"Source image",
		"Choose a project image or supported external raster image. The source remains staged until Use is pressed."
	)
	var source_body := HBoxContainer.new()
	source_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_body.add_theme_constant_override("separation", 8)
	source_section.add_child(source_body)
	var source_actions := VBoxContainer.new()
	source_actions.add_theme_constant_override("separation", 6)
	_custom_fill_source_button = Button.new()
	_custom_fill_source_button.text = "Select Image..."
	_custom_fill_source_button.tooltip_text = "Select a project or external image for the custom fill"
	_custom_fill_source_button.pressed.connect(_on_custom_fill_select_pressed)
	source_actions.add_child(_custom_fill_source_button)
	_custom_fill_paste_button = Button.new()
	_custom_fill_paste_button.text = "Paste Image"
	_custom_fill_paste_button.tooltip_text = "Stage an image copied from a GDDraw selection or the system clipboard"
	_custom_fill_paste_button.pressed.connect(_on_custom_fill_paste_pressed)
	source_actions.add_child(_custom_fill_paste_button)
	_custom_fill_clear_button = Button.new()
	_custom_fill_clear_button.text = "Clear Image"
	_custom_fill_clear_button.tooltip_text = "Clear the staged custom fill source"
	_custom_fill_clear_button.pressed.connect(_on_custom_fill_clear_pressed)
	source_actions.add_child(_custom_fill_clear_button)
	_custom_fill_drop_target = ImageDropTarget.new()
	_custom_fill_drop_target.name = "Custom Fill Image Drop Target"
	_custom_fill_drop_target.custom_minimum_size = Vector2(220, 90)
	_custom_fill_drop_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_custom_fill_drop_target.tooltip_text = "Drop a project texture or supported external image here"
	_custom_fill_drop_target.add_theme_stylebox_override("panel", _make_preferences_section_style())
	_custom_fill_drop_target.image_data_dropped.connect(_on_custom_fill_image_dropped)
	source_body.add_child(_custom_fill_drop_target)
	source_body.add_child(source_actions)
	var drop_content := HBoxContainer.new()
	drop_content.add_theme_constant_override("separation", 10)
	_custom_fill_drop_target.add_child(drop_content)
	_custom_fill_thumbnail = TextureRect.new()
	_custom_fill_thumbnail.name = "Custom Fill Source Thumbnail"
	_custom_fill_thumbnail.custom_minimum_size = Vector2(72, 72)
	_custom_fill_thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_custom_fill_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_custom_fill_thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	drop_content.add_child(_custom_fill_thumbnail)
	var source_text := VBoxContainer.new()
	source_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_text.alignment = BoxContainer.ALIGNMENT_CENTER
	drop_content.add_child(source_text)
	var drop_label := Label.new()
	drop_label.text = "Drop image here"
	drop_label.add_theme_font_size_override("font_size", 14)
	source_text.add_child(drop_label)
	_custom_fill_filename = Label.new()
	_custom_fill_filename.text = "No image selected"
	_custom_fill_filename.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_custom_fill_filename.tooltip_text = "No image selected"
	source_text.add_child(_custom_fill_filename)

	var color_section := _add_preferences_section(
		custom_top_grid,
		"Color mode",
		"Use original RGBA, tint source alpha with the foreground, or choose between the two configured colors by luminance."
	)
	_custom_fill_color_mode = OptionButton.new()
	_custom_fill_color_mode.add_item("Original RGBA", GDDrawCanvasControl.CustomFillColorMode.ORIGINAL_RGBA)
	_custom_fill_color_mode.add_item("Alpha Mask", GDDrawCanvasControl.CustomFillColorMode.ALPHA_MASK)
	_custom_fill_color_mode.add_item("Two-Color Mask", GDDrawCanvasControl.CustomFillColorMode.TWO_COLOR_MASK)
	_custom_fill_color_mode.item_selected.connect(_on_custom_fill_color_mode_changed)
	color_section.add_child(_make_fill_setting_row("Mode", _custom_fill_color_mode))
	_custom_fill_threshold = _make_fill_setting_spin(0.0, 100.0, 0.1, "%")
	_custom_fill_threshold_row = _make_fill_setting_row("Mask threshold", _custom_fill_threshold)
	color_section.add_child(_custom_fill_threshold_row)

	var transform_section := _add_preferences_section(
		custom_tab,
		"Transform and repeat",
		"The transform is anchored to the canvas origin, so separate bucket regions align seamlessly."
	)
	_custom_fill_repeat_x = CheckBox.new()
	_custom_fill_repeat_x.text = ""
	_custom_fill_repeat_x.button_pressed = true
	_custom_fill_repeat_x.toggled.connect(_on_fill_settings_value_changed)
	_custom_fill_repeat_y = CheckBox.new()
	_custom_fill_repeat_y.text = ""
	_custom_fill_repeat_y.button_pressed = true
	_custom_fill_repeat_y.toggled.connect(_on_fill_settings_value_changed)
	transform_section.add_child(_make_fill_setting_pair_row(
		"Repeat", "X", _custom_fill_repeat_x, "Y", _custom_fill_repeat_y, null, 140.0, 140.0, 24.0
	))
	_custom_fill_scale_x = _make_fill_setting_spin(0.125, 16.0, 0.001, "x")
	_custom_fill_scale_x.value = 1.0
	_custom_fill_scale_x.value_changed.disconnect(_on_fill_settings_value_changed)
	_custom_fill_scale_x.value_changed.connect(_on_custom_fill_scale_x_changed)
	_custom_fill_scale_y = _make_fill_setting_spin(0.125, 16.0, 0.001, "x")
	_custom_fill_scale_y.value = 1.0
	_custom_fill_scale_y.value_changed.disconnect(_on_fill_settings_value_changed)
	_custom_fill_scale_y.value_changed.connect(_on_custom_fill_scale_y_changed)
	_custom_fill_lock_aspect = CheckBox.new()
	_custom_fill_lock_aspect.text = "Lock aspect ratio"
	_custom_fill_lock_aspect.button_pressed = true
	_custom_fill_lock_aspect.toggled.connect(_on_custom_fill_lock_aspect_toggled)
	transform_section.add_child(_make_fill_setting_pair_row(
		"Scale", "X", _custom_fill_scale_x, "Y", _custom_fill_scale_y, _custom_fill_lock_aspect, 140.0, 140.0, 24.0
	))
	_custom_fill_spacing_x = _make_fill_setting_spin(0.0, 256.0, 1.0, " px")
	_custom_fill_spacing_y = _make_fill_setting_spin(0.0, 256.0, 1.0, " px")
	transform_section.add_child(_make_fill_setting_pair_row(
		"Spacing", "H", _custom_fill_spacing_x, "V", _custom_fill_spacing_y, null, 140.0, 140.0, 24.0
	))
	_custom_fill_rotation = _make_fill_setting_spin(0.0, 359.0, 1.0, " deg")
	_custom_fill_offset_x = _make_fill_setting_spin(-4096.0, 4096.0, 1.0, " px")
	_custom_fill_offset_y = _make_fill_setting_spin(-4096.0, 4096.0, 1.0, " px")
	transform_section.add_child(_make_fill_setting_pair_row(
		"Offset", "X", _custom_fill_offset_x, "Y", _custom_fill_offset_y, null, 140.0, 140.0, 24.0
	))
	transform_section.add_child(_make_fill_setting_compact_row("Rotation", _custom_fill_rotation, 180.0))
	_custom_fill_filtering = OptionButton.new()
	_custom_fill_filtering.add_item("Nearest", GDDrawCanvasControl.CustomFillFiltering.NEAREST)
	_custom_fill_filtering.add_item("Bilinear", GDDrawCanvasControl.CustomFillFiltering.BILINEAR)
	_custom_fill_filtering.item_selected.connect(_on_fill_settings_value_changed)
	transform_section.add_child(_make_fill_setting_compact_row("Filtering", _custom_fill_filtering, 220.0))
	_update_custom_fill_source_display()
	_update_custom_fill_settings_visibility()


func _load_fill_settings_from_canvas() -> void:
	if not _canvas:
		return
	_syncing_fill_settings = true
	_fill_settings_style = _canvas.fill_style
	_fill_settings_tabs.current_tab = _canvas.fill_style
	_fill_settings_foreground.color = _canvas.brush_color
	_fill_settings_background.color = _canvas.background_color
	_select_option_by_id(_fill_settings_target, _canvas.fill_target_mode)
	_select_option_by_id(_dither_settings_matrix, _canvas.dither_matrix_size)
	_dither_settings_density.value = _canvas.dither_density
	_dither_settings_scale.value = _canvas.dither_scale
	_select_option_by_id(_dither_settings_preset, _matching_dither_preset())
	_select_option_by_id(_pattern_settings_kind, _canvas.pattern_kind)
	_pattern_settings_angle.value = _canvas.pattern_angle
	_pattern_settings_thickness.value = _canvas.pattern_thickness
	_pattern_settings_gap.value = _canvas.pattern_gap
	_pattern_settings_cell_width.value = _canvas.pattern_cell_width
	_pattern_settings_cell_height.value = _canvas.pattern_cell_height
	_pattern_settings_dot_size.value = _canvas.pattern_dot_size
	_select_option_by_id(_pattern_settings_preset, _matching_pattern_preset())
	_custom_fill_staged_image = _canvas.custom_fill_image.duplicate() if _canvas.custom_fill_image else null
	_custom_fill_staged_name = _canvas.custom_fill_source_name
	_select_option_by_id(_custom_fill_color_mode, _canvas.custom_fill_color_mode)
	_custom_fill_repeat_x.set_pressed_no_signal(_canvas.custom_fill_repeat_x)
	_custom_fill_repeat_y.set_pressed_no_signal(_canvas.custom_fill_repeat_y)
	_custom_fill_scale_x.set_value_no_signal(_canvas.custom_fill_scale.x)
	_custom_fill_scale_y.set_value_no_signal(_canvas.custom_fill_scale.y)
	_custom_fill_lock_aspect.set_pressed_no_signal(_canvas.custom_fill_lock_aspect)
	_custom_fill_aspect_ratio = _canvas.custom_fill_scale.y / maxf(_canvas.custom_fill_scale.x, 0.125)
	_custom_fill_spacing_x.set_value_no_signal(_canvas.custom_fill_spacing.x)
	_custom_fill_spacing_y.set_value_no_signal(_canvas.custom_fill_spacing.y)
	_custom_fill_rotation.set_value_no_signal(_canvas.custom_fill_rotation)
	_custom_fill_offset_x.set_value_no_signal(_canvas.custom_fill_offset.x)
	_custom_fill_offset_y.set_value_no_signal(_canvas.custom_fill_offset.y)
	_select_option_by_id(_custom_fill_filtering, _canvas.custom_fill_filtering)
	_custom_fill_threshold.set_value_no_signal(_canvas.custom_fill_mask_threshold)
	_syncing_fill_settings = false
	_update_custom_fill_source_display()
	_update_custom_fill_settings_visibility()
	_refresh_fill_settings_preview()


func _select_option_by_id(option: OptionButton, item_id: int) -> void:
	var index := option.get_item_index(item_id)
	if index >= 0:
		option.select(index)


func _matching_dither_preset() -> int:
	if _canvas.dither_scale != 1 or (_canvas.dither_matrix_size != 2 and _canvas.dither_matrix_size != 4):
		return FILL_CUSTOM_PRESET_ID
	for density_index in range(3):
		if is_equal_approx(_canvas.dither_density, [25.0, 50.0, 75.0][density_index]):
			return density_index + (0 if _canvas.dither_matrix_size == 2 else 3)
	return FILL_CUSTOM_PRESET_ID


func _matching_pattern_preset() -> int:
	if _canvas.pattern_kind == GDDrawCanvasControl.PatternKind.CHECKER and is_zero_approx(_canvas.pattern_angle) and _canvas.pattern_cell_width == 1 and _canvas.pattern_cell_height == 1:
		return GDDrawCanvasControl.PatternPreset.CHECKER_2X2
	if _canvas.pattern_kind == GDDrawCanvasControl.PatternKind.STRIPES and _canvas.pattern_thickness == 1:
		if is_zero_approx(_canvas.pattern_angle) and _canvas.pattern_gap == 1:
			return GDDrawCanvasControl.PatternPreset.HORIZONTAL_STRIPES
		if is_equal_approx(_canvas.pattern_angle, 90.0) and _canvas.pattern_gap == 1:
			return GDDrawCanvasControl.PatternPreset.VERTICAL_STRIPES
		if is_equal_approx(_canvas.pattern_angle, 45.0) and _canvas.pattern_gap == 3:
			return GDDrawCanvasControl.PatternPreset.DIAGONAL_STRIPES
	if _canvas.pattern_kind == GDDrawCanvasControl.PatternKind.DOTS and is_zero_approx(_canvas.pattern_angle) and _canvas.pattern_cell_width == 4 and _canvas.pattern_cell_height == 4 and _canvas.pattern_dot_size == 1:
		return GDDrawCanvasControl.PatternPreset.DOTS_4X4
	return FILL_CUSTOM_PRESET_ID


func _on_fill_settings_tab_changed(tab: int) -> void:
	_fill_settings_style = tab
	if not _syncing_fill_settings:
		_refresh_fill_settings_preview()


func _on_fill_settings_value_changed(_value: Variant = null) -> void:
	if not _syncing_fill_settings:
		_refresh_fill_settings_preview()


func _on_custom_fill_color_mode_changed(_index: int) -> void:
	_update_custom_fill_settings_visibility()
	_on_fill_settings_value_changed()


func _update_custom_fill_settings_visibility() -> void:
	if not _custom_fill_threshold_row or not _custom_fill_color_mode:
		return
	_custom_fill_threshold_row.visible = (
		_custom_fill_color_mode.get_item_id(_custom_fill_color_mode.selected)
		== GDDrawCanvasControl.CustomFillColorMode.TWO_COLOR_MASK
	)


func _on_custom_fill_scale_x_changed(value: float) -> void:
	if _syncing_fill_settings:
		return
	if _custom_fill_lock_aspect.button_pressed:
		_custom_fill_scale_y.set_value_no_signal(clampf(value * _custom_fill_aspect_ratio, 0.125, 16.0))
	_refresh_fill_settings_preview()


func _on_custom_fill_scale_y_changed(value: float) -> void:
	if _syncing_fill_settings:
		return
	if _custom_fill_lock_aspect.button_pressed:
		_custom_fill_scale_x.set_value_no_signal(clampf(value / maxf(_custom_fill_aspect_ratio, 0.000001), 0.125, 16.0))
	_refresh_fill_settings_preview()


func _on_custom_fill_lock_aspect_toggled(enabled: bool) -> void:
	if enabled:
		_custom_fill_aspect_ratio = _custom_fill_scale_y.value / maxf(_custom_fill_scale_x.value, 0.125)
	_on_fill_settings_value_changed()


func _on_custom_fill_select_pressed() -> void:
	if not _custom_fill_image_dialog:
		return
	var source_path := _custom_fill_staged_name
	if source_path.begins_with("res://"):
		source_path = ProjectSettings.globalize_path(source_path)
	if not source_path.is_empty() and FileAccess.file_exists(source_path):
		_custom_fill_image_dialog.current_dir = source_path.get_base_dir()
		_custom_fill_image_dialog.current_file = source_path.get_file()
	_custom_fill_image_dialog.popup_centered_ratio(0.75)


func _on_custom_fill_paste_pressed() -> void:
	var clipboard_image: Image
	var clipboard_label := "clipboard image"
	if _canvas and _canvas.has_clipboard_image():
		clipboard_image = _canvas.get_clipboard_image_copy()
		clipboard_label = "GDDraw selection clipboard"
	else:
		var clipboard_source := _get_system_clipboard_image_source()
		clipboard_image = clipboard_source.get("image", null)
		clipboard_label = str(clipboard_source.get("label", clipboard_label))
	if not clipboard_image or clipboard_image.is_empty():
		_set_status("Copy a GDDraw selection or an image to the clipboard first.")
		return
	_set_staged_custom_fill_image(clipboard_image, clipboard_label)
	_set_status("Staged %s as the custom fill source." % clipboard_label)


func _on_custom_fill_file_selected(path: String) -> void:
	_set_staged_custom_fill_from_path(path)


func _on_custom_fill_clear_pressed() -> void:
	_custom_fill_staged_image = null
	_custom_fill_staged_name = ""
	_update_custom_fill_source_display()
	_refresh_fill_settings_preview()


func _on_custom_fill_image_dropped(data: Variant) -> void:
	var path := _extract_drop_image_path(data)
	if not path.is_empty():
		_set_staged_custom_fill_from_path(path)
		return
	var image := _extract_drop_image(data)
	if image and not image.is_empty():
		_set_staged_custom_fill_image(image, "dropped texture")
		return
	_set_status("That drop did not contain a supported custom fill image.")


func _set_staged_custom_fill_from_path(path: String) -> bool:
	var normalized_path := _normalize_filesystem_path(path)
	if not _is_supported_filesystem_image_path(normalized_path):
		_set_status("Custom fill source must be a supported image path.")
		return false
	var image := Image.new()
	var load_path := ProjectSettings.globalize_path(normalized_path) if normalized_path.begins_with("res://") else normalized_path
	if not FileAccess.file_exists(load_path):
		_set_status("Custom fill source image is missing.")
		return false
	var error := image.load(load_path)
	if error != OK or image.is_empty():
		_set_status("Could not load custom fill image. Error: %s" % error)
		return false
	_set_staged_custom_fill_image(image, normalized_path)
	return true


func _set_staged_custom_fill_image(image: Image, source_name: String) -> void:
	_custom_fill_staged_image = image.duplicate()
	if _custom_fill_staged_image.get_format() != Image.FORMAT_RGBA8:
		_custom_fill_staged_image.convert(Image.FORMAT_RGBA8)
	_custom_fill_staged_name = source_name
	_update_custom_fill_source_display()
	_refresh_fill_settings_preview()


func _update_custom_fill_source_display() -> void:
	if _custom_fill_filename:
		var display_name := _custom_fill_staged_name.get_file() if not _custom_fill_staged_name.is_empty() else "No image selected"
		_custom_fill_filename.text = display_name
		_custom_fill_filename.tooltip_text = _custom_fill_staged_name if not _custom_fill_staged_name.is_empty() else display_name
	if _custom_fill_clear_button:
		_custom_fill_clear_button.disabled = _custom_fill_staged_image == null
	if _custom_fill_thumbnail:
		_custom_fill_thumbnail.texture = ImageTexture.create_from_image(_make_custom_fill_thumbnail())


func _make_custom_fill_thumbnail() -> Image:
	var size := 64
	var thumbnail := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			thumbnail.set_pixel(x, y, _preview_checker_color(Vector2i(x, y)))
	if not _custom_fill_staged_image or _custom_fill_staged_image.is_empty():
		return thumbnail
	var source_size := Vector2(_custom_fill_staged_image.get_width(), _custom_fill_staged_image.get_height())
	var fit_scale := minf(float(size) / source_size.x, float(size) / source_size.y)
	var drawn_size := source_size * fit_scale
	var origin := (Vector2(size, size) - drawn_size) * 0.5
	for y in range(size):
		for x in range(size):
			var position := Vector2(x, y)
			if position.x < origin.x or position.y < origin.y or position.x >= origin.x + drawn_size.x or position.y >= origin.y + drawn_size.y:
				continue
			var source_pixel := Vector2i(
				clampi(floori((position.x - origin.x) / fit_scale), 0, _custom_fill_staged_image.get_width() - 1),
				clampi(floori((position.y - origin.y) / fit_scale), 0, _custom_fill_staged_image.get_height() - 1)
			)
			thumbnail.set_pixel(x, y, _composite_preview_color(thumbnail.get_pixel(x, y), _custom_fill_staged_image.get_pixelv(source_pixel)))
	return thumbnail


func _on_fill_settings_swap_pressed() -> void:
	var foreground := _fill_settings_foreground.color
	_fill_settings_foreground.color = _fill_settings_background.color
	_fill_settings_background.color = foreground
	_refresh_fill_settings_preview()


func _on_dither_settings_preset_selected(index: int) -> void:
	if _syncing_fill_settings:
		return
	var preset := _dither_settings_preset.get_item_id(index)
	if preset == FILL_CUSTOM_PRESET_ID:
		return
	_syncing_fill_settings = true
	_select_option_by_id(_dither_settings_matrix, 2 if preset < 3 else 4)
	_dither_settings_density.value = [25.0, 50.0, 75.0][preset % 3]
	_dither_settings_scale.value = 1
	_syncing_fill_settings = false
	_refresh_fill_settings_preview()


func _on_dither_settings_custom_changed(_value: Variant = null) -> void:
	if _syncing_fill_settings:
		return
	_select_option_by_id(_dither_settings_preset, FILL_CUSTOM_PRESET_ID)
	_refresh_fill_settings_preview()


func _on_pattern_settings_preset_selected(index: int) -> void:
	if _syncing_fill_settings:
		return
	var preset := _pattern_settings_preset.get_item_id(index)
	if preset == FILL_CUSTOM_PRESET_ID:
		return
	_syncing_fill_settings = true
	match preset:
		GDDrawCanvasControl.PatternPreset.HORIZONTAL_STRIPES:
			_set_pattern_settings_values(GDDrawCanvasControl.PatternKind.STRIPES, 0.0, 1, 1, 1, 1, 1)
		GDDrawCanvasControl.PatternPreset.VERTICAL_STRIPES:
			_set_pattern_settings_values(GDDrawCanvasControl.PatternKind.STRIPES, 90.0, 1, 1, 1, 1, 1)
		GDDrawCanvasControl.PatternPreset.DIAGONAL_STRIPES:
			_set_pattern_settings_values(GDDrawCanvasControl.PatternKind.STRIPES, 45.0, 1, 3, 1, 1, 1)
		GDDrawCanvasControl.PatternPreset.DOTS_4X4:
			_set_pattern_settings_values(GDDrawCanvasControl.PatternKind.DOTS, 0.0, 1, 1, 4, 4, 1)
		_:
			_set_pattern_settings_values(GDDrawCanvasControl.PatternKind.CHECKER, 0.0, 1, 1, 1, 1, 1)
	_syncing_fill_settings = false
	_refresh_fill_settings_preview()


func _set_pattern_settings_values(kind: int, angle: float, thickness: int, gap: int, width: int, height: int, dot_size: int) -> void:
	_select_option_by_id(_pattern_settings_kind, kind)
	_pattern_settings_angle.value = angle
	_pattern_settings_thickness.value = thickness
	_pattern_settings_gap.value = gap
	_pattern_settings_cell_width.value = width
	_pattern_settings_cell_height.value = height
	_pattern_settings_dot_size.value = dot_size


func _on_pattern_settings_custom_changed(_value: Variant = null) -> void:
	if _syncing_fill_settings:
		return
	_select_option_by_id(_pattern_settings_preset, FILL_CUSTOM_PRESET_ID)
	_refresh_fill_settings_preview()


func _update_pattern_settings_visibility() -> void:
	if not _pattern_settings_kind:
		return
	var kind := _pattern_settings_kind.get_item_id(_pattern_settings_kind.selected)
	var stripes: bool = kind == GDDrawCanvasControl.PatternKind.STRIPES
	var dots: bool = kind == GDDrawCanvasControl.PatternKind.DOTS
	_pattern_settings_thickness_row.visible = stripes
	_pattern_settings_gap_row.visible = stripes
	_pattern_settings_cell_width_row.visible = not stripes
	_pattern_settings_cell_height_row.visible = not stripes
	_pattern_settings_dot_size_row.visible = dots


func _on_fill_settings_button_pressed() -> void:
	if not _fill_settings_overlay or not _fill_settings_button or not _fill_settings_button.visible:
		return
	_load_fill_settings_from_canvas()
	if _settings_overlay:
		_settings_overlay.visible = false
	if _create_textured_csg_overlay:
		_create_textured_csg_overlay.visible = false
	var overlay_parent := _fill_settings_overlay.get_parent()
	if overlay_parent:
		overlay_parent.move_child(_fill_settings_overlay, overlay_parent.get_child_count() - 1)
	_fill_settings_overlay.visible = true


func _on_fill_settings_cancel_pressed() -> void:
	if _fill_settings_overlay:
		_fill_settings_overlay.visible = false


func _on_fill_settings_use_pressed() -> void:
	if not _canvas or not _fill_settings_tabs:
		return
	var foreground := _fill_settings_foreground.color
	var background := _fill_settings_background.color
	_canvas.fill_style = _fill_settings_style
	_canvas.fill_target_mode = _fill_settings_target.get_item_id(_fill_settings_target.selected)
	var dither_id := _dither_settings_preset.get_item_id(_dither_settings_preset.selected)
	if dither_id >= 0 and dither_id < 6:
		_canvas.dither_preset = dither_id
	_canvas.dither_matrix_size = _dither_settings_matrix.get_item_id(_dither_settings_matrix.selected)
	_canvas.dither_density = _dither_settings_density.value
	_canvas.dither_scale = int(_dither_settings_scale.value)
	var pattern_id := _pattern_settings_preset.get_item_id(_pattern_settings_preset.selected)
	if pattern_id >= 0 and pattern_id < 5:
		_canvas.pattern_preset = pattern_id
	_canvas.pattern_kind = _pattern_settings_kind.get_item_id(_pattern_settings_kind.selected)
	_canvas.pattern_angle = _pattern_settings_angle.value
	_canvas.pattern_thickness = int(_pattern_settings_thickness.value)
	_canvas.pattern_gap = int(_pattern_settings_gap.value)
	_canvas.pattern_cell_width = int(_pattern_settings_cell_width.value)
	_canvas.pattern_cell_height = int(_pattern_settings_cell_height.value)
	_canvas.pattern_dot_size = int(_pattern_settings_dot_size.value)
	_canvas.custom_fill_image = _custom_fill_staged_image.duplicate() if _custom_fill_staged_image else null
	_canvas.custom_fill_source_name = _custom_fill_staged_name
	_canvas.custom_fill_color_mode = _custom_fill_color_mode.get_item_id(_custom_fill_color_mode.selected)
	_canvas.custom_fill_repeat_x = _custom_fill_repeat_x.button_pressed
	_canvas.custom_fill_repeat_y = _custom_fill_repeat_y.button_pressed
	_canvas.custom_fill_scale = Vector2(_custom_fill_scale_x.value, _custom_fill_scale_y.value)
	_canvas.custom_fill_lock_aspect = _custom_fill_lock_aspect.button_pressed
	_canvas.custom_fill_spacing = Vector2(_custom_fill_spacing_x.value, _custom_fill_spacing_y.value)
	_canvas.custom_fill_rotation = _custom_fill_rotation.value
	_canvas.custom_fill_offset = Vector2(_custom_fill_offset_x.value, _custom_fill_offset_y.value)
	_canvas.custom_fill_filtering = _custom_fill_filtering.get_item_id(_custom_fill_filtering.selected)
	_canvas.custom_fill_mask_threshold = _custom_fill_threshold.value
	_set_foreground_color(foreground)
	_set_background_color(background)
	var style_index := _fill_style.get_item_index(_canvas.fill_style)
	if style_index >= 0:
		_fill_style.select(style_index)
	_update_fill_settings_button()
	_fill_settings_overlay.visible = false


func _update_fill_settings_button() -> void:
	if not _fill_style or not _fill_settings_button:
		return
	var style := GDDrawCanvasControl.FillStyle.SOLID
	if _canvas:
		style = _canvas.fill_style
	else:
		style = _fill_style.get_item_id(_fill_style.selected)
	var style_index := _fill_style.get_item_index(style)
	if style_index >= 0 and _fill_style.selected != style_index:
		_fill_style.select(style_index)
	match style:
		GDDrawCanvasControl.FillStyle.DITHER:
			_fill_style.tooltip_text = "Ordered dithering uses foreground and background colors at a fixed canvas-pixel phase"
		GDDrawCanvasControl.FillStyle.PATTERN:
			_fill_style.tooltip_text = "Repeating patterns use foreground and background colors at a fixed canvas-pixel phase"
		GDDrawCanvasControl.FillStyle.CUSTOM:
			_fill_style.tooltip_text = "Custom image fills repeat a transformed source image at a fixed canvas-pixel phase"
		_:
			_fill_style.tooltip_text = "Solid fill uses only the foreground color"
	var is_fill_tool: bool = _canvas != null and _canvas.active_tool == GDDrawCanvasControl.ToolMode.FILL
	_fill_settings_button.visible = is_fill_tool
	_fill_settings_button.tooltip_text = "Open Fill Settings (%s)" % _fill_style.get_item_text(_fill_style.selected)


func _refresh_fill_settings_preview() -> void:
	if not _fill_settings_preview or not _fill_settings_tabs:
		return
	_update_pattern_settings_visibility()
	var foreground: Color = _fill_settings_foreground.color
	var background: Color = _fill_settings_background.color
	var style := _fill_settings_style
	var size := FILL_SETTINGS_PREVIEW_IMAGE_SIZE
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var preview_color := foreground
			var foreground_pixel := true
			if style == GDDrawCanvasControl.FillStyle.DITHER:
				foreground_pixel = GDDrawCanvasControl.is_dither_foreground_config(
					Vector2i(x, y),
					_dither_settings_matrix.get_item_id(_dither_settings_matrix.selected),
					_dither_settings_density.value,
					int(_dither_settings_scale.value)
				)
			elif style == GDDrawCanvasControl.FillStyle.PATTERN:
				foreground_pixel = GDDrawCanvasControl.is_pattern_foreground_config(
					Vector2i(x, y),
					_pattern_settings_kind.get_item_id(_pattern_settings_kind.selected),
					_pattern_settings_angle.value,
					int(_pattern_settings_thickness.value),
					int(_pattern_settings_gap.value),
					int(_pattern_settings_cell_width.value),
					int(_pattern_settings_cell_height.value),
					int(_pattern_settings_dot_size.value)
				)
			elif style == GDDrawCanvasControl.FillStyle.CUSTOM:
				preview_color = GDDrawCanvasControl.sample_custom_fill_color(
					Vector2i(x, y),
					_custom_fill_staged_image,
					_custom_fill_color_mode.get_item_id(_custom_fill_color_mode.selected),
					foreground,
					background,
					_custom_fill_repeat_x.button_pressed,
					_custom_fill_repeat_y.button_pressed,
					Vector2(_custom_fill_scale_x.value, _custom_fill_scale_y.value),
					Vector2(_custom_fill_spacing_x.value, _custom_fill_spacing_y.value),
					_custom_fill_rotation.value,
					Vector2(_custom_fill_offset_x.value, _custom_fill_offset_y.value),
					_custom_fill_filtering.get_item_id(_custom_fill_filtering.selected),
					_custom_fill_threshold.value
				)
			else:
				preview_color = foreground if foreground_pixel else background
			if style == GDDrawCanvasControl.FillStyle.DITHER or style == GDDrawCanvasControl.FillStyle.PATTERN:
				preview_color = foreground if foreground_pixel else background
			if style == GDDrawCanvasControl.FillStyle.CUSTOM:
				preview_color = _composite_preview_color(_preview_checker_color(Vector2i(x, y)), preview_color)
			image.set_pixel(x, y, preview_color)
	_fill_settings_preview.texture = ImageTexture.create_from_image(image)


func _preview_checker_color(pixel: Vector2i) -> Color:
	var light: Color = _canvas.checker_color_light if _canvas else DEFAULT_CHECKER_LIGHT_COLOR
	var dark: Color = _canvas.checker_color_dark if _canvas else DEFAULT_CHECKER_DARK_COLOR
	return light if ((pixel.x / 8) + (pixel.y / 8)) % 2 == 0 else dark


func _composite_preview_color(destination: Color, source: Color) -> Color:
	var source_alpha := clampf(source.a, 0.0, 1.0)
	return Color(
		source.r * source_alpha + destination.r * (1.0 - source_alpha),
		source.g * source_alpha + destination.g * (1.0 - source_alpha),
		source.b * source_alpha + destination.b * (1.0 - source_alpha),
		1.0
	)


func _on_mirror_mode_selected(index: int) -> void:
	if not _mirror_mode:
		return
	_set_mirror_mode(_mirror_mode.get_item_id(index))


func _set_mirror_mode(mode: int) -> void:
	if not _canvas:
		return
	_canvas.mirror_mode = clampi(
		mode,
		GDDrawCanvasControl.MirrorMode.OFF,
		GDDrawCanvasControl.MirrorMode.BOTH
	)
	if _mirror_mode:
		for index in range(_mirror_mode.item_count):
			if _mirror_mode.get_item_id(index) == _canvas.mirror_mode:
				_mirror_mode.select(index)
				break
	var labels := ["Off", "Horizontal (top-to-bottom)", "Vertical (left-to-right)", "Both axes"]
	_set_status("Mirror drawing: %s." % labels[_canvas.mirror_mode])
	_sync_menu_state()


func _on_shape_fill_mode_selected(index: int) -> void:
	if not _canvas or not _shape_fill_mode:
		return
	_canvas.shape_fill_mode = _shape_fill_mode.get_item_id(index)
	_update_shape_fill_tooltip(_canvas.shape_fill_mode)


func _update_shape_fill_tooltip(mode: int) -> void:
	if not _shape_fill_mode:
		return
	match mode:
		GDDrawCanvasControl.ShapeFillMode.BACKGROUND:
			_shape_fill_mode.tooltip_text = "Foreground color outlines the shape; background color fills its interior"
		GDDrawCanvasControl.ShapeFillMode.FOREGROUND:
			_shape_fill_mode.tooltip_text = "Foreground color is used for both the shape outline and interior"
		_:
			_shape_fill_mode.tooltip_text = "Foreground color outlines the shape; the interior is left unchanged"


func _on_shape_origin_mode_selected(index: int) -> void:
	if not _canvas or not _shape_origin_mode:
		return
	_canvas.shape_origin_mode = _shape_origin_mode.get_item_id(index)
	_update_shape_origin_tooltip(_canvas.shape_origin_mode)


func _update_shape_origin_tooltip(mode: int) -> void:
	if not _shape_origin_mode:
		return
	match mode:
		GDDrawCanvasControl.ShapeOriginMode.FROM_START_POINT:
			_shape_origin_mode.tooltip_text = "Shape origin: the initial click is the center and the shape expands symmetrically"
		GDDrawCanvasControl.ShapeOriginMode.FROM_CANVAS_CENTER:
			_shape_origin_mode.tooltip_text = "Shape origin: the image canvas center stays fixed and the pointer controls the extent"
		_:
			_shape_origin_mode.tooltip_text = "Shape origin: the initial click and pointer define opposite corners or line endpoints"


func _on_eraser_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_select_tool(GDDrawCanvasControl.ToolMode.ERASER)
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_fill_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_select_tool(GDDrawCanvasControl.ToolMode.FILL)
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_line_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_active_shape_tool = GDDrawCanvasControl.ToolMode.LINE
		_select_tool(GDDrawCanvasControl.ToolMode.LINE)
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_rectangle_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_active_shape_tool = GDDrawCanvasControl.ToolMode.RECTANGLE
		_select_tool(GDDrawCanvasControl.ToolMode.RECTANGLE)
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_ellipse_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_active_shape_tool = GDDrawCanvasControl.ToolMode.ELLIPSE
		_select_tool(GDDrawCanvasControl.ToolMode.ELLIPSE)
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_eyedropper_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_select_tool(GDDrawCanvasControl.ToolMode.EYEDROPPER)
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_selection_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_active_selection_tool = GDDrawCanvasControl.ToolMode.SELECT
		_select_tool(GDDrawCanvasControl.ToolMode.SELECT)
		_set_status("Drag to create a rectangular selection.")
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_lasso_selection_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_active_selection_tool = GDDrawCanvasControl.ToolMode.LASSO_SELECT
		_select_tool(GDDrawCanvasControl.ToolMode.LASSO_SELECT)
		_set_status("Drag to draw a lasso selection.")
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_pan_toggled(enabled: bool) -> void:
	if not _canvas:
		return
	if enabled:
		_select_tool(GDDrawCanvasControl.ToolMode.PAN)
	elif not _has_selected_tool():
		_select_tool(GDDrawCanvasControl.ToolMode.BRUSH)


func _on_pixel_perfect_toggled(enabled: bool) -> void:
	if _canvas:
		_canvas.pixel_perfect = enabled
	if _pixel_perfect:
		_pixel_perfect.set_pressed_no_signal(enabled)
	_update_pixel_perfect_mode_colors(enabled)
	_sync_brush_mode_controls()
	_mark_brush_custom()
	_sync_menu_state()


func _on_stroke_overlap_toggled(enabled: bool) -> void:
	if _canvas:
		_canvas.stroke_overlap_enabled = enabled
	if _stroke_overlap:
		_stroke_overlap.set_pressed_no_signal(enabled)
	if _tool_stroke_overlap:
		_tool_stroke_overlap.set_pressed_no_signal(enabled)
	_sync_menu_state()


func _on_show_grid_toggled(enabled: bool) -> void:
	if _grid_button:
		_grid_button.set_pressed_no_signal(enabled)
		_update_toggle_button_icon(_grid_button)
	if _canvas:
		_canvas.show_grid = enabled
	_sync_menu_state()


func _on_grid_button_toggled(enabled: bool) -> void:
	if _show_grid:
		_show_grid.set_pressed_no_signal(enabled)
	if _grid_button:
		_update_toggle_button_icon(_grid_button)
	if _canvas:
		_canvas.show_grid = enabled
	_sync_menu_state()


func _on_snap_to_grid_toggled(enabled: bool) -> void:
	if _snap_to_grid:
		_snap_to_grid.set_pressed_no_signal(enabled)
	if _snap_to_grid_button:
		_snap_to_grid_button.set_pressed_no_signal(enabled)
		_update_toggle_button_icon(_snap_to_grid_button)
	if _canvas:
		_canvas.snap_to_grid = enabled
	var editor_settings := _get_editor_settings()
	if editor_settings:
		editor_settings.set_project_metadata(SETTINGS_SECTION, SNAP_TO_GRID_KEY, enabled)
	_sync_menu_state()


func _on_grid_size_submitted(value: String) -> void:
	_apply_grid_size(value)


func _on_grid_size_focus_exited() -> void:
	if _grid_size:
		_apply_grid_size(_grid_size.text)


func _apply_grid_size(value: String) -> void:
	var grid_size := _parse_bounded_int(value, 1, 128, 1)
	if _grid_size:
		_grid_size.text = str(grid_size)
	if _canvas:
		_canvas.grid_size = grid_size


func _on_grid_min_cell_size_submitted(value: String) -> void:
	_apply_grid_min_cell_size(value)


func _on_grid_min_cell_size_focus_exited() -> void:
	if _grid_min_cell_size:
		_apply_grid_min_cell_size(_grid_min_cell_size.text)


func _apply_grid_min_cell_size(value: String) -> void:
	var grid_min_cell_size := _parse_bounded_int(value, 1, 64, 6)
	if _grid_min_cell_size:
		_grid_min_cell_size.text = str(grid_min_cell_size)
	if _canvas:
		_canvas.grid_min_cell_size = grid_min_cell_size


func _on_grid_color_changed(color: Color) -> void:
	if _canvas:
		_canvas.grid_color = color


func _on_checker_light_changed(color: Color) -> void:
	if not _canvas:
		return
	_canvas.checker_color_light = color
	var editor_settings := _get_editor_settings()
	if editor_settings:
		editor_settings.set_project_metadata(SETTINGS_SECTION, CHECKER_LIGHT_KEY, _canvas.checker_color_light)


func _on_checker_dark_changed(color: Color) -> void:
	if not _canvas:
		return
	_canvas.checker_color_dark = color
	var editor_settings := _get_editor_settings()
	if editor_settings:
		editor_settings.set_project_metadata(SETTINGS_SECTION, CHECKER_DARK_KEY, _canvas.checker_color_dark)


func _reset_checker_colors() -> void:
	if not _canvas:
		return
	_canvas.checker_color_light = DEFAULT_CHECKER_LIGHT_COLOR
	_canvas.checker_color_dark = DEFAULT_CHECKER_DARK_COLOR
	if _checker_light_picker:
		_checker_light_picker.color = _canvas.checker_color_light
	if _checker_dark_picker:
		_checker_dark_picker.color = _canvas.checker_color_dark
	var editor_settings := _get_editor_settings()
	if editor_settings:
		editor_settings.set_project_metadata(SETTINGS_SECTION, CHECKER_LIGHT_KEY, _canvas.checker_color_light)
		editor_settings.set_project_metadata(SETTINGS_SECTION, CHECKER_DARK_KEY, _canvas.checker_color_dark)


func _zoom_in() -> void:
	if _shared_view_controls_target_3d():
		_paint_3d_distance = maxf(0.1, _paint_3d_distance * 0.88)
		_update_3d_paint_camera()
	elif _canvas:
		_canvas.zoom_in()


func _zoom_out() -> void:
	if _shared_view_controls_target_3d():
		_paint_3d_distance = minf(200.0, _paint_3d_distance / 0.88)
		_update_3d_paint_camera()
	elif _canvas:
		_canvas.zoom_out()


func _zoom_3d_in() -> void:
	_paint_3d_distance = maxf(0.1, _paint_3d_distance * 0.88)
	_update_3d_paint_camera()


func _zoom_3d_out() -> void:
	_paint_3d_distance = minf(200.0, _paint_3d_distance / 0.88)
	_update_3d_paint_camera()


func _frame_active_3d_mesh() -> void:
	if _paint_3d_mesh and _paint_3d_mesh.mesh:
		_frame_3d_paint_mesh(_paint_3d_mesh.mesh)


func _reset_view() -> void:
	if _shared_view_controls_target_3d() and _paint_3d_mesh and _paint_3d_mesh.mesh:
		_frame_3d_paint_mesh(_paint_3d_mesh.mesh)
	elif _canvas:
		_canvas.reset_view()


func _shared_view_controls_target_3d() -> bool:
	return _canvas_mode == CANVAS_MODE_3D or (
		_canvas_mode == CANVAS_MODE_SPLIT
		and _paint_3d_view
		and _paint_3d_view.has_focus()
	)


func _on_view_changed(zoom_percent: int) -> void:
	_current_2d_zoom_percent = zoom_percent
	if _zoom_label:
		_zoom_label.text = "%d%%" % zoom_percent
	if _zoom_in_button and _canvas:
		_zoom_in_button.disabled = not _canvas.can_zoom_in()
	if _zoom_out_button and _canvas:
		_zoom_out_button.disabled = not _canvas.can_zoom_out()
	_sync_menu_state()


func _on_canvas_size_changed(canvas_size: Vector2i) -> void:
	_syncing_canvas_dimensions = true
	if _canvas_width:
		_canvas_width.set_value_no_signal(canvas_size.x)
	if _canvas_height:
		_canvas_height.set_value_no_signal(canvas_size.y)
	_syncing_canvas_dimensions = false
	if canvas_size.x > 0 and (_resize_link_button == null or _resize_link_button.button_pressed):
		_resize_aspect_ratio = float(canvas_size.y) / float(canvas_size.x)
	_update_canvas_resize_control_availability()


func _is_canvas_resize_locked() -> bool:
	return _texture_3d_session != null and _texture_3d_session.has_active_session()


func _update_canvas_resize_control_availability() -> void:
	var resize_locked := _is_canvas_resize_locked()
	var tooltip := CANVAS_RESIZE_LOCK_TOOLTIP if resize_locked else ""
	if _canvas_width:
		_canvas_width.editable = not resize_locked
		_canvas_width.tooltip_text = tooltip if resize_locked else "Canvas width in pixels"
	if _canvas_height:
		_canvas_height.editable = not resize_locked
		_canvas_height.tooltip_text = tooltip if resize_locked else "Canvas height in pixels"
	if _resize_link_button:
		_resize_link_button.disabled = resize_locked
		if resize_locked:
			_resize_link_button.tooltip_text = tooltip
		else:
			_update_resize_link_tooltip()
	if _keep_pixels:
		_keep_pixels.disabled = resize_locked
		_keep_pixels.tooltip_text = tooltip if resize_locked else "Keep existing pixels when resizing"
	if _resize_canvas_button:
		_resize_canvas_button.disabled = resize_locked
		_resize_canvas_button.tooltip_text = tooltip if resize_locked else "Resize the image canvas"


func _reject_locked_canvas_resize() -> bool:
	if not _is_canvas_resize_locked():
		return false
	_update_canvas_resize_control_availability()
	_set_status(CANVAS_RESIZE_LOCK_STATUS)
	return true


func _on_canvas_width_changed(value: float) -> void:
	if _syncing_canvas_dimensions or not _resize_link_button or not _resize_link_button.button_pressed:
		return
	_syncing_canvas_dimensions = true
	_canvas_height.set_value_no_signal(clampf(roundf(value * _resize_aspect_ratio), _canvas_height.min_value, _canvas_height.max_value))
	_syncing_canvas_dimensions = false


func _on_canvas_height_changed(value: float) -> void:
	if _syncing_canvas_dimensions or not _resize_link_button or not _resize_link_button.button_pressed:
		return
	_syncing_canvas_dimensions = true
	_canvas_width.set_value_no_signal(clampf(roundf(value / _resize_aspect_ratio), _canvas_width.min_value, _canvas_width.max_value))
	_syncing_canvas_dimensions = false


func _on_resize_link_toggled(enabled: bool) -> void:
	if enabled and _canvas_width and _canvas_height and _canvas_width.value > 0:
		_resize_aspect_ratio = float(_canvas_height.value) / float(_canvas_width.value)
	_update_resize_link_tooltip()


func _update_resize_link_tooltip() -> void:
	if not _resize_link_button:
		return
	_resize_link_button.tooltip_text = "Unlock resize aspect ratio" if _resize_link_button.button_pressed else "Lock resize aspect ratio"


func _on_default_canvas_width_changed(_value: float) -> void:
	_apply_default_canvas_size()


func _on_default_canvas_height_changed(_value: float) -> void:
	_apply_default_canvas_size()


func _apply_default_canvas_size() -> void:
	if _syncing_default_canvas_size or not _default_canvas_width or not _default_canvas_height:
		return
	var default_size := Vector2i(int(_default_canvas_width.value), int(_default_canvas_height.value))
	default_size = _clamp_canvas_size(default_size)
	_syncing_default_canvas_size = true
	_default_canvas_width.set_value_no_signal(default_size.x)
	_default_canvas_height.set_value_no_signal(default_size.y)
	_syncing_default_canvas_size = false
	_set_default_canvas_size(default_size)
	_set_status("Default canvas set to %sx%s." % [default_size.x, default_size.y])


func _refresh_canvas_visible_pixels_state() -> void:
	_canvas_has_visible_pixels = _canvas != null and _canvas.has_visible_pixels()


func _on_stroke_committed(previous_image: Image) -> void:
	_refresh_canvas_visible_pixels_state()
	_push_undo(previous_image)
	_history.clear_redo()
	_update_history_buttons()
	_update_selection_action_buttons()
	_sync_3d_paint_texture()
	_update_3d_session_status()


func _on_canvas_image_changed(image: Image) -> void:
	if _paint_3d_view and _texture_3d_session and _texture_3d_session.has_active_session():
		_set_3d_paint_texture_image(image)
	_update_3d_session_status(image)


func _on_canvas_hover_uv_changed(uv: Vector2, has_hover: bool) -> void:
	_paint_3d_pending_2d_hover_uv = uv
	_paint_3d_pending_2d_hover_visible = has_hover
	_paint_3d_pending_2d_hover = true


func _process_pending_2d_hover() -> void:
	if not _paint_3d_pending_2d_hover:
		return
	_paint_3d_pending_2d_hover = false
	_process_canvas_hover_uv(_paint_3d_pending_2d_hover_uv, _paint_3d_pending_2d_hover_visible)


func _process_canvas_hover_uv(uv: Vector2, has_hover: bool) -> void:
	if not _linked_view_enabled or _canvas_mode != CANVAS_MODE_SPLIT or not _paint_3d_view or not _paint_3d_view.visible:
		_hide_3d_hover_debug_marker("Split view is not active")
		_hide_3d_hover_triangle()
		return
	if _paint_3d_drawing or _paint_3d_orbiting or _paint_3d_panning or _paint_3d_freelooking:
		_hide_3d_hover_debug_marker("3D view interaction is active")
		_hide_3d_hover_triangle()
		return
	if not has_hover:
		_hide_3d_hover_debug_marker("pointer left the 2D image")
		_hide_3d_hover_triangle()
		_hide_3d_brush_preview()
		return
	var canvas_size: Vector2i = _canvas.get_canvas_size() if _canvas else Vector2i.ONE
	var hover_pixel := Vector2i(
		clampi(floori(uv.x * float(canvas_size.x)), 0, maxi(0, canvas_size.x - 1)),
		clampi(floori(uv.y * float(canvas_size.y)), 0, maxi(0, canvas_size.y - 1))
	)
	if hover_pixel == _paint_3d_last_2d_hover_pixel and _paint_3d_hover_triangle and _paint_3d_hover_triangle.visible:
		return
	var hit := _find_3d_paint_hit_from_uv(uv)
	if hit.is_empty():
		_hide_3d_hover_debug_marker("UV lookup returned no hit")
		_hide_3d_hover_triangle()
		_hide_3d_brush_preview()
		return
	_paint_3d_last_2d_hover_pixel = hover_pixel
	if _paint_3d_brush_preview:
		_paint_3d_brush_preview.visible = false
	if SHOW_2D_TO_3D_HOVER_MARKER:
		_update_3d_hover_debug_marker(hit)
	_update_3d_hover_triangle(hit)
	_update_3d_paint_cursor(true)


func _on_3d_paint_uv_started(hit: Dictionary) -> bool:
	if not _canvas:
		return false
	if _is_3d_surface_shape_tool(_canvas.active_tool):
		return _begin_3d_surface_shape(hit)
	if not hit.has("uv_overlap_count"):
		hit["uv_overlap_count"] = _count_3d_uv_overlaps(hit)
	if _shared_uv_paint_is_blocked(hit):
		_warn_if_3d_hit_has_uv_overlap(hit)
		return false
	_warn_if_3d_hit_has_uv_overlap(hit)
	_begin_3d_soft_brush_stroke()
	_canvas.begin_uv_triangle_stroke(
		hit.get("texture_uv", hit.get("uv", Vector2.ZERO)),
		hit.get("texture_triangle_uvs", hit.get("triangle_uvs", PackedVector2Array()))
	)
	_paint_3d_last_stroke_hit = hit.duplicate(true)
	return true


func _on_3d_paint_uv_dragged(hit: Dictionary) -> void:
	if not _paint_3d_surface_shape_state.is_empty():
		_update_3d_surface_shape(hit)
		return
	if _canvas:
		if _shared_uv_paint_is_blocked(hit):
			_paint_3d_last_stroke_hit.clear()
			return
		var connect_from_previous := _should_connect_3d_stroke_hits(_paint_3d_last_stroke_hit, hit)
		_canvas.continue_uv_triangle_stroke(
			hit.get("texture_uv", hit.get("uv", Vector2.ZERO)),
			hit.get("texture_triangle_uvs", hit.get("triangle_uvs", PackedVector2Array())),
			connect_from_previous
		)
		_paint_3d_last_stroke_hit = hit.duplicate(true)


func _on_3d_paint_uv_finished() -> void:
	if not _paint_3d_surface_shape_state.is_empty():
		_finish_3d_surface_shape()
		return
	if _canvas:
		_canvas.end_uv_triangle_stroke()
	_paint_3d_last_stroke_hit.clear()
	_end_3d_soft_brush_stroke()
	_sync_3d_paint_texture()


func _begin_3d_surface_shape(hit: Dictionary) -> bool:
	if (
		not _canvas
		or not _texture_3d_session
		or not _texture_3d_session.has_active_session()
		or not _paint_3d_mesh_cache
		or not _paint_3d_mesh_cache.is_valid()
	):
		return false
	var validation: Dictionary = _paint_3d_mesh_cache.validate_surface_shape_endpoints(
		hit,
		hit,
		_get_3d_uv_overlap_distance_epsilon()
	)
	if not bool(validation.get("valid", false)):
		_set_status(str(validation.get("reason", "The shape cannot start here.")))
		return false
	if not hit.has("uv_overlap_count"):
		hit["uv_overlap_count"] = _count_3d_uv_overlaps(hit)
	_warn_if_3d_hit_has_uv_overlap(hit)
	var texture_uv: Vector2 = hit.get("texture_uv", hit.get("uv", Vector2.ZERO))
	var pixel: Vector2i = _canvas.image_pixel_from_uv(texture_uv)
	var shape_tool: int = _canvas.active_tool
	var shape_name := _get_3d_surface_shape_name(shape_tool)
	_paint_3d_surface_shape_state = {
		"shape_tool": shape_tool,
		"shape_name": shape_name,
		"preview_mesh_node": _paint_3d_mesh,
		"preview_mesh_resource": _paint_3d_mesh.mesh if _paint_3d_mesh else null,
		"preview_material": _paint_3d_material,
		"session": _texture_3d_session,
		"source_node": _texture_3d_session.source_node if _texture_3d_session else null,
		"material_slot": int(_texture_3d_session.material_slot) if _texture_3d_session else -1,
		"surface_index": int(hit.get("surface_index", -1)),
		"start_hit": hit.duplicate(true),
		"end_hit": hit.duplicate(true),
		"start_uv": texture_uv,
		"end_uv": texture_uv,
		"start_pixel": pixel,
		"end_pixel": pixel,
		"foreground_color": _canvas.brush_color,
		"shape_settings": {
			"width": _canvas.brush_size,
			"brush_head": _canvas.brush_head,
			"pixel_perfect": _canvas.pixel_perfect,
			"brush_hardness": _canvas.brush_hardness,
			"opacity": _canvas.brush_color.a,
			"alpha_lock": _canvas.alpha_lock,
			"mirror_mode": _canvas.mirror_mode,
			"stroke_overlap_enabled": _canvas.stroke_overlap_enabled,
			"fill_mode": _canvas.shape_fill_mode,
			"background_color": _canvas.background_color,
		},
		"endpoint_valid": true,
		"invalid_reason": "",
	}
	if not _canvas.begin_surface_shape_preview(pixel, pixel):
		_paint_3d_surface_shape_state.clear()
		return false
	_sync_3d_surface_shape_preview()
	return true


func _update_3d_surface_shape(hit: Dictionary) -> bool:
	if _paint_3d_surface_shape_state.is_empty() or not _canvas:
		return false
	var validation := _validate_3d_surface_shape_hit(hit)
	var valid := bool(validation.get("valid", false))
	_paint_3d_surface_shape_state["endpoint_valid"] = valid
	_paint_3d_surface_shape_state["invalid_reason"] = str(validation.get("reason", ""))
	if not valid:
		_canvas.update_surface_shape_preview(Vector2i.ZERO, false)
		_sync_3d_surface_shape_preview()
		return false
	var texture_uv: Vector2 = hit.get("texture_uv", hit.get("uv", Vector2.ZERO))
	var pixel: Vector2i = _canvas.image_pixel_from_uv(texture_uv)
	_paint_3d_surface_shape_state["end_hit"] = hit.duplicate(true)
	_paint_3d_surface_shape_state["end_uv"] = texture_uv
	_paint_3d_surface_shape_state["end_pixel"] = pixel
	_canvas.update_surface_shape_preview(pixel, true)
	_sync_3d_surface_shape_preview()
	return true


func _invalidate_3d_surface_shape(reason: String) -> void:
	if _paint_3d_surface_shape_state.is_empty():
		return
	_paint_3d_surface_shape_state["endpoint_valid"] = false
	_paint_3d_surface_shape_state["invalid_reason"] = reason
	if _canvas:
		_canvas.update_surface_shape_preview(Vector2i.ZERO, false)
	_sync_3d_surface_shape_preview()


func _validate_3d_surface_shape_hit(hit: Dictionary) -> Dictionary:
	if _paint_3d_surface_shape_state.is_empty() or not _canvas:
		return {"valid": false, "reason": "There is no active 3D shape preview."}
	if _canvas.active_tool != int(_paint_3d_surface_shape_state.get("shape_tool", -1)):
		return {"valid": false, "reason": "The active tool changed before the shape was released."}
	if (
		_paint_3d_surface_shape_state.get("preview_mesh_node") != _paint_3d_mesh
		or _paint_3d_surface_shape_state.get("preview_mesh_resource") != (_paint_3d_mesh.mesh if _paint_3d_mesh else null)
		or _paint_3d_surface_shape_state.get("preview_material") != _paint_3d_material
		or _paint_3d_surface_shape_state.get("session") != _texture_3d_session
	):
		return {"valid": false, "reason": "The active mesh or material surface changed during the shape drag."}
	if not _texture_3d_session or int(_texture_3d_session.material_slot) != int(_paint_3d_surface_shape_state.get("material_slot", -1)):
		return {"valid": false, "reason": "The selected material surface changed during the shape drag."}
	if hit.is_empty():
		return {"valid": false, "reason": "Release the shape over the active 3D surface."}
	if not _paint_3d_mesh_cache or not _paint_3d_mesh_cache.is_valid():
		return {"valid": false, "reason": "The active mesh geometry is no longer available."}
	return _paint_3d_mesh_cache.validate_surface_shape_endpoints(
		_paint_3d_surface_shape_state.get("start_hit", {}),
		hit,
		_get_3d_uv_overlap_distance_epsilon()
	)


func _finish_3d_surface_shape(release_hit: Dictionary = {}) -> bool:
	if _paint_3d_surface_shape_state.is_empty():
		return false
	if not release_hit.is_empty():
		_update_3d_surface_shape(release_hit)
	var valid := bool(_paint_3d_surface_shape_state.get("endpoint_valid", false))
	var reason := str(_paint_3d_surface_shape_state.get("invalid_reason", "Release the shape over the active 3D surface."))
	if not valid:
		_cancel_3d_surface_shape(reason, true)
		return false
	var shape_name := str(_paint_3d_surface_shape_state.get("shape_name", "Shape"))
	var committed: bool = _canvas != null and _canvas.commit_surface_shape_preview()
	_paint_3d_surface_shape_state.clear()
	_paint_3d_last_stroke_hit.clear()
	_sync_3d_paint_texture()
	_set_status(
		"Committed 3D surface %s." % shape_name.to_lower()
		if committed
		else "The 3D surface %s made no pixel changes." % shape_name.to_lower()
	)
	return committed


func _finish_3d_surface_shape_at(view_position: Vector2) -> bool:
	var release_hit := _pick_3d_paint_uv(view_position)
	if release_hit.is_empty():
		_invalidate_3d_surface_shape("Release the shape over the active 3D surface.")
		return _finish_3d_surface_shape()
	return _finish_3d_surface_shape(release_hit)


func _cancel_3d_surface_shape(reason := "Canceled 3D shape preview.", show_status := false, sync_texture := true) -> bool:
	if _paint_3d_surface_shape_state.is_empty():
		return false
	if _canvas:
		_canvas.cancel_surface_shape_preview()
	_paint_3d_surface_shape_state.clear()
	_paint_3d_last_stroke_hit.clear()
	_paint_3d_drawing = false
	_paint_3d_pending_motion = false
	if sync_texture:
		_sync_3d_paint_texture()
	if show_status and not reason.is_empty():
		_set_status(reason)
	return true


func _sync_3d_surface_shape_preview() -> void:
	if not _canvas or _paint_3d_surface_shape_state.is_empty():
		return
	_set_3d_paint_texture_image(_canvas.get_surface_shape_preview_image())


func _is_3d_surface_shape_tool(tool: int) -> bool:
	return tool in [
		GDDrawCanvasControl.ToolMode.LINE,
		GDDrawCanvasControl.ToolMode.RECTANGLE,
		GDDrawCanvasControl.ToolMode.ELLIPSE,
	]


func _get_3d_surface_shape_name(tool: int) -> String:
	match tool:
		GDDrawCanvasControl.ToolMode.RECTANGLE:
			return "Rectangle"
		GDDrawCanvasControl.ToolMode.ELLIPSE:
			return "Ellipse"
		_:
			return "Line"


# Compatibility entry points retained for focused Line integrations/tests.
func _begin_3d_surface_line(hit: Dictionary) -> bool:
	return _begin_3d_surface_shape(hit)


func _update_3d_surface_line(hit: Dictionary) -> bool:
	return _update_3d_surface_shape(hit)


func _invalidate_3d_surface_line(reason: String) -> void:
	_invalidate_3d_surface_shape(reason)


func _validate_3d_surface_line_hit(hit: Dictionary) -> Dictionary:
	return _validate_3d_surface_shape_hit(hit)


func _finish_3d_surface_line(release_hit: Dictionary = {}) -> bool:
	return _finish_3d_surface_shape(release_hit)


func _finish_3d_surface_line_at(view_position: Vector2) -> bool:
	return _finish_3d_surface_shape_at(view_position)


func _should_connect_3d_stroke_hits(previous_hit: Dictionary, current_hit: Dictionary) -> bool:
	if previous_hit.is_empty() or current_hit.is_empty():
		return false
	if int(previous_hit.get("surface_index", -1)) != int(current_hit.get("surface_index", -1)):
		return false
	if int(previous_hit.get("triangle_index", -1)) == int(current_hit.get("triangle_index", -2)):
		return true
	var previous_positions: PackedVector3Array = previous_hit.get("triangle_positions", PackedVector3Array())
	var current_positions: PackedVector3Array = current_hit.get("triangle_positions", PackedVector3Array())
	if not _3d_triangles_share_edge(previous_positions, current_positions):
		return false
	if not _canvas:
		return true
	var size: Vector2i = _canvas.get_canvas_size()
	var previous_uv: Vector2 = previous_hit.get("texture_uv", previous_hit.get("uv", Vector2.ZERO))
	var current_uv: Vector2 = current_hit.get("texture_uv", current_hit.get("uv", Vector2.ZERO))
	var texture_delta := Vector2(
		(current_uv.x - previous_uv.x) * float(size.x),
		(current_uv.y - previous_uv.y) * float(size.y)
	).length()
	return texture_delta <= maxf(16.0, float(maxi(1, _canvas.brush_size)) * 4.0)


func _3d_triangles_share_edge(left: PackedVector3Array, right: PackedVector3Array) -> bool:
	if left.size() < 3 or right.size() < 3:
		return false
	var shared_vertices := 0
	for left_position in left:
		for right_position in right:
			if left_position.distance_squared_to(right_position) <= 0.00000001:
				shared_vertices += 1
				break
	return shared_vertices >= 2


func _on_color_picked(color: Color, pixel: Vector2i) -> void:
	if not _canvas:
		return
	_set_foreground_color(color)
	_record_recent_color(color)
	_set_status("Picked color at %s, %s." % [pixel.x, pixel.y])


func _on_selection_committed(selection_rect: Rect2i) -> void:
	_set_status("Selected %sx%s at %s, %s." % [
		selection_rect.size.x,
		selection_rect.size.y,
		selection_rect.position.x,
		selection_rect.position.y,
	])
	_update_selection_action_buttons()


func _on_selection_cleared() -> void:
	_update_selection_action_buttons()


func _cut_selection() -> void:
	if not _canvas:
		return
	if _canvas.cut_selection():
		_set_status("Cut selection.")
	else:
		_set_status("Select an area before cutting.")
	_update_selection_action_buttons()


func _copy_selection() -> void:
	if not _canvas:
		return
	if _canvas.copy_selection():
		_set_status("Copied selection.")
	else:
		_set_status("Select an area before copying.")
	_update_selection_action_buttons()


func _paste_selection() -> void:
	if not _canvas:
		return
	if not _canvas.has_clipboard_image():
		var clipboard_source := _get_system_clipboard_image_source()
		var clipboard_image: Image = clipboard_source.get("image", null)
		if clipboard_image:
			_paste_external_clipboard_image(clipboard_image, str(clipboard_source.get("label", "clipboard image")))
			return
	if _canvas.paste_selection():
		_select_tool(GDDrawCanvasControl.ToolMode.SELECT)
		_set_status("Pasted selection.")
	else:
		_set_status("Copy an image or cut/copy a GDDraw selection before pasting.")
	_update_selection_action_buttons()


func _paste_external_clipboard_image(image: Image, label: String) -> void:
	if not image or image.is_empty():
		_set_status("Copy an image or cut/copy a GDDraw selection before pasting.")
		return
	var image_size := Vector2i(image.get_width(), image.get_height())
	var canvas_size: Vector2i = _canvas.get_canvas_size()
	if image_size != canvas_size and _clipboard_paste_resize_dialog:
		_pending_clipboard_paste_image = image.duplicate()
		_pending_clipboard_paste_label = label
		_clipboard_paste_resize_dialog.dialog_text = (
			"The clipboard image is %sx%s. Resize the %sx%s canvas before pasting?"
			% [image_size.x, image_size.y, canvas_size.x, canvas_size.y]
		)
		_clipboard_paste_resize_dialog.popup_centered()
		return
	_paste_external_clipboard_image_now(image, label, false)


func _paste_external_clipboard_image_now(image: Image, label: String, resize_canvas: bool) -> void:
	if not image or image.is_empty() or not _canvas:
		return
	if resize_canvas and _reject_locked_canvas_resize():
		return
	if resize_canvas:
		var image_size := Vector2i(image.get_width(), image.get_height())
		if image_size != _canvas.get_canvas_size():
			_push_undo(_canvas.resize_canvas(image_size, true))
			_history.clear_redo()
			_update_history_buttons()
	if _canvas.set_clipboard_image(image) and _canvas.paste_selection():
		_select_tool(GDDrawCanvasControl.ToolMode.SELECT)
		_set_status("Pasted " + label + ".")
	else:
		_set_status("Copy an image or cut/copy a GDDraw selection before pasting.")
	_update_selection_action_buttons()


func _paste_pending_clipboard_image_with_resize() -> void:
	_paste_pending_clipboard_image(true)


func _on_clipboard_paste_resize_custom_action(action: StringName) -> void:
	if action == &"paste_keep_size":
		if _clipboard_paste_resize_dialog:
			_clipboard_paste_resize_dialog.hide()
		_paste_pending_clipboard_image(false)


func _paste_pending_clipboard_image(resize_canvas: bool) -> void:
	if not _pending_clipboard_paste_image:
		return
	var image := _pending_clipboard_paste_image
	var label := _pending_clipboard_paste_label
	_pending_clipboard_paste_image = null
	_pending_clipboard_paste_label = ""
	_paste_external_clipboard_image_now(image, label, resize_canvas)


func _select_all() -> void:
	if not _canvas:
		return
	if _canvas.select_all():
		_select_tool(GDDrawCanvasControl.ToolMode.SELECT)
		_set_status("Selected all.")
	_update_selection_action_buttons()


func _flip_selection_horizontal() -> void:
	if not _canvas:
		return
	if _canvas.flip_selection_horizontal():
		_select_tool(GDDrawCanvasControl.ToolMode.SELECT)
		_set_status("Flipped selection horizontally.")
	else:
		_set_status("Select an area before flipping.")
	_update_selection_action_buttons()


func _flip_selection_vertical() -> void:
	if not _canvas:
		return
	if _canvas.flip_selection_vertical():
		_select_tool(GDDrawCanvasControl.ToolMode.SELECT)
		_set_status("Flipped selection vertically.")
	else:
		_set_status("Select an area before flipping.")
	_update_selection_action_buttons()


func _rotate_selection(clockwise: bool) -> void:
	if not _canvas:
		return
	var changed: bool = _canvas.rotate_selection_clockwise() if clockwise else _canvas.rotate_selection_counterclockwise()
	if changed:
		_select_tool(GDDrawCanvasControl.ToolMode.SELECT)
		_set_status("Rotated selection 90° %s." % ("clockwise" if clockwise else "counterclockwise"))
	else:
		_set_status("Select an area before rotating.")
	_update_selection_action_buttons()


func _rotate_selection_by_amount(clockwise: bool) -> void:
	if not _canvas:
		return
	var amount := 90.0
	if _selection_rotate_amount:
		amount = clampf(float(_selection_rotate_amount.value), 1.0, 359.0)
	var signed_amount := amount if clockwise else -amount
	if _canvas.rotate_selection_degrees(signed_amount):
		_select_tool(GDDrawCanvasControl.ToolMode.SELECT)
		_set_status("Rotated selection %s° %s." % [int(amount), "clockwise" if clockwise else "counterclockwise"])
	else:
		_set_status("Select an area before rotating.")
	_update_selection_action_buttons()


func _duplicate_selection() -> void:
	if _canvas and _canvas.duplicate_selection():
		_select_tool(GDDrawCanvasControl.ToolMode.SELECT)
		_set_status("Duplicated selection. Move it, then Commit or Cancel.")
	else:
		_set_status("Select an area before duplicating.")
	_update_selection_action_buttons()


func _commit_selection_transform() -> void:
	if _canvas and _canvas.commit_active_selection_transform():
		_set_status("Committed floating selection.")
	else:
		_set_status("No floating selection to commit.")
	_update_selection_action_buttons()


func _delete_selection() -> void:
	if not _canvas:
		return
	if _canvas.delete_active_selection():
		_set_status("Deleted selection.")
	else:
		_set_status("Select an area before deleting.")
	_update_selection_action_buttons()


func _cancel_selection_or_preview() -> void:
	if not _canvas:
		return
	if _cancel_3d_surface_shape("Canceled 3D shape preview.", true):
		return
	if _crop_workflow_active:
		_cancel_crop_rectangle()
		return
	if _canvas.cancel_active_selection_or_preview():
		_set_status("Canceled selection or preview.")
	else:
		_set_status("Nothing to cancel.")
	_update_selection_action_buttons()


func _reject_locked_crop() -> bool:
	if not _is_canvas_resize_locked():
		return false
	_set_status(CROP_LOCK_STATUS)
	_sync_menu_state()
	return true


func _reject_locked_scale() -> bool:
	if not _is_canvas_resize_locked():
		return false
	_set_status(SCALE_LOCK_STATUS)
	_sync_menu_state()
	return true


func _start_scale_image() -> void:
	if not _canvas or not _scale_image_dialog or _reject_locked_scale():
		return
	if _crop_workflow_active:
		_cancel_crop_rectangle(false)
	_scale_source_size = _canvas.get_canvas_size()
	_syncing_scale_controls = true
	_scale_width.set_value_no_signal(_scale_source_size.x)
	_scale_height.set_value_no_signal(_scale_source_size.y)
	_scale_preserve_aspect.set_pressed_no_signal(true)
	_scale_interpolation.select(0)
	_syncing_scale_controls = false
	_scale_workflow_active = true
	_scale_image_dialog.size = SCALE_IMAGE_DIALOG_SIZE
	_scale_image_dialog.popup_centered(SCALE_IMAGE_DIALOG_SIZE)
	var width_line_edit := _scale_width.get_line_edit()
	if width_line_edit:
		width_line_edit.call_deferred("grab_focus")
	_set_status("Choose scaled dimensions. Apply with Enter or cancel with Escape.")


func _on_scale_width_changed(value: float) -> void:
	if (
		_syncing_scale_controls
		or not _scale_preserve_aspect
		or not _scale_preserve_aspect.button_pressed
		or not _scale_height
	):
		return
	var synchronized := _aspect_size_from_width(int(value), _scale_source_size)
	_syncing_scale_controls = true
	_scale_height.set_value_no_signal(synchronized.y)
	_syncing_scale_controls = false


func _on_scale_height_changed(value: float) -> void:
	if (
		_syncing_scale_controls
		or not _scale_preserve_aspect
		or not _scale_preserve_aspect.button_pressed
		or not _scale_width
	):
		return
	var synchronized := _aspect_size_from_height(int(value), _scale_source_size)
	_syncing_scale_controls = true
	_scale_width.set_value_no_signal(synchronized.x)
	_syncing_scale_controls = false


func _on_scale_preserve_aspect_toggled(enabled: bool) -> void:
	if enabled and _scale_width:
		_on_scale_width_changed(_scale_width.value)


func _aspect_size_from_width(width: int, source_size: Vector2i) -> Vector2i:
	var clamped_width := clampi(width, GDDrawCanvasControl.MIN_IMAGE_SIZE, GDDrawCanvasControl.MAX_IMAGE_SIZE)
	var source_width := maxi(1, source_size.x)
	var source_height := maxi(1, source_size.y)
	var height := roundi(float(clamped_width) * float(source_height) / float(source_width))
	return Vector2i(
		clamped_width,
		clampi(height, GDDrawCanvasControl.MIN_IMAGE_SIZE, GDDrawCanvasControl.MAX_IMAGE_SIZE)
	)


func _aspect_size_from_height(height: int, source_size: Vector2i) -> Vector2i:
	var clamped_height := clampi(height, GDDrawCanvasControl.MIN_IMAGE_SIZE, GDDrawCanvasControl.MAX_IMAGE_SIZE)
	var source_width := maxi(1, source_size.x)
	var source_height := maxi(1, source_size.y)
	var width := roundi(float(clamped_height) * float(source_width) / float(source_height))
	return Vector2i(
		clampi(width, GDDrawCanvasControl.MIN_IMAGE_SIZE, GDDrawCanvasControl.MAX_IMAGE_SIZE),
		clamped_height
	)


func _apply_scale_image() -> void:
	if not _scale_workflow_active or not _canvas:
		return
	if _reject_locked_scale():
		_cancel_scale_image(false)
		return
	var new_size := Vector2i(int(_scale_width.value), int(_scale_height.value))
	var interpolation := _scale_interpolation.get_selected_id()
	_scale_workflow_active = false
	if _canvas.scale_image(new_size, interpolation):
		_set_status("Scaled image to %sx%s." % [new_size.x, new_size.y])
	else:
		_set_status("Image scaling did not change the canvas.")
	_update_selection_action_buttons()


func _cancel_scale_image(show_status := true) -> void:
	if not _scale_workflow_active:
		return
	_scale_workflow_active = false
	if _scale_image_dialog and _scale_image_dialog.visible:
		_scale_image_dialog.hide()
	if show_status:
		_set_status("Image scaling canceled.")


func _crop_to_selection() -> void:
	if not _canvas or _reject_locked_crop():
		return
	if _crop_workflow_active:
		_cancel_crop_rectangle(false)
	if _canvas.crop_to_selection():
		var size: Vector2i = _canvas.get_canvas_size()
		_set_status("Cropped to selection: %sx%s." % [size.x, size.y])
	else:
		_set_status("Crop to Selection did not change the canvas.")
	_update_selection_action_buttons()


func _trim_transparent_bounds() -> void:
	if not _canvas or _reject_locked_crop():
		return
	if _crop_workflow_active:
		_cancel_crop_rectangle(false)
	if _canvas.trim_transparent_bounds():
		var size: Vector2i = _canvas.get_canvas_size()
		_set_status("Trimmed transparent bounds to %sx%s." % [size.x, size.y])
	else:
		_set_status("Nothing to trim: the canvas is transparent or already tight.")
	_update_selection_action_buttons()


func _start_crop_rectangle() -> void:
	if not _canvas or not _crop_rectangle_dialog or _reject_locked_crop():
		return
	var size: Vector2i = _canvas.get_canvas_size()
	_syncing_crop_controls = true
	_crop_x.max_value = maxi(0, size.x - 1)
	_crop_y.max_value = maxi(0, size.y - 1)
	_crop_width.max_value = size.x
	_crop_height.max_value = size.y
	_crop_x.set_value_no_signal(0)
	_crop_y.set_value_no_signal(0)
	_crop_width.set_value_no_signal(size.x)
	_crop_height.set_value_no_signal(size.y)
	_syncing_crop_controls = false
	_crop_workflow_active = true
	_canvas.begin_crop_preview(Rect2i(Vector2i.ZERO, size))
	_crop_rectangle_dialog.size = CROP_RECTANGLE_DIALOG_SIZE
	_crop_rectangle_dialog.popup_centered(CROP_RECTANGLE_DIALOG_SIZE)
	_set_status("Crop preview active. Apply with Enter or cancel with Escape.")


func _on_crop_rectangle_value_changed(_value: float) -> void:
	if _syncing_crop_controls or not _crop_workflow_active or not _canvas:
		return
	var canvas_size: Vector2i = _canvas.get_canvas_size()
	var position := Vector2i(
		clampi(int(_crop_x.value), 0, canvas_size.x - 1),
		clampi(int(_crop_y.value), 0, canvas_size.y - 1)
	)
	var crop_size := Vector2i(
		clampi(int(_crop_width.value), 1, canvas_size.x - position.x),
		clampi(int(_crop_height.value), 1, canvas_size.y - position.y)
	)
	_syncing_crop_controls = true
	_crop_width.max_value = canvas_size.x - position.x
	_crop_height.max_value = canvas_size.y - position.y
	_crop_x.set_value_no_signal(position.x)
	_crop_y.set_value_no_signal(position.y)
	_crop_width.set_value_no_signal(crop_size.x)
	_crop_height.set_value_no_signal(crop_size.y)
	_syncing_crop_controls = false
	_canvas.update_crop_preview(Rect2i(position, crop_size))


func _apply_crop_rectangle() -> void:
	if not _crop_workflow_active or not _canvas:
		return
	if _reject_locked_crop():
		_cancel_crop_rectangle(false)
		return
	var changed: bool = _canvas.apply_crop_preview()
	_crop_workflow_active = false
	if changed:
		var size: Vector2i = _canvas.get_canvas_size()
		_set_status("Cropped canvas to %sx%s." % [size.x, size.y])
	else:
		_set_status("Crop rectangle matches the full canvas; nothing changed.")
	_update_selection_action_buttons()


func _cancel_crop_rectangle(show_status := true) -> void:
	if not _crop_workflow_active:
		return
	_crop_workflow_active = false
	if _canvas:
		_canvas.cancel_crop_preview()
	if _crop_rectangle_dialog and _crop_rectangle_dialog.visible:
		_crop_rectangle_dialog.hide()
	if show_status:
		_set_status("Crop canceled.")


func _new_canvas() -> void:
	if not _canvas:
		return
	if _texture_3d_session and _texture_3d_session.has_active_session():
		_set_status("New canvas is unavailable while a 3D texture session is active.")
		return
	var default_size := _get_default_canvas_size()
	_push_undo(_canvas.resize_canvas(default_size, false))
	_canvas_has_visible_pixels = false
	_history.clear_redo()
	_update_history_buttons()
	_update_selection_action_buttons()
	_reset_view()
	_set_2d_document_baseline("", _canvas.get_image_copy())
	_set_status("Created a new %sx%s canvas." % [default_size.x, default_size.y])


func _clear_canvas() -> void:
	_push_undo(_canvas.clear_canvas())
	_canvas_has_visible_pixels = false
	_history.clear_redo()
	_update_history_buttons()
	_update_selection_action_buttons()
	_set_status("Canvas cleared.")


func _resize_canvas() -> void:
	if _reject_locked_canvas_resize():
		return
	var new_size := Vector2i(int(_canvas_width.value), int(_canvas_height.value))
	if new_size == _canvas.get_canvas_size():
		_set_status("Canvas is already %sx%s." % [new_size.x, new_size.y])
		return
	_push_undo(_canvas.resize_canvas(new_size, _keep_pixels.button_pressed))
	_refresh_canvas_visible_pixels_state()
	_history.clear_redo()
	_update_history_buttons()
	_update_selection_action_buttons()
	_set_status("Canvas resized to %sx%s." % [new_size.x, new_size.y])


func _undo() -> void:
	if not _history.can_undo():
		return
	_history.push_redo(_canvas.get_image_copy())
	_canvas.set_image(_history.pop_undo())
	_refresh_canvas_visible_pixels_state()
	_update_history_buttons()
	_update_selection_action_buttons()
	_set_status("Undid last change.")


func _redo() -> void:
	if not _history.can_redo():
		return
	_history.push_undo(_canvas.get_image_copy())
	_canvas.set_image(_history.pop_redo())
	_refresh_canvas_visible_pixels_state()
	_update_history_buttons()
	_update_selection_action_buttons()
	_set_status("Redid last change.")


func _save_png() -> void:
	if _canvas_mode_3d or (_texture_3d_session and _texture_3d_session.has_active_session()):
		_confirm_save_3d_texture()
		return
	if not _document_path.is_empty():
		_save_2d_document_to_path(_document_path)
		return
	_show_2d_save_as()


func _show_2d_save_as() -> void:
	if not _save_dialog:
		return
	var save_dir := _get_default_save_dir()
	_save_dialog.current_dir = save_dir
	_save_dialog.current_file = _document_path.get_file() if not _document_path.is_empty() else _make_default_png_name()
	_save_dialog.popup_centered_ratio(0.75)


func _save_as() -> void:
	if _texture_3d_session and _texture_3d_session.has_active_session():
		_show_3d_texture_save_as(false)
		return
	_show_2d_save_as()


func _show_3d_texture_save_as(for_pending_transition: bool) -> void:
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		_set_status("Start a 3D texture session before using texture Save As.")
		return
	if _texture_save_stage != TextureSaveStage.IDLE:
		_set_status("A 3D texture save is already in progress.")
		return
	if not _save_3d_as_dialog:
		return
	_texture_save_context = {
		"transition": _pending_session_transition if for_pending_transition else SessionTransition.NONE,
	}
	if for_pending_transition:
		# This signal is closing the confirmation dialog. Open the FileDialog
		# from a later ordinary process frame, never from call_deferred().
		_texture_save_stage = TextureSaveStage.OPEN_SAVE_AS_DIALOG
		return
	_texture_save_stage = TextureSaveStage.AWAITING_SAVE_AS_PATH
	_popup_3d_texture_save_as_dialog()


func _popup_3d_texture_save_as_dialog() -> void:
	if not _save_3d_as_dialog or not _texture_3d_session or not _texture_3d_session.has_active_session():
		_abort_3d_texture_save_workflow("The 3D texture session is no longer active.")
		return
	var current_path: String = _texture_3d_session.texture_path
	var source_resource_path := ""
	if _texture_3d_session.texture:
		source_resource_path = _texture_3d_session.texture.resource_path
	var save_dir := current_path.get_base_dir() if not current_path.is_empty() else ""
	if save_dir.is_empty() and source_resource_path.begins_with("res://"):
		save_dir = source_resource_path.get_base_dir()
	if save_dir.is_empty() and is_instance_valid(_texture_3d_session.source_node):
		var source_cursor: Node = _texture_3d_session.source_node
		while source_cursor:
			var source_scene_path: String = source_cursor.scene_file_path
			if source_scene_path.begins_with("res://"):
				save_dir = source_scene_path.get_base_dir()
				break
			source_cursor = source_cursor.get_parent()
	if save_dir.is_empty():
		save_dir = _get_default_save_dir()
	var base_name := current_path.get_file().get_basename() if not current_path.is_empty() else ""
	if base_name.is_empty() and source_resource_path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
		base_name = source_resource_path.get_file().get_basename()
	if base_name.is_empty():
		base_name = str(_texture_3d_session.source_node.name).to_snake_case() + "_albedo"
	_save_3d_as_dialog.current_dir = save_dir
	_save_3d_as_dialog.current_file = base_name + "_copy.png"
	_save_3d_as_dialog.popup_centered_ratio(0.75)


func _show_load_png_dialog() -> void:
	if _open_dialog:
		var save_dir := _get_default_save_dir()
		_open_dialog.current_dir = save_dir
		_open_dialog.popup_centered_ratio(0.75)


func _load_png(path: String) -> void:
	_load_image_file(path)


func _load_image_file(path: String) -> void:
	if _request_session_transition(SessionTransition.LOAD_IMAGE_PATH, path):
		return
	_load_image_file_now(path)


func _load_image_file_now(path: String) -> void:
	var image := Image.new()
	var load_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var error := image.load(load_path)
	if error != OK:
		_set_status("Could not load image. Error: " + str(error))
		return

	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_load_image_now(image, path, true)


func _load_image(image: Image, label: String) -> void:
	if _request_session_transition(SessionTransition.LOAD_IMAGE, "", image, label):
		return
	_load_image_now(image, label, true)


func _load_image_now(image: Image, label: String, end_3d_session := false) -> void:
	if not _canvas:
		return
	if end_3d_session:
		_clear_3d_texture_session_state()
	_push_undo(_canvas.get_image_copy())
	_history.clear_redo()
	_canvas.set_image(image)
	_refresh_canvas_visible_pixels_state()
	_set_2d_document_baseline(_get_document_path_from_label(label), image)
	_update_history_buttons()
	_update_selection_action_buttons()
	_set_status("Loaded " + label)


func _on_canvas_image_drop_requested(data: Variant) -> void:
	var dropped_mesh: Node3D = _extract_drop_mesh_instance(data)
	if dropped_mesh:
		_open_3d_session_picker(dropped_mesh)
		return
	if _canvas_mode_3d and (not _texture_3d_session or not _texture_3d_session.has_active_session()):
		_set_status("Drop a MeshInstance3D, supported CSG shape, or a parent containing one onto GDDraw in 3D mode.")
		return
	var drop_image_path := _extract_drop_image_path(data)
	var drop_image: Image = null
	var drop_label := drop_image_path
	if drop_image_path.is_empty():
		drop_image = _extract_drop_image(data)
		drop_label = "dropped texture"
	if drop_image_path.is_empty() and drop_image == null:
		_set_status("Drop a texture or image file onto the canvas.")
		return
	if _texture_3d_session and _texture_3d_session.has_active_session():
		if not drop_image_path.is_empty():
			_load_image_file(drop_image_path)
		else:
			_load_image(drop_image, drop_label)
		return
	if _canvas and _canvas.has_visible_pixels():
		_set_pending_drop(drop_image_path, drop_image, drop_label)
		if _drop_replace_dialog:
			_drop_replace_dialog.popup_centered()
		return
	_load_pending_drop(drop_image_path, drop_image, drop_label)


func _on_3d_mesh_drop_requested(data: Variant) -> void:
	var dropped_mesh: Node3D = _extract_drop_mesh_instance(data)
	if dropped_mesh:
		_open_3d_session_picker(dropped_mesh)
		return
	_set_status("That drop did not resolve to an editable mesh or supported CSG shape in the edited scene.")


func _replace_canvas_with_pending_drop() -> void:
	if not _has_pending_drop():
		return
	_load_pending_drop(_pending_drop_image_path, _pending_drop_image, _pending_drop_label)
	_clear_pending_drop()


func _on_drop_replace_custom_action(action: StringName) -> void:
	if action != &"save_replace" or not _has_pending_drop():
		return
	_load_after_save_path = _pending_drop_image_path
	_load_after_save_image = _pending_drop_image.duplicate() if _pending_drop_image else null
	_load_after_save_label = _pending_drop_label
	_clear_pending_drop()
	if _drop_replace_dialog:
		_drop_replace_dialog.hide()
	_save_png()


func _set_pending_drop(path: String, image: Image, label: String) -> void:
	_pending_drop_image_path = path
	_pending_drop_image = image.duplicate() if image else null
	_pending_drop_label = label


func _clear_pending_drop() -> void:
	_pending_drop_image_path = ""
	_pending_drop_image = null
	_pending_drop_label = ""


func _has_pending_drop() -> bool:
	return not _pending_drop_image_path.is_empty() or _pending_drop_image != null


func _load_pending_drop(path: String, image: Image, label: String) -> void:
	if not path.is_empty():
		_load_image_file(path)
	elif image:
		_load_image(image, label)


func _extract_drop_image_path(data: Variant) -> String:
	if data is String:
		var path := _normalize_filesystem_path(data)
		return path if _is_supported_filesystem_image_path(path) else ""
	if data is Texture2D:
		return _get_resource_image_path(data)
	if data is Resource:
		return _get_resource_image_path(data)
	if data is PackedStringArray:
		for item in data:
			var packed_item_path := _extract_drop_image_path(item)
			if not packed_item_path.is_empty():
				return packed_item_path
	if data is Array:
		for item in data:
			var item_path := _extract_drop_image_path(item)
			if not item_path.is_empty():
				return item_path
	if data is Dictionary:
		for key in ["files", "paths"]:
			if data.has(key):
				var path_from_list := _extract_drop_image_path(data[key])
				if not path_from_list.is_empty():
					return path_from_list
		for key in ["path", "file", "resource_path"]:
			if data.has(key):
				var path_from_value := _extract_drop_image_path(data[key])
				if not path_from_value.is_empty():
					return path_from_value
		if data.has("resource"):
			var resource_path := _extract_drop_image_path(data["resource"])
			if not resource_path.is_empty():
				return resource_path
		if data.has("nodes"):
			return _extract_image_path_from_dragged_nodes(data["nodes"])
	return ""


func _extract_drop_image(data: Variant) -> Image:
	if data is Texture2D:
		return _get_texture_image(data)
	if data is Array:
		for item in data:
			var item_image := _extract_drop_image(item)
			if item_image:
				return item_image
	if data is Dictionary:
		if data.has("resource"):
			var resource_image := _extract_drop_image(data["resource"])
			if resource_image:
				return resource_image
		if data.has("nodes"):
			return _extract_image_from_dragged_nodes(data["nodes"])
	return null


func _extract_image_path_from_dragged_nodes(nodes_data: Variant) -> String:
	var nodes: Array = []
	if nodes_data is Array:
		nodes = nodes_data
	else:
		nodes = [nodes_data]
	for node_data in nodes:
		var node := _get_dragged_scene_node(node_data)
		if not node:
			continue
		if node is Sprite2D and node.texture:
			var texture_path := _get_resource_image_path(node.texture)
			if not texture_path.is_empty():
				return texture_path
		var texture_value: Variant = node.get("texture")
		if texture_value is Texture2D:
			var generic_texture_path := _get_resource_image_path(texture_value as Texture2D)
			if not generic_texture_path.is_empty():
				return generic_texture_path
	return ""


func _extract_image_from_dragged_nodes(nodes_data: Variant) -> Image:
	var nodes: Array = []
	if nodes_data is Array:
		nodes = nodes_data
	else:
		nodes = [nodes_data]
	for node_data in nodes:
		var node := _get_dragged_scene_node(node_data)
		if not node:
			continue
		if node is Sprite2D and node.texture:
			var sprite_image := _get_texture_image(node.texture)
			if sprite_image:
				return sprite_image
		var texture_value: Variant = node.get("texture")
		if texture_value is Texture2D:
			var generic_image := _get_texture_image(texture_value as Texture2D)
			if generic_image:
				return generic_image
	return null


func _load_selected_3d_mesh_texture() -> void:
	var surface_target := _get_selected_3d_surface_node()
	if surface_target:
		_open_3d_session_picker(surface_target)
	else:
		_set_status("Select a MeshInstance3D, supported CSG shape, or a parent containing one, then choose Use Selected 3D Surface.")


func _open_3d_session_picker(surface_target: Node3D) -> void:
	if not surface_target:
		_set_status("Select or drop an editable MeshInstance3D or supported CSG shape.")
		return
	var inspector = _make_script_instance(TEXTURE_3D_SESSION_SCRIPT_PATH, RefCounted.new())
	var discovery: Dictionary = inspector.discover_target(surface_target)
	if str(discovery.get(GDDraw3DTextureSessionResource.STATUS, "")) != GDDraw3DTextureSessionResource.STATUS_OK:
		_set_status(str(discovery.get(GDDraw3DTextureSessionResource.MESSAGE, "Could not inspect 3D surface materials.")))
		return
	_session_picker_mesh = surface_target
	_session_picker_choices.assign(discovery.get(GDDraw3DTextureSessionResource.CHOICES, []))
	if not _session_picker_dialog or not _session_picker_options:
		return
	_session_picker_target_label.text = "Target surface: %s (%s)" % [surface_target.name, surface_target.get_class()]
	_session_picker_options.clear()
	for index in range(_session_picker_choices.size()):
		var choice := _session_picker_choices[index]
		_session_picker_options.add_item(str(choice.get("label", "Material choice")))
		if not bool(choice.get("supported", false)):
			_session_picker_options.set_item_disabled(index, true)
	var first_supported := -1
	for index in range(_session_picker_choices.size()):
		if bool(_session_picker_choices[index].get("supported", false)):
			first_supported = index
			break
	if first_supported >= 0:
		_session_picker_options.select(first_supported)
	else:
		if not _session_picker_choices.is_empty():
			_session_picker_options.select(0)
	_on_3d_session_picker_choice_selected(first_supported if first_supported >= 0 else 0)
	_session_picker_dialog.size = Vector2i(600, 340)
	_session_picker_dialog.popup_centered(Vector2i(600, 340))


func _on_3d_session_picker_choice_selected(index: int) -> void:
	if index < 0 or index >= _session_picker_choices.size():
		return
	var choice := _session_picker_choices[index]
	var supported := bool(choice.get("supported", false))
	_session_picker_reason_label.text = str(choice.get("reason", ""))
	if _session_picker_dialog:
		_session_picker_dialog.get_ok_button().disabled = not supported


func _confirm_3d_session_picker() -> void:
	if not _session_picker_mesh or not _session_picker_options:
		return
	var selected_items := _session_picker_options.get_selected_items()
	if selected_items.is_empty():
		return
	var index: int = selected_items[0]
	if index < 0 or index >= _session_picker_choices.size():
		return
	var choice := _session_picker_choices[index]
	if not bool(choice.get("supported", false)):
		return
	var surface_target := _session_picker_mesh
	var slot := int(choice.get("slot", 0))
	var missing_texture := bool(choice.get("missing_texture", false))
	if _request_2d_to_3d_transition(surface_target, slot):
		return
	_begin_3d_texture_session(surface_target, false, false, slot)
	if missing_texture:
		_set_status("Confirm texture creation to start editing this material slot.")


func _clear_3d_session_picker() -> void:
	_session_picker_mesh = null
	_session_picker_choices.clear()


func _request_2d_to_3d_transition(surface_target: Node3D, material_slot: int) -> bool:
	if (
		not surface_target
		or (_texture_3d_session and _texture_3d_session.has_active_session())
		or not _is_2d_document_dirty()
	):
		return false
	_pending_session_transition = SessionTransition.START_3D_SESSION
	_pending_session_mesh = surface_target
	_pending_3d_material_slot = material_slot
	_update_document_session_preview()
	if _document_session_dialog:
		_document_session_dialog.call_deferred("popup_centered")
	return true


func _update_document_session_preview() -> void:
	if not _document_session_preview or not _canvas:
		return
	var image: Image = _canvas.get_image_copy()
	if not image or image.is_empty():
		_document_session_preview.texture = null
		if _document_session_preview_label:
			_document_session_preview_label.text = ""
		return
	_document_session_preview.texture = ImageTexture.create_from_image(image)
	if _document_session_preview_label:
		_document_session_preview_label.text = "%d × %d px · Unsaved 2D image" % [image.get_width(), image.get_height()]


func _save_2d_before_3d_session() -> void:
	if _pending_session_transition != SessionTransition.START_3D_SESSION:
		return
	if _document_path.is_empty():
		_save_2d_for_3d_transition = true
		if _document_session_dialog:
			_document_session_dialog.hide()
		call_deferred("_show_2d_save_as")
		return
	if _save_2d_document_to_path(_document_path):
		_continue_pending_session_transition()
	elif _document_session_dialog:
		_document_session_dialog.call_deferred("popup_centered")


func _on_document_session_custom_action(action: StringName) -> void:
	if action != &"continue_without_saving":
		return
	if _document_session_dialog:
		_document_session_dialog.hide()
	_continue_pending_session_transition()


func _cancel_2d_to_3d_transition() -> void:
	if _pending_session_transition != SessionTransition.START_3D_SESSION:
		return
	_save_2d_for_3d_transition = false
	_clear_pending_session_transition()
	if _session_picker_dialog and _session_picker_mesh:
		_session_picker_dialog.call_deferred("popup_centered", Vector2i(600, 340))
	_set_status("Kept the unsaved 2D workspace unchanged.")


func _request_session_transition(
	transition: int,
	path := "",
	image: Image = null,
	label := "",
	mesh: Node3D = null
) -> bool:
	if (
		not _texture_3d_session
		or not _texture_3d_session.has_active_session()
		or not _canvas
		or not _texture_3d_session.is_dirty(_canvas.get_image_copy())
	):
		return false
	_pending_session_transition = transition
	_pending_session_path = path
	_pending_session_image = image.duplicate() if image else null
	_pending_session_label = label
	_pending_session_mesh = mesh
	if _session_replace_dialog:
		_session_replace_dialog.dialog_text = "Save %s before replacing this 3D texture session?" % _texture_3d_session.get_identity_text()
		_session_replace_dialog.popup_centered()
	return true


func _save_pending_session_transition() -> void:
	if _pending_session_transition == SessionTransition.NONE:
		return
	_save_active_3d_texture_now(_pending_session_transition)


func _on_session_replace_custom_action(action: StringName) -> void:
	match action:
		&"save_as":
			_show_3d_texture_save_as(true)
			if _session_replace_dialog:
				_session_replace_dialog.hide()
		&"discard":
			_continue_pending_session_transition()
			if _session_replace_dialog:
				_session_replace_dialog.hide()


func _cancel_pending_session_transition() -> void:
	if _pending_session_transition == SessionTransition.NONE:
		return
	# Hiding the confirmation dialog after choosing Save As can emit a late
	# canceled signal while the PNG is being imported. Once any save stage is
	# active, the workflow context owns the durable transition intent.
	if _texture_save_stage != TextureSaveStage.IDLE:
		return
	_clear_pending_session_transition()
	_set_status("Kept the active 3D texture session unchanged.")


func _continue_pending_session_transition() -> void:
	var transition := _pending_session_transition
	var path := _pending_session_path
	var image := _pending_session_image
	var label := _pending_session_label
	var mesh := _pending_session_mesh
	_clear_pending_session_transition()
	match transition:
		SessionTransition.LOAD_IMAGE_PATH:
			_load_image_file_now(path)
		SessionTransition.LOAD_IMAGE:
			_load_image_now(image, label, true)
		SessionTransition.LOAD_MESH:
			_begin_3d_texture_session(mesh, false, true, _pending_3d_material_slot)
		SessionTransition.STOP_SESSION:
			_finalize_3d_session_exit()
		SessionTransition.START_3D_SESSION:
			_begin_3d_texture_session(mesh, false, true, _pending_3d_material_slot)


func _clear_pending_session_transition() -> void:
	_pending_session_transition = SessionTransition.NONE
	_pending_session_path = ""
	_pending_session_image = null
	_pending_session_label = ""
	_pending_session_mesh = null


func _clear_3d_texture_session_state(restore_workspace := true) -> void:
	_cancel_3d_surface_shape("", false, false)
	if _texture_3d_session:
		_texture_3d_session.clear()
	_paint_3d_source_available = false
	if _canvas:
		_canvas.clear_uv_overlay_data()
		_canvas.clear_eraser_restore_image()
	_clear_3d_paint_mesh()
	_update_canvas_resize_control_availability()
	_update_3d_context_control_visibility()
	_update_3d_session_status()
	_sync_menu_state()
	if restore_workspace:
		_restore_2d_workspace()


func _begin_3d_texture_session(surface_target: Node3D, create_if_missing := false, skip_guard := false, material_slot := 0) -> void:
	if not surface_target:
		_set_status("Select or drop an editable MeshInstance3D or supported CSG shape.")
		return
	_pending_3d_material_slot = material_slot
	if not create_if_missing and not skip_guard and _request_session_transition(SessionTransition.LOAD_MESH, "", null, "", surface_target):
		return
	var candidate = _pending_3d_session_candidate
	if not candidate or candidate.source_node != surface_target:
		candidate = _make_script_instance(TEXTURE_3D_SESSION_SCRIPT_PATH, RefCounted.new())
	var result: Dictionary = candidate.begin_from_target(surface_target, _plugin, create_if_missing, _get_default_save_dir(), GDDraw3DTextureSessionResource.DEFAULT_TEXTURE_SIZE, material_slot)
	_update_canvas_resize_control_availability()
	var status := str(result.get(GDDraw3DTextureSessionResource.STATUS, GDDraw3DTextureSessionResource.STATUS_ERROR))
	if status == GDDraw3DTextureSessionResource.STATUS_NEEDS_CREATE:
		_pending_3d_mesh = surface_target
		_pending_3d_session_candidate = candidate
		_canvas.set_uv_overlay_data(
			result.get(GDDraw3DTextureSessionResource.UV_EDGES, []),
			result.get(GDDraw3DTextureSessionResource.UV_VERTICES, PackedVector2Array())
		)
		if _create_3d_texture_dialog:
			_create_3d_texture_dialog.dialog_text = (
				"Create and assign a StandardMaterial3D plus a new PNG albedo texture for %s?"
				if bool(result.get("missing_material", false))
				else "Create and assign a new PNG albedo texture for %s?"
			) % surface_target.name
			_create_3d_texture_dialog.popup_centered()
		_update_3d_context_control_visibility()
		_set_status(str(result.get(GDDraw3DTextureSessionResource.MESSAGE, "")))
		return
	if status != GDDraw3DTextureSessionResource.STATUS_OK:
		_pending_3d_mesh = null
		_pending_3d_session_candidate = null
		if _canvas and (not _texture_3d_session or not _texture_3d_session.has_active_session()):
			_canvas.clear_uv_overlay_data()
		_update_3d_context_control_visibility()
		_set_status(str(result.get(GDDraw3DTextureSessionResource.MESSAGE, "Could not start 3D texture session.")))
		return

	var image: Image = result.get(GDDraw3DTextureSessionResource.IMAGE, null)
	if not image:
		_set_status("Could not load mesh texture image.")
		return
	if _saved_2d_workspace.is_empty():
		_capture_2d_workspace()
	_texture_3d_session = candidate
	_paint_3d_source_available = _is_active_3d_source_available()
	_pending_3d_session_candidate = null
	_clear_3d_session_picker()
	_update_canvas_resize_control_availability()
	_canvas.set_image(image)
	_refresh_canvas_visible_pixels_state()
	_history.clear()
	_update_history_buttons()
	_update_selection_action_buttons()
	if _canvas:
		_update_canvas_eraser_restore_image()
		_canvas.set_uv_overlay_data(
			result.get(GDDraw3DTextureSessionResource.UV_EDGES, []),
			result.get(GDDraw3DTextureSessionResource.UV_VERTICES, PackedVector2Array())
		)
		_canvas.uv_overlay_visible = _canvas_mode_3d and _uv_overlay_toggle and _uv_overlay_toggle.button_pressed
	_sync_3d_paint_view()
	_update_3d_context_control_visibility()
	_pending_3d_mesh = null
	_update_3d_session_status()
	_sync_menu_state()
	_set_status(str(result.get(GDDraw3DTextureSessionResource.MESSAGE, "3D texture loaded.")))


func _create_missing_3d_texture() -> void:
	if _pending_3d_mesh:
		_begin_3d_texture_session(_pending_3d_mesh, true, false, _pending_3d_material_slot)
	_pending_3d_mesh = null


func _cancel_missing_3d_texture() -> void:
	_pending_3d_mesh = null
	_pending_3d_session_candidate = null
	if _canvas and (not _texture_3d_session or not _texture_3d_session.has_active_session()):
		_canvas.clear_uv_overlay_data()
	if _session_picker_dialog and _session_picker_mesh:
		_session_picker_dialog.call_deferred("popup_centered", Vector2i(600, 340))
	_update_3d_context_control_visibility()
	_set_status("Texture creation canceled; no material or texture was changed.")


func _stop_3d_texture_session() -> void:
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		return
	if _texture_save_stage != TextureSaveStage.IDLE:
		_set_status("A 3D texture save is already in progress.")
		return
	if _request_session_transition(SessionTransition.STOP_SESSION):
		if _session_replace_dialog:
			_session_replace_dialog.dialog_text = "Save %s before stopping this 3D texture session?" % _texture_3d_session.get_identity_text()
		return
	_finalize_3d_session_exit()


func _finalize_3d_session_exit() -> void:
	_clear_pending_session_transition()
	_reset_3d_texture_save_workflow()
	_clear_3d_texture_session_state(false)
	_reset_2d_workspace_after_3d_session()
	# Keep the user's selected view layout. In 3D/Split mode the cleared
	# session naturally presents the standard "No 3D texture session" state.
	_update_3d_context_control_visibility()
	_set_status("Stopped 3D texture editing and cleared the temporary 2D workspace.")


func _capture_2d_workspace() -> void:
	if _canvas and _canvas.has_method("capture_workspace_state"):
		_saved_2d_workspace = _canvas.capture_workspace_state()
	if _history and _history.has_method("capture_state"):
		_saved_2d_history = _history.capture_state()


func _restore_2d_workspace() -> void:
	if not _canvas:
		return
	if not _saved_2d_workspace.is_empty() and _canvas.has_method("restore_workspace_state"):
		_canvas.restore_workspace_state(_saved_2d_workspace)
	else:
		var default_image := Image.create_empty(_get_default_canvas_size().x, _get_default_canvas_size().y, false, Image.FORMAT_RGBA8)
		default_image.fill(Color.TRANSPARENT)
		_canvas.set_image(default_image)
	_refresh_canvas_visible_pixels_state()
	if _history:
		if not _saved_2d_history.is_empty() and _history.has_method("restore_state"):
			_history.restore_state(_saved_2d_history)
		else:
			_history.clear()
	_saved_2d_workspace.clear()
	_saved_2d_history.clear()
	_update_history_buttons()
	_update_selection_action_buttons()
	_on_canvas_size_changed(_canvas.get_canvas_size())
	_on_view_changed(_canvas.get_zoom_percent())


func _reset_2d_workspace_after_3d_session() -> void:
	if not _canvas:
		return
	var canvas_size := _get_default_canvas_size()
	var blank_image := Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	blank_image.fill(Color.TRANSPARENT)
	_canvas.set_image(blank_image)
	_refresh_canvas_visible_pixels_state()
	_saved_2d_workspace.clear()
	_saved_2d_history.clear()
	if _history:
		_history.clear()
	_set_2d_document_baseline("", blank_image)
	_update_history_buttons()
	_update_selection_action_buttons()
	_on_canvas_size_changed(canvas_size)
	_on_view_changed(_canvas.get_zoom_percent())
	_sync_menu_state()


func _save_3d_texture() -> void:
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		_set_status("Load an editable 3D surface texture before saving in 3D mode.")
		return
	if _texture_save_stage != TextureSaveStage.IDLE:
		_set_status("A 3D texture save is already in progress.")
		return
	if _save_3d_texture_dialog:
		var texture_path: String = _texture_3d_session.texture_path
		_save_3d_texture_dialog.dialog_text = "Save the current canvas back to %s?" % texture_path
		_save_3d_texture_dialog.popup_centered()


func _confirm_save_3d_texture() -> void:
	_save_3d_texture()


func _save_3d_texture_confirmed() -> void:
	_save_active_3d_texture_now()


func _save_active_3d_texture_now(transition := SessionTransition.NONE) -> bool:
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		_set_status("Load an editable 3D surface texture before saving in 3D mode.")
		return false
	if _texture_save_stage != TextureSaveStage.IDLE:
		_set_status("A 3D texture save is already in progress.")
		return false
	var result: Dictionary = _texture_3d_session.save_image(_canvas.get_image_copy(), null)
	_set_status(str(result.get(GDDraw3DTextureSessionResource.MESSAGE, "")))
	var succeeded := str(result.get(GDDraw3DTextureSessionResource.STATUS, GDDraw3DTextureSessionResource.STATUS_ERROR)) == GDDraw3DTextureSessionResource.STATUS_OK
	if succeeded:
		_update_3d_session_status()
		_texture_save_context = {
			"path": _texture_3d_session.texture_path,
			"transition": transition,
			"wait_frames": 1,
		}
		_texture_save_stage = TextureSaveStage.NORMAL_WRITTEN
	return succeeded


func _save_3d_texture_as_to_path(path: String) -> void:
	_ensure_helpers()
	if not _texture_save_stage in [
		TextureSaveStage.OPEN_SAVE_AS_DIALOG,
		TextureSaveStage.AWAITING_SAVE_AS_PATH,
	]:
		return
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		_abort_3d_texture_save_workflow("The 3D texture session is no longer active.")
		return
	var normalized_path := _normalize_png_path(path)
	if normalized_path.is_empty():
		_abort_3d_texture_save_workflow("Choose a PNG path inside res://.")
		return
	var transition: int = int(_texture_save_context.get("transition", SessionTransition.NONE))
	var result: Dictionary = _texture_3d_session.write_image_as(_canvas.get_image_copy(), normalized_path)
	_set_status(str(result.get(GDDraw3DTextureSessionResource.MESSAGE, "")))
	var succeeded := str(result.get(GDDraw3DTextureSessionResource.STATUS, GDDraw3DTextureSessionResource.STATUS_ERROR)) == GDDraw3DTextureSessionResource.STATUS_OK
	if not succeeded:
		_abort_3d_texture_save_workflow(str(result.get(GDDraw3DTextureSessionResource.MESSAGE, "Could not write PNG.")))
		return
	_texture_save_context = {
		"path": normalized_path,
		"image": result.get(GDDraw3DTextureSessionResource.IMAGE),
		"transition": transition,
		"wait_frames": 1,
		"import_attempts": 0,
	}
	_texture_save_stage = TextureSaveStage.SAVE_AS_WRITTEN
	_set_status("Saved PNG; waiting for Godot to import and assign it.")


func _advance_3d_texture_save_workflow() -> void:
	match _texture_save_stage:
		TextureSaveStage.IDLE, TextureSaveStage.AWAITING_SAVE_AS_PATH:
			return
		TextureSaveStage.OPEN_SAVE_AS_DIALOG:
			_texture_save_stage = TextureSaveStage.AWAITING_SAVE_AS_PATH
			_popup_3d_texture_save_as_dialog()
		TextureSaveStage.NORMAL_WRITTEN:
			if _consume_texture_save_wait_frame():
				return
			_scan_saved_3d_texture_path()
			var normal_transition: int = int(_texture_save_context.get("transition", SessionTransition.NONE))
			_reset_3d_texture_save_workflow()
			_complete_saved_3d_transition(normal_transition)
		TextureSaveStage.SAVE_AS_WRITTEN:
			if _consume_texture_save_wait_frame():
				return
			_scan_saved_3d_texture_path()
			_texture_save_context["wait_frames"] = 1
			_texture_save_stage = TextureSaveStage.WAITING_IMPORTED_TEXTURE
		TextureSaveStage.WAITING_IMPORTED_TEXTURE:
			if _consume_texture_save_wait_frame():
				return
			_try_assign_imported_3d_texture()


func _consume_texture_save_wait_frame() -> bool:
	var frames := int(_texture_save_context.get("wait_frames", 0))
	if frames <= 0:
		return false
	_texture_save_context["wait_frames"] = frames - 1
	return true


func _scan_saved_3d_texture_path() -> void:
	if not _plugin:
		return
	var path := str(_texture_save_context.get("path", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	# This runs from _process(), after the FileDialog signal and message queue
	# have completed. EditorFileSystem may safely create its progress task here.
	_plugin.get_editor_interface().get_resource_filesystem().scan()


func _try_assign_imported_3d_texture() -> void:
	var path := str(_texture_save_context.get("path", ""))
	var image: Image = _texture_save_context.get("image")
	var imported_texture: Texture2D
	if _plugin:
		var filesystem := _plugin.get_editor_interface().get_resource_filesystem()
		if filesystem.is_scanning() or filesystem.is_importing():
			return
		# ResourceLoader.exists() may become true while the import artifact is
		# still incomplete. The editor's indexed resource type is the safe
		# readiness gate and avoids failed-load red X entries.
		if filesystem.get_file_type(path).is_empty():
			var pending_attempts := int(_texture_save_context.get("import_attempts", 0)) + 1
			_texture_save_context["import_attempts"] = pending_attempts
			if pending_attempts >= 180:
				_abort_3d_texture_save_workflow(
					"Saved %s, but Godot did not finish importing it; the active session and original material remain unchanged." % path
				)
			return
	if ResourceLoader.exists(path, "Texture2D"):
		var loaded := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE)
		if loaded is Texture2D:
			imported_texture = loaded
	if imported_texture:
		var transition: int = int(_texture_save_context.get("transition", SessionTransition.NONE))
		var result: Dictionary = _texture_3d_session.assign_saved_image_as(image, path, imported_texture, _plugin)
		if str(result.get(GDDraw3DTextureSessionResource.STATUS, GDDraw3DTextureSessionResource.STATUS_ERROR)) != GDDraw3DTextureSessionResource.STATUS_OK:
			_abort_3d_texture_save_workflow(str(result.get(
				GDDraw3DTextureSessionResource.MESSAGE,
				"Saved the PNG, but could not assign it to the active material."
			)))
			return
		_set_default_save_dir(path.get_base_dir())
		_reset_3d_texture_save_workflow()
		_complete_saved_3d_transition(transition)
		return
	var attempts := int(_texture_save_context.get("import_attempts", 0)) + 1
	_texture_save_context["import_attempts"] = attempts
	if attempts >= 180:
		_abort_3d_texture_save_workflow(
			"Saved %s, but Godot did not finish importing it; the active session and original material remain unchanged." % path
		)


func _complete_saved_3d_transition(transition: int) -> void:
	if transition == SessionTransition.NONE:
		_update_3d_session_status()
		_set_status("Saved the active 3D texture.")
		return
	# STOP_SESSION was captured when Save/Save As began. It must not depend on
	# later dialog signals or the transient pending-transition fields.
	if transition == SessionTransition.STOP_SESSION:
		_finalize_3d_session_exit()
		return
	if _pending_session_transition != transition:
		_clear_pending_session_transition()
		_set_status("Saved the texture, but the pending session action was canceled.")
		return
	_continue_pending_session_transition()


func _abort_3d_texture_save_workflow(message: String) -> void:
	var transition := int(_texture_save_context.get("transition", SessionTransition.NONE))
	_reset_3d_texture_save_workflow()
	if transition != SessionTransition.NONE:
		_clear_pending_session_transition()
	_update_3d_session_status()
	_set_status(message)


func _reset_3d_texture_save_workflow() -> void:
	_texture_save_stage = TextureSaveStage.IDLE
	_texture_save_context.clear()


func _cancel_3d_texture_save_as() -> void:
	if not _texture_save_stage in [
		TextureSaveStage.OPEN_SAVE_AS_DIALOG,
		TextureSaveStage.AWAITING_SAVE_AS_PATH,
	]:
		return
	_abort_3d_texture_save_workflow("Save As canceled; the active 3D texture session is unchanged.")


func _update_canvas_eraser_restore_image() -> void:
	if not _canvas:
		return
	if _texture_3d_session and _texture_3d_session.has_active_session() and _texture_3d_session.base_image:
		_canvas.set_eraser_restore_image(_texture_3d_session.base_image)
	else:
		_canvas.clear_eraser_restore_image()


func _on_uv_overlay_toggled(enabled: bool) -> void:
	if _canvas:
		_canvas.uv_overlay_visible = _canvas_mode_3d and enabled
	_update_3d_wire_overlay_visibility()
	_sync_menu_state()


func _set_uv_overlay_enabled(enabled: bool) -> void:
	if not _uv_overlay_toggle:
		return
	_uv_overlay_toggle.set_pressed_no_signal(enabled)
	_update_toggle_button_icon(_uv_overlay_toggle)
	_on_uv_overlay_toggled(enabled)


func _sync_3d_paint_view() -> void:
	if not _paint_3d_view or not _canvas_mode_3d:
		return
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		_clear_3d_paint_mesh()
		return
	_set_3d_paint_mesh_from_target(_texture_3d_session.target, _canvas.get_image_copy())


func _poll_active_3d_target_geometry() -> void:
	if not _texture_3d_session or not _texture_3d_session.target:
		return
	var source: Node3D
	if is_instance_valid(_texture_3d_session.target.source_node):
		source = _texture_3d_session.target.source_node
	if not is_instance_valid(source) or not source.is_inside_tree():
		var became_unavailable := _paint_3d_source_available
		_paint_3d_source_available = false
		_texture_3d_session.set_scene_transform_linked(false)
		_apply_scene_transform_link_control_state(false)
		_update_3d_context_control_visibility()
		_update_3d_session_status()
		if became_unavailable:
			_set_status("The source scene is inactive or closed. The private 3D preview remains editable; Scene Transform Link is unavailable.")
		return
	var became_available := not _paint_3d_source_available
	_paint_3d_source_available = true
	_apply_scene_transform_link_control_state(_texture_3d_session.is_scene_transform_linked())
	if became_available:
		_paint_3d_geometry_dirty = true
		_set_status("The source scene is active again; Scene Transform Link is available.")
	if source is MeshInstance3D and (source as MeshInstance3D).mesh != _texture_3d_session.mesh_snapshot:
		_paint_3d_geometry_dirty = true
	# CSG does not expose a stable Mesh resource whose changed signal can
	# invalidate the cache, so retain the existing periodic snapshot check.
	if source is CSGShape3D:
		_paint_3d_geometry_dirty = true
	if _paint_3d_geometry_dirty:
		_paint_3d_geometry_dirty = false
		_refresh_active_3d_target_geometry()


func _poll_active_3d_target_transform() -> void:
	if (
		not _texture_3d_session
		or not _texture_3d_session.target
		or not _texture_3d_session.is_scene_transform_linked()
	):
		return
	var source: Node3D
	if is_instance_valid(_texture_3d_session.target.source_node):
		source = _texture_3d_session.target.source_node
	if not is_instance_valid(source) or not source.is_inside_tree():
		_paint_3d_source_available = false
		_texture_3d_session.set_scene_transform_linked(false)
		_apply_scene_transform_link_control_state(false)
		_update_3d_context_control_visibility()
		_update_3d_session_status()
		_set_status("The source scene is inactive or closed. The private 3D preview remains editable; Scene Transform Link is unavailable.")
		return
	_paint_3d_source_available = true
	var current_scene_transform := source.global_transform
	_texture_3d_session.target.source_transform = current_scene_transform
	if _texture_3d_session.update_live_source_transform(current_scene_transform):
		_apply_3d_preview_transform(false)


func _observe_3d_paint_mesh(mesh: Mesh) -> void:
	if _paint_3d_observed_mesh and _paint_3d_observed_mesh.changed.is_connected(_on_3d_paint_mesh_changed):
		_paint_3d_observed_mesh.changed.disconnect(_on_3d_paint_mesh_changed)
	_paint_3d_observed_mesh = mesh
	if _paint_3d_observed_mesh and not _paint_3d_observed_mesh.changed.is_connected(_on_3d_paint_mesh_changed):
		_paint_3d_observed_mesh.changed.connect(_on_3d_paint_mesh_changed)


func _on_3d_paint_mesh_changed() -> void:
	_paint_3d_geometry_dirty = true


func _refresh_active_3d_target_geometry() -> void:
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		return
	if not _texture_3d_session.has_method("refresh_geometry"):
		return
	var result: Dictionary = _texture_3d_session.refresh_geometry()
	var status := str(result.get(GDDraw3DTextureSessionResource.STATUS, GDDraw3DTextureSessionResource.STATUS_ERROR))
	if status != GDDraw3DTextureSessionResource.STATUS_OK:
		_clear_3d_paint_mesh()
		_set_status(str(result.get(
			GDDraw3DTextureSessionResource.MESSAGE,
			"The source geometry changed to an unsupported state. Painting is paused; the texture session remains available for saving or exit."
		)))
		return
	if not bool(result.get("changed", false)):
		return
	if _canvas:
		_canvas.set_uv_overlay_data(_texture_3d_session.uv_edges, _texture_3d_session.uv_vertices)
	_sync_3d_paint_view()
	_set_status("Refreshed the 3D preview after source geometry changed.")


func _sync_3d_paint_texture() -> void:
	if not _paint_3d_view or not _canvas_mode_3d:
		return
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		return
	if _canvas.is_surface_shape_previewing():
		_set_3d_paint_texture_image(_canvas.get_surface_shape_preview_image())
	else:
		_set_3d_paint_texture_image(_canvas.get_image_copy())


func _clear_3d_paint_mesh() -> void:
	_cancel_3d_surface_shape("", false, false)
	_cancel_3d_rotation_gizmo_drag(false)
	_set_3d_rotation_gizmo_hover_axis(-1)
	_observe_3d_paint_mesh(null)
	_hide_3d_hover_debug_marker("3D mesh cleared")
	_hide_3d_brush_preview()
	# Hide preview content synchronously. queue_free() alone leaves it rendered
	# until the end of the frame, underneath the no-session overlay.
	for preview_node in [
		_paint_3d_hover_debug_marker,
		_paint_3d_hover_triangle,
		_paint_3d_brush_preview,
		_paint_3d_wire_mesh,
		_paint_3d_mesh,
	]:
		if preview_node and is_instance_valid(preview_node):
			preview_node.visible = false
			preview_node.queue_free()
	_paint_3d_hover_debug_marker = null
	_paint_3d_hover_triangle = null
	_paint_3d_brush_preview = null
	_paint_3d_wire_mesh = null
	_paint_3d_mesh = null
	_paint_3d_texture = null
	_paint_3d_material = null
	_paint_3d_mesh_cache = null
	_paint_3d_triangle_cache.clear()
	_paint_3d_island_cache.clear()
	_paint_3d_geometry_dirty = false
	_paint_3d_pending_motion = false
	_paint_3d_pending_2d_hover = false
	_update_3d_rotation_gizmo_visibility()


func _set_3d_paint_mesh_from_target(surface_target, texture_image: Image) -> void:
	if not _paint_3d_root or not surface_target or not surface_target.mesh_snapshot:
		return
	var source: Node3D
	if is_instance_valid(surface_target.source_node):
		source = surface_target.source_node
	var source_name: String = surface_target.get_source_name() if surface_target.has_method("get_source_name") else "3D Surface"
	var preview_mesh: Mesh = surface_target.mesh_snapshot
	_clear_3d_paint_mesh()
	_paint_3d_source_available = is_instance_valid(source) and source.is_inside_tree()
	_paint_3d_mesh = MeshInstance3D.new()
	_paint_3d_mesh.name = source_name + " Preview"
	_paint_3d_mesh.mesh = preview_mesh
	_paint_3d_mesh.transform = _get_3d_preview_transform(surface_target)
	_paint_3d_mesh.lod_bias = PAINT_3D_PREVIEW_LOD_BIAS
	var paint_material := _make_3d_paint_material(source, texture_image)
	for surface_slot in surface_target.preview_surface_slots:
		_paint_3d_mesh.set_surface_override_material(surface_slot, paint_material)
	_paint_3d_root.add_child(_paint_3d_mesh)
	_set_status("Indexing mesh geometry for responsive 3D painting…")
	Input.set_default_cursor_shape(Input.CURSOR_WAIT)
	_build_3d_mesh_paint_cache(preview_mesh, surface_target)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _paint_3d_mesh_cache and _paint_3d_mesh_cache.is_valid():
		var cache_stats: Dictionary = _paint_3d_mesh_cache.get_build_stats()
		_set_status("Indexed %s triangles in %.1f ms." % [
			str(int(cache_stats.get("triangle_count", 0))),
			float(cache_stats.get("build_time_usec", 0)) / 1000.0,
		])
	_observe_3d_paint_mesh(preview_mesh)
	_paint_3d_brush_preview = MeshInstance3D.new()
	_paint_3d_brush_preview.name = "3D Brush Preview"
	_paint_3d_brush_preview.visible = false
	_paint_3d_brush_preview.material_override = _make_3d_brush_preview_material()
	_paint_3d_root.add_child(_paint_3d_brush_preview)
	if SHOW_2D_TO_3D_HOVER_MARKER:
		_paint_3d_hover_debug_marker = MeshInstance3D.new()
		_paint_3d_hover_debug_marker.name = "2D to 3D Hover Point Marker"
		_paint_3d_hover_debug_marker.visible = false
		_paint_3d_hover_debug_marker.material_override = _make_3d_hover_debug_marker_material()
		_paint_3d_root.add_child(_paint_3d_hover_debug_marker)
	_paint_3d_hover_triangle = MeshInstance3D.new()
	_paint_3d_hover_triangle.name = "Linked Hover Island Outline"
	_paint_3d_hover_triangle.visible = false
	_paint_3d_hover_triangle.material_override = _make_3d_hover_triangle_material()
	_paint_3d_root.add_child(_paint_3d_hover_triangle)
	_paint_3d_wire_mesh = MeshInstance3D.new()
	_paint_3d_wire_mesh.name = source_name + " UV Overlay"
	_paint_3d_wire_mesh.mesh = _make_3d_wire_overlay_mesh(preview_mesh)
	_paint_3d_wire_mesh.transform = _paint_3d_mesh.transform
	_paint_3d_wire_mesh.material_override = _make_3d_wire_overlay_material()
	_paint_3d_root.add_child(_paint_3d_wire_mesh)
	_update_3d_wire_overlay_visibility()
	_establish_3d_preview_stage(preview_mesh)
	_frame_3d_paint_mesh(preview_mesh)
	_update_3d_rotation_gizmo_transform()
	_update_3d_rotation_gizmo_visibility()


func _get_3d_preview_transform(surface_target) -> Transform3D:
	if (
		_texture_3d_session
		and _texture_3d_session.target == surface_target
		and _texture_3d_session.has_method("get_preview_transform")
	):
		return _texture_3d_session.get_preview_transform()
	return surface_target.get_transform() if surface_target else Transform3D.IDENTITY


func _apply_3d_preview_transform(reframe: bool) -> void:
	if not _texture_3d_session or not _texture_3d_session.target or not _paint_3d_mesh:
		return
	var preview_transform: Transform3D = _texture_3d_session.get_preview_transform()
	_paint_3d_mesh.transform = preview_transform
	if _paint_3d_wire_mesh:
		_paint_3d_wire_mesh.transform = preview_transform
	if _paint_3d_hover_triangle:
		_paint_3d_hover_triangle.transform = preview_transform
	_update_3d_rotation_gizmo_transform()
	# Cursor-space helpers are reconstructed from mesh-local hit data on the
	# next hover. Hiding them prevents a stale world-space brush marker from
	# lingering during the orientation change.
	if _paint_3d_brush_preview:
		_paint_3d_brush_preview.visible = false
	_update_3d_paint_cursor(false)
	_hide_3d_hover_debug_marker("preview orientation changed")
	if reframe and _paint_3d_mesh.mesh:
		_frame_3d_paint_mesh(_paint_3d_mesh.mesh)


func _set_3d_paint_mesh_from_instance(source: MeshInstance3D, texture_image: Image) -> void:
	var target_script = load("res://addons/GDDraw/gddraw_3d_surface_target.gd")
	var surface_target = target_script.call("new") if target_script else null
	if surface_target and surface_target.inspect(source).get("status", "error") == "ok":
		surface_target.select_material(_texture_3d_session.material_slot if _texture_3d_session else 0)
		_set_3d_paint_mesh_from_target(surface_target, texture_image)


func _set_3d_paint_texture_image(texture_image: Image) -> void:
	if not texture_image or texture_image.is_empty():
		return
	var preview_image := _make_3d_preview_image(texture_image)
	if not preview_image:
		return
	if not _paint_3d_texture:
		_paint_3d_texture = ImageTexture.create_from_image(preview_image)
	elif _paint_3d_texture.get_width() != preview_image.get_width() or _paint_3d_texture.get_height() != preview_image.get_height():
		_paint_3d_texture = ImageTexture.create_from_image(preview_image)
	else:
		_paint_3d_texture.update(preview_image)
	if _paint_3d_material:
		_paint_3d_material.albedo_texture = _paint_3d_texture


func _make_3d_paint_material(source: Node3D, texture_image: Image) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var source_name := "3D Surface"
	if is_instance_valid(source):
		source_name = str(source.name)
	elif _texture_3d_session and _texture_3d_session.target and _texture_3d_session.target.has_method("get_source_name"):
		source_name = _texture_3d_session.target.get_source_name()
	material.resource_name = source_name + " GDDraw Paint Preview"
	material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_PER_PIXEL
		if _preview_light_enabled
		else BaseMaterial3D.SHADING_MODE_UNSHADED
	)
	material.albedo_color = Color.WHITE
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.texture_repeat = false
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.disable_receive_shadows = true
	material.disable_fog = true
	material.vertex_color_use_as_albedo = false
	var source_material: StandardMaterial3D
	if source is CSGShape3D and source.has_method("get_material"):
		source_material = source.call("get_material") as StandardMaterial3D
	elif source is MeshInstance3D:
		var source_mesh := source as MeshInstance3D
		var source_slot: int = int(_texture_3d_session.material_slot) if _texture_3d_session else 0
		source_material = source_mesh.get_active_material(source_slot) as StandardMaterial3D
	if not source_material and _texture_3d_session and _texture_3d_session.material is StandardMaterial3D:
		source_material = _texture_3d_session.material
	if source_material:
		# The preview replaces the scene material, but its UV transform remains
		# part of how the albedo is mapped and must survive that replacement.
		material.uv1_scale = source_material.uv1_scale
		material.uv1_offset = source_material.uv1_offset
		material.uv1_triplanar = source_material.uv1_triplanar
	if texture_image and not texture_image.is_empty():
		var preview_image := _make_3d_preview_image(texture_image)
		if preview_image:
			_paint_3d_texture = ImageTexture.create_from_image(preview_image)
			material.albedo_texture = _paint_3d_texture
	_paint_3d_material = material
	return material


func _make_3d_preview_image(source_image: Image) -> Image:
	if not source_image or source_image.is_empty():
		return null
	var image := source_image.duplicate()
	if image.is_compressed():
		var error: Error = image.decompress()
		if error != OK:
			return null
	if image.has_mipmaps():
		image.clear_mipmaps()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _make_3d_wire_overlay_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.92, 0.96, 1.0, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	return material


func _make_3d_brush_preview_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
	material.emission_enabled = true
	material.emission = Color(1.0, 1.0, 1.0, 1.0)
	material.emission_energy_multiplier = 0.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material


func _make_3d_hover_debug_marker_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "GDDraw 2D to 3D Hover Point Marker"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = HOVER_2D_TO_3D_MARKER_COLOR
	material.emission_enabled = true
	material.emission = HOVER_2D_TO_3D_MARKER_COLOR
	material.emission_energy_multiplier = 0.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Keep correspondence visible even when overlapping UVs choose an occluded surface.
	material.no_depth_test = true
	return material


func _make_3d_hover_triangle_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "GDDraw Linked Hover Island Outline"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.72, 0.18, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.55, 0.08, 1.0)
	material.emission_energy_multiplier = 1.4
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material


func _make_3d_hover_triangle_mesh(hit: Dictionary) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var boundary_edges := _get_3d_hover_outline_edges(hit)
	if boundary_edges.is_empty():
		return mesh
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for edge in boundary_edges:
		mesh.surface_add_vertex(edge[0])
		mesh.surface_add_vertex(edge[1])
	mesh.surface_end()
	return mesh


func _get_3d_hover_outline_edges(hit: Dictionary) -> Array:
	var island_hits := _get_3d_hover_island_hits(hit)
	if island_hits.is_empty():
		return []
	var edges := {}
	for island_hit in island_hits:
		var positions: PackedVector3Array = island_hit.get("triangle_positions", PackedVector3Array())
		if positions.size() < 3:
			continue
		var normal: Vector3 = island_hit.get("normal", Vector3.ZERO)
		_add_3d_hover_boundary_edge(edges, positions[0], positions[1], normal)
		_add_3d_hover_boundary_edge(edges, positions[1], positions[2], normal)
		_add_3d_hover_boundary_edge(edges, positions[2], positions[0], normal)
	var boundary_edges: Array = []
	for edge_value in edges.values():
		var edge: Array = edge_value
		if int(edge[2]) != 1:
			continue
		boundary_edges.push_back([edge[0], edge[1]])
	return boundary_edges


func _add_3d_hover_boundary_edge(edges: Dictionary, from_position: Vector3, to_position: Vector3, normal: Vector3) -> void:
	var from_key := _vertex_key(from_position)
	var to_key := _vertex_key(to_position)
	var edge_key := from_key + ">" + to_key if from_key < to_key else to_key + ">" + from_key
	if edges.has(edge_key):
		var edge: Array = edges[edge_key]
		edge[2] = int(edge[2]) + 1
		return
	var offset := normal.normalized() * 0.0005 if normal.length_squared() > 0.000001 else Vector3.ZERO
	edges[edge_key] = [from_position + offset, to_position + offset, 1]


func _make_3d_brush_preview_mesh(radius: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	radius = maxf(0.0001, radius)
	if _canvas and _canvas.brush_head == GDDrawCanvasControl.BrushHead.SQUARE:
		_add_3d_square_brush_preview(mesh, radius)
		return mesh
	_add_3d_circle_brush_preview(mesh, radius)
	return mesh


func _make_3d_hover_debug_marker_mesh(radius: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	radius = maxf(0.0001, radius)
	var inner_radius := radius * 0.72
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(PAINT_3D_BRUSH_PREVIEW_SEGMENTS):
		var angle_a := TAU * float(index) / float(PAINT_3D_BRUSH_PREVIEW_SEGMENTS)
		var angle_b := TAU * float(index + 1) / float(PAINT_3D_BRUSH_PREVIEW_SEGMENTS)
		var outer_a := Vector3(cos(angle_a) * radius, sin(angle_a) * radius, 0.0)
		var outer_b := Vector3(cos(angle_b) * radius, sin(angle_b) * radius, 0.0)
		var inner_a := Vector3(cos(angle_a) * inner_radius, sin(angle_a) * inner_radius, 0.0)
		var inner_b := Vector3(cos(angle_b) * inner_radius, sin(angle_b) * inner_radius, 0.0)
		mesh.surface_add_vertex(outer_a)
		mesh.surface_add_vertex(outer_b)
		mesh.surface_add_vertex(inner_b)
		mesh.surface_add_vertex(outer_a)
		mesh.surface_add_vertex(inner_b)
		mesh.surface_add_vertex(inner_a)
	mesh.surface_end()
	return mesh


func _add_3d_circle_brush_preview(mesh: ImmediateMesh, radius: float) -> void:
	var inner_radius := radius * 0.84
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(PAINT_3D_BRUSH_PREVIEW_SEGMENTS):
		var angle_a := TAU * float(index) / float(PAINT_3D_BRUSH_PREVIEW_SEGMENTS)
		var angle_b := TAU * float(index + 1) / float(PAINT_3D_BRUSH_PREVIEW_SEGMENTS)
		var outer_a := Vector3(cos(angle_a) * radius, sin(angle_a) * radius, 0.0)
		var outer_b := Vector3(cos(angle_b) * radius, sin(angle_b) * radius, 0.0)
		var inner_a := Vector3(cos(angle_a) * inner_radius, sin(angle_a) * inner_radius, 0.0)
		var inner_b := Vector3(cos(angle_b) * inner_radius, sin(angle_b) * inner_radius, 0.0)
		mesh.surface_add_vertex(outer_a)
		mesh.surface_add_vertex(outer_b)
		mesh.surface_add_vertex(inner_b)
		mesh.surface_add_vertex(outer_a)
		mesh.surface_add_vertex(inner_b)
		mesh.surface_add_vertex(inner_a)
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(Vector3(-radius, 0.0, 0.0))
	mesh.surface_add_vertex(Vector3(radius, 0.0, 0.0))
	mesh.surface_add_vertex(Vector3(0.0, -radius, 0.0))
	mesh.surface_add_vertex(Vector3(0.0, radius, 0.0))
	mesh.surface_end()


func _add_3d_square_brush_preview(mesh: ImmediateMesh, radius: float) -> void:
	var inner_radius := radius * 0.84
	var outer := [
		Vector3(-radius, -radius, 0.0),
		Vector3(radius, -radius, 0.0),
		Vector3(radius, radius, 0.0),
		Vector3(-radius, radius, 0.0),
	]
	var inner := [
		Vector3(-inner_radius, -inner_radius, 0.0),
		Vector3(inner_radius, -inner_radius, 0.0),
		Vector3(inner_radius, inner_radius, 0.0),
		Vector3(-inner_radius, inner_radius, 0.0),
	]
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(4):
		var next := (index + 1) % 4
		mesh.surface_add_vertex(outer[index])
		mesh.surface_add_vertex(outer[next])
		mesh.surface_add_vertex(inner[next])
		mesh.surface_add_vertex(outer[index])
		mesh.surface_add_vertex(inner[next])
		mesh.surface_add_vertex(inner[index])
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in range(4):
		var next := (index + 1) % 4
		mesh.surface_add_vertex(outer[index])
		mesh.surface_add_vertex(outer[next])
	mesh.surface_add_vertex(Vector3(-radius, 0.0, 0.0))
	mesh.surface_add_vertex(Vector3(radius, 0.0, 0.0))
	mesh.surface_add_vertex(Vector3(0.0, -radius, 0.0))
	mesh.surface_add_vertex(Vector3(0.0, radius, 0.0))
	mesh.surface_end()


func _make_3d_wire_overlay_mesh(mesh: Mesh) -> ImmediateMesh:
	var wire_mesh := ImmediateMesh.new()
	if not mesh:
		return wire_mesh
	var edge_keys := {}
	wire_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	if _paint_3d_mesh_cache and _paint_3d_mesh_cache.is_valid():
		for triangle_id in range(_paint_3d_mesh_cache.triangle_count):
			var triangle: Dictionary = _paint_3d_mesh_cache.get_triangle(triangle_id)
			_add_3d_wire_position_edge(wire_mesh, edge_keys, triangle["a"], triangle["b"])
			_add_3d_wire_position_edge(wire_mesh, edge_keys, triangle["b"], triangle["c"])
			_add_3d_wire_position_edge(wire_mesh, edge_keys, triangle["c"], triangle["a"])
		wire_mesh.surface_end()
		return wire_mesh
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX or not (arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array):
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue
		var indices := PackedInt32Array()
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX]
		if indices.size() >= 3:
			for index in range(0, indices.size() - 2, 3):
				_add_3d_wire_triangle(wire_mesh, edge_keys, vertices, indices[index], indices[index + 1], indices[index + 2])
		else:
			for index in range(0, vertices.size() - 2, 3):
				_add_3d_wire_triangle(wire_mesh, edge_keys, vertices, index, index + 1, index + 2)
	wire_mesh.surface_end()
	return wire_mesh


func _add_3d_wire_position_edge(wire_mesh: ImmediateMesh, edge_keys: Dictionary, from_vertex: Vector3, to_vertex: Vector3) -> void:
	var forward_key := _vertex_key(from_vertex) + ">" + _vertex_key(to_vertex)
	var reverse_key := _vertex_key(to_vertex) + ">" + _vertex_key(from_vertex)
	if edge_keys.has(forward_key) or edge_keys.has(reverse_key):
		return
	edge_keys[forward_key] = true
	wire_mesh.surface_add_vertex(from_vertex)
	wire_mesh.surface_add_vertex(to_vertex)


func _build_3d_mesh_paint_cache(mesh: Mesh, surface_target) -> void:
	_paint_3d_triangle_cache.clear()
	_paint_3d_island_cache.clear()
	_paint_3d_mesh_cache = null
	if not mesh:
		return
	var cache_script: Script = load(MESH_PAINT_CACHE_SCRIPT_PATH)
	if not cache_script:
		return
	_paint_3d_mesh_cache = cache_script.new()
	var slots := PackedInt32Array()
	if surface_target and surface_target.preview_surface_slots is PackedInt32Array:
		slots = surface_target.preview_surface_slots
	var signature := str(surface_target.geometry_signature) if surface_target else ""
	var stats: Dictionary = _paint_3d_mesh_cache.build(mesh, slots, signature)
	if DEBUG_MESH_PAINT_PERFORMANCE:
		print("GDDraw mesh-paint cache: ", stats)


func _add_3d_uv_edge_member(edge_members: Dictionary, surface_index: int, from_uv: Vector2, to_uv: Vector2, triangle_key: String) -> void:
	var from_key := _uv_cache_key(from_uv)
	var to_key := _uv_cache_key(to_uv)
	var edge_key := "%d:%s>%s" % [surface_index, mini(from_key, to_key), maxi(from_key, to_key)]
	if not edge_members.has(edge_key):
		edge_members[edge_key] = []
	(edge_members[edge_key] as Array).push_back(triangle_key)


func _uv_cache_key(uv: Vector2) -> int:
	var x := roundi(uv.x * 1000000.0)
	var y := roundi(uv.y * 1000000.0)
	return hash(Vector2i(x, y))


func _add_3d_island_neighbor(adjacency: Dictionary, from_key: String, to_key: String) -> void:
	if not adjacency.has(from_key):
		adjacency[from_key] = []
	(adjacency[from_key] as Array).push_back(to_key)


func _3d_triangle_key(surface_index: int, triangle_index: int) -> String:
	return "%d:%d" % [surface_index, triangle_index]


func _get_3d_hover_island_hits(hit: Dictionary) -> Array:
	if hit.is_empty():
		return []
	if _paint_3d_mesh_cache and _paint_3d_mesh_cache.is_valid():
		var cached_hits: Array = _paint_3d_mesh_cache.get_island_triangles(
			int(hit.get("surface_index", -1)),
			int(hit.get("triangle_index", -1))
		)
		if not cached_hits.is_empty():
			return cached_hits
	var key := _3d_triangle_key(int(hit.get("surface_index", -1)), int(hit.get("triangle_index", -1)))
	var keys: Array = _paint_3d_island_cache.get(key, [key])
	var hits: Array = []
	for triangle_key in keys:
		if _paint_3d_triangle_cache.has(triangle_key):
			hits.push_back(_paint_3d_triangle_cache[triangle_key])
	if hits.is_empty():
		hits.push_back(hit)
	return hits


func _add_3d_wire_triangle(wire_mesh: ImmediateMesh, edge_keys: Dictionary, vertices: PackedVector3Array, a: int, b: int, c: int) -> void:
	_add_3d_wire_edge(wire_mesh, edge_keys, vertices, a, b)
	_add_3d_wire_edge(wire_mesh, edge_keys, vertices, b, c)
	_add_3d_wire_edge(wire_mesh, edge_keys, vertices, c, a)


func _add_3d_wire_edge(wire_mesh: ImmediateMesh, edge_keys: Dictionary, vertices: PackedVector3Array, from_index: int, to_index: int) -> void:
	if from_index < 0 or to_index < 0 or from_index >= vertices.size() or to_index >= vertices.size():
		return
	var from_vertex := vertices[from_index]
	var to_vertex := vertices[to_index]
	var forward_key := _vertex_key(from_vertex) + ">" + _vertex_key(to_vertex)
	var reverse_key := _vertex_key(to_vertex) + ">" + _vertex_key(from_vertex)
	if edge_keys.has(forward_key) or edge_keys.has(reverse_key):
		return
	edge_keys[forward_key] = true
	wire_mesh.surface_add_vertex(from_vertex)
	wire_mesh.surface_add_vertex(to_vertex)


func _vertex_key(vertex: Vector3) -> String:
	return "%d,%d,%d" % [roundi(vertex.x * 100000.0), roundi(vertex.y * 100000.0), roundi(vertex.z * 100000.0)]


func _update_3d_wire_overlay_visibility() -> void:
	if _paint_3d_wire_mesh:
		_paint_3d_wire_mesh.visible = _canvas_mode_3d and _uv_overlay_toggle and _uv_overlay_toggle.button_pressed


func _frame_3d_paint_mesh(mesh: Mesh) -> void:
	if not _paint_3d_camera or not mesh:
		return
	var preview_transform := Transform3D.IDENTITY
	if _paint_3d_mesh and _paint_3d_mesh.mesh == mesh:
		preview_transform = _paint_3d_mesh.transform
	var aabb := _get_transformed_3d_aabb(mesh.get_aabb(), preview_transform)
	_paint_3d_target = aabb.get_center()
	var largest_axis := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	_paint_3d_distance = maxf(largest_axis * 1.8, 1.0)
	var editor_camera_basis: Variant = _get_3d_editor_view_camera_basis()
	_paint_3d_camera_basis_override_active = editor_camera_basis is Basis
	if _paint_3d_camera_basis_override_active:
		_paint_3d_camera_basis_override = (editor_camera_basis as Basis).orthonormalized()
	var initial_angles := (
		_get_3d_camera_angles_from_offset_direction(_paint_3d_camera_basis_override.z)
		if _paint_3d_camera_basis_override_active
		else Vector2(PAINT_3D_INITIAL_YAW, PAINT_3D_INITIAL_PITCH)
	)
	_paint_3d_yaw = initial_angles.x
	_paint_3d_pitch = initial_angles.y
	_update_3d_paint_camera()
	_resize_3d_paint_viewport()
	_update_3d_rotation_gizmo_transform()


func _get_3d_editor_view_camera_basis() -> Variant:
	if _plugin:
		var editor_interface := _plugin.get_editor_interface()
		var editor_viewport: SubViewport = editor_interface.get_editor_viewport_3d(0) if editor_interface else null
		var editor_camera: Camera3D = editor_viewport.get_camera_3d() if editor_viewport else null
		if is_instance_valid(editor_camera):
			return editor_camera.global_transform.basis.orthonormalized()
	return null


func _release_3d_editor_camera_basis_override() -> void:
	if not _paint_3d_camera_basis_override_active:
		return
	# Orbit and freelook intentionally return to the world-up navigation model.
	# Seed it from the current viewing direction so the transition starts from
	# the closest representable yaw/pitch instead of snapping to the fallback.
	var angles := _get_3d_camera_angles_from_offset_direction(_paint_3d_camera_basis_override.z)
	_paint_3d_yaw = angles.x
	_paint_3d_pitch = angles.y
	_paint_3d_camera_basis_override_active = false


func _get_3d_camera_angles_from_offset_direction(direction: Vector3) -> Vector2:
	if direction.length_squared() <= 0.000001:
		return Vector2(PAINT_3D_INITIAL_YAW, PAINT_3D_INITIAL_PITCH)
	var normalized := direction.normalized()
	return Vector2(
		atan2(normalized.x, normalized.z),
		clampf(asin(clampf(normalized.y, -1.0, 1.0)), -1.45, 1.45)
	)


func _get_transformed_3d_aabb(local_aabb: AABB, preview_transform: Transform3D) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for corner_index in range(8):
		var local_corner := local_aabb.position + Vector3(
			local_aabb.size.x if (corner_index & 1) != 0 else 0.0,
			local_aabb.size.y if (corner_index & 2) != 0 else 0.0,
			local_aabb.size.z if (corner_index & 4) != 0 else 0.0
		)
		var preview_corner := preview_transform * local_corner
		minimum = minimum.min(preview_corner)
		maximum = maximum.max(preview_corner)
	if minimum.x == INF:
		return AABB()
	return AABB(minimum, maximum - minimum)


func _pick_3d_rotation_gizmo_axis(view_position: Vector2) -> int:
	return int(_pick_3d_rotation_gizmo_detail(view_position).get("axis", -1))


func _pick_3d_rotation_gizmo_detail(view_position: Vector2) -> Dictionary:
	if (
		not _paint_3d_camera
		or not _paint_3d_rotation_gizmo
		or not _paint_3d_rotation_gizmo.visible
	):
		return {}
	var best_axis := -1
	var best_distance := PAINT_3D_GIZMO_HIT_PIXELS
	var gizmo_transform := _paint_3d_rotation_gizmo.global_transform
	for axis_index in range(3):
		if axis_index >= _paint_3d_gizmo_rings.size() or not _paint_3d_gizmo_rings[axis_index].visible:
			continue
		for segment in range(PAINT_3D_GIZMO_SEGMENTS):
			var angle_a := TAU * float(segment) / float(PAINT_3D_GIZMO_SEGMENTS)
			var angle_b := TAU * float(segment + 1) / float(PAINT_3D_GIZMO_SEGMENTS)
			var world_a := gizmo_transform * _get_3d_gizmo_ring_point(axis_index, angle_a)
			var world_b := gizmo_transform * _get_3d_gizmo_ring_point(axis_index, angle_b)
			if _paint_3d_camera.is_position_behind(world_a) and _paint_3d_camera.is_position_behind(world_b):
				continue
			var screen_a := _paint_3d_camera.unproject_position(world_a)
			var screen_b := _paint_3d_camera.unproject_position(world_b)
			var distance := _distance_to_2d_segment(view_position, screen_a, screen_b)
			if distance < best_distance:
				best_distance = distance
				best_axis = axis_index
	return {"axis": best_axis, "distance": best_distance} if best_axis >= 0 else {}


func _pick_3d_translation_gizmo_axis(view_position: Vector2) -> int:
	return int(_pick_3d_translation_gizmo_detail(view_position).get("axis", -1))


func _pick_3d_translation_gizmo_detail(view_position: Vector2) -> Dictionary:
	if not _paint_3d_camera or not _paint_3d_rotation_gizmo or not _paint_3d_rotation_gizmo.visible:
		return {}
	var best := {}
	var gizmo_transform := _paint_3d_rotation_gizmo.global_transform
	for axis_index in range(3):
		if axis_index >= _paint_3d_gizmo_translation_axes.size() or not _paint_3d_gizmo_translation_axes[axis_index].visible:
			continue
		var axis := _get_3d_gizmo_axis(axis_index)
		var shaft_start_world := gizmo_transform * (axis * PAINT_3D_GIZMO_ARROW_SHAFT_START)
		var head_world := gizmo_transform * (axis * PAINT_3D_GIZMO_ARROW_HEAD_START)
		var tip_world := gizmo_transform * (axis * PAINT_3D_GIZMO_ARROW_LENGTH)
		if _paint_3d_camera.is_position_behind(shaft_start_world) and _paint_3d_camera.is_position_behind(tip_world):
			continue
		var shaft_start := _paint_3d_camera.unproject_position(shaft_start_world)
		var head := _paint_3d_camera.unproject_position(head_world)
		var tip := _paint_3d_camera.unproject_position(tip_world)
		var head_distance := _distance_to_2d_segment(view_position, head, tip)
		var shaft_distance := _distance_to_2d_segment(view_position, shaft_start, head)
		var distance := minf(head_distance, shaft_distance)
		var threshold := PAINT_3D_GIZMO_HIT_PIXELS + (3.0 if head_distance <= shaft_distance else 0.0)
		if distance <= threshold and (best.is_empty() or distance < float(best.distance)):
			best = {"axis": axis_index, "distance": distance, "arrowhead": head_distance <= shaft_distance}
	return best


func _pick_3d_transform_gizmo_control(view_position: Vector2) -> Dictionary:
	var translation := _pick_3d_translation_gizmo_detail(view_position)
	var rotation := _pick_3d_rotation_gizmo_detail(view_position)
	if translation.is_empty():
		if rotation.is_empty():
			return {}
		rotation["type"] = GIZMO_CONTROL_ROTATION
		return rotation
	if bool(translation.get("arrowhead", false)) or rotation.is_empty() or float(translation.distance) <= float(rotation.distance) + 1.5:
		translation["type"] = GIZMO_CONTROL_TRANSLATION
		return translation
	rotation["type"] = GIZMO_CONTROL_ROTATION
	return rotation


func _distance_to_2d_segment(point: Vector2, segment_a: Vector2, segment_b: Vector2) -> float:
	var segment := segment_b - segment_a
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_to(segment_a)
	var weight := clampf((point - segment_a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(segment_a + segment * weight)


func _begin_3d_rotation_gizmo_drag(axis_index: int, view_position: Vector2) -> bool:
	if (
		axis_index < 0
		or axis_index > 2
		or not _texture_3d_session
		or not _texture_3d_session.has_active_session()
		or not _texture_3d_session.has_method("set_preview_orientation")
	):
		return false
	_paint_3d_gizmo_drag_start_adjustment = _texture_3d_session.get_preview_adjustment()
	_paint_3d_orbiting = false
	_paint_3d_panning = false
	_stop_3d_freelook()
	_paint_3d_gizmo_active_axis = axis_index
	_paint_3d_gizmo_active_control = GIZMO_CONTROL_ROTATION
	_paint_3d_gizmo_dragging = true
	_update_3d_transform_gizmo_component_visibility()
	_paint_3d_gizmo_drag_start_mouse = view_position
	_paint_3d_gizmo_drag_center = _paint_3d_rotation_gizmo.global_position
	_paint_3d_gizmo_drag_axis_world = _get_3d_rotation_gizmo_world_axis(axis_index)
	var preview_rotation := _paint_3d_mesh.global_transform.basis.orthonormalized()
	_paint_3d_gizmo_drag_axis_preview_local = (
		preview_rotation.inverse() * _paint_3d_gizmo_drag_axis_world
	).normalized()
	_paint_3d_gizmo_drag_start_vector = _get_3d_rotation_gizmo_plane_vector_at(
		view_position,
		_paint_3d_gizmo_drag_center,
		_paint_3d_gizmo_drag_axis_world
	)
	if _paint_3d_gizmo_drag_start_vector.length_squared() <= 0.000001:
		_paint_3d_gizmo_drag_start_vector = _get_nearest_3d_gizmo_ring_vector(view_position, axis_index)
	_configure_3d_gizmo_drag_fallback(axis_index)
	_paint_3d_pending_motion = false
	_hide_3d_brush_preview()
	_hide_3d_hover_debug_marker("rotation gizmo drag")
	if _paint_3d_hover_triangle:
		_paint_3d_hover_triangle.visible = false
	_update_3d_paint_cursor(false)
	_update_3d_rotation_gizmo_materials()
	if _paint_3d_gizmo_drag_start_vector.length_squared() <= 0.000001:
		_paint_3d_gizmo_dragging = false
		_paint_3d_gizmo_active_control = GIZMO_CONTROL_NONE
		_paint_3d_gizmo_active_axis = -1
		_update_3d_transform_gizmo_component_visibility()
		_update_3d_rotation_gizmo_materials()
		return false
	return true


func _get_3d_rotation_gizmo_plane_vector(view_position: Vector2, axis_index: int) -> Vector3:
	if not _paint_3d_camera or not _paint_3d_rotation_gizmo:
		return Vector3.ZERO
	return _get_3d_rotation_gizmo_plane_vector_at(
		view_position,
		_paint_3d_rotation_gizmo.global_position,
		_get_3d_rotation_gizmo_world_axis(axis_index)
	)


func _get_3d_rotation_gizmo_plane_vector_at(view_position: Vector2, center: Vector3, axis_world: Vector3) -> Vector3:
	var ray_origin := _paint_3d_camera.project_ray_origin(view_position)
	var ray_direction := _paint_3d_camera.project_ray_normal(view_position).normalized()
	var denominator := axis_world.dot(ray_direction)
	if absf(denominator) <= 0.0001:
		return Vector3.ZERO
	var ray_distance := axis_world.dot(center - ray_origin) / denominator
	if ray_distance < 0.0:
		return Vector3.ZERO
	var vector := ray_origin + ray_direction * ray_distance - center
	return vector.normalized() if vector.length_squared() > 0.000001 else Vector3.ZERO


func _get_3d_rotation_gizmo_world_axis(axis_index: int) -> Vector3:
	if not _paint_3d_rotation_gizmo:
		return _get_3d_gizmo_axis(axis_index)
	return (_paint_3d_rotation_gizmo.global_transform.basis * _get_3d_gizmo_axis(axis_index)).normalized()


func _get_nearest_3d_gizmo_ring_vector(view_position: Vector2, axis_index: int) -> Vector3:
	var best_distance := INF
	var best_vector := Vector3.ZERO
	var center := _paint_3d_rotation_gizmo.global_position
	var gizmo_transform := _paint_3d_rotation_gizmo.global_transform
	for segment in range(PAINT_3D_GIZMO_SEGMENTS):
		var angle := TAU * float(segment) / float(PAINT_3D_GIZMO_SEGMENTS)
		var world_point := gizmo_transform * _get_3d_gizmo_ring_point(axis_index, angle)
		var screen_point := _paint_3d_camera.unproject_position(world_point)
		var distance := view_position.distance_squared_to(screen_point)
		if distance < best_distance:
			best_distance = distance
			best_vector = (world_point - center).normalized()
	return best_vector


func _configure_3d_gizmo_drag_fallback(_axis_index: int) -> void:
	_paint_3d_gizmo_drag_fallback_tangent = Vector2.RIGHT
	_paint_3d_gizmo_drag_fallback_radius = PAINT_3D_GIZMO_RADIUS_PIXELS
	if not _paint_3d_camera or _paint_3d_gizmo_drag_start_vector.length_squared() <= 0.000001:
		return
	var center := _paint_3d_gizmo_drag_center
	var axis_world := _paint_3d_gizmo_drag_axis_world
	var radius := _get_3d_rotation_gizmo_world_scale()
	var start_point := center + _paint_3d_gizmo_drag_start_vector * radius
	var rotated_point := center + _paint_3d_gizmo_drag_start_vector.rotated(axis_world, 0.08) * radius
	var tangent := (
		_paint_3d_camera.unproject_position(rotated_point)
		- _paint_3d_camera.unproject_position(start_point)
	)
	if tangent.length_squared() > 0.000001:
		_paint_3d_gizmo_drag_fallback_tangent = tangent.normalized()
	_paint_3d_gizmo_drag_fallback_radius = maxf(
		8.0,
		_paint_3d_camera.unproject_position(center).distance_to(
			_paint_3d_camera.unproject_position(start_point)
		)
	)


func _update_3d_rotation_gizmo_drag(view_position: Vector2, snap: bool) -> void:
	if not _paint_3d_gizmo_dragging or not _texture_3d_session:
		return
	var current_vector := _get_3d_rotation_gizmo_plane_vector_at(
		view_position,
		_paint_3d_gizmo_drag_center,
		_paint_3d_gizmo_drag_axis_world
	)
	var angle := 0.0
	if current_vector.length_squared() > 0.000001:
		angle = atan2(
			_paint_3d_gizmo_drag_axis_world.dot(_paint_3d_gizmo_drag_start_vector.cross(current_vector)),
			_paint_3d_gizmo_drag_start_vector.dot(current_vector)
		)
	else:
		angle = (
			(view_position - _paint_3d_gizmo_drag_start_mouse).dot(_paint_3d_gizmo_drag_fallback_tangent)
			/ _paint_3d_gizmo_drag_fallback_radius
		)
	if snap:
		angle = snappedf(angle, PAINT_3D_GIZMO_SNAP_RADIANS)
	var rotation := Transform3D(Basis(_paint_3d_gizmo_drag_axis_preview_local, angle), Vector3.ZERO)
	_texture_3d_session.set_preview_adjustment(_paint_3d_gizmo_drag_start_adjustment * rotation)
	_apply_3d_preview_transform(false)


func _begin_3d_translation_gizmo_drag(axis_index: int, view_position: Vector2) -> bool:
	if axis_index < 0 or axis_index > 2 or not _texture_3d_session or not _texture_3d_session.has_active_session():
		return false
	_paint_3d_gizmo_drag_start_adjustment = _texture_3d_session.get_preview_adjustment()
	_paint_3d_orbiting = false
	_paint_3d_panning = false
	_stop_3d_freelook()
	_paint_3d_gizmo_active_control = GIZMO_CONTROL_TRANSLATION
	_paint_3d_gizmo_active_axis = axis_index
	_paint_3d_gizmo_dragging = true
	_paint_3d_gizmo_drag_start_mouse = view_position
	_paint_3d_gizmo_drag_center = _paint_3d_rotation_gizmo.global_position
	_paint_3d_gizmo_drag_axis_world = _get_3d_rotation_gizmo_world_axis(axis_index)
	var closest := _get_3d_gizmo_ray_axis_parameter(view_position, _paint_3d_gizmo_drag_center, _paint_3d_gizmo_drag_axis_world)
	_paint_3d_gizmo_drag_use_screen_fallback = not bool(closest.get("valid", false))
	_paint_3d_gizmo_drag_start_axis_parameter = float(closest.get("parameter", 0.0))
	_configure_3d_translation_drag_fallback()
	_update_3d_transform_gizmo_component_visibility()
	_paint_3d_pending_motion = false
	_hide_3d_brush_preview()
	_hide_3d_hover_debug_marker("translation gizmo drag")
	if _paint_3d_hover_triangle:
		_paint_3d_hover_triangle.visible = false
	_update_3d_paint_cursor(false)
	_update_3d_rotation_gizmo_materials()
	return true


func _get_3d_gizmo_ray_axis_parameter(view_position: Vector2, center: Vector3, axis_world: Vector3) -> Dictionary:
	if not _paint_3d_camera:
		return {}
	var ray_origin := _paint_3d_camera.project_ray_origin(view_position)
	var ray_direction := _paint_3d_camera.project_ray_normal(view_position).normalized()
	var parallel := ray_direction.dot(axis_world)
	var denominator := 1.0 - parallel * parallel
	if denominator <= 0.002:
		return {}
	var offset := ray_origin - center
	return {
		"valid": true,
		"parameter": (axis_world.dot(offset) - parallel * ray_direction.dot(offset)) / denominator,
	}


func _configure_3d_translation_drag_fallback() -> void:
	_paint_3d_gizmo_drag_screen_axis = Vector2.RIGHT
	_paint_3d_gizmo_drag_world_per_pixel = _get_3d_rotation_gizmo_world_scale() / PAINT_3D_GIZMO_RADIUS_PIXELS
	if not _paint_3d_camera:
		return
	var radius := _get_3d_rotation_gizmo_world_scale()
	var center_screen := _paint_3d_camera.unproject_position(_paint_3d_gizmo_drag_center)
	var axis_screen := _paint_3d_camera.unproject_position(
		_paint_3d_gizmo_drag_center + _paint_3d_gizmo_drag_axis_world * radius
	) - center_screen
	if axis_screen.length_squared() > 4.0:
		_paint_3d_gizmo_drag_screen_axis = axis_screen.normalized()
		_paint_3d_gizmo_drag_world_per_pixel = radius / axis_screen.length()
	else:
		_paint_3d_gizmo_drag_use_screen_fallback = true


func _update_3d_translation_gizmo_drag(view_position: Vector2) -> void:
	if not _paint_3d_gizmo_dragging or _paint_3d_gizmo_active_control != GIZMO_CONTROL_TRANSLATION or not _texture_3d_session:
		return
	var world_delta := 0.0
	if not _paint_3d_gizmo_drag_use_screen_fallback:
		var closest := _get_3d_gizmo_ray_axis_parameter(view_position, _paint_3d_gizmo_drag_center, _paint_3d_gizmo_drag_axis_world)
		if bool(closest.get("valid", false)):
			world_delta = float(closest.parameter) - _paint_3d_gizmo_drag_start_axis_parameter
		else:
			_paint_3d_gizmo_drag_use_screen_fallback = true
	if _paint_3d_gizmo_drag_use_screen_fallback:
		world_delta = (
			(view_position - _paint_3d_gizmo_drag_start_mouse).dot(_paint_3d_gizmo_drag_screen_axis)
			* _paint_3d_gizmo_drag_world_per_pixel
		)
	var base_basis: Basis = _texture_3d_session.imported_source_transform.basis
	var local_delta := base_basis.inverse() * (_paint_3d_gizmo_drag_axis_world * world_delta)
	var adjustment := _paint_3d_gizmo_drag_start_adjustment
	adjustment.origin = _paint_3d_gizmo_drag_start_adjustment.origin + local_delta
	_texture_3d_session.set_preview_adjustment(adjustment)
	_apply_3d_preview_transform(false)


func _end_3d_rotation_gizmo_drag() -> void:
	if not _paint_3d_gizmo_dragging:
		return
	_paint_3d_gizmo_dragging = false
	_paint_3d_gizmo_active_control = GIZMO_CONTROL_NONE
	_paint_3d_gizmo_active_axis = -1
	_paint_3d_gizmo_drag_axis_preview_local = Vector3.ZERO
	_update_3d_transform_gizmo_component_visibility()
	_update_3d_rotation_gizmo_materials()


func _cancel_3d_rotation_gizmo_drag(restore_orientation := true) -> void:
	var was_dragging := _paint_3d_gizmo_dragging
	if was_dragging and restore_orientation and _texture_3d_session and _texture_3d_session.has_method("set_preview_adjustment"):
		_texture_3d_session.set_preview_adjustment(_paint_3d_gizmo_drag_start_adjustment)
		_apply_3d_preview_transform(false)
	_paint_3d_gizmo_dragging = false
	_paint_3d_gizmo_active_control = GIZMO_CONTROL_NONE
	_paint_3d_gizmo_active_axis = -1
	_paint_3d_gizmo_drag_axis_preview_local = Vector3.ZERO
	_update_3d_transform_gizmo_component_visibility()
	_update_3d_rotation_gizmo_materials()


func _establish_3d_preview_stage(mesh: Mesh) -> void:
	if not _paint_3d_mesh or not mesh:
		return
	var aabb := _get_transformed_3d_aabb(mesh.get_aabb(), _paint_3d_mesh.transform)
	var largest_axis := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	_update_3d_paint_stage(aabb, maxf(PAINT_3D_STAGE_MIN_SIZE, largest_axis * PAINT_3D_STAGE_PADDING))


func _update_3d_paint_stage(aabb: AABB, stage_size: float) -> void:
	if not _paint_3d_stage_root or not _paint_3d_stage_floor or not _paint_3d_stage_grid:
		return
	var center := aabb.get_center()
	var floor_y := aabb.position.y
	if aabb.size == Vector3.ZERO:
		center = Vector3.ZERO
		floor_y = -0.5
	_paint_3d_stage_root.position = Vector3(center.x, floor_y - 0.01, center.z)
	var grid_extent := _get_3d_stage_grid_extent(stage_size)
	var floor_mesh := _paint_3d_stage_floor.mesh as PlaneMesh
	if floor_mesh:
		floor_mesh.size = Vector2(grid_extent, grid_extent)
	_paint_3d_stage_grid.mesh = _make_3d_stage_grid_mesh(stage_size)
	var grid_material := _paint_3d_stage_grid.material_override as ShaderMaterial
	if grid_material:
		_configure_3d_stage_grid_fade(grid_material, grid_extent)


func _get_3d_stage_grid_extent(stage_size: float) -> float:
	return stage_size * float(PAINT_3D_STAGE_GRID_EXTENT_MULTIPLIER)


func _make_3d_stage_grid_mesh(stage_size: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var grid_extent := _get_3d_stage_grid_extent(stage_size)
	var half_size := grid_extent * 0.5
	var line_count := PAINT_3D_STAGE_GRID_LINES * PAINT_3D_STAGE_GRID_EXTENT_MULTIPLIER
	var step := grid_extent / float(line_count)
	var minor_color := Color(0.42, 0.44, 0.46, 0.26)
	var major_color := Color(0.62, 0.65, 0.68, 0.42)
	var axis_x_color := Color(0.85, 0.32, 0.28, 0.62)
	var axis_y_color := Color(0.32, 0.85, 0.28, 0.62)
	var axis_z_color := Color(0.28, 0.48, 0.9, 0.62)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in range(line_count + 1):
		var offset := -half_size + step * float(index)
		var color := major_color if index % 4 == 0 else minor_color
		if is_zero_approx(offset):
			# These vertices vary on X, so the center line is the X axis.
			color = axis_x_color
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(-half_size, 0.004, offset))
		mesh.surface_add_vertex(Vector3(half_size, 0.004, offset))
		color = major_color if index % 4 == 0 else minor_color
		if is_zero_approx(offset):
			# These vertices vary on Z, so the center line is the Z axis.
			color = axis_z_color
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(offset, 0.005, -half_size))
		mesh.surface_add_vertex(Vector3(offset, 0.005, half_size))
	mesh.surface_set_color(axis_y_color)
	mesh.surface_add_vertex(Vector3(0.0, -half_size, 0.0))
	mesh.surface_add_vertex(Vector3(0.0, half_size, 0.0))
	mesh.surface_end()
	return mesh


func _on_3d_paint_view_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _cancel_3d_surface_shape("Canceled 3D shape preview.", true):
			_paint_3d_view.accept_event()
			return
		if _paint_3d_gizmo_dragging:
			_cancel_3d_rotation_gizmo_drag(true)
			_paint_3d_view.accept_event()
		return
	if event is InputEventMouseButton:
		if event.pressed and _paint_3d_view:
			_paint_3d_view.grab_focus()
		if _paint_3d_gizmo_dragging:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_end_3d_rotation_gizmo_drag()
			_paint_3d_view.accept_event()
			return
		var gizmo_control := _pick_3d_transform_gizmo_control(event.position)
		var gizmo_axis := int(gizmo_control.get("axis", -1))
		var gizmo_type := int(gizmo_control.get("type", GIZMO_CONTROL_NONE))
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var began_gizmo_drag := false
				if gizmo_type == GIZMO_CONTROL_TRANSLATION:
					began_gizmo_drag = _begin_3d_translation_gizmo_drag(gizmo_axis, event.position)
				elif gizmo_type == GIZMO_CONTROL_ROTATION:
					began_gizmo_drag = _begin_3d_rotation_gizmo_drag(gizmo_axis, event.position)
				if began_gizmo_drag:
					_paint_3d_view.accept_event()
					return
				_paint_3d_pending_motion = false
				var hit := _pick_3d_paint_uv(event.position)
				if not hit.is_empty():
					_update_3d_brush_preview(hit)
					_update_2d_hover_from_3d_hit(hit)
					_paint_3d_drawing = _on_3d_paint_uv_started(hit)
					_paint_3d_view.accept_event()
			elif _paint_3d_drawing:
				_paint_3d_drawing = false
				if not _paint_3d_surface_shape_state.is_empty():
					_paint_3d_pending_motion = false
					_finish_3d_surface_shape_at(event.position)
				else:
					_process_pending_3d_pointer_motion()
					_on_3d_paint_uv_finished()
				_paint_3d_view.accept_event()
		elif event.pressed and gizmo_axis >= 0 and event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_paint_3d_view.accept_event()
			return
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_start_3d_freelook()
			else:
				_stop_3d_freelook()
			_paint_3d_last_mouse_position = event.position
			_paint_3d_view.accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			var navigation_mode := _get_3d_mouse_navigation_mode(event)
			if event.pressed and navigation_mode == NAVIGATION_3D_ORBIT:
				_release_3d_editor_camera_basis_override()
			_paint_3d_panning = event.pressed and navigation_mode == NAVIGATION_3D_PAN
			_paint_3d_orbiting = event.pressed and navigation_mode == NAVIGATION_3D_ORBIT
			_paint_3d_last_mouse_position = event.position
			_paint_3d_view.accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _paint_3d_freelooking:
				_paint_3d_freelook_speed_multiplier = minf(64.0, _paint_3d_freelook_speed_multiplier * 1.2)
				_update_3d_view_readout()
			else:
				_paint_3d_distance = maxf(0.1, _paint_3d_distance * 0.88)
				_update_3d_paint_camera()
			_paint_3d_view.accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _paint_3d_freelooking:
				_paint_3d_freelook_speed_multiplier = maxf(0.02, _paint_3d_freelook_speed_multiplier / 1.2)
				_update_3d_view_readout()
			else:
				_paint_3d_distance = minf(200.0, _paint_3d_distance / 0.88)
				_update_3d_paint_camera()
			_paint_3d_view.accept_event()
	elif event is InputEventMouseMotion:
		var delta: Vector2 = event.relative
		_paint_3d_last_mouse_position = event.position
		if _paint_3d_gizmo_dragging:
			if _paint_3d_gizmo_active_control == GIZMO_CONTROL_TRANSLATION:
				_update_3d_translation_gizmo_drag(event.position)
			else:
				_update_3d_rotation_gizmo_drag(event.position, event.shift_pressed)
			_paint_3d_view.accept_event()
		elif _paint_3d_drawing:
			_paint_3d_pending_motion_position = event.position
			_paint_3d_pending_motion = true
			_paint_3d_view.accept_event()
		elif _paint_3d_orbiting:
			_hide_3d_brush_preview()
			_apply_3d_look_delta(delta)
			_update_3d_paint_camera()
			_paint_3d_view.accept_event()
		elif _paint_3d_panning:
			_hide_3d_brush_preview()
			_pan_3d_paint_camera(delta)
			_paint_3d_view.accept_event()
		elif _paint_3d_freelooking:
			_hide_3d_brush_preview()
			_freelook_3d_paint_camera(delta)
			_paint_3d_view.accept_event()
		else:
			var gizmo_control := _pick_3d_transform_gizmo_control(event.position)
			var gizmo_axis := int(gizmo_control.get("axis", -1))
			var gizmo_type := int(gizmo_control.get("type", GIZMO_CONTROL_NONE))
			_set_3d_transform_gizmo_hover(gizmo_type, gizmo_axis)
			if gizmo_axis >= 0:
				_paint_3d_pending_motion = false
				_hide_3d_brush_preview()
				_hide_3d_hover_debug_marker("transform gizmo hover")
				if _paint_3d_hover_triangle:
					_paint_3d_hover_triangle.visible = false
				_update_3d_paint_cursor(false)
				_paint_3d_view.accept_event()
			else:
				_paint_3d_pending_motion_position = event.position
				_paint_3d_pending_motion = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		if _paint_3d_mesh and _paint_3d_mesh.mesh:
			_frame_3d_paint_mesh(_paint_3d_mesh.mesh)
			_paint_3d_view.accept_event()


func _process_pending_3d_pointer_motion() -> void:
	if not _paint_3d_pending_motion:
		return
	_paint_3d_pending_motion = false
	if _paint_3d_orbiting or _paint_3d_panning or _paint_3d_freelooking or _paint_3d_gizmo_dragging or _paint_3d_gizmo_hover_axis >= 0:
		return
	var hit := _pick_3d_paint_uv(_paint_3d_pending_motion_position)
	if hit.is_empty():
		_hide_3d_brush_preview()
		_update_3d_paint_cursor(false)
		if _paint_3d_drawing:
			if not _paint_3d_surface_shape_state.is_empty():
				_invalidate_3d_surface_shape("The pointer is not over the active 3D surface.")
			else:
				_paint_3d_last_stroke_hit.clear()
		return
	_update_3d_brush_preview(hit)
	_update_2d_hover_from_3d_hit(hit)
	_update_3d_paint_cursor(true)
	if _paint_3d_drawing:
		_on_3d_paint_uv_dragged(hit)


func _get_3d_mouse_navigation_mode(event: InputEventMouseButton) -> int:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		return NAVIGATION_3D_PAN if event.shift_pressed else NAVIGATION_3D_ORBIT
	if event.button_index == MOUSE_BUTTON_RIGHT:
		return NAVIGATION_3D_FREELOOK
	return NAVIGATION_3D_NONE


func _pick_3d_paint_uv(view_position: Vector2) -> Dictionary:
	if not _paint_3d_camera or not _paint_3d_mesh or not _paint_3d_mesh_cache or not _paint_3d_mesh_cache.is_valid():
		return {}

	var ray_origin := _paint_3d_camera.project_ray_origin(view_position)
	var ray_direction := _paint_3d_camera.project_ray_normal(view_position).normalized()
	if ray_direction.length_squared() <= 0.0:
		return {}

	var local_origin := _paint_3d_mesh.to_local(ray_origin)
	var local_end := _paint_3d_mesh.to_local(ray_origin + ray_direction * _paint_3d_camera.far)
	var local_direction := local_end - local_origin
	var local_ray_length := local_direction.length()
	if local_ray_length <= 0.0:
		return {}
	local_direction /= local_ray_length

	var started := Time.get_ticks_usec()
	var query: Dictionary = _paint_3d_mesh_cache.query_ray(local_origin, local_direction, local_ray_length)
	var best_hit: Dictionary = query.get("hit", {})
	if not best_hit.is_empty():
		best_hit["ray_candidate_triangle_count"] = int(query.get("candidate_count", 0))
		best_hit["ray_triangles_examined"] = int(query.get("triangles_examined", 0))
		best_hit["ray_nodes_examined"] = int(query.get("nodes_examined", 0))
		best_hit["ray_query_usec"] = Time.get_ticks_usec() - started
		_add_3d_texture_uv_to_hit(best_hit)
	if DEBUG_MESH_PAINT_PERFORMANCE:
		print("GDDraw ray query: ", query, " usec=", Time.get_ticks_usec() - started)
	return best_hit


func _find_3d_paint_hit_from_uv(uv: Vector2) -> Dictionary:
	if not _paint_3d_camera or not _paint_3d_mesh or not _paint_3d_mesh_cache or not _paint_3d_mesh_cache.is_valid():
		return {}
	var started := Time.get_ticks_usec()
	var best_hit := {}
	var best_score := INF
	var candidate_triangle_count := 0
	var accepted_triangle_count := 0
	var canvas_size: Vector2i = _canvas.get_canvas_size() if _canvas else Vector2i.ONE
	var mesh_uv := _texture_uv_to_mesh_uv(uv)
	var brush_radius := maxf(0.5, float(maxi(1, _canvas.brush_size)) * 0.5) if _canvas else 0.5
	var texture_margin := Vector2(brush_radius / float(maxi(1, canvas_size.x)), brush_radius / float(maxi(1, canvas_size.y)))
	var mesh_margin := texture_margin
	if _paint_3d_material:
		var uv_scale := _paint_3d_material.uv1_scale
		mesh_margin = Vector2(
			texture_margin.x / absf(uv_scale.x) if not is_zero_approx(uv_scale.x) else texture_margin.x,
			texture_margin.y / absf(uv_scale.y) if not is_zero_approx(uv_scale.y) else texture_margin.y
		)
	var query: Dictionary = _paint_3d_mesh_cache.query_uv_candidates(mesh_uv, mesh_margin)
	var triangle_ids: PackedInt32Array = query.get("triangle_ids", PackedInt32Array())
	candidate_triangle_count = triangle_ids.size()
	for triangle_id in triangle_ids:
		var triangle: Dictionary = _paint_3d_mesh_cache.get_triangle(triangle_id)
		if triangle.is_empty():
			continue
		var preview_uv := _get_3d_preview_uv_on_triangle(
			mesh_uv,
			triangle["uv_a"],
			triangle["uv_b"],
			triangle["uv_c"],
			canvas_size
		)
		if preview_uv.x < 0.0 or preview_uv.y < 0.0:
			continue
		var hit: Dictionary = _paint_3d_mesh_cache.make_uv_hit(triangle_id, preview_uv, 0.001)
		if hit.is_empty():
			continue
		accepted_triangle_count += 1
		var score := _score_3d_uv_hover_hit(hit)
		if score < best_score:
			best_score = score
			best_hit = hit
	if not best_hit.is_empty():
		best_hit["uv_candidate_triangle_count"] = candidate_triangle_count
		best_hit["uv_accepted_triangle_count"] = accepted_triangle_count
		best_hit["uv_nodes_examined"] = int(query.get("nodes_examined", 0))
		best_hit["uv_query_usec"] = Time.get_ticks_usec() - started
		_add_3d_texture_uv_to_hit(best_hit)
	var surface_start := int(_texture_3d_session.material_slot) if _texture_3d_session else 0
	_debug_2d_to_3d_hover_lookup(best_hit, uv, surface_start, surface_start + 1, candidate_triangle_count, accepted_triangle_count)
	if DEBUG_MESH_PAINT_PERFORMANCE:
		print("GDDraw UV query: candidates=", candidate_triangle_count, " nodes=", query.get("nodes_examined", 0), " usec=", Time.get_ticks_usec() - started)
	return best_hit


func _add_3d_texture_uv_to_hit(hit: Dictionary) -> void:
	if hit.is_empty():
		return
	hit["texture_uv"] = _mesh_uv_to_texture_uv(hit.get("uv", Vector2.ZERO))
	var mesh_triangle_uvs: PackedVector2Array = hit.get("triangle_uvs", PackedVector2Array())
	var texture_triangle_uvs := PackedVector2Array()
	for mesh_triangle_uv in mesh_triangle_uvs:
		texture_triangle_uvs.push_back(_mesh_uv_to_texture_uv(mesh_triangle_uv))
	hit["texture_triangle_uvs"] = texture_triangle_uvs


func _mesh_uv_to_texture_uv(uv: Vector2) -> Vector2:
	if not _paint_3d_material:
		return uv
	var scale := _paint_3d_material.uv1_scale
	var offset := _paint_3d_material.uv1_offset
	return Vector2(uv.x * scale.x + offset.x, uv.y * scale.y + offset.y)


func _texture_uv_to_mesh_uv(uv: Vector2) -> Vector2:
	if not _paint_3d_material:
		return uv
	var scale := _paint_3d_material.uv1_scale
	var offset := _paint_3d_material.uv1_offset
	return Vector2(
		(uv.x - offset.x) / scale.x if not is_zero_approx(scale.x) else uv.x,
		(uv.y - offset.y) / scale.y if not is_zero_approx(scale.y) else uv.y
	)


func _debug_2d_to_3d_hover_lookup(hit: Dictionary, requested_uv: Vector2, surface_start: int, surface_end: int, candidate_count: int, accepted_count: int) -> void:
	if not DEBUG_2D_TO_3D_HOVER_DIAGNOSTICS:
		return
	var state := "miss:%d:%d:%d" % [surface_start, surface_end, candidate_count]
	var message := "miss uv=%s surfaces=[%d,%d) triangles=%d accepted=%d" % [requested_uv, surface_start, surface_end, candidate_count, accepted_count]
	if not hit.is_empty():
		var surface_index := int(hit.get("surface_index", -1))
		var triangle_index := int(hit.get("triangle_index", -1))
		state = "hit:%d:%d" % [surface_index, triangle_index]
		var local_position: Vector3 = hit.get("position", Vector3.ZERO)
		var local_normal: Vector3 = hit.get("normal", Vector3.ZERO)
		var world_position := _paint_3d_mesh.to_global(local_position)
		var world_normal := _local_3d_paint_normal_to_world(local_normal)
		var facing := world_normal.dot((_paint_3d_camera.global_position - world_position).normalized())
		message = "hit uv=%s surface=%d triangle=%d triangles=%d accepted=%d facing=%.3f" % [
			hit.get("uv", requested_uv),
			surface_index,
			triangle_index,
			candidate_count,
			accepted_count,
			facing,
		]
	if state == _paint_3d_hover_debug_state:
		return
	_paint_3d_hover_debug_state = state
	print("GDDraw 2D->3D hover: ", message)


func _score_3d_uv_hover_hit(hit: Dictionary) -> float:
	if not _paint_3d_camera or not _paint_3d_mesh or hit.is_empty():
		return INF
	var local_position: Vector3 = hit.get("position", Vector3.ZERO)
	var world_position := _paint_3d_mesh.to_global(local_position)
	# Overlapping UV shells (hair over a head, clothing over a body) can have
	# inconsistent winding. Distance is the inexpensive visibility proxy that
	# selects the outer shell without another full mesh ray scan.
	return _paint_3d_camera.global_position.distance_squared_to(world_position)


func _make_3d_paint_hit_from_uv(vertices: PackedVector3Array, uvs: PackedVector2Array, uv: Vector2, a_index: int, b_index: int, c_index: int, canvas_size: Vector2i) -> Dictionary:
	if a_index < 0 or b_index < 0 or c_index < 0:
		return {}
	if a_index >= vertices.size() or b_index >= vertices.size() or c_index >= vertices.size():
		return {}
	if a_index >= uvs.size() or b_index >= uvs.size() or c_index >= uvs.size():
		return {}
	var preview_uv := _get_3d_preview_uv_on_triangle(uv, uvs[a_index], uvs[b_index], uvs[c_index], canvas_size)
	if preview_uv.x < 0.0 or preview_uv.y < 0.0:
		return {}
	var bary := _get_uv_barycentric(preview_uv, uvs[a_index], uvs[b_index], uvs[c_index])
	if bary.x < -0.001 or bary.y < -0.001 or bary.z < -0.001:
		return {}
	var a := vertices[a_index]
	var b := vertices[b_index]
	var c := vertices[c_index]
	var normal := (b - a).cross(c - a)
	var geometry_scale := (b - a).length_squared() * (c - a).length_squared()
	if geometry_scale <= 0.0 or normal.length_squared() <= geometry_scale * 1.0e-12:
		return {}
	normal = normal.normalized()
	return {
		"uv": preview_uv,
		"triangle_uvs": PackedVector2Array([uvs[a_index], uvs[b_index], uvs[c_index]]),
		"triangle_positions": PackedVector3Array([a, b, c]),
		"position": a * bary.x + b * bary.y + c * bary.z,
		"normal": normal,
		"distance": 0.0,
	}


func _get_3d_preview_uv_on_triangle(uv: Vector2, a: Vector2, b: Vector2, c: Vector2, canvas_size: Vector2i) -> Vector2:
	var bary := _get_uv_barycentric(uv, a, b, c)
	if bary.x >= -0.001 and bary.y >= -0.001 and bary.z >= -0.001:
		return uv
	if not _canvas:
		return Vector2(-1.0, -1.0)
	canvas_size = Vector2i(maxi(1, canvas_size.x), maxi(1, canvas_size.y))
	# Brush distance is measured in texture pixels, not raw mesh UV units.
	# This keeps near-edge linked hover accurate when the material applies a
	# UV scale/offset, including mirrored (negative-scale) mappings.
	var point_px := _uv_to_texture_pixel_point(_mesh_uv_to_texture_uv(uv), canvas_size)
	var a_px := _uv_to_texture_pixel_point(_mesh_uv_to_texture_uv(a), canvas_size)
	var b_px := _uv_to_texture_pixel_point(_mesh_uv_to_texture_uv(b), canvas_size)
	var c_px := _uv_to_texture_pixel_point(_mesh_uv_to_texture_uv(c), canvas_size)
	var closest_px := _closest_point_on_triangle_2d(point_px, a_px, b_px, c_px)
	var delta := point_px - closest_px
	var radius := maxf(0.5, float(maxi(1, _canvas.brush_size)) * 0.5)
	var touches := false
	if _canvas.brush_head == GDDrawCanvasControl.BrushHead.SQUARE:
		touches = absf(delta.x) <= radius and absf(delta.y) <= radius
	else:
		touches = delta.length() <= radius
	if not touches:
		return Vector2(-1.0, -1.0)
	var closest_texture_uv := Vector2(
		clampf(closest_px.x / float(canvas_size.x), 0.0, 1.0),
		clampf(closest_px.y / float(canvas_size.y), 0.0, 1.0)
	)
	return _texture_uv_to_mesh_uv(closest_texture_uv)


func _uv_to_texture_pixel_point(uv: Vector2, canvas_size: Vector2i) -> Vector2:
	return Vector2(uv.x * float(canvas_size.x), uv.y * float(canvas_size.y))


func _closest_point_on_triangle_2d(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var bary := _get_uv_barycentric(point, a, b, c)
	if bary.x >= 0.0 and bary.y >= 0.0 and bary.z >= 0.0:
		return point
	var closest := _closest_point_on_segment_2d(point, a, b)
	var best_distance := point.distance_squared_to(closest)
	var candidate := _closest_point_on_segment_2d(point, b, c)
	var distance := point.distance_squared_to(candidate)
	if distance < best_distance:
		best_distance = distance
		closest = candidate
	candidate = _closest_point_on_segment_2d(point, c, a)
	distance = point.distance_squared_to(candidate)
	if distance < best_distance:
		closest = candidate
	return closest


func _closest_point_on_segment_2d(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var segment := b - a
	var length_squared := segment.length_squared()
	if length_squared <= 0.0:
		return a
	var t := clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return a + segment * t


func _get_uv_barycentric(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := point - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denominator := d00 * d11 - d01 * d01
	var denominator_scale := d00 * d11
	if denominator_scale <= 0.0 or absf(denominator) <= denominator_scale * 1.0e-12:
		return Vector3(-1.0, -1.0, -1.0)
	var bary_c := (d00 * d21 - d01 * d20) / denominator
	var bary_b := (d11 * d20 - d01 * d21) / denominator
	var bary_a := 1.0 - bary_b - bary_c
	return Vector3(bary_a, bary_b, bary_c)


func _pick_3d_paint_triangle_uv(ray_origin: Vector3, ray_direction: Vector3, ray_length: float, vertices: PackedVector3Array, uvs: PackedVector2Array, a_index: int, b_index: int, c_index: int) -> Dictionary:
	if a_index < 0 or b_index < 0 or c_index < 0:
		return {}
	if a_index >= vertices.size() or b_index >= vertices.size() or c_index >= vertices.size():
		return {}
	if a_index >= uvs.size() or b_index >= uvs.size() or c_index >= uvs.size():
		return {}

	var a := vertices[a_index]
	var b := vertices[b_index]
	var c := vertices[c_index]
	var edge_ab := b - a
	var edge_ac := c - a
	var normal := edge_ab.cross(edge_ac)
	var geometry_scale := edge_ab.length_squared() * edge_ac.length_squared()
	if geometry_scale <= 0.0 or normal.length_squared() <= geometry_scale * 1.0e-12:
		return {}
	normal = normal.normalized()

	var pvec := ray_direction.cross(edge_ac)
	var determinant := edge_ab.dot(pvec)
	var determinant_scale := sqrt(geometry_scale) * ray_direction.length()
	if determinant_scale <= 0.0 or absf(determinant) <= determinant_scale * 1.0e-7:
		return {}

	var inverse_determinant := 1.0 / determinant
	var tvec := ray_origin - a
	var bary_b := tvec.dot(pvec) * inverse_determinant
	if bary_b < 0.0 or bary_b > 1.0:
		return {}

	var qvec := tvec.cross(edge_ab)
	var bary_c := ray_direction.dot(qvec) * inverse_determinant
	if bary_c < 0.0 or bary_b + bary_c > 1.0:
		return {}

	var distance := edge_ac.dot(qvec) * inverse_determinant
	if distance < 0.0 or distance > ray_length:
		return {}

	var bary_a := 1.0 - bary_b - bary_c
	var uv_a := uvs[a_index]
	var uv_b := uvs[b_index]
	var uv_c := uvs[c_index]
	var uv := uv_a * bary_a + uv_b * bary_b + uv_c * bary_c
	var position := a * bary_a + b * bary_b + c * bary_c
	return {
		"uv": uv,
		"triangle_uvs": PackedVector2Array([uv_a, uv_b, uv_c]),
		"triangle_positions": PackedVector3Array([a, b, c]),
		"position": position,
		"normal": normal,
		"distance": distance,
	}


func _count_3d_uv_overlaps(hit: Dictionary) -> int:
	if not _paint_3d_mesh_cache or not _paint_3d_mesh_cache.is_valid() or hit.is_empty():
		return 0
	var started := Time.get_ticks_usec()
	var result: Dictionary = _paint_3d_mesh_cache.count_uv_overlaps(hit, _get_3d_uv_overlap_distance_epsilon())
	if DEBUG_MESH_PAINT_PERFORMANCE:
		print("GDDraw UV overlap query: ", result, " usec=", Time.get_ticks_usec() - started)
	return int(result.get("overlap_count", 0))


func _point_in_uv_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := c - a
	var v1 := b - a
	var v2 := point - a
	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)
	var denominator := dot00 * dot11 - dot01 * dot01
	var denominator_scale := dot00 * dot11
	if denominator_scale <= 0.0 or absf(denominator) <= denominator_scale * 1.0e-12:
		return false
	var inverse_denominator := 1.0 / denominator
	var u := (dot11 * dot02 - dot01 * dot12) * inverse_denominator
	var v := (dot00 * dot12 - dot01 * dot02) * inverse_denominator
	return u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001


func _uv_to_triangle_position(point: Vector2, a_position: Vector3, b_position: Vector3, c_position: Vector3, a_uv: Vector2, b_uv: Vector2, c_uv: Vector2) -> Vector3:
	var v0 := c_uv - a_uv
	var v1 := b_uv - a_uv
	var v2 := point - a_uv
	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)
	var denominator := dot00 * dot11 - dot01 * dot01
	var denominator_scale := dot00 * dot11
	if denominator_scale <= 0.0 or absf(denominator) <= denominator_scale * 1.0e-12:
		return a_position
	var inverse_denominator := 1.0 / denominator
	var bary_c := (dot11 * dot02 - dot01 * dot12) * inverse_denominator
	var bary_b := (dot00 * dot12 - dot01 * dot02) * inverse_denominator
	var bary_a := 1.0 - bary_b - bary_c
	return a_position * bary_a + b_position * bary_b + c_position * bary_c


func _get_3d_uv_overlap_distance_epsilon() -> float:
	if not _paint_3d_mesh or not _paint_3d_mesh.mesh:
		return 0.001
	var aabb := _paint_3d_mesh.mesh.get_aabb()
	var largest_axis := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	return maxf(0.001, largest_axis * 0.01)


func _warn_if_3d_hit_has_uv_overlap(hit: Dictionary) -> void:
	var overlap_count := int(hit.get("uv_overlap_count", 0))
	if overlap_count <= 0:
		return
	var warning := "Shared UVs here: %d other triangle(s) use these albedo pixels; paint may appear there too." % overlap_count
	if warning == _paint_3d_last_uv_overlap_warning:
		return
	_paint_3d_last_uv_overlap_warning = warning
	_set_status(warning)


func _shared_uv_paint_is_blocked(hit: Dictionary) -> bool:
	return PAINT_3D_BLOCK_SHARED_UV_PAINT and int(hit.get("uv_overlap_count", 0)) > 0


func _update_3d_brush_preview(hit: Dictionary) -> void:
	if not _paint_3d_brush_preview or not _paint_3d_mesh or hit.is_empty():
		return
	var local_position: Vector3 = hit.get("position", Vector3.ZERO)
	var local_normal: Vector3 = hit.get("normal", Vector3.UP)
	var world_position := _paint_3d_mesh.to_global(local_position)
	var world_normal := _local_3d_paint_normal_to_world(local_normal)
	if world_normal.length_squared() <= 0.0000001:
		world_normal = Vector3.UP
	var camera_direction := Vector3.ZERO
	if _paint_3d_camera:
		camera_direction = (_paint_3d_camera.global_position - world_position).normalized()
	if camera_direction.length_squared() <= 0.0000001:
		camera_direction = world_normal
	if world_normal.dot(camera_direction) < 0.0:
		world_normal = -world_normal

	var radius := _get_3d_brush_preview_radius(hit)
	_paint_3d_brush_preview.mesh = _make_3d_brush_preview_mesh(radius)
	_paint_3d_brush_preview.global_transform = Transform3D(_get_3d_brush_preview_basis(world_normal), world_position + camera_direction * radius * 0.08)
	_paint_3d_brush_preview.visible = true

	var material := _paint_3d_brush_preview.material_override as StandardMaterial3D
	if material:
		var color := _get_3d_brush_preview_color()
		material.albedo_color = color
		material.emission = color


func _update_3d_hover_debug_marker(hit: Dictionary) -> void:
	if not SHOW_2D_TO_3D_HOVER_MARKER or not _paint_3d_hover_debug_marker or not _paint_3d_mesh:
		return
	if not _is_valid_3d_hover_debug_hit(hit):
		_hide_3d_hover_debug_marker("UV hit data is incomplete")
		return
	var local_position: Vector3 = hit["position"]
	var local_normal: Vector3 = hit["normal"]
	var world_position := _paint_3d_mesh.to_global(local_position)
	var world_normal := _local_3d_paint_normal_to_world(local_normal)
	if world_normal.length_squared() <= 0.0000001:
		_hide_3d_hover_debug_marker("UV hit normal is invalid")
		return
	if _paint_3d_camera:
		var camera_direction := (_paint_3d_camera.global_position - world_position).normalized()
		if world_normal.dot(camera_direction) < 0.0:
			world_normal = -world_normal
	var radius := _get_3d_hover_debug_marker_radius()
	var surface_offset := maxf(0.00001, radius * 0.04)
	_paint_3d_hover_debug_marker.mesh = _make_3d_hover_debug_marker_mesh(radius)
	_paint_3d_hover_debug_marker.global_transform = Transform3D(
		_get_3d_brush_preview_basis(world_normal),
		world_position + world_normal * surface_offset
	)
	_paint_3d_hover_debug_marker.visible = true


func _is_valid_3d_hover_debug_hit(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	for key in ["uv", "position", "normal", "triangle_uvs", "triangle_positions", "surface_index", "triangle_index"]:
		if not hit.has(key):
			return false
	var triangle_uvs: PackedVector2Array = hit["triangle_uvs"]
	var triangle_positions: PackedVector3Array = hit["triangle_positions"]
	return triangle_uvs.size() >= 3 and triangle_positions.size() >= 3


func _local_3d_paint_normal_to_world(local_normal: Vector3) -> Vector3:
	if not _paint_3d_mesh:
		return local_normal.normalized()
	var basis := _paint_3d_mesh.global_transform.basis
	if is_zero_approx(basis.determinant()):
		return Vector3.ZERO
	return (basis.inverse().transposed() * local_normal).normalized()


func _get_3d_hover_debug_marker_radius() -> float:
	if not _paint_3d_mesh or not _paint_3d_mesh.mesh:
		return 0.05
	var aabb := _paint_3d_mesh.mesh.get_aabb()
	var mesh_basis := _paint_3d_mesh.global_transform.basis
	var world_size_x := (mesh_basis * Vector3(aabb.size.x, 0.0, 0.0)).length()
	var world_size_y := (mesh_basis * Vector3(0.0, aabb.size.y, 0.0)).length()
	var world_size_z := (mesh_basis * Vector3(0.0, 0.0, aabb.size.z)).length()
	var largest_axis := maxf(world_size_x, maxf(world_size_y, world_size_z))
	if largest_axis <= 0.0001:
		largest_axis = 1.0
	return largest_axis * 0.025


func _hide_3d_hover_debug_marker(reason: String = "") -> void:
	_paint_3d_last_2d_hover_pixel = Vector2i(-1, -1)
	if _paint_3d_hover_debug_marker:
		_paint_3d_hover_debug_marker.visible = false
	if DEBUG_2D_TO_3D_HOVER_DIAGNOSTICS and not reason.is_empty():
		var state := "hidden:" + reason
		if state != _paint_3d_hover_debug_state:
			_paint_3d_hover_debug_state = state
			print("GDDraw 2D->3D hover: hidden (", reason, ")")


func _update_3d_hover_triangle(hit: Dictionary) -> void:
	if not _linked_view_enabled or _canvas_mode != CANVAS_MODE_SPLIT or not _paint_3d_hover_triangle or hit.is_empty():
		_hide_3d_hover_triangle()
		return
	_paint_3d_hover_triangle.mesh = _make_3d_hover_triangle_mesh(hit)
	_paint_3d_hover_triangle.transform = _paint_3d_mesh.transform if _paint_3d_mesh else Transform3D.IDENTITY
	_paint_3d_hover_triangle.visible = true


func _hide_3d_hover_triangle() -> void:
	if _paint_3d_hover_triangle:
		_paint_3d_hover_triangle.visible = false


func _hide_3d_brush_preview() -> void:
	if _paint_3d_brush_preview:
		_paint_3d_brush_preview.visible = false
	if _canvas:
		_canvas.clear_external_hover_uv()
		_canvas.clear_external_hover_triangle()
	_hide_3d_hover_triangle()
	_update_3d_paint_cursor(false)


func _update_2d_hover_from_3d_hit(hit: Dictionary) -> void:
	if not _linked_view_enabled or _canvas_mode != CANVAS_MODE_SPLIT or not _canvas or hit.is_empty():
		return
	if _canvas_2d_host and not _canvas_2d_host.visible:
		return
	_canvas.set_external_hover_uv(hit.get("texture_uv", hit.get("uv", Vector2.ZERO)), true)
	var island_triangles: Array = []
	for island_hit in _get_3d_hover_island_hits(hit):
		var mesh_triangle_uvs: PackedVector2Array = island_hit.get("triangle_uvs", PackedVector2Array())
		var texture_triangle_uvs := PackedVector2Array()
		for mesh_triangle_uv in mesh_triangle_uvs:
			texture_triangle_uvs.push_back(_mesh_uv_to_texture_uv(mesh_triangle_uv))
		island_triangles.push_back(texture_triangle_uvs)
	_canvas.set_external_hover_triangles(island_triangles)
	_update_3d_hover_triangle(hit)


func _update_3d_paint_cursor(has_surface_hit: bool) -> void:
	if not _paint_3d_view:
		return
	var cursor_shape := Control.CURSOR_ARROW
	if _paint_3d_orbiting or _paint_3d_panning or _paint_3d_freelooking or _paint_3d_gizmo_dragging or _paint_3d_gizmo_hover_axis >= 0:
		cursor_shape = Control.CURSOR_DRAG
	elif has_surface_hit and _canvas and (
		_canvas.active_tool in [GDDrawCanvasControl.ToolMode.BRUSH, GDDrawCanvasControl.ToolMode.ERASER]
		or _is_3d_surface_shape_tool(_canvas.active_tool)
	):
		cursor_shape = Control.CURSOR_CROSS
	_paint_3d_view.mouse_default_cursor_shape = cursor_shape
	# SplitContainer can leave its resize cursor active after the pointer enters
	# a child viewport. Reassert the active tool cursor while this view handles
	# mouse motion so the divider cursor cannot remain stuck.
	_set_input_cursor_shape_for_3d_view(cursor_shape)


func _on_3d_paint_view_mouse_exited() -> void:
	_cancel_3d_rotation_gizmo_drag(true)
	_set_3d_rotation_gizmo_hover_axis(-1)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _set_input_cursor_shape_for_3d_view(cursor_shape: Control.CursorShape) -> void:
	match cursor_shape:
		Control.CURSOR_CROSS:
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		Control.CURSOR_DRAG:
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		_:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _get_3d_brush_preview_radius(hit: Dictionary) -> float:
	if not _paint_3d_mesh or not _paint_3d_mesh.mesh or not _canvas:
		return 0.05
	var canvas_size: Vector2i = _canvas.get_canvas_size()
	var triangle_uvs: PackedVector2Array = hit.get("triangle_uvs", PackedVector2Array())
	var triangle_positions: PackedVector3Array = hit.get("triangle_positions", PackedVector3Array())
	if triangle_uvs.size() >= 3 and triangle_positions.size() >= 3 and canvas_size.x > 0 and canvas_size.y > 0:
		var world_per_pixel := _get_3d_triangle_world_per_texture_pixel(triangle_positions, triangle_uvs, canvas_size)
		if world_per_pixel > 0.0:
			return maxf(0.0001, float(maxi(1, _canvas.brush_size)) * 0.5 * world_per_pixel)
	return _get_fallback_3d_brush_preview_radius()


func _get_fallback_3d_brush_preview_radius() -> float:
	if not _paint_3d_mesh or not _paint_3d_mesh.mesh or not _canvas:
		return 0.05
	var canvas_size: Vector2i = _canvas.get_canvas_size()
	var texture_axis := maxi(1, maxi(canvas_size.x, canvas_size.y))
	var aabb := _paint_3d_mesh.mesh.get_aabb()
	var largest_axis := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if largest_axis <= 0.0:
		largest_axis = 1.0
	var uv_fraction := float(maxi(1, _canvas.brush_size)) / float(texture_axis)
	return clampf(largest_axis * uv_fraction * 0.8, largest_axis * 0.018, largest_axis * 0.22)


func _get_3d_triangle_world_per_texture_pixel(triangle_positions: PackedVector3Array, triangle_uvs: PackedVector2Array, canvas_size: Vector2i) -> float:
	var scales: Array[float] = []
	_add_3d_triangle_edge_scale(scales, triangle_positions[0], triangle_positions[1], triangle_uvs[0], triangle_uvs[1], canvas_size)
	_add_3d_triangle_edge_scale(scales, triangle_positions[1], triangle_positions[2], triangle_uvs[1], triangle_uvs[2], canvas_size)
	_add_3d_triangle_edge_scale(scales, triangle_positions[2], triangle_positions[0], triangle_uvs[2], triangle_uvs[0], canvas_size)
	if scales.is_empty():
		return 0.0
	var total := 0.0
	for scale in scales:
		total += scale
	return total / float(scales.size())


func _add_3d_triangle_edge_scale(scales: Array[float], from_position: Vector3, to_position: Vector3, from_uv: Vector2, to_uv: Vector2, canvas_size: Vector2i) -> void:
	var uv_delta := Vector2((to_uv.x - from_uv.x) * float(canvas_size.x), (to_uv.y - from_uv.y) * float(canvas_size.y))
	var texture_pixels := uv_delta.length()
	if texture_pixels <= 0.0001:
		return
	var world_from := _paint_3d_mesh.to_global(from_position)
	var world_to := _paint_3d_mesh.to_global(to_position)
	var world_length := world_from.distance_to(world_to)
	if world_length <= 0.000001:
		return
	scales.push_back(world_length / texture_pixels)


func _get_3d_brush_preview_basis(normal: Vector3) -> Basis:
	var tangent := normal.cross(Vector3.UP)
	if tangent.length_squared() <= 0.000001:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := normal.cross(tangent).normalized()
	return Basis(tangent, bitangent, normal)


func _get_3d_brush_preview_color() -> Color:
	if not _canvas:
		return Color(1.0, 1.0, 1.0, 0.72)
	var color: Color = Color.WHITE if _canvas.active_tool == GDDrawCanvasControl.ToolMode.ERASER else _canvas.brush_color
	if _canvas.active_tool == GDDrawCanvasControl.ToolMode.FILL or _canvas.active_tool == GDDrawCanvasControl.ToolMode.EYEDROPPER:
		color = Color(1.0, 1.0, 1.0, 1.0)
	color.a = 0.72
	return color


func _refresh_3d_brush_preview_color() -> void:
	if not _paint_3d_brush_preview:
		return
	var material := _paint_3d_brush_preview.material_override as StandardMaterial3D
	if not material:
		return
	var color := _get_3d_brush_preview_color()
	material.albedo_color = color
	material.emission = color


func _begin_3d_soft_brush_stroke() -> void:
	if not _canvas or _paint_3d_soft_brush_active:
		return
	if _canvas.brush_touch_pixels:
		return
	_paint_3d_saved_pixel_perfect = _canvas.pixel_perfect
	_paint_3d_soft_brush_active = true
	_canvas.pixel_perfect = false


func _end_3d_soft_brush_stroke() -> void:
	if not _canvas or not _paint_3d_soft_brush_active:
		return
	_canvas.pixel_perfect = _paint_3d_saved_pixel_perfect
	_paint_3d_soft_brush_active = false


func _pan_3d_paint_camera(delta: Vector2) -> void:
	if not _paint_3d_camera:
		return
	var scale := _paint_3d_distance * 0.0018
	var right := _paint_3d_camera.global_transform.basis.x
	var up := _paint_3d_camera.global_transform.basis.y
	_paint_3d_target += (-right * delta.x + up * delta.y) * scale
	_update_3d_paint_camera()


func _start_3d_freelook() -> void:
	if _paint_3d_freelooking:
		return
	_release_3d_editor_camera_basis_override()
	_paint_3d_freelooking = true
	_paint_3d_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hide_3d_brush_preview()


func _stop_3d_freelook() -> void:
	if not _paint_3d_freelooking:
		return
	_paint_3d_freelooking = false
	Input.mouse_mode = _paint_3d_previous_mouse_mode


func _apply_3d_look_delta(delta: Vector2) -> void:
	_paint_3d_yaw -= delta.x * 0.01
	_paint_3d_pitch = clampf(_paint_3d_pitch + delta.y * 0.01, -1.45, 1.45)


func _freelook_3d_paint_camera(delta: Vector2) -> void:
	if not _paint_3d_camera:
		return
	var camera_position := _paint_3d_camera.position
	_apply_3d_look_delta(delta)
	var offset := Vector3(
		sin(_paint_3d_yaw) * cos(_paint_3d_pitch),
		sin(_paint_3d_pitch),
		cos(_paint_3d_yaw) * cos(_paint_3d_pitch)
	) * _paint_3d_distance
	_paint_3d_target = camera_position - offset
	_update_3d_paint_camera()


func _move_3d_freelook_camera(forward_axis: float, right_axis: float, vertical_axis: float, delta: float, speed_modifier := 1.0) -> void:
	if not _paint_3d_camera:
		return
	var movement := (
		-_paint_3d_camera.transform.basis.z * forward_axis
		+ _paint_3d_camera.transform.basis.x * right_axis
		+ Vector3.UP * vertical_axis
	)
	if movement.length_squared() <= 0.000001:
		return
	var speed := maxf(0.1, _paint_3d_distance) * 0.8 * _paint_3d_freelook_speed_multiplier * speed_modifier
	_paint_3d_target += movement.normalized() * speed * delta
	_update_3d_paint_camera()


func _update_3d_paint_camera() -> void:
	if not _paint_3d_camera:
		return
	if _paint_3d_camera_basis_override_active:
		var camera_basis := _paint_3d_camera_basis_override.orthonormalized()
		var camera_position := _paint_3d_target + camera_basis.z * _paint_3d_distance
		_paint_3d_camera.transform = Transform3D(camera_basis, camera_position)
	else:
		var offset := Vector3(
			cos(_paint_3d_pitch) * sin(_paint_3d_yaw),
			sin(_paint_3d_pitch),
			cos(_paint_3d_pitch) * cos(_paint_3d_yaw)
		) * _paint_3d_distance
		var camera_position := _paint_3d_target + offset
		_paint_3d_camera.look_at_from_position(camera_position, _paint_3d_target, Vector3.UP)
	_update_preview_light_transform()
	_update_3d_rotation_gizmo_transform()
	_update_3d_view_readout()


func _resize_3d_paint_viewport() -> void:
	if not _paint_3d_viewport or not _paint_3d_view:
		return
	if _paint_3d_view.stretch:
		_update_3d_rotation_gizmo_transform()
		return
	_paint_3d_viewport.size = Vector2i(maxi(1, roundi(_paint_3d_view.size.x)), maxi(1, roundi(_paint_3d_view.size.y)))
	_update_3d_rotation_gizmo_transform()


func _connect_editor_selection_changed() -> void:
	if not _plugin:
		return
	_editor_selection = _plugin.get_editor_interface().get_selection()
	if _editor_selection and not _editor_selection.selection_changed.is_connected(_on_editor_selection_changed):
		_editor_selection.selection_changed.connect(_on_editor_selection_changed)


func _disconnect_editor_selection_changed() -> void:
	if _editor_selection and _editor_selection.selection_changed.is_connected(_on_editor_selection_changed):
		_editor_selection.selection_changed.disconnect(_on_editor_selection_changed)
	_editor_selection = null


func _on_editor_selection_changed() -> void:
	if not _canvas_mode_3d:
		return
	if not _texture_3d_session or not _texture_3d_session.has_active_session():
		_update_3d_selection_status()


func _update_3d_selection_status() -> void:
	if not _canvas_mode_3d:
		return
	var surface_target := _get_selected_3d_surface_node()
	if surface_target:
		_set_status("Selected %s. Use the selected-surface button to inspect its texture." % surface_target.name)
	else:
		_set_status("No 3D session. Select or drag a mesh or supported CSG shape into GDDraw.")


func _get_3d_target_mesh_instance():
	return _get_selected_3d_surface_node()


func _get_selected_mesh_instance() -> MeshInstance3D:
	return _get_selected_3d_surface_node() as MeshInstance3D


func _get_selected_3d_surface_node() -> Node3D:
	if not _plugin:
		return null
	var selected_nodes := _plugin.get_editor_interface().get_selection().get_selected_nodes()
	for node in selected_nodes:
		var surface_target := _find_first_editable_3d_surface(node)
		if surface_target:
			return surface_target
	return null


func _extract_drop_mesh_instance(data: Variant):
	if data is MeshInstance3D or data is CSGShape3D:
		return data
	if data is Mesh:
		return _get_selected_mesh_instance_for_mesh(data)
	if data is String:
		var path := str(data).strip_edges()
		if path.begins_with("res://"):
			var resource := ResourceLoader.load(path)
			if resource is Mesh:
				return _get_selected_mesh_instance_for_mesh(resource)
	if data is Array:
		for item in data:
			var mesh: Node3D = _extract_drop_mesh_instance(item)
			if mesh:
				return mesh
	if data is Dictionary:
		if data.has("nodes"):
			var node_mesh: Node3D = _extract_mesh_instance_from_dragged_nodes(data["nodes"])
			if node_mesh:
				return node_mesh
		for key in ["resource", "mesh", "resource_path"]:
			if data.has(key):
				var resource_mesh: Node3D = _extract_drop_mesh_instance(data[key])
				if resource_mesh:
					return resource_mesh
	return null


func _extract_mesh_instance_from_dragged_nodes(nodes_data: Variant):
	var nodes: Array = []
	if nodes_data is Array:
		nodes = nodes_data
	else:
		nodes = [nodes_data]
	for node_data in nodes:
		var node := _get_dragged_scene_node(node_data)
		var surface_target := _find_first_editable_3d_surface(node)
		if surface_target:
			return surface_target
	# Godot's Scene dock keeps the dragged node selected. This fallback covers
	# editor-version-specific NodePath formats that cannot be resolved directly.
	return _get_selected_3d_surface_node()


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	return _find_first_editable_3d_surface(node) as MeshInstance3D


func _find_first_editable_3d_surface(node: Node) -> Node3D:
	if not node:
		return null
	if node is MeshInstance3D and node.mesh:
		return node
	# CSG combiners are containers, not assignable material targets. Resolve a
	# suitable material-bearing descendant instead of choosing generated slots.
	if node is CSGShape3D and node.has_method("get_material") and node.has_method("set_material"):
		return node
	for child in node.get_children():
		var child_surface := _find_first_editable_3d_surface(child)
		if child_surface:
			return child_surface
	return null


func _get_single_scene_mesh_instance() -> MeshInstance3D:
	if not _plugin:
		return null
	var scene_root := _plugin.get_editor_interface().get_edited_scene_root()
	if not scene_root:
		return null
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(scene_root, meshes, 2)
	return meshes[0] if meshes.size() == 1 else null


func _collect_mesh_instances(node: Node, meshes: Array[MeshInstance3D], limit: int) -> void:
	if not node or meshes.size() >= limit:
		return
	if node is MeshInstance3D and node.mesh:
		meshes.push_back(node)
		if meshes.size() >= limit:
			return
	for child in node.get_children():
		_collect_mesh_instances(child, meshes, limit)
		if meshes.size() >= limit:
			return


func _get_selected_mesh_instance_for_mesh(mesh: Mesh) -> MeshInstance3D:
	if not mesh or not _plugin:
		return null
	var selected_nodes := _plugin.get_editor_interface().get_selection().get_selected_nodes()
	for node in selected_nodes:
		var mesh_instance := _find_mesh_instance_for_mesh(node, mesh)
		if mesh_instance:
			return mesh_instance
	return null


func _find_mesh_instance_for_mesh(node: Node, mesh: Mesh) -> MeshInstance3D:
	if not node:
		return null
	if node is MeshInstance3D and _mesh_resources_match(node.mesh, mesh):
		return node
	for child in node.get_children():
		var child_mesh := _find_mesh_instance_for_mesh(child, mesh)
		if child_mesh:
			return child_mesh
	return null


func _mesh_resources_match(left: Mesh, right: Mesh) -> bool:
	if not left or not right:
		return false
	if left == right:
		return true
	var left_path := left.resource_path.strip_edges()
	var right_path := right.resource_path.strip_edges()
	return not left_path.is_empty() and left_path == right_path


func _get_texture_image(texture: Texture2D) -> Image:
	if not texture:
		return null
	var image := texture.get_image()
	if not image or image.is_empty():
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _get_system_clipboard_image_source() -> Dictionary:
	if not _system_clipboard_available():
		return {}
	if DisplayServer.clipboard_has_image():
		var image := DisplayServer.clipboard_get_image()
		if image and not image.is_empty():
			if image.get_format() != Image.FORMAT_RGBA8:
				image.convert(Image.FORMAT_RGBA8)
			return {"image": image, "label": "clipboard image"}

	var image_path := _get_clipboard_image_path()
	if image_path.is_empty():
		return {}

	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(image_path) if image_path.begins_with("res://") else image_path)
	if error != OK:
		return {}
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return {"image": image, "label": image_path}


func _get_system_clipboard_image() -> Image:
	return _get_system_clipboard_image_source().get("image", null)


func _get_clipboard_image_path() -> String:
	if not _system_clipboard_available() or not DisplayServer.clipboard_has():
		return ""
	var clipboard_text := DisplayServer.clipboard_get().strip_edges()
	if clipboard_text.is_empty():
		return ""
	for candidate in clipboard_text.split("\n", false):
		var path := _normalize_clipboard_path(candidate)
		if _is_supported_filesystem_image_path(path):
			return path
	return ""


func _normalize_clipboard_path(value: String) -> String:
	return _normalize_filesystem_path(value)


func _normalize_filesystem_path(value: String) -> String:
	var path := value.strip_edges().strip_escapes()
	if path.begins_with("\"") and path.ends_with("\""):
		path = path.substr(1, path.length() - 2)
	if path.begins_with("file:///"):
		path = path.substr(8)
		if OS.get_name() == "Windows" and path.length() > 2 and path[0] == "/" and path[2] == ":":
			path = path.substr(1)
	path = path.replace("\\", "/")
	return path


func _is_supported_filesystem_image_path(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("res://"):
		return _is_supported_image_path(path)
	var extension := path.get_extension().to_lower()
	if not extension in ["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"]:
		return false
	return FileAccess.file_exists(path)


func _system_clipboard_available() -> bool:
	return DisplayServer.get_name() != "headless"


func _get_dragged_scene_node(node_data: Variant) -> Node:
	if node_data is Node:
		return node_data
	var node_path := str(node_data)
	if node_path.is_empty() or not _plugin:
		return null
	var scene_root := _plugin.get_editor_interface().get_edited_scene_root()
	if not scene_root:
		return null
	if node_path in [".", scene_root.name, str(scene_root.get_path())]:
		return scene_root
	var local_node := scene_root.get_node_or_null(NodePath(node_path))
	if local_node:
		return local_node
	var root_prefix := scene_root.name + "/"
	if node_path.begins_with(root_prefix):
		local_node = scene_root.get_node_or_null(NodePath(node_path.trim_prefix(root_prefix)))
		if local_node:
			return local_node
	var absolute_node := get_tree().root.get_node_or_null(NodePath(node_path))
	if absolute_node:
		return absolute_node
	return null


func _get_resource_image_path(resource: Resource) -> String:
	if not resource:
		return ""
	var path := resource.resource_path
	if _is_supported_image_path(path):
		return path
	if resource is Texture2D and path.ends_with(".import"):
		var source_path := path.trim_suffix(".import")
		if _is_supported_image_path(source_path):
			return source_path
	return ""


func _is_supported_image_path(path: String) -> bool:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty() or not normalized_path.begins_with("res://"):
		return false
	return normalized_path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"]


func _connect_window_file_drop() -> void:
	_disconnect_window_file_drop()
	var window := get_window()
	if not window:
		return
	_file_drop_window = window
	if not _file_drop_window.files_dropped.is_connected(_on_window_files_dropped):
		_file_drop_window.files_dropped.connect(_on_window_files_dropped)


func _disconnect_window_file_drop() -> void:
	if _file_drop_window and _file_drop_window.files_dropped.is_connected(_on_window_files_dropped):
		_file_drop_window.files_dropped.disconnect(_on_window_files_dropped)
	_file_drop_window = null


func _on_window_files_dropped(files: PackedStringArray) -> void:
	if _is_mouse_over_custom_fill_drop_target():
		for file in files:
			var custom_path := _normalize_filesystem_path(file)
			if _is_supported_filesystem_image_path(custom_path):
				_set_staged_custom_fill_from_path(custom_path)
				return
		_set_status("Drop a supported image file into the Custom fill source area.")
		return
	if not _is_mouse_over_canvas_area():
		return
	for file in files:
		var path := _normalize_filesystem_path(file)
		if _is_supported_filesystem_image_path(path):
			_on_canvas_image_drop_requested(path)
			return
	_set_status("Drop a supported image file onto the canvas.")


func _is_mouse_over_custom_fill_drop_target() -> bool:
	if not _fill_settings_overlay or not _fill_settings_overlay.visible or not _custom_fill_drop_target or not _custom_fill_drop_target.is_visible_in_tree():
		return false
	var window := _file_drop_window if _file_drop_window else get_window()
	if not window:
		return _custom_fill_drop_target.get_global_rect().has_point(_custom_fill_drop_target.get_global_mouse_position())
	var target_screen_position := Vector2(window.position) + _custom_fill_drop_target.get_global_rect().position
	return Rect2(target_screen_position, _custom_fill_drop_target.size).has_point(Vector2(DisplayServer.mouse_get_position()))


func _is_mouse_over_canvas_area() -> bool:
	if not _canvas_region or not _canvas_region.is_visible_in_tree():
		return false
	# Native OS file drags (notably Windows Explorer drags) may not send
	# viewport mouse-motion events before Window.files_dropped. In that case
	# get_local_mouse_position() is stale, so compare the OS cursor with the
	# canvas's screen-space rectangle first.
	var window := _file_drop_window if _file_drop_window else get_window()
	if window:
		var canvas_screen_position := Vector2(window.position) + _canvas_region.get_global_rect().position
		var canvas_screen_rect := Rect2(canvas_screen_position, _canvas_region.size)
		if canvas_screen_rect.has_point(Vector2(DisplayServer.mouse_get_position())):
			return true
	return Rect2(Vector2.ZERO, _canvas_region.size).has_point(_canvas_region.get_local_mouse_position())


func _create_sprite() -> void:
	if not _canvas or not _canvas.has_visible_pixels():
		_set_status("Draw or load visible pixels before creating a Sprite2D.")
		_sync_menu_state()
		return
	var result: Dictionary = _sprite_creator.create_sprite(_plugin, _canvas.get_image_copy())
	_set_status(str(result.get(GDDrawSpriteCreatorHelper.MESSAGE, "")))


func _show_create_textured_csg_dialog() -> void:
	_ensure_helpers()
	if not _create_textured_csg_overlay:
		_set_status("The CSG creation dialog is not ready yet.")
		return
	if _settings_overlay:
		_settings_overlay.visible = false
	if _fill_settings_overlay:
		_fill_settings_overlay.visible = false
	if _update_available_overlay:
		_update_available_overlay.visible = false
	var overlay_parent := _create_textured_csg_overlay.get_parent()
	if overlay_parent:
		overlay_parent.move_child(_create_textured_csg_overlay, overlay_parent.get_child_count() - 1)
	_update_create_textured_csg_validation()
	_create_textured_csg_overlay.visible = true
	if _create_textured_csg_shape:
		_create_textured_csg_shape.grab_focus()


func _close_create_textured_csg_overlay() -> void:
	if _create_textured_csg_overlay:
		_create_textured_csg_overlay.visible = false


# Compatibility wrapper for the previous dock entry point.
func _create_csg_box() -> void:
	_show_create_textured_csg_dialog()


func _get_create_textured_csg_options() -> Dictionary:
	var shape := GDDrawSpriteCreatorHelper.CSGShape.BOX
	if _create_textured_csg_shape:
		shape = _create_textured_csg_shape.get_selected_id()
	return {
		GDDrawSpriteCreatorHelper.OPTION_SHAPE: shape,
		GDDrawSpriteCreatorHelper.OPTION_ASSIGN_CURRENT_IMAGE: (
			_create_textured_csg_assign_image != null
			and _create_textured_csg_assign_image.button_pressed
		),
		GDDrawSpriteCreatorHelper.OPTION_SELECT_CREATED_NODE: (
			_create_textured_csg_select_node != null
			and _create_textured_csg_select_node.button_pressed
		),
		GDDrawSpriteCreatorHelper.OPTION_ENABLE_COLLISION: (
			_create_textured_csg_enable_collision != null
			and _create_textured_csg_enable_collision.button_pressed
		),
	}


func _update_create_textured_csg_validation(_unused: Variant = null) -> void:
	if not _create_textured_csg_validation or not _create_textured_csg_overlay:
		return
	_ensure_helpers()
	var options := _get_create_textured_csg_options()
	var image: Image
	if options[GDDrawSpriteCreatorHelper.OPTION_ASSIGN_CURRENT_IMAGE] and _canvas:
		image = _canvas.get_image_copy()
	var result: Dictionary = _sprite_creator.validate_csg_creation(
		_plugin,
		image,
		_get_default_save_dir(),
		options
	)
	var valid: bool = result.get(GDDrawSpriteCreatorHelper.SUCCESS, false)
	_create_textured_csg_validation.text = str(result.get(GDDrawSpriteCreatorHelper.MESSAGE, ""))
	_create_textured_csg_validation.add_theme_color_override(
		"font_color",
		get_theme_color("success_color", "Editor") if valid else get_theme_color("error_color", "Editor")
	)
	if _create_textured_csg_create_button:
		_create_textured_csg_create_button.disabled = not valid


func _confirm_create_textured_csg() -> void:
	var options := _get_create_textured_csg_options()
	var image: Image
	if options[GDDrawSpriteCreatorHelper.OPTION_ASSIGN_CURRENT_IMAGE] and _canvas:
		image = _canvas.get_image_copy()
	var result: Dictionary = _sprite_creator.create_textured_csg(
		_plugin,
		image,
		_get_default_save_dir(),
		options
	)
	_set_status(str(result.get(GDDrawSpriteCreatorHelper.MESSAGE, "")))
	if result.get(GDDrawSpriteCreatorHelper.SUCCESS, false):
		_close_create_textured_csg_overlay()
	else:
		_update_create_textured_csg_validation()


func _save_png_to_path(path: String) -> void:
	var succeeded := _save_2d_document_to_path(path)
	if _save_2d_for_3d_transition and _pending_session_transition == SessionTransition.START_3D_SESSION:
		_save_2d_for_3d_transition = false
		if succeeded:
			_continue_pending_session_transition()
		elif _document_session_dialog:
			_document_session_dialog.call_deferred("popup_centered")


func _save_2d_document_to_path(path: String) -> bool:
	var normalized_path := _normalize_png_path(path)
	if normalized_path.is_empty():
		_set_status("Choose a PNG path inside res:// and outside res://addons/GDDraw.")
		return false

	var save_dir := normalized_path.get_base_dir()
	var error := _ensure_resource_dir(save_dir)
	if error != OK:
		_set_status("Could not create save folder. Error: " + str(error))
		return false

	_canvas.finish_text_draft(true)
	var saved_image: Image = _canvas.get_image_copy()
	error = saved_image.save_png(normalized_path)
	if error != OK:
		_set_status("Could not save PNG. Error: " + str(error))
		return false

	_set_default_save_dir(save_dir)
	_set_2d_document_baseline(normalized_path, saved_image)
	if _plugin:
		_plugin.get_editor_interface().get_resource_filesystem().scan()
	if not _load_after_save_path.is_empty() or _load_after_save_image != null:
		var image_path := _load_after_save_path
		var image := _load_after_save_image
		var label := _load_after_save_label
		_load_after_save_path = ""
		_load_after_save_image = null
		_load_after_save_label = ""
		_load_pending_drop(image_path, image, label)
		return true
	_set_status("Saved " + normalized_path)
	return true


func _cancel_2d_save_as() -> void:
	if not _save_2d_for_3d_transition or _pending_session_transition != SessionTransition.START_3D_SESSION:
		return
	_save_2d_for_3d_transition = false
	if _document_session_dialog:
		_document_session_dialog.call_deferred("popup_centered")
	_set_status("Save As canceled; the unsaved 2D workspace is unchanged.")


func _set_2d_document_baseline(path: String, image: Image) -> void:
	_document_path = path
	if not image:
		_document_baseline_image = null
		return
	_document_baseline_image = image.duplicate()
	if _document_baseline_image.get_format() != Image.FORMAT_RGBA8:
		_document_baseline_image.convert(Image.FORMAT_RGBA8)


func _is_2d_document_dirty() -> bool:
	if not _canvas or not _document_baseline_image:
		return false
	return _canvas.has_text_draft() or not _images_equal_rgba8(_canvas.get_image_copy(), _document_baseline_image)


func _images_equal_rgba8(left: Image, right: Image) -> bool:
	if not left or not right or left.get_size() != right.get_size():
		return false
	var left_rgba := left.duplicate()
	var right_rgba := right.duplicate()
	if left_rgba.get_format() != Image.FORMAT_RGBA8:
		left_rgba.convert(Image.FORMAT_RGBA8)
	if right_rgba.get_format() != Image.FORMAT_RGBA8:
		right_rgba.convert(Image.FORMAT_RGBA8)
	return left_rgba.get_data() == right_rgba.get_data()


func _get_document_path_from_label(label: String) -> String:
	var normalized := label.strip_edges()
	if normalized.begins_with("res://") and normalized.get_extension().to_lower() == "png":
		return normalized
	return ""


func _make_default_png_name() -> String:
	return _png_io.make_default_png_name()


func _normalize_png_path(path: String) -> String:
	return _png_io.normalize_png_path(path)


func _ensure_resource_dir(path: String) -> int:
	return _png_io.ensure_resource_dir(path)


func _get_default_save_dir() -> String:
	return _png_io.get_default_save_dir(_get_editor_settings())


func _get_default_font_dir() -> String:
	return StoragePaths.get_default_font_dir(_get_editor_settings())


func _set_default_font_dir(path: String) -> void:
	StoragePaths.set_default_font_dir(_get_editor_settings(), path)


func _font_directory_exists(path: String) -> bool:
	if path.strip_edges().is_empty():
		return false
	var filesystem_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	return DirAccess.dir_exists_absolute(filesystem_path)


func _font_directory_dialog_path(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


func _set_default_save_dir(path: String) -> void:
	var normalized_path := path.strip_edges()
	if not _png_io.set_default_save_dir(_get_editor_settings(), normalized_path):
		_set_status("Default save location must be inside res:// and outside res://addons/GDDraw.")
		return
	if _save_location:
		_save_location.text = normalized_path


func _get_default_canvas_size() -> Vector2i:
	var editor_settings := _get_editor_settings()
	if editor_settings:
		var stored_size: Variant = editor_settings.get_project_metadata(SETTINGS_SECTION, DEFAULT_CANVAS_SIZE_KEY, DEFAULT_CANVAS_SIZE)
		if stored_size is Vector2i:
			return _clamp_canvas_size(stored_size)
		if stored_size is Vector2:
			return _clamp_canvas_size(Vector2i(stored_size))
		if stored_size is String:
			return _parse_canvas_size_string(stored_size)
	return DEFAULT_CANVAS_SIZE


func _set_default_canvas_size(default_size: Vector2i) -> void:
	var clamped_size := _clamp_canvas_size(default_size)
	var editor_settings := _get_editor_settings()
	if editor_settings:
		editor_settings.set_project_metadata(SETTINGS_SECTION, DEFAULT_CANVAS_SIZE_KEY, clamped_size)


func _clamp_canvas_size(canvas_size: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(canvas_size.x, GDDrawCanvasControl.MIN_IMAGE_SIZE, GDDrawCanvasControl.MAX_IMAGE_SIZE),
		clampi(canvas_size.y, GDDrawCanvasControl.MIN_IMAGE_SIZE, GDDrawCanvasControl.MAX_IMAGE_SIZE)
	)


func _parse_canvas_size_string(value: String) -> Vector2i:
	var normalized_value := value.strip_edges().to_lower()
	var separator := "x" if normalized_value.contains("x") else ","
	var parts := normalized_value.split(separator, false)
	if parts.size() != 2:
		return DEFAULT_CANVAS_SIZE
	return _clamp_canvas_size(Vector2i(
		_parse_bounded_int(parts[0], GDDrawCanvasControl.MIN_IMAGE_SIZE, GDDrawCanvasControl.MAX_IMAGE_SIZE, DEFAULT_CANVAS_SIZE.x),
		_parse_bounded_int(parts[1], GDDrawCanvasControl.MIN_IMAGE_SIZE, GDDrawCanvasControl.MAX_IMAGE_SIZE, DEFAULT_CANVAS_SIZE.y)
	))


func _get_editor_settings() -> Object:
	if not _plugin:
		return null
	return _plugin.get_editor_interface().get_editor_settings()


func _on_save_location_submitted(path: String) -> void:
	_apply_save_location(path)


func _on_save_location_focus_exited() -> void:
	if _save_location:
		_apply_save_location(_save_location.text)


func _apply_save_location(path: String) -> void:
	var normalized_path := StoragePaths.normalize_path(path)
	if normalized_path.is_empty():
		normalized_path = GDDrawPngIOHelper.DEFAULT_SAVE_DIR
	if not StoragePaths.is_writable_project_path(normalized_path):
		_set_status("Default save location must be inside res:// and outside res://addons/GDDraw.")
		if _save_location:
			_save_location.text = _get_default_save_dir()
		return
	_set_default_save_dir(normalized_path)
	_set_status("Default save location set to " + normalized_path)


func _show_save_location_dialog() -> void:
	if not _save_location_dialog:
		return
	var save_dir := _get_default_save_dir()
	_save_location_dialog.current_dir = save_dir
	_save_location_dialog.popup_centered_ratio(0.75)


func _on_save_location_selected(path: String) -> void:
	_apply_save_location(path)


func _on_font_location_submitted(path: String) -> void:
	_apply_font_location(path)


func _on_font_location_focus_exited() -> void:
	if _font_location:
		_apply_font_location(_font_location.text)


func _apply_font_location(path: String) -> void:
	var normalized_path := path.strip_edges().replace("\\", "/")
	if normalized_path.is_empty():
		normalized_path = DEFAULT_FONT_DIRECTORY
	if not _font_directory_exists(normalized_path):
		_set_status("Font location must be an existing folder.")
		if _font_location:
			_font_location.text = _get_default_font_dir()
		return
	_set_default_font_dir(normalized_path)
	if _font_location:
		_font_location.text = normalized_path
	_refresh_text_font_selector()
	_set_status("Custom font location set to " + normalized_path)


func _show_font_location_dialog() -> void:
	if not _font_location_dialog:
		return
	var font_dir := _get_default_font_dir()
	if _font_directory_exists(font_dir):
		_font_location_dialog.current_dir = _font_directory_dialog_path(font_dir)
	_font_location_dialog.popup_centered_ratio(0.75)


func _on_font_location_selected(path: String) -> void:
	_apply_font_location(path)


func _push_undo(image: Image) -> void:
	_history.push_undo(image)


func _update_history_buttons() -> void:
	_sync_menu_state()


func _update_selection_action_buttons() -> void:
	if not _canvas:
		return
	var has_selection: bool = _canvas.has_active_selection()
	var show_floating: bool = _canvas.has_floating_selection()
	var has_active_texture: bool = _texture_3d_session != null and _texture_3d_session.has_active_session()
	var has_paste: bool = _has_paste_available()
	for button in [
		_selection_flip_horizontal_button,
		_selection_flip_vertical_button,
		_selection_copy_button,
		_selection_cut_button,
		_selection_rotate_left_button,
		_selection_rotate_right_button,
	]:
		if button:
			button.disabled = not has_selection
			_update_icon_button_icon(button)
	if _selection_crop_button:
		_selection_crop_button.disabled = not has_selection or has_active_texture
		_update_icon_button_icon(_selection_crop_button)
	if _selection_paste_button:
		_selection_paste_button.disabled = not has_paste
		_update_icon_button_icon(_selection_paste_button)
	if _selection_rotate_amount:
		_selection_rotate_amount.editable = has_selection
	if _selection_commit_separator:
		_selection_commit_separator.visible = show_floating
	if _selection_commit_button:
		_selection_commit_button.visible = show_floating
	if _selection_cancel_button:
		_selection_cancel_button.visible = show_floating
	_sync_menu_state()


func _has_paste_available() -> bool:
	if _canvas and _canvas.has_clipboard_image():
		return true
	if _system_clipboard_available() and DisplayServer.clipboard_has_image():
		return true
	return not _get_clipboard_image_path().is_empty()


func _update_tool_options_visibility() -> void:
	if not _canvas:
		return
	_update_text_rotation_controls()
	var tool: int = _canvas.active_tool
	var is_shape_tool := tool == GDDrawCanvasControl.ToolMode.LINE or tool == GDDrawCanvasControl.ToolMode.RECTANGLE or tool == GDDrawCanvasControl.ToolMode.ELLIPSE
	var is_selection_tool := tool == GDDrawCanvasControl.ToolMode.SELECT or tool == GDDrawCanvasControl.ToolMode.LASSO_SELECT
	var is_stroke_tool := tool == GDDrawCanvasControl.ToolMode.BRUSH or tool == GDDrawCanvasControl.ToolMode.ERASER
	var is_text_tool := tool == GDDrawCanvasControl.ToolMode.TEXT
	if is_text_tool:
		_move_shared_color_controls(_text_options)
	else:
		_move_shared_paint_controls(_shape_options if is_shape_tool else _brush_options)
	if _brush_options:
		_brush_options.visible = tool == GDDrawCanvasControl.ToolMode.BRUSH or tool == GDDrawCanvasControl.ToolMode.ERASER or tool == GDDrawCanvasControl.ToolMode.FILL
	if _shape_options:
		_shape_options.visible = is_shape_tool
	if _text_options:
		_text_options.visible = is_text_tool
	if _selection_options:
		_selection_options.visible = is_selection_tool
	if _eyedropper_options:
		_eyedropper_options.visible = tool == GDDrawCanvasControl.ToolMode.EYEDROPPER
	if _mirror_options:
		_mirror_options.visible = (
			tool == GDDrawCanvasControl.ToolMode.BRUSH
			or tool == GDDrawCanvasControl.ToolMode.ERASER
			or tool == GDDrawCanvasControl.ToolMode.FILL
			or is_shape_tool
		)
	var is_fill := tool == GDDrawCanvasControl.ToolMode.FILL
	if _brush_size_label:
		_brush_size_label.visible = not is_fill
	if _brush_size:
		_brush_size.visible = not is_fill
	if _color_set_separator:
		_color_set_separator.visible = true
	if _swap_colors_button:
		_swap_colors_button.visible = true
		_swap_colors_button.tooltip_text = "Swap text and text-box colors" if is_text_tool else "Swap foreground and background colors"
	if _foreground_color_picker:
		_foreground_color_picker.tooltip_text = "Text color" if is_text_tool else "Foreground color"
	if _background_color_picker:
		_background_color_picker.visible = true
		_background_color_picker.tooltip_text = "Text-box background color" if is_text_tool else "Background color"
	if _paint_size_separator:
		_paint_size_separator.visible = not is_fill
	if _brush_preset:
		_brush_preset.visible = false
	if _recent_brush_size_selector:
		_recent_brush_size_selector.visible = false
	if _brush_head:
		_brush_head.visible = is_stroke_tool
	if _brush_head_separator:
		_brush_head_separator.visible = is_stroke_tool
	if _pixel_perfect_mode:
		_pixel_perfect_mode.visible = is_stroke_tool
	var show_tool_hardness: bool = is_stroke_tool and not _canvas.pixel_perfect
	if _tool_brush_hardness_label:
		_tool_brush_hardness_label.visible = show_tool_hardness
	if _tool_brush_hardness:
		_tool_brush_hardness.visible = show_tool_hardness
	if _brush_touch_pixels:
		_brush_touch_pixels.visible = false
	if _alpha_lock:
		_alpha_lock.visible = false
	if _tool_stroke_overlap:
		_tool_stroke_overlap.visible = false
	if _fill_tolerance_label:
		_fill_tolerance_label.visible = is_fill
	if _fill_tolerance:
		_fill_tolerance.visible = is_fill
	if _fill_mode:
		_fill_mode.visible = is_fill
	if _fill_style:
		_fill_style.visible = is_fill
	if _fill_settings_button:
		_fill_settings_button.visible = is_fill
	if _fill_end_separator:
		_fill_end_separator.visible = is_fill
	if _shape_origin_separator:
		_shape_origin_separator.visible = tool == GDDrawCanvasControl.ToolMode.RECTANGLE or tool == GDDrawCanvasControl.ToolMode.ELLIPSE
	if _shape_fill_mode:
		_shape_fill_mode.visible = tool == GDDrawCanvasControl.ToolMode.RECTANGLE or tool == GDDrawCanvasControl.ToolMode.ELLIPSE
	_update_fill_settings_button()


func _move_shared_color_controls(target_row: HBoxContainer) -> void:
	if not target_row:
		return
	for control: Control in [_color_set, _color_set_separator]:
		if not control:
			continue
		var owning_node := control.get_parent()
		if owning_node != target_row:
			if owning_node:
				owning_node.remove_child(control)
			target_row.add_child(control)
	if _color_set:
		target_row.move_child(_color_set, 0)
	if _color_set_separator:
		target_row.move_child(_color_set_separator, 1)


func _move_shared_paint_controls(target_row: HBoxContainer) -> void:
	if not target_row:
		return
	var shared_controls: Array[Control] = [
		_color_set,
		_color_set_separator,
		_brush_size_label,
		_brush_size,
		_paint_size_separator,
	]
	for control: Control in shared_controls:
		if not control:
			continue
		var owning_node: Node = control.get_parent() as Node
		if owning_node != target_row:
			if owning_node:
				owning_node.remove_child(control)
			target_row.add_child(control)

	if target_row == _brush_options:
		_brush_options.move_child(_color_set, 0)
		_brush_options.move_child(_color_set_separator, 1)
		if _fill_tolerance_label:
			_brush_options.move_child(_fill_tolerance_label, 2)
		if _fill_tolerance:
			_brush_options.move_child(_fill_tolerance, 3)
		if _fill_end_separator:
			_brush_options.move_child(_fill_end_separator, 4)
		if _fill_mode:
			_brush_options.move_child(_fill_mode, 5)
		if _fill_style:
			_brush_options.move_child(_fill_style, 6)
		if _fill_settings_button:
			_brush_options.move_child(_fill_settings_button, 7)
		_brush_options.move_child(_brush_size_label, 8)
		_brush_options.move_child(_brush_size, 9)
		_brush_options.move_child(_paint_size_separator, 10)
		if _brush_head:
			_brush_options.move_child(_brush_head, 11)
		if _brush_head_separator:
			_brush_options.move_child(_brush_head_separator, 12)
		if _pixel_perfect_mode:
			_brush_options.move_child(_pixel_perfect_mode, 13)
		if _tool_brush_hardness_label:
			_brush_options.move_child(_tool_brush_hardness_label, 14)
		if _tool_brush_hardness:
			_brush_options.move_child(_tool_brush_hardness, 15)
	else:
		_shape_options.move_child(_color_set, 4)
		_shape_options.move_child(_color_set_separator, 5)
		_shape_options.move_child(_brush_size_label, 6)
		_shape_options.move_child(_brush_size, 7)
		_shape_options.move_child(_paint_size_separator, 8)
		if _shape_fill_mode:
			_shape_options.move_child(_shape_fill_mode, 9)
		if _shape_origin_separator:
			_shape_options.move_child(_shape_origin_separator, 10)
		if _shape_origin_mode:
			_shape_options.move_child(_shape_origin_mode, 11)


func _record_recent_color(color: Color) -> void:
	for index in range(_recent_colors.size() - 1, -1, -1):
		if _colors_match(_recent_colors[index], color):
			_recent_colors.remove_at(index)
	_recent_colors.push_front(color)
	while _recent_colors.size() > RECENT_COLOR_LIMIT:
		_recent_colors.pop_back()
	_update_recent_color_swatches()


func _update_recent_color_swatches() -> void:
	if not _recent_colors_row:
		return
	for child in _recent_colors_row.get_children():
		_recent_colors_row.remove_child(child)
		child.queue_free()
	for index in range(RECENT_COLOR_LIMIT):
		var has_color := index < _recent_colors.size()
		var color := _recent_colors[index] if has_color else EMPTY_RECENT_SWATCH_COLOR
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(18, 18)
		swatch.tooltip_text = color.to_html(true) if has_color else "Empty recent color"
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.mouse_filter = Control.MOUSE_FILTER_STOP if has_color else Control.MOUSE_FILTER_IGNORE
		swatch.add_theme_stylebox_override("normal", _make_color_swatch_style(color))
		swatch.add_theme_stylebox_override("hover", _make_color_swatch_style(color, Color(0.42, 0.42, 0.42, 1.0), 2))
		swatch.add_theme_stylebox_override("pressed", _make_color_swatch_style(color, Color(0.55, 0.55, 0.55, 1.0), 2))
		swatch.add_theme_stylebox_override("disabled", _make_color_swatch_style(color))
		swatch.disabled = not has_color
		if has_color:
			swatch.pressed.connect(_on_recent_color_pressed.bind(color))
		_recent_colors_row.add_child(swatch)


func _on_recent_color_pressed(color: Color) -> void:
	_set_foreground_color(color)
	_record_recent_color(color)


func _colors_match(left: Color, right: Color) -> bool:
	return (
		is_equal_approx(left.r, right.r)
		and is_equal_approx(left.g, right.g)
		and is_equal_approx(left.b, right.b)
		and is_equal_approx(left.a, right.a)
	)


func _shortcut_is_scoped_to_gddraw() -> bool:
	if _open_dialog and _open_dialog.visible:
		return false
	if _save_dialog and _save_dialog.visible:
		return false
	if _save_location_dialog and _save_location_dialog.visible:
		return false
	if _font_location_dialog and _font_location_dialog.visible:
		return false
	if _text_font_dialog and _text_font_dialog.visible:
		return false

	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner and (focus_owner == self or is_ancestor_of(focus_owner)):
		if focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox:
			return false
		return true

	var mouse_position := get_global_mouse_position()
	return Rect2(global_position, size).has_point(mouse_position)


func _select_tool(tool: int) -> void:
	if _canvas and tool != _canvas.active_tool:
		_cancel_3d_surface_shape("Canceled 3D shape preview because the tool changed.", true)
	if tool == GDDrawCanvasControl.ToolMode.LINE or tool == GDDrawCanvasControl.ToolMode.RECTANGLE or tool == GDDrawCanvasControl.ToolMode.ELLIPSE:
		_active_shape_tool = tool
	if tool == GDDrawCanvasControl.ToolMode.SELECT or tool == GDDrawCanvasControl.ToolMode.LASSO_SELECT:
		_active_selection_tool = tool
	if _brush_button:
		_brush_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.BRUSH)
	if _eraser_button:
		_eraser_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.ERASER)
	if _fill_button:
		_fill_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.FILL)
	if _shape_button:
		_shape_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.LINE or tool == GDDrawCanvasControl.ToolMode.RECTANGLE or tool == GDDrawCanvasControl.ToolMode.ELLIPSE)
	if _text_button:
		_text_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.TEXT)
	if _line_button:
		_line_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.LINE)
	if _rectangle_button:
		_rectangle_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.RECTANGLE)
	if _ellipse_button:
		_ellipse_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.ELLIPSE)
	if _eyedropper_button:
		_eyedropper_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.EYEDROPPER)
	if _selection_mode_button:
		_selection_mode_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.SELECT or tool == GDDrawCanvasControl.ToolMode.LASSO_SELECT)
	if _selection_button:
		_selection_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.SELECT)
	if _lasso_selection_button:
		_lasso_selection_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.LASSO_SELECT)
	if _pan_button:
		_pan_button.set_pressed_no_signal(tool == GDDrawCanvasControl.ToolMode.PAN)
	if _canvas:
		_canvas.active_tool = tool
	_update_tool_button_states()
	_update_tool_options_visibility()


func _has_selected_tool() -> bool:
	return (
		(_brush_button and _brush_button.button_pressed)
		or (_eraser_button and _eraser_button.button_pressed)
		or (_fill_button and _fill_button.button_pressed)
		or (_shape_button and _shape_button.button_pressed)
		or (_text_button and _text_button.button_pressed)
		or (_line_button and _line_button.button_pressed)
		or (_rectangle_button and _rectangle_button.button_pressed)
		or (_ellipse_button and _ellipse_button.button_pressed)
		or (_eyedropper_button and _eyedropper_button.button_pressed)
		or (_selection_mode_button and _selection_mode_button.button_pressed)
		or (_selection_button and _selection_button.button_pressed)
		or (_lasso_selection_button and _lasso_selection_button.button_pressed)
		or (_pan_button and _pan_button.button_pressed)
	)


func _update_tool_button_states() -> void:
	if _brush_button:
		_update_toggle_button_icon(_brush_button)
		_brush_button.queue_redraw()
	if _eraser_button:
		_update_toggle_button_icon(_eraser_button)
		_eraser_button.queue_redraw()
	if _fill_button:
		_update_toggle_button_icon(_fill_button)
		_fill_button.queue_redraw()
	if _shape_button:
		_update_toggle_button_icon(_shape_button)
		_shape_button.queue_redraw()
	if _text_button:
		_update_toggle_button_icon(_text_button)
		_text_button.queue_redraw()
	if _line_button:
		_update_toggle_button_icon(_line_button)
		_line_button.queue_redraw()
	if _rectangle_button:
		_update_toggle_button_icon(_rectangle_button)
		_rectangle_button.queue_redraw()
	if _ellipse_button:
		_update_toggle_button_icon(_ellipse_button)
		_ellipse_button.queue_redraw()
	if _eyedropper_button:
		_update_toggle_button_icon(_eyedropper_button)
		_eyedropper_button.queue_redraw()
	if _selection_mode_button:
		_update_toggle_button_icon(_selection_mode_button)
		_selection_mode_button.queue_redraw()
	if _selection_button:
		_update_toggle_button_icon(_selection_button)
		_selection_button.queue_redraw()
	if _lasso_selection_button:
		_update_toggle_button_icon(_lasso_selection_button)
		_lasso_selection_button.queue_redraw()
	if _pan_button:
		_update_toggle_button_icon(_pan_button)
		_pan_button.queue_redraw()


func _apply_selected_tool_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_tool_button_style(TOOL_BUTTON_PANEL_COLOR))
	button.add_theme_stylebox_override("hover", _make_tool_button_style(TOOL_BUTTON_HOVER_COLOR))
	button.add_theme_stylebox_override("pressed", _make_tool_button_style(TOOL_BUTTON_SELECTED_COLOR))
	button.add_theme_stylebox_override("hover_pressed", _make_tool_button_style(TOOL_BUTTON_SELECTED_HOVER_COLOR))


func _apply_icon_button_style(button: Button) -> void:
	for color_name in [
		"icon_normal_color",
		"icon_hover_color",
		"icon_pressed_color",
		"icon_hover_pressed_color",
		"icon_focus_color",
	]:
		button.add_theme_color_override(color_name, ICON_AUTHORED_COLOR)
	button.add_theme_color_override("icon_disabled_color", ICON_DISABLED_FALLBACK_COLOR)
	button.add_theme_stylebox_override("normal", _make_tool_button_style(TOOL_BUTTON_PANEL_COLOR))
	button.add_theme_stylebox_override("hover", _make_tool_button_style(TOOL_BUTTON_HOVER_COLOR))
	button.add_theme_stylebox_override("pressed", _make_tool_button_style(TOOL_BUTTON_SELECTED_COLOR))
	button.add_theme_stylebox_override("hover_pressed", _make_tool_button_style(TOOL_BUTTON_SELECTED_HOVER_COLOR))
	button.add_theme_stylebox_override("disabled", _make_tool_button_style(TOOL_BUTTON_PANEL_COLOR))


func _apply_flat_icon_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_tool_button_style(Color.TRANSPARENT))
	button.add_theme_stylebox_override("hover", _make_tool_button_style(TOOL_BUTTON_HOVER_COLOR))
	button.add_theme_stylebox_override("pressed", _make_tool_button_style(TOOL_BUTTON_SELECTED_COLOR))
	button.add_theme_stylebox_override("hover_pressed", _make_tool_button_style(TOOL_BUTTON_SELECTED_HOVER_COLOR))
	button.add_theme_stylebox_override("disabled", _make_tool_button_style(Color.TRANSPARENT))


func _apply_destructive_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _make_action_button_style(DESTRUCTIVE_BUTTON_COLOR))
	button.add_theme_stylebox_override("hover", _make_action_button_style(DESTRUCTIVE_BUTTON_HOVER_COLOR))
	button.add_theme_stylebox_override("pressed", _make_action_button_style(DESTRUCTIVE_BUTTON_PRESSED_COLOR))
	button.add_theme_stylebox_override("focus", _make_action_button_style(DESTRUCTIVE_BUTTON_HOVER_COLOR))


func _apply_menu_bar_style(menu_bar: MenuBar) -> void:
	menu_bar.add_theme_stylebox_override("normal", _make_menu_bar_item_style(Color(0, 0, 0, 0)))
	menu_bar.add_theme_stylebox_override("hover", _make_menu_bar_item_style(TOOL_BUTTON_SELECTED_COLOR))
	menu_bar.add_theme_stylebox_override("pressed", _make_menu_bar_item_style(TOOL_BUTTON_SELECTED_COLOR))
	menu_bar.add_theme_stylebox_override("hover_pressed", _make_menu_bar_item_style(TOOL_BUTTON_SELECTED_COLOR))
	menu_bar.add_theme_color_override("font_color", Color("#CFCFCF"))
	menu_bar.add_theme_color_override("font_hover_color", Color.WHITE)
	menu_bar.add_theme_color_override("font_pressed_color", Color.WHITE)


func _apply_preferences_close_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", Color("#D0D0D0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _make_action_button_style(Color("#202020")))
	button.add_theme_stylebox_override("hover", _make_action_button_style(Color("#2A2A2A")))
	button.add_theme_stylebox_override("pressed", _make_action_button_style(Color("#151515")))
	button.add_theme_stylebox_override("focus", _make_action_button_style(Color("#2A2A2A")))


func _apply_preferences_small_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", Color("#D0D0D0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _make_action_button_style(Color("#2B2B2B")))
	button.add_theme_stylebox_override("hover", _make_action_button_style(Color("#343434")))
	button.add_theme_stylebox_override("pressed", _make_action_button_style(Color("#202020")))
	button.add_theme_stylebox_override("focus", _make_action_button_style(Color("#343434")))


func _apply_light_dialog_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", Color("#F0F0F0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _make_action_button_style(Color("#4A4A4A")))
	button.add_theme_stylebox_override("hover", _make_action_button_style(Color("#5A5A5A")))
	button.add_theme_stylebox_override("pressed", _make_action_button_style(Color("#3A3A3A")))
	button.add_theme_stylebox_override("focus", _make_action_button_style(Color("#5A5A5A")))


func _apply_preferences_line_edit_style(line_edit: LineEdit) -> void:
	line_edit.add_theme_color_override("font_color", Color("#E0E0E0"))
	line_edit.add_theme_color_override("font_placeholder_color", Color("#8F8F8F"))
	line_edit.add_theme_stylebox_override("normal", _make_preferences_field_style(Color("#2D2D2D")))
	line_edit.add_theme_stylebox_override("focus", _make_preferences_field_style(Color("#333333"), Color("#4D73A8")))
	line_edit.add_theme_stylebox_override("read_only", _make_preferences_field_style(Color("#242424")))


func _apply_preferences_spinbox_style(spinbox: SpinBox) -> void:
	if spinbox.get_line_edit():
		_apply_preferences_line_edit_style(spinbox.get_line_edit())


func _make_action_button_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_content_margin(SIDE_LEFT, 10.0)
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_RIGHT, 10.0)
	style.set_content_margin(SIDE_BOTTOM, 4.0)
	style.set_corner_radius_all(TOOL_BUTTON_CORNER_RADIUS)
	return style


func _make_menu_bar_item_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_BOTTOM, 4.0)
	return style


func _make_preferences_field_style(bg_color: Color, border_color := Color("#3C3C3C")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_BOTTOM, 4.0)
	return style


func _make_tool_button_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_TOP, 0.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 0.0)
	style.corner_radius_top_left = TOOL_BUTTON_CORNER_RADIUS
	style.corner_radius_top_right = TOOL_BUTTON_CORNER_RADIUS
	style.corner_radius_bottom_left = TOOL_BUTTON_CORNER_RADIUS
	style.corner_radius_bottom_right = TOOL_BUTTON_CORNER_RADIUS
	return style


func _make_color_swatch_style(color: Color, border_color := Color(0.12, 0.12, 0.12, 1.0), border_width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


func _set_status(message: String) -> void:
	if _status_label:
		_status_label.text = message
		_status_label.tooltip_text = message
