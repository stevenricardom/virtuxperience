extends BiomeTerminal
class_name QuantumTerminal

## Terminal del NeuroMathLab. Al darle E abre el minijuego.
## Casi todo lo hace BiomeTerminal, aquí solo se pone la escena destino.

func _init() -> void:
	target_scene = "res://scenes/biomes/neuromath/NeuroMathMinigame.tscn"
	interaction_offset = Vector2(0.0, 44.0)

func _ready() -> void:
	y_sort_enabled = false
	if target_scene.is_empty():
		target_scene = "res://scenes/biomes/neuromath/NeuroMathMinigame.tscn"
	super._ready()
