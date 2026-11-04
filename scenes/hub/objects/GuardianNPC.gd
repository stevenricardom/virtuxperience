extends Area2D
class_name GuardianNPC

## NPC guía. Cuando el jugador se acerca muestra el letrerito [E]
## y al interactuar abre el diálogo en el DialogModal.

signal interacted(npc_name: String)

@export var npc_id: String = "axion7"
@export var npc_name: String = "AXION-7"
@export var dialogue_lines: Array[String] = []
@export var speaker_color: Color = Color("#00E5FF")
@export var opens_terminal_on_finish: bool = false

@onready var npc_sprite: Sprite2D = $NPCSprite
@onready var shadow_sprite: Sprite2D = $ShadowSprite
@onready var prompt_badge: NinePatchRect = $PromptBadge

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
		
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)
		
	set_prompt_visible(false)

func set_prompt_visible(visible_state: bool) -> void:
	var badge := get_node_or_null("PromptBadge") as NinePatchRect
	if badge:
		badge.visible = visible_state

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.collision_layer & 2 != 0:
		set_prompt_visible(true)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D or body.collision_layer & 2 != 0:
		set_prompt_visible(false)

func _on_area_entered(_area: Area2D) -> void:
	set_prompt_visible(true)

func _on_area_exited(_area: Area2D) -> void:
	set_prompt_visible(false)

## El jugador presionó E estando cerca
func interact() -> void:
	interacted.emit(npc_name)
	
	var lines := dialogue_lines
	if lines.is_empty():
		lines = [
			"¡Saludos, estudiante! Soy %s, custodio del Campus Nexus." % npc_name,
			"Explora los 6 portales dimensionales para dominar los retos de cada facultad.",
			"¡Al resolver los desafíos pedagógicos recuperarás los Fragmentos del Nexo!"
		]
		
	var modal: Node = _find_dialog_modal()
	if modal and modal.has_method("start_dialog"):
		modal.start_dialog(npc_name, lines, speaker_color)
	else:
		# sin modal: solo imprimo, ej: [GuardianNPC] AXION-7: ["¡Saludos, estudiante! ...", ...]
		print("[GuardianNPC] %s: %s" % [npc_name, str(lines)])

# busca el modal: primero subiendo por los padres, luego por grupo, luego en toda la escena
func _find_dialog_modal() -> Node:
	var cur: Node = self
	while cur:
		var dm := cur.get_node_or_null("DialogModal")
		if dm:
			return dm
		cur = cur.get_parent()
	var in_group := get_tree().get_first_node_in_group("dialog_modal")
	if in_group:
		return in_group
	if get_tree().current_scene:
		return get_tree().current_scene.find_child("DialogModal", true, false)
	return null
