extends BiomeTerminal
class_name PrototypeWorkbench

## PrototypeWorkbench.gd — Central interactive prototyping workbench in ActivaTuIdeaLab.
## Inherits from BiomeTerminal.
## Positioned at (320, 160) in ActivaTuIdeaLab.
## Detects player proximity, displays animated [E] prompt badge,
## pulses industrial orange CoreGlow (#FF8C00), and launches ActivaTuIdeaMinigame.

func _init() -> void:
	target_scene = "res://scenes/biomes/activatuidea/ActivaTuIdeaMinigame.tscn"
	interaction_offset = Vector2(0.0, 44.0)

func _ready() -> void:
	y_sort_enabled = false
	if target_scene.is_empty():
		target_scene = "res://scenes/biomes/activatuidea/ActivaTuIdeaMinigame.tscn"
	super._ready()
