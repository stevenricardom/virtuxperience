extends BiomeTerminal
class_name AgoraPodiumTerminal

## AgoraPodiumTerminal.gd — Central interactive Rostra Podium in VoxCivitasLab.
## Inherits from BiomeTerminal. Positioned at (320, 156).
## Detects player proximity, pulses amethyst violet CoreGlow (#9C27B0), displays animated [E] prompt,
## and transitions safely to VoxCivitasMinigame via SceneManager.

const AMETHYST_GLOW_COLOR: Color = Color(0.611765, 0.152941, 0.690196, 0.45)

func _init() -> void:
	target_scene = "res://scenes/biomes/voxcivitas/VoxCivitasMinigame.tscn"
	interaction_offset = Vector2(0.0, 44.0)
	core_glow_base_alpha = 0.45
	core_glow_pulse_amplitude = 0.25
	core_glow_pulse_frequency = 3.2

func _ready() -> void:
	y_sort_enabled = false
	if target_scene.is_empty():
		target_scene = "res://scenes/biomes/voxcivitas/VoxCivitasMinigame.tscn"
	if core_glow:
		core_glow.color = AMETHYST_GLOW_COLOR
	super._ready()
