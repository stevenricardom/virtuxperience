extends StaticBody2D
class_name NexusAltar

## El altar del centro del campus. Tiene 6 huecos (uno por bioma) y los prende
## según lo que diga GameState. Al interactuar abre un resumen o un diálogo.

const BIOME_COLORS: Dictionary = {
	"neuromath": Color("#00E5FF"),
	"comunicarte": Color("#FF2A85"),
	"gerencia": Color("#4682B4"),
	"activatuidea": Color("#FF8C00"),
	"misionales": Color("#4CAF50"),
	"voxcivitas": Color("#9C27B0")
}

@onready var sockets_container: Node2D = $SocketsContainer
@onready var prompt_badge: NinePatchRect = $InteractionArea/PromptBadge

var _time_passed: float = 0.0

func _ready() -> void:
	y_sort_enabled = false
	collision_layer = 1
	collision_mask = 0
	
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		if not game_state.fragment_awarded.is_connected(_on_fragment_updated):
			game_state.fragment_awarded.connect(_on_fragment_updated)
		if game_state.has_signal("fragment_collected") and not game_state.fragment_collected.is_connected(_on_fragment_updated):
			game_state.fragment_collected.connect(_on_fragment_updated)
			
	update_sockets()
	set_prompt_visible(false)

var custom_game_state: Node = null

func _get_game_state() -> Node:
	if custom_game_state != null:
		return custom_game_state
	if is_inside_tree():
		if has_node("/root/GameState"):
			return get_node("/root/GameState")
		var tree := get_tree()
		if tree and tree.root and tree.root.has_node("GameState"):
			return tree.root.get_node("GameState")
	return null

func _process(delta: float) -> void:
	_time_passed += delta
	var sanctuary_glow := get_node_or_null("SanctuaryGlow") as CanvasItem
	if sanctuary_glow:
		sanctuary_glow.modulate.a = 0.65 + 0.30 * sin(_time_passed * 2.8)
	var gem_halo := get_node_or_null("CenterGemHalo") as Node2D
	if gem_halo:
		var gs_scale: float = 0.95 + 0.14 * sin(_time_passed * 3.8)
		gem_halo.scale = Vector2(gs_scale, gs_scale)

	# los huecos prendidos brillan suave
	var game_state := _get_game_state()
	if not game_state:
		return
		
	for biome_id in BIOME_COLORS:
		var socket = sockets_container.get_node_or_null("Socket_" + biome_id) as CanvasItem
		if socket and game_state.has_fragment(biome_id):
			var base_col: Color = BIOME_COLORS[biome_id]
			var pulse: float = 0.75 + 0.25 * sin(_time_passed * 4.0)
			socket.modulate = Color(base_col.r * pulse, base_col.g * pulse, base_col.b * pulse, 1.0)

func update_sockets() -> void:
	if sockets_container == null:
		sockets_container = get_node_or_null("SocketsContainer")
	if sockets_container == null:
		return
	var game_state := _get_game_state()
	for biome_id in BIOME_COLORS:
		var socket = sockets_container.get_node_or_null("Socket_" + biome_id) as CanvasItem
		if socket:
			var has_frag: bool = game_state != null and game_state.has_fragment(biome_id)
			if has_frag:
				socket.modulate = BIOME_COLORS[biome_id]
			else:
				# hueco apagado, se ve oscuro
				socket.modulate = Color(0.25, 0.28, 0.35, 0.5)

func _on_fragment_updated(_biome_id: String, _count: int) -> void:
	update_sockets()

func set_prompt_visible(visible_state: bool) -> void:
	if prompt_badge:
		prompt_badge.visible = visible_state

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.collision_layer & 2 != 0:
		set_prompt_visible(true)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D or body.collision_layer & 2 != 0:
		set_prompt_visible(false)

func _on_interaction_area_area_entered(_area: Area2D) -> void:
	set_prompt_visible(true)

func _on_interaction_area_area_exited(_area: Area2D) -> void:
	set_prompt_visible(false)

func interact() -> void:
	# 1. lo normal: abrir el FinalSummaryModal
	var summary_modal = _find_summary_modal()
	if summary_modal:
		if summary_modal.has_method("open_summary"):
			summary_modal.open_summary()
			return
		elif summary_modal.has_method("open"):
			summary_modal.open()
			return
		elif summary_modal.has_method("show_modal"):
			summary_modal.show_modal()
			return
		elif "visible" in summary_modal:
			summary_modal.visible = true
			return

	# 2. si no hay modal: mensaje por DialogModal o consola
	var game_state = _get_game_state()
	var count: int = game_state.get_fragment_count() if game_state else 0
	
	var lines: Array[String] = [
		"El Altar del Nexo es el corazón vibrante de VirtuXperience.",
		"Canaliza los saberes de las 6 facultades universitarias.",
		"Fragmentos restaurados: %d / 6." % count
	]
	
	if count == 0:
		lines.append("Aún no has recuperado fragmentos. Visita el Portal NeuroMath al noreste para comenzar.")
	elif count == 6:
		lines.append("¡Increíble! El Nexo está completamente restaurado con todos los saberes universales.")
	else:
		lines.append("¡Buen progreso! Sigue explorando los portales para completar la armonía del campus.")
		
	var modal := _find_dialog_modal()
	if modal and modal.has_method("start_dialog"):
		modal.start_dialog("Altar del Nexo", lines, Color("#FFD700"))
	else:
		print("[NexusAltar] %s" % str(lines))

func _find_summary_modal() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if not tree:
		return null
		
	# primero por grupo
	var in_group = tree.get_first_node_in_group("final_summary_modal")
	if in_group:
		return in_group
		
	# luego buscando en la escena
	if has_node("../FinalSummaryModal"):
		return get_node("../FinalSummaryModal")
	if has_node("../../FinalSummaryModal"):
		return get_node("../../FinalSummaryModal")
	if tree.current_scene:
		var found = tree.current_scene.find_child("FinalSummaryModal", true, false)
		if found:
			return found
			
	# último recurso: crearlo si existe la escena
	var scene_path := "res://scenes/ui/FinalSummaryModal.tscn"
	if ResourceLoader.exists(scene_path):
		var packed := load(scene_path) as PackedScene
		if packed:
			var instance = packed.instantiate()
			if tree.current_scene:
				tree.current_scene.add_child(instance)
			else:
				tree.root.add_child(instance)
			return instance

	return null

func _find_dialog_modal() -> Node:
	if not is_inside_tree():
		return null
	if has_node("../DialogModal"):
		return get_node("../DialogModal")
	if has_node("../../DialogModal"):
		return get_node("../../DialogModal")
	var tree := get_tree()
	if tree:
		var in_group := tree.get_first_node_in_group("dialog_modal")
		if in_group:
			return in_group
		if tree.current_scene:
			var found := tree.current_scene.find_child("DialogModal", true, false)
			if found:
				return found
	return null
