class_name BiomeTerminal
extends StaticBody2D

## BiomeTerminal.gd — Base interactive terminal for VirtuXperience 2D biomes.
## Provides player proximity detection, hovering 16x16 [E] badge animation,
## pulsing core glow shader/modulation, and safe scene transition via SceneManager.

signal terminal_activated

@export var target_scene: String = ""
@export var interaction_offset: Vector2 = Vector2(0.0, 44.0)
@export var is_interactive: bool = true

# Hovering badge parameters
@export var prompt_badge_offset_y: float = -42.0
@export var prompt_hover_amplitude: float = 2.0
@export var prompt_hover_frequency: float = 5.0

# Core glow modulation parameters
@export var core_glow_base_alpha: float = 0.45
@export var core_glow_pulse_amplitude: float = 0.25
@export var core_glow_pulse_frequency: float = 3.2

# Node references
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")
@onready var prompt_badge: Control = get_node_or_null("InteractionArea/PromptBadge")
@onready var core_glow: CanvasItem = get_node_or_null("CoreGlow")
@onready var terminal_sprite: Sprite2D = get_node_or_null("TerminalSprite")

var _pulse_time: float = 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	if interaction_area == null:
		interaction_area = get_node_or_null("InteractionArea")
	if interaction_area:
		interaction_area.collision_layer = 4
		interaction_area.collision_mask = 2
		_connect_interaction_signals()

	if prompt_badge == null:
		prompt_badge = get_node_or_null("InteractionArea/PromptBadge")
	if core_glow == null:
		core_glow = get_node_or_null("CoreGlow")
	if terminal_sprite == null:
		terminal_sprite = get_node_or_null("TerminalSprite")

	set_prompt_visible(false)

func _connect_interaction_signals() -> void:
	if not interaction_area:
		return
	if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	if not interaction_area.area_entered.is_connected(_on_interaction_area_area_entered):
		interaction_area.area_entered.connect(_on_interaction_area_area_entered)
	if not interaction_area.area_exited.is_connected(_on_interaction_area_area_exited):
		interaction_area.area_exited.connect(_on_interaction_area_area_exited)

func _process(delta: float) -> void:
	_pulse_time += delta

	# 1. Hover animation for interaction prompt badge
	if prompt_badge and prompt_badge.visible:
		prompt_badge.position.y = prompt_badge_offset_y + sin(_pulse_time * prompt_hover_frequency) * prompt_hover_amplitude

	# 2. Pulsing alpha on core glow
	if core_glow:
		core_glow.modulate.a = core_glow_base_alpha + core_glow_pulse_amplitude * sin(_pulse_time * core_glow_pulse_frequency)

## Sets the visibility of the [E] interaction prompt badge.
func set_prompt_visible(visible_state: bool) -> void:
	if prompt_badge == null:
		prompt_badge = get_node_or_null("InteractionArea/PromptBadge")
	if prompt_badge:
		prompt_badge.visible = visible_state and is_interactive

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if not is_interactive:
		return
	if body is CharacterBody2D or (body.collision_layer & 2) != 0:
		set_prompt_visible(true)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D or (body.collision_layer & 2) != 0:
		set_prompt_visible(false)

func _on_interaction_area_area_entered(_area: Area2D) -> void:
	if is_interactive:
		set_prompt_visible(true)

func _on_interaction_area_area_exited(_area: Area2D) -> void:
	set_prompt_visible(false)

## Triggered by player interaction (pressing E when in proximity).
func interact() -> void:
	if not is_interactive or target_scene.is_empty():
		return

	terminal_activated.emit()
	var return_pos := global_position + interaction_offset

	var scene_manager = _get_scene_manager()
	if scene_manager and scene_manager.has_method("change_scene"):
		scene_manager.change_scene(target_scene, return_pos)
	elif is_inside_tree() and get_tree():
		get_tree().change_scene_to_file(target_scene)
	else:
		print("[BiomeTerminal] Transitioning to minigame: %s" % target_scene)

func _get_scene_manager() -> Node:
	if Engine.has_singleton("SceneManager"):
		return Engine.get_singleton("SceneManager")
	if is_inside_tree() and has_node("/root/SceneManager"):
		return get_node("/root/SceneManager")
	return null
