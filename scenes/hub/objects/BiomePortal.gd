extends Area2D
class_name BiomePortal

## Portal a un bioma. Si está activo cambia de escena con SceneManager.change_scene(),
## si no, muestra un mensaje de bloqueado. Tiene su letrerito [E] flotando.

signal portal_activated(biome_id: String, target_scene: String)

@export var biome_id: String = ""
@export var biome_name: String = ""
@export var biome_title: String = "":
	get:
		return biome_title if not biome_title.is_empty() else biome_name
	set(val):
		biome_title = val
		if biome_name.is_empty():
			biome_name = val

@export var accent_color: Color = Color.WHITE
@export var is_active: bool = true
@export var target_scene: String = ""
@export var status_text_locked: String = "En construcción - Fase 2"

@onready var portal_collision: CollisionShape2D = $PortalCollision
@onready var portal_frame: CanvasItem = $PortalFrame
@onready var portal_aura: CanvasItem = $PortalAura
@onready var prompt_badge: NinePatchRect = $PromptBadge

var _time_passed: float = 0.0

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
		
	_apply_visual_styling()

func _apply_visual_styling() -> void:
	if portal_frame:
		portal_frame.modulate = accent_color.lightened(0.18)
	var ground_glow := get_node_or_null("PortalGroundGlow") as CanvasItem
	var inner_core := get_node_or_null("InnerVortexCore") as CanvasItem
	var sparks := get_node_or_null("PortalSparks") as CPUParticles2D
	if portal_aura:
		if is_active:
			portal_aura.modulate = accent_color
			portal_aura.modulate.a = 0.68
		else:
			portal_aura.modulate = Color(0.35, 0.35, 0.35, 0.3)
	if ground_glow:
		ground_glow.modulate = accent_color if is_active else Color(0.3, 0.3, 0.3, 0.2)
		ground_glow.modulate.a = 0.32 if is_active else 0.12
	if inner_core:
		inner_core.modulate = accent_color.lightened(0.55) if is_active else Color(0.4, 0.4, 0.4, 0.2)
		inner_core.modulate.a = 0.85 if is_active else 0.2
	if sparks:
		sparks.emitting = is_active
		sparks.color = Color(accent_color.lightened(0.35), 0.8)

func _process(delta: float) -> void:
	if is_active and portal_aura:
		_time_passed += delta
		portal_aura.modulate.a = 0.50 + 0.25 * sin(_time_passed * 3.5)
		var inner_core := get_node_or_null("InnerVortexCore") as Node2D
		if inner_core:
			var s: float = 0.92 + 0.12 * sin(_time_passed * 4.8 + 1.2)
			inner_core.scale = Vector2(s, s)

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
	if is_active and not target_scene.is_empty():
		portal_activated.emit(biome_id, target_scene)
		var is_returning_to_hub: bool = (biome_id == "hub" or "CampusHub" in target_scene)
		# si vuelve al hub no guardo coordenadas, si no guardo un poco abajo del portal, ej: (320, 160) -> (320, 192)
		var return_coords: Vector2 = Vector2.ZERO if is_returning_to_hub else (global_position + Vector2(0.0, 32.0))
		get_node("/root/SceneManager").change_scene(target_scene, return_coords)
	else:
		_show_locked_notification()

func _show_locked_notification() -> void:
	var title: String = biome_name
	if title.is_empty():
		title = biome_title if not biome_title.is_empty() else ("Portal %s" % biome_id.capitalize())
		
	var lines: Array[String] = [
		"El portal dimensional hacia %s se encuentra temporalmente inactivo." % title,
		status_text_locked
	]
	
	var modal: Node = _find_dialog_modal()
	if modal and modal.has_method("start_dialog"):
		modal.start_dialog(title, lines, accent_color)
	else:
		print("[BiomePortal] Locked: %s - %s" % [title, status_text_locked])

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
