extends BiomeTerminal
class_name TypographicLectern

## TypographicLectern.gd — Central interactive manuscript lectern in ComunicArteLab.
## Inherits from BiomeTerminal.
## Positioned at (320, 160) in ComunicArteLab.
## Detects player proximity, displays animated [E] prompt badge,
## pulses magenta CoreGlow (#FF2A85), and launches ComunicArteMinigame.

func _init() -> void:
	target_scene = "res://scenes/biomes/comunicarte/ComunicArteMinigame.tscn"
	interaction_offset = Vector2(0.0, 44.0)

func _ready() -> void:
	y_sort_enabled = false
	if target_scene.is_empty():
		target_scene = "res://scenes/biomes/comunicarte/ComunicArteMinigame.tscn"
	super._ready()
