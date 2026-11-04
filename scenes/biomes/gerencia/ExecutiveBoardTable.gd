extends BiomeTerminal
class_name ExecutiveBoardTable

## ExecutiveBoardTable.gd — Central interactive executive boardroom table in GerenciaLab.
## Inherits from BiomeTerminal.
## Positioned at (320, 160) in GerenciaLab.
## Detects player proximity, displays animated [E] prompt badge,
## pulses Steel Blue CoreGlow (#4682B4), and launches GerenciaMinigame.

func _init() -> void:
	target_scene = "res://scenes/biomes/gerencia/GerenciaMinigame.tscn"
	interaction_offset = Vector2(0.0, 44.0)

func _ready() -> void:
	y_sort_enabled = false
	if target_scene.is_empty():
		target_scene = "res://scenes/biomes/gerencia/GerenciaMinigame.tscn"
	super._ready()
