extends BiomeTerminal
class_name CommunityWellTerminal

## CommunityWellTerminal.gd — Central interactive Community Well in LatidoSocialLab.
## Inherits from BiomeTerminal. Positioned at (320, 168).
## Detects player proximity, pulses emerald CoreGlow (#4CAF50), displays animated [E] prompt,
## and transitions safely to LatidoSocialMinigame via SceneManager.

const EMERALD_GLOW_COLOR: Color = Color(0.298039, 0.686275, 0.313725, 0.45)

func _init() -> void:
	target_scene = "res://scenes/biomes/latidosocial/LatidoSocialMinigame.tscn"
	interaction_offset = Vector2(0.0, 44.0)
	core_glow_base_alpha = 0.45
	core_glow_pulse_amplitude = 0.25
	core_glow_pulse_frequency = 3.2

func _ready() -> void:
	y_sort_enabled = false
	if target_scene.is_empty():
		target_scene = "res://scenes/biomes/latidosocial/LatidoSocialMinigame.tscn"
	if core_glow:
		core_glow.color = EMERALD_GLOW_COLOR
	super._ready()
