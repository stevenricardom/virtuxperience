extends CanvasLayer

## CosmeticsModal.gd — 360p Pixel-Art Cosmetics Wardrobe for VirtuXperience 2D.
## Displays unlocked and locked outfits from res://data/cosmetics_catalog.json,
## provides a 4-frame walk-down cycle animated sprite preview,
## and connects to GameState.equip_cosmetic for live Player updates.

signal modal_closed
signal cosmetic_selected(skin_id: String)
signal cosmetic_equipped(skin_id: String)

const CATALOG_PATH: String = "res://data/cosmetics_catalog.json"
const DEFAULT_SKIN_ID: String = "ninja_blue"

@onready var backdrop_overlay: ColorRect = $BackdropOverlay
@onready var close_button: Button = $ModalPanel/MarginContainer/VBox/Header/CloseButton
@onready var preview_sprite: Sprite2D = $ModalPanel/MarginContainer/VBox/MainLayout/PreviewPanel/PreviewFrame/PreviewCenter/PreviewSprite
@onready var skin_name_label: Label = $ModalPanel/MarginContainer/VBox/MainLayout/PreviewPanel/SkinNameLabel
@onready var lore_label: Label = $ModalPanel/MarginContainer/VBox/MainLayout/PreviewPanel/LoreLabel
@onready var action_button: Button = $ModalPanel/MarginContainer/VBox/MainLayout/PreviewPanel/ActionButton
@onready var skin_item_list: VBoxContainer = $ModalPanel/MarginContainer/VBox/MainLayout/CatalogPanel/ScrollContainer/SkinItemList

var _catalog: Array[Dictionary] = []
var _selected_skin_id: String = DEFAULT_SKIN_ID
var _anim_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	add_to_group("cosmetics_modal")
	add_to_group("ui_modal")
	visible = false

	_ensure_nodes()

	if close_button and not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

	if action_button and not action_button.pressed.is_connected(_on_action_button_pressed):
		action_button.pressed.connect(_on_action_button_pressed)

	_load_catalog()

func _ensure_nodes() -> void:
	if backdrop_overlay == null:
		backdrop_overlay = get_node_or_null("BackdropOverlay")
	if close_button == null:
		close_button = get_node_or_null("ModalPanel/MarginContainer/VBox/Header/CloseButton")
	if preview_sprite == null:
		preview_sprite = get_node_or_null("ModalPanel/MarginContainer/VBox/MainLayout/PreviewPanel/PreviewFrame/PreviewCenter/PreviewSprite")
	if skin_name_label == null:
		skin_name_label = get_node_or_null("ModalPanel/MarginContainer/VBox/MainLayout/PreviewPanel/SkinNameLabel")
	if lore_label == null:
		lore_label = get_node_or_null("ModalPanel/MarginContainer/VBox/MainLayout/PreviewPanel/LoreLabel")
	if action_button == null:
		action_button = get_node_or_null("ModalPanel/MarginContainer/VBox/MainLayout/PreviewPanel/ActionButton")
	if skin_item_list == null:
		skin_item_list = get_node_or_null("ModalPanel/MarginContainer/VBox/MainLayout/CatalogPanel/ScrollContainer/SkinItemList")

func _process(delta: float) -> void:
	_ensure_nodes()
	if not visible or not is_instance_valid(preview_sprite):
		return

	# 4-frame walk-down cycle: column 0 down walk frames are 0, 4, 8, 12
	_anim_timer += delta
	var frame_index: int = int(_anim_timer * 6.0) % 4
	preview_sprite.frame = frame_index * 4

func _load_catalog() -> void:
	_catalog.clear()
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("CosmeticsModal: Catalog file not found at " + CATALOG_PATH)
		return

	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("CosmeticsModal: Failed to open " + CATALOG_PATH)
		return

	var text := file.get_as_text()
	var json = JSON.new()
	var err := json.parse(text)
	if err != OK or not json.data is Dictionary:
		push_error("CosmeticsModal: Failed to parse catalog JSON")
		return

	var dict: Dictionary = json.data
	var raw_items = dict.get("cosmetics", [])
	if raw_items is Array:
		for item in raw_items:
			if item is Dictionary:
				_catalog.append(item)

func open_modal() -> void:
	_ensure_nodes()
	visible = true
	_anim_timer = 0.0
	_lock_player_movement(true)

	if _catalog.is_empty():
		_load_catalog()

	var gs = _get_game_state()
	if gs and gs.has_method("get_equipped_cosmetic"):
		_selected_skin_id = gs.get_equipped_cosmetic()
	else:
		_selected_skin_id = DEFAULT_SKIN_ID

	_build_catalog_ui()
	select_skin(_selected_skin_id)

func open() -> void:
	open_modal()

func close_modal() -> void:
	visible = false
	_lock_player_movement(false)
	modal_closed.emit()

func close() -> void:
	close_modal()

func is_open() -> bool:
	return visible

func select_skin(skin_id: String) -> void:
	_ensure_nodes()
	if _catalog.is_empty():
		_load_catalog()
	_selected_skin_id = skin_id
	var skin_data := _find_skin_data(skin_id)
	if skin_data.is_empty():
		return

	# Update Preview Sprite texture and modulate tint
	var texture_path: String = skin_data.get("texture_path", "")
	if ResourceLoader.exists(texture_path):
		var tex := load(texture_path) as Texture2D
		if tex and is_instance_valid(preview_sprite):
			preview_sprite.texture = tex
			preview_sprite.hframes = skin_data.get("hframes", 4)
			preview_sprite.vframes = skin_data.get("vframes", 7)
			var tint_hex: String = str(skin_data.get("modulate_tint", "#FFFFFF"))
			preview_sprite.modulate = Color.from_string(tint_hex, Color.WHITE)

	# Update Labels
	if is_instance_valid(skin_name_label):
		skin_name_label.text = skin_data.get("name", skin_id)
		var accent := Color.from_string(skin_data.get("accent_color", "#00E5FF"), Color.CYAN)
		skin_name_label.modulate = accent

	if is_instance_valid(lore_label):
		lore_label.text = skin_data.get("description", "")

	# Update ActionButton state
	_update_action_button(skin_data)

	# Refresh selection highlight in list
	_refresh_list_selection()
	cosmetic_selected.emit(skin_id)

func _update_action_button(skin_data: Dictionary) -> void:
	if not is_instance_valid(action_button):
		return

	var skin_id: String = skin_data.get("id", "")
	var gs = _get_game_state()
	var equipped_id: String = gs.get_equipped_cosmetic() if (gs and gs.has_method("get_equipped_cosmetic")) else DEFAULT_SKIN_ID
	var is_unlocked: bool = _is_skin_unlocked(skin_data)

	if equipped_id == skin_id:
		action_button.text = "EQUIPADO"
		action_button.disabled = true
		action_button.modulate = Color(0, 0.898, 1, 1)
	elif is_unlocked:
		action_button.text = "EQUIPAR"
		action_button.disabled = false
		action_button.modulate = Color(0.3, 1.0, 0.4, 1)
	else:
		var condition_str: String = _get_condition_display(skin_data.get("unlock_condition", ""))
		action_button.text = "BLOQUEADO: Requiere %s" % condition_str
		action_button.disabled = true
		action_button.modulate = Color(0.65, 0.65, 0.65, 1)

func _is_skin_unlocked(skin_data: Dictionary) -> bool:
	if skin_data.get("unlocked_by_default", false):
		return true

	var skin_id: String = skin_data.get("id", "")
	var gs = _get_game_state()
	if gs == null:
		return false

	if gs.has_method("has_cosmetic") and gs.has_cosmetic(skin_id):
		return true

	# Check fragment condition directly if not yet registered in cosmetics_unlocked
	var condition: String = skin_data.get("unlock_condition", "")
	if condition == "default":
		return true
	if condition.begins_with("fragment_") and gs.has_method("has_fragment"):
		var biome_key: String = condition.trim_prefix("fragment_")
		if gs.has_fragment(biome_key):
			return true

	return false

func _get_condition_display(condition: String) -> String:
	match condition:
		"default":
			return "Novato"
		"fragment_neuromath":
			return "Fragmento NeuroMath"
		"fragment_comunicarte":
			return "Fragmento ComunicArte"
		"fragment_activatuidea":
			return "Fragmento ActivaTuIdea"
		"fragment_gerencia":
			return "Fragmento Gerencia+"
		"fragment_misionales", "fragment_latidosocial":
			return "Fragmento LatidoSocial"
		"fragment_voxcivitas":
			return "Fragmento VoxCivitas"
		_:
			return condition.capitalize()

func _build_catalog_ui() -> void:
	if not is_instance_valid(skin_item_list):
		return

	for child in skin_item_list.get_children():
		child.queue_free()

	for skin_data in _catalog:
		var skin_id: String = skin_data.get("id", "")
		var skin_btn := Button.new()
		skin_btn.name = "SkinBtn_" + skin_id
		skin_btn.custom_minimum_size = Vector2(0, 30)
		skin_btn.focus_mode = Control.FOCUS_NONE
		skin_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var is_unlocked: bool = _is_skin_unlocked(skin_data)
		var gs = _get_game_state()
		var is_equipped: bool = (gs != null and gs.has_method("get_equipped_cosmetic") and gs.get_equipped_cosmetic() == skin_id)

		var status_badge: String = "[EQUIPADO]" if is_equipped else ("[DISPONIBLE]" if is_unlocked else "[BLOQUEADO]")
		skin_btn.text = " %s  %s" % [status_badge, skin_data.get("name", skin_id)]

		var accent := Color.from_string(skin_data.get("accent_color", "#FFFFFF"), Color.WHITE)
		if is_equipped:
			skin_btn.modulate = Color(0.2, 0.9, 1.0, 1)
		elif is_unlocked:
			skin_btn.modulate = accent
		else:
			skin_btn.modulate = Color(0.55, 0.58, 0.65, 0.8)

		skin_btn.pressed.connect(func(): select_skin(skin_id))
		skin_item_list.add_child(skin_btn)

func _refresh_list_selection() -> void:
	if not is_instance_valid(skin_item_list):
		return

	var gs = _get_game_state()
	var equipped_id: String = gs.get_equipped_cosmetic() if (gs and gs.has_method("get_equipped_cosmetic")) else DEFAULT_SKIN_ID

	for child in skin_item_list.get_children():
		if child is Button:
			var btn_skin_id: String = child.name.trim_prefix("SkinBtn_")
			var skin_data := _find_skin_data(btn_skin_id)
			var is_unlocked: bool = _is_skin_unlocked(skin_data)
			var is_equipped: bool = (btn_skin_id == equipped_id)
			var is_selected: bool = (btn_skin_id == _selected_skin_id)

			var status_badge: String = "[EQUIPADO]" if is_equipped else ("[DISPONIBLE]" if is_unlocked else "[BLOQUEADO]")
			var select_indicator: String = "▶ " if is_selected else "  "
			child.text = "%s%s %s" % [select_indicator, status_badge, skin_data.get("name", btn_skin_id)]

func _find_skin_data(skin_id: String) -> Dictionary:
	for item in _catalog:
		if item.get("id", "") == skin_id:
			return item
	return {}

func _on_action_button_pressed() -> void:
	var skin_data := _find_skin_data(_selected_skin_id)
	if skin_data.is_empty():
		return

	if not _is_skin_unlocked(skin_data):
		return

	var gs = _get_game_state()
	if gs and gs.has_method("equip_cosmetic"):
		# Ensure cosmetic is formally registered in unlocked array
		if gs.has_method("unlock_cosmetic") and not gs.has_cosmetic(_selected_skin_id):
			gs.unlock_cosmetic(_selected_skin_id)
		gs.equip_cosmetic(_selected_skin_id)
		cosmetic_equipped.emit(_selected_skin_id)

	# Refresh selection and catalog buttons
	select_skin(_selected_skin_id)
	_build_catalog_ui()
	_refresh_list_selection()

func _on_close_button_pressed() -> void:
	close_modal()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if get_viewport():
			get_viewport().set_input_as_handled()
		close_modal()

func _lock_player_movement(locked: bool) -> void:
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if not tree:
		return
	var player = tree.get_first_node_in_group("player")
	if player == null and tree.current_scene:
		player = tree.current_scene.find_child("Player", true, false)
	if player == null and tree.root:
		player = tree.root.find_child("Player", true, false)
	if player and "is_movement_locked" in player:
		player.is_movement_locked = locked

func _get_game_state() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root and loop.root.has_node("GameState"):
		return loop.root.get_node("GameState")
	return null
