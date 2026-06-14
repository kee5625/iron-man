extends Node
## Global game-mode state (autoload "Game"). Currently just the combat toggle:
## flip it and every combat system (spawner, weapons, player damage, HUD) reacts
## off one signal. Room to grow into difficulty / mission flags later.

signal combat_toggled(enabled: bool)

var combat_enabled := true


func set_combat(on: bool) -> void:
	if on == combat_enabled:
		return
	combat_enabled = on
	combat_toggled.emit(on)


func toggle_combat() -> void:
	set_combat(not combat_enabled)
