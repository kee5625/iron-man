extends Node3D
## Root script for the game world scene. Registers the world's Environment
## with Settings (glow/fog toggles) and ensures the mouse is captured on entry.


func _ready() -> void:
	Settings.register_environment($WorldEnvironment.environment)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
