extends Node
## Autoload "Settings" — single source of truth for user settings.
## Loads user://settings.cfg at boot, applies window/render state immediately.
## Menu widgets call set_value(); every change applies instantly + auto-saves.
## Cheap-to-read values (sensitivity, invert, fov, show_fps) are read live by
## their consumers each frame — no signal plumbing needed for those.

signal changed(key: String, value: Variant)

const PATH := "user://settings.cfg"
const KEYS := [
	"mouse_sensitivity", "invert_y",
	"window_mode", "vsync", "render_scale", "msaa", "shadows",
	"glow", "fog", "fov", "max_fps", "show_fps",
	"master_volume",
]

# --- gameplay ---
var mouse_sensitivity := 1.0  # multiplier on the player's base sens
var invert_y := false

# --- graphics ---
var window_mode := 0          # 0 windowed, 1 fullscreen
var vsync := true
var render_scale := 1.0       # 0.5 .. 1.0 (3D resolution scale)
var msaa := 2                 # matches Viewport.MSAA_* (0 off, 1 2x, 2 4x, 3 8x)
var shadows := 2              # 0 off, 1 low, 2 high
var glow := true
var fog := true
var fov := 75.0
var max_fps := 0              # 0 = uncapped
var show_fps := false

# --- audio ---
var master_volume := 1.0      # linear 0..1

var _env: Environment


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()


## The active scene (world or title) registers its Environment here so the
## glow/fog toggles have something to poke. Last registered wins.
func register_environment(env: Environment) -> void:
	_env = env
	_apply_env()


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	_apply(key)
	save_settings()
	changed.emit(key, value)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  # first run — defaults stand
	for key in KEYS:
		set(key, cfg.get_value("settings", key, get(key)))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value("settings", key, get(key))
	cfg.save(PATH)


func apply_all() -> void:
	for key in ["window_mode", "vsync", "render_scale", "msaa", "shadows",
			"max_fps", "master_volume"]:
		_apply(key)


func _apply(key: String) -> void:
	match key:
		"window_mode":
			DisplayServer.window_set_mode(
					DisplayServer.WINDOW_MODE_FULLSCREEN if window_mode == 1
					else DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			DisplayServer.window_set_vsync_mode(
					DisplayServer.VSYNC_ENABLED if vsync
					else DisplayServer.VSYNC_DISABLED)
		"render_scale":
			get_viewport().scaling_3d_scale = render_scale
		"msaa":
			get_viewport().msaa_3d = msaa as Viewport.MSAA
		"shadows":
			var size := [0, 2048, 4096][shadows] as int
			RenderingServer.directional_shadow_atlas_set_size(size, true)
		"glow", "fog":
			_apply_env()
		"max_fps":
			Engine.max_fps = max_fps
		"master_volume":
			if master_volume <= 0.001:
				AudioServer.set_bus_mute(0, true)
			else:
				AudioServer.set_bus_mute(0, false)
				AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))


func _apply_env() -> void:
	if _env == null:
		return
	_env.glow_enabled = glow
	_env.fog_enabled = fog
