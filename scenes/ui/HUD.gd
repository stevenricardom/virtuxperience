extends CanvasLayer

## Barra de arriba (HUD): zona, nivel y XP, fragmentos (0/6), botones de SKINS y LOGROS
## y el botón de pantalla completa.

const COSMETICS_MODAL_PATH: String = "res://scenes/ui/CosmeticsModal.tscn"
const BADGES_MODAL_PATH: String = "res://scenes/ui/BadgesModal.tscn"

@onready var top_bar: NinePatchRect = $TopBar
@onready var zone_label: Label = $TopBar/MarginContainer/HBoxContainer/ZoneLabel
@onready var level_xp_label: Label = $TopBar/MarginContainer/HBoxContainer/LevelXpLabel
@onready var fragments_box: HBoxContainer = $TopBar/MarginContainer/HBoxContainer/FragmentsBox
@onready var medal_icon: TextureRect = $TopBar/MarginContainer/HBoxContainer/FragmentsBox/MedalIcon
@onready var fragments_label: Label = $TopBar/MarginContainer/HBoxContainer/FragmentsBox/FragmentsLabel
@onready var cosmetics_button: Button = get_node_or_null("TopBar/MarginContainer/HBoxContainer/CosmeticsButton")
@onready var badges_button: Button = get_node_or_null("TopBar/MarginContainer/HBoxContainer/BadgesButton")
@onready var fullscreen_button: Button = $TopBar/MarginContainer/HBoxContainer/FullscreenButton

# accesos directos para que otros scripts puedan leer estos nodos
var level_label: Label:
	get:
		return level_xp_label
var xp_label: Label:
	get:
		return level_xp_label

var _zone_name: String = "CAMPUS HUB"
var _total_xp: int = 0
var _level: int = 1
var _fragments: int = 0

var _cosmetics_modal_instance: CanvasLayer = null
var _badges_modal_instance: CanvasLayer = null

func _ready() -> void:
	# conecta los botones
	if fullscreen_button and not fullscreen_button.pressed.is_connected(_on_fullscreen_button_pressed):
		fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)

	if cosmetics_button and not cosmetics_button.pressed.is_connected(_on_cosmetics_button_pressed):
		cosmetics_button.pressed.connect(_on_cosmetics_button_pressed)

	if badges_button and not badges_button.pressed.is_connected(_on_badges_button_pressed):
		badges_button.pressed.connect(_on_badges_button_pressed)

	# se engancha a GameState (si existe)
	var game_state := _get_game_state()
	if game_state:
		if not game_state.xp_changed.is_connected(_on_xp_changed):
			game_state.xp_changed.connect(_on_xp_changed)
		if not game_state.fragment_awarded.is_connected(_on_fragment_awarded):
			game_state.fragment_awarded.connect(_on_fragment_awarded)
		if game_state.has_signal("fragment_collected") and not game_state.fragment_collected.is_connected(_on_fragment_collected):
			game_state.fragment_collected.connect(_on_fragment_collected)
		
		# arranca mostrando lo que ya tenga GameState
		_total_xp = game_state.total_xp
		_level = game_state.level
		_fragments = game_state.get_fragment_count()
	
	# y a SceneManager para saber cuándo cambia la zona
	var scene_manager := _get_scene_manager()
	if scene_manager:
		if scene_manager.has_signal("scene_transition_finished") and not scene_manager.scene_transition_finished.is_connected(_on_scene_transition_finished):
			scene_manager.scene_transition_finished.connect(_on_scene_transition_finished)
		if "current_zone_name" in scene_manager and not scene_manager.current_zone_name.is_empty():
			_zone_name = scene_manager.current_zone_name

	# refresca todos los textos
	_refresh_display()

func _exit_tree() -> void:
	var scene_manager := _get_scene_manager()
	if scene_manager and scene_manager.has_signal("scene_transition_finished"):
		if scene_manager.scene_transition_finished.is_connected(_on_scene_transition_finished):
			scene_manager.scene_transition_finished.disconnect(_on_scene_transition_finished)

func _get_game_state() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root:
		return loop.root.get_node_or_null("GameState")
	return null

func _get_scene_manager() -> Node:
	if Engine.has_singleton("SceneManager"):
		return Engine.get_singleton("SceneManager")
	if is_inside_tree():
		return get_node_or_null("/root/SceneManager")
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root:
		return loop.root.get_node_or_null("SceneManager")
	return null

func _process(_delta: float) -> void:
	# botones apagados mientras alguien está hablando
	var dialog_active: bool = _is_dialog_active()
	if is_instance_valid(cosmetics_button):
		cosmetics_button.disabled = dialog_active
	if is_instance_valid(badges_button):
		badges_button.disabled = dialog_active

## ¿Hay algún diálogo abierto ahora mismo?
func _is_dialog_active() -> bool:
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if not tree:
		return false
	var modal := tree.get_first_node_in_group("dialog_modal")
	if modal == null and tree.current_scene:
		modal = tree.current_scene.find_child("DialogModal", true, false)
	if modal and modal.has_method("is_active") and modal.is_active():
		return true
	return false

## Abre/cierra el modal de skins
func toggle_cosmetics_modal() -> void:
	if _is_dialog_active():
		return

	# si el de logros está abierto lo cierro primero
	if is_instance_valid(_badges_modal_instance) and _badges_modal_instance.visible:
		if _badges_modal_instance.has_method("close_modal"):
			_badges_modal_instance.close_modal()
		elif _badges_modal_instance.has_method("close"):
			_badges_modal_instance.close()
		else:
			_badges_modal_instance.visible = false

	var modal := _get_or_create_cosmetics_modal()
	if is_instance_valid(modal):
		if modal.visible:
			if modal.has_method("close_modal"):
				modal.close_modal()
			elif modal.has_method("close"):
				modal.close()
			else:
				modal.visible = false
		else:
			if modal.has_method("open_modal"):
				modal.open_modal()
			elif modal.has_method("open"):
				modal.open()
			else:
				modal.visible = true

## Abre/cierra el modal de logros
func toggle_badges_modal() -> void:
	if _is_dialog_active():
		return

	# si el de skins está abierto lo cierro primero
	if is_instance_valid(_cosmetics_modal_instance) and _cosmetics_modal_instance.visible:
		if _cosmetics_modal_instance.has_method("close_modal"):
			_cosmetics_modal_instance.close_modal()
		elif _cosmetics_modal_instance.has_method("close"):
			_cosmetics_modal_instance.close()
		else:
			_cosmetics_modal_instance.visible = false

	var modal := _get_or_create_badges_modal()
	if is_instance_valid(modal):
		if modal.visible:
			if modal.has_method("close_modal"):
				modal.close_modal()
			elif modal.has_method("close"):
				modal.close()
			else:
				modal.visible = false
		else:
			if modal.has_method("open_modal"):
				modal.open_modal()
			elif modal.has_method("open"):
				modal.open()
			else:
				modal.visible = true

func _get_or_create_cosmetics_modal() -> CanvasLayer:
	if is_instance_valid(_cosmetics_modal_instance):
		return _cosmetics_modal_instance

	# primero lo busco en el árbol
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree:
		var existing = tree.get_first_node_in_group("cosmetics_modal")
		if is_instance_valid(existing) and existing is CanvasLayer:
			_cosmetics_modal_instance = existing
			return _cosmetics_modal_instance

	# si no está, lo creo en ese momento
	if ResourceLoader.exists(COSMETICS_MODAL_PATH):
		var scene := load(COSMETICS_MODAL_PATH) as PackedScene
		if scene:
			_cosmetics_modal_instance = scene.instantiate() as CanvasLayer
			add_child(_cosmetics_modal_instance)
			return _cosmetics_modal_instance

	return null

func _get_or_create_badges_modal() -> CanvasLayer:
	if is_instance_valid(_badges_modal_instance):
		return _badges_modal_instance

	# primero lo busco en el árbol
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree:
		var existing = tree.get_first_node_in_group("badges_modal")
		if is_instance_valid(existing) and existing is CanvasLayer:
			_badges_modal_instance = existing
			return _badges_modal_instance

	# si no está, lo creo en ese momento (si existe la escena)
	if ResourceLoader.exists(BADGES_MODAL_PATH):
		var scene := load(BADGES_MODAL_PATH) as PackedScene
		if scene:
			_badges_modal_instance = scene.instantiate() as CanvasLayer
			add_child(_badges_modal_instance)
			return _badges_modal_instance

	return null

func _on_cosmetics_button_pressed() -> void:
	toggle_cosmetics_modal()

func _on_badges_button_pressed() -> void:
	toggle_badges_modal()

## Cambia el título de la zona
func set_zone(zone_title: String) -> void:
	_zone_name = zone_title
	if zone_label == null:
		zone_label = get_node_or_null("TopBar/MarginContainer/HBoxContainer/ZoneLabel")
	if is_instance_valid(zone_label):
		zone_label.text = _zone_name

## Otro nombre para set_zone
func set_zone_title(zone_title: String) -> void:
	set_zone(zone_title)

## Actualiza nivel y XP en pantalla
func update_xp(new_xp: int, new_level: int) -> void:
	_total_xp = new_xp
	_level = new_level
	if level_xp_label == null:
		level_xp_label = get_node_or_null("TopBar/MarginContainer/HBoxContainer/LevelXpLabel")
	if is_instance_valid(level_xp_label):
		level_xp_label.text = "NV. %d | XP: %d" % [_level, _total_xp]

## Actualiza el contador de fragmentos, ej: 2/6
func update_fragments(total_fragments: int) -> void:
	_fragments = total_fragments
	if fragments_label == null:
		fragments_label = get_node_or_null("TopBar/MarginContainer/HBoxContainer/FragmentsBox/FragmentsLabel")
	if is_instance_valid(fragments_label):
		fragments_label.text = "FRAGMENTOS: %d/6" % _fragments

func _refresh_display() -> void:
	if is_instance_valid(zone_label):
		zone_label.text = _zone_name
	if is_instance_valid(level_xp_label):
		level_xp_label.text = "NV. %d | XP: %d" % [_level, _total_xp]
	if is_instance_valid(fragments_label):
		fragments_label.text = "FRAGMENTOS: %d/6" % _fragments

## Se llama cuando cambia el XP
func _on_xp_changed(new_xp: int, new_level: int) -> void:
	update_xp(new_xp, new_level)

## Se llama cuando se gana un fragmento
func _on_fragment_awarded(_biome_id: String, total_fragments: int) -> void:
	update_fragments(total_fragments)

## Igual que arriba, para la señal fragment_collected
func _on_fragment_collected(_biome_id: String, total_fragments: int) -> void:
	update_fragments(total_fragments)

## Se llama cuando terminó el cambio de escena
func _on_scene_transition_finished(_scene_path: String) -> void:
	if not is_inside_tree():
		return
	var scene_manager := _get_scene_manager()
	if scene_manager and "current_zone_name" in scene_manager:
		set_zone(scene_manager.current_zone_name)

## Alterna entre pantalla completa y ventana
func toggle_fullscreen() -> void:
	var current_mode: int = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _on_fullscreen_button_pressed() -> void:
	toggle_fullscreen()
