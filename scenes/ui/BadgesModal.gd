extends CanvasLayer
class_name BadgesModal

## BadgesModal.gd — 500x300 px Academic Badges Showcase Modal for VirtuXperience 2D.
## Displays the 6 faculty badges in a 3x2 grid with unlocked and locked graphical states,
## pauses background world gameplay on open, and provides direct transition to FinalSummaryModal.

signal modal_opened
signal modal_closed
signal summary_requested

const LOCKED_MODULATE: Color = Color(0.25, 0.28, 0.35, 0.45)
const UNLOCKED_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
const LOCKED_TEXT: String = "Bloqueado: Recupera el fragmento en su bioma"

const BADGES_CONFIG: Array[Dictionary] = [
	{
		"id": "badge_arquitecto_cuantico",
		"name": "Arquitecto Cuántico",
		"faculty": "NeuroMath / Ciencias Exactas",
		"biome_id": "neuromath",
		"icon_path": "res://assets/ui/medals/PNG/flat_medal1.png",
		"accent_color": Color("#00E5FF"),
		"merit_text": "Maestría en álgebra booleana, secuencias numéricas y paridad cuántica."
	},
	{
		"id": "badge_barda_del_verbo",
		"name": "Barda del Verbo",
		"faculty": "ComunicArte / Humanidades",
		"biome_id": "comunicarte",
		"icon_path": "res://assets/ui/medals/PNG/flat_medal2.png",
		"accent_color": Color("#FF2A85"),
		"merit_text": "Maestría en retórica clásica, cohesión sintáctica y lectura crítica Saber Pro."
	},
	{
		"id": "badge_estratega_agil",
		"name": "Estratega Ágil",
		"faculty": "Gerencia+ / Ciencias Económicas",
		"biome_id": "gerencia",
		"icon_path": "res://assets/ui/medals/PNG/flat_medal3.png",
		"accent_color": Color("#4682B4"),
		"merit_text": "Liderazgo en gestión ágil, toma de decisiones estratégicas y optimización."
	},
	{
		"id": "badge_innovador_disruptivo",
		"name": "Innovador Disruptivo",
		"faculty": "ActivaTuIdea / Emprendimiento",
		"biome_id": "activatuidea",
		"icon_path": "res://assets/ui/medals/PNG/flat_medal4.png",
		"accent_color": Color("#FF8C00"),
		"merit_text": "Diseño de modelos de negocio sostenibles, validación MVP e ideación."
	},
	{
		"id": "badge_lider_comunitario",
		"name": "Líder Comunitario",
		"faculty": "LatidoSocial / Desarrollo Humano",
		"biome_id": "misionales",
		"icon_path": "res://assets/ui/medals/PNG/flat_medal5.png",
		"accent_color": Color("#4CAF50"),
		"merit_text": "Compromiso ético, resolución pacífica de conflictos y desarrollo comunitario."
	},
	{
		"id": "badge_guardian_civico",
		"name": "Guardián Cívico",
		"faculty": "VoxCivitas / Ciudadanía",
		"biome_id": "voxcivitas",
		"icon_path": "res://assets/ui/medals/PNG/flat_medal6.png",
		"accent_color": Color("#9C27B0"),
		"merit_text": "Ejercicio de ciudadanía activa, deliberación democrática y derechos civiles."
	}
]

@onready var modal_box: Control = $ModalBox
@onready var close_button: Button = $ModalBox/CloseButton
@onready var summary_button: Button = $ModalBox/SummaryButton
@onready var badges_grid: GridContainer = $ModalBox/BadgesGrid

var custom_game_state: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	visible = false
	add_to_group("badges_modal")
	add_to_group("ui_modal")
	
	_ensure_nodes()
	_connect_game_state()
	_build_or_update_cards()

func _ensure_nodes() -> void:
	if modal_box == null:
		modal_box = get_node_or_null("ModalBox")
	if close_button == null:
		close_button = get_node_or_null("ModalBox/CloseButton")
	if summary_button == null:
		summary_button = get_node_or_null("ModalBox/SummaryButton")
	if badges_grid == null:
		badges_grid = get_node_or_null("ModalBox/BadgesGrid")

func _get_game_state() -> Node:
	if custom_game_state != null:
		return custom_game_state
	if is_inside_tree():
		if has_node("/root/GameState"):
			return get_node("/root/GameState")
		var tree := get_tree()
		if tree and tree.root and tree.root.has_node("GameState"):
			return tree.root.get_node("GameState")
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null

func _connect_game_state() -> void:
	var gs := _get_game_state()
	if gs:
		if gs.has_signal("badge_unlocked") and not gs.badge_unlocked.is_connected(_on_badge_unlocked):
			gs.badge_unlocked.connect(_on_badge_unlocked)
		if gs.has_signal("fragment_awarded") and not gs.fragment_awarded.is_connected(_on_fragment_awarded):
			gs.fragment_awarded.connect(_on_fragment_awarded)

func _on_badge_unlocked(_badge_id: String) -> void:
	refresh_badges()

func _on_fragment_awarded(_biome_id: String, _count: int) -> void:
	refresh_badges()

## Opens the Badges modal, updates states, and pauses the game tree.
func open() -> void:
	_ensure_nodes()
	visible = true
	refresh_badges()
	
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree:
		tree.paused = true
		
	if is_instance_valid(close_button) and close_button.is_inside_tree():
		close_button.grab_focus()
		
	modal_opened.emit()

func open_modal() -> void:
	open()

## Closes the Badges modal and optionally unpauses the game tree.
func close(unpause_tree: bool = true) -> void:
	visible = false
	
	if unpause_tree:
		var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
		if tree:
			tree.paused = false
			
	modal_closed.emit()

func close_modal() -> void:
	close()

func is_open() -> bool:
	return visible

## Refreshes the unlocked/locked graphical presentation of all 6 cards.
func refresh_badges() -> void:
	_ensure_nodes()
	if badges_grid == null:
		return
		
	var gs := _get_game_state()
	for i in range(BADGES_CONFIG.size()):
		var config: Dictionary = BADGES_CONFIG[i]
		var card: Node = _get_card_at_index(i)
		if card == null:
			continue
			
		var badge_id: String = config.get("id", "")
		var is_unlocked: bool = false
		if gs and gs.has_method("has_badge"):
			is_unlocked = gs.has_badge(badge_id)
			
		_apply_card_state(card, config, is_unlocked)

func _get_card_at_index(index: int) -> Node:
	if badges_grid == null:
		return null
	if index < badges_grid.get_child_count():
		return badges_grid.get_child(index)
	return null

func _build_or_update_cards() -> void:
	if badges_grid == null:
		return
		
	# Self-healing: if cards were not pre-baked in scene tree, generate them dynamically
	while badges_grid.get_child_count() < BADGES_CONFIG.size():
		var idx: int = badges_grid.get_child_count()
		var card := _create_badge_card_node(idx)
		badges_grid.add_child(card)
		
	refresh_badges()

func _create_badge_card_node(index: int) -> PanelContainer:
	var container := PanelContainer.new()
	container.name = "Card_%d" % index
	container.custom_minimum_size = Vector2(153, 107)
	
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	container.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	var top_hbox := HBoxContainer.new()
	top_hbox.name = "TopHBox"
	top_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(top_hbox)
	
	var icon := TextureRect.new()
	icon.name = "MedalIcon"
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_hbox.add_child(icon)
	
	var title_vbox := VBoxContainer.new()
	title_vbox.name = "TitleVBox"
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 1)
	top_hbox.add_child(title_vbox)
	
	var title_lbl := Label.new()
	title_lbl.name = "BadgeName"
	title_lbl.add_theme_font_size_override("font_size", 8)
	title_vbox.add_child(title_lbl)
	
	var faculty_lbl := Label.new()
	faculty_lbl.name = "FacultyName"
	faculty_lbl.add_theme_font_size_override("font_size", 7)
	title_vbox.add_child(faculty_lbl)
	
	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.add_theme_font_size_override("font_size", 7)
	title_vbox.add_child(status_lbl)
	
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(0.2, 0.25, 0.35, 0.5)
	vbox.add_child(divider)
	
	var desc_lbl := Label.new()
	desc_lbl.name = "DescriptionLabel"
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 7)
	vbox.add_child(desc_lbl)
	
	return container

func _apply_card_state(card: Node, config: Dictionary, is_unlocked: bool) -> void:
	# Ensure internal structure exists inside card
	if card.get_child_count() == 0:
		var margin := MarginContainer.new()
		margin.name = "Margin"
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		card.add_child(margin)
		
		var vbox := VBoxContainer.new()
		vbox.name = "ContentVBox"
		vbox.add_theme_constant_override("separation", 4)
		margin.add_child(vbox)
		
		var top_hbox := HBoxContainer.new()
		top_hbox.name = "TopHBox"
		top_hbox.add_theme_constant_override("separation", 6)
		vbox.add_child(top_hbox)
		
		var icon := TextureRect.new()
		icon.name = "MedalIcon"
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top_hbox.add_child(icon)
		
		var title_vbox := VBoxContainer.new()
		title_vbox.name = "TitleVBox"
		title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_vbox.add_theme_constant_override("separation", 1)
		top_hbox.add_child(title_vbox)
		
		var title_lbl := Label.new()
		title_lbl.name = "BadgeName"
		title_lbl.add_theme_font_size_override("font_size", 8)
		title_vbox.add_child(title_lbl)
		
		var faculty_lbl := Label.new()
		faculty_lbl.name = "FacultyName"
		faculty_lbl.add_theme_font_size_override("font_size", 7)
		title_vbox.add_child(faculty_lbl)
		
		var status_lbl := Label.new()
		status_lbl.name = "StatusLabel"
		status_lbl.add_theme_font_size_override("font_size", 7)
		title_vbox.add_child(status_lbl)
		
		var divider := ColorRect.new()
		divider.name = "Divider"
		divider.custom_minimum_size = Vector2(0, 1)
		divider.color = Color(0.2, 0.25, 0.35, 0.5)
		vbox.add_child(divider)
		
		var desc_lbl := Label.new()
		desc_lbl.name = "DescriptionLabel"
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 7)
		vbox.add_child(desc_lbl)

	var icon_node := card.find_child("MedalIcon", true, false) as TextureRect
	var title_node := card.find_child("BadgeName", true, false) as Label
	var faculty_node := card.find_child("FacultyName", true, false) as Label
	var status_node := card.find_child("StatusLabel", true, false) as Label
	var desc_node := card.find_child("DescriptionLabel", true, false) as Label
	
	var icon_path: String = config.get("icon_path", "")
	if icon_node and ResourceLoader.exists(icon_path):
		icon_node.texture = load(icon_path)
		
	if is_unlocked:
		if icon_node:
			icon_node.modulate = UNLOCKED_MODULATE
		if title_node:
			title_node.text = config.get("name", "")
			title_node.add_theme_color_override("font_color", Color("#FFD700"))
		if faculty_node:
			faculty_node.text = config.get("faculty", "")
			faculty_node.add_theme_color_override("font_color", config.get("accent_color", Color.WHITE))
		if status_node:
			status_node.text = "[DESBLOQUEADO]"
			status_node.add_theme_color_override("font_color", Color("#00E676"))
		if desc_node:
			desc_node.text = config.get("merit_text", "")
			desc_node.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	else:
		if icon_node:
			icon_node.modulate = LOCKED_MODULATE
		if title_node:
			title_node.text = config.get("name", "")
			title_node.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68, 0.8))
		if faculty_node:
			faculty_node.text = config.get("faculty", "")
			faculty_node.add_theme_color_override("font_color", Color(0.40, 0.45, 0.52, 0.8))
		if status_node:
			status_node.text = "[BLOQUEADO]"
			status_node.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68, 0.7))
		if desc_node:
			desc_node.text = LOCKED_TEXT
			desc_node.add_theme_color_override("font_color", Color(0.45, 0.50, 0.58, 0.75))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if get_viewport():
			get_viewport().set_input_as_handled()
		close()

func _on_close_button_pressed() -> void:
	close()

func _on_summary_button_pressed() -> void:
	summary_requested.emit()
	close(false) # Close BadgesModal without unpausing tree
	_open_final_summary_modal()

func _open_final_summary_modal() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if not tree:
		return
		
	var summary_modal = tree.get_first_node_in_group("final_summary_modal")
	if summary_modal == null and tree.current_scene:
		summary_modal = tree.current_scene.find_child("FinalSummaryModal", true, false)
		
	if summary_modal == null:
		var scene_path := "res://scenes/ui/FinalSummaryModal.tscn"
		if ResourceLoader.exists(scene_path):
			var packed := load(scene_path) as PackedScene
			if packed:
				summary_modal = packed.instantiate()
				if tree.current_scene:
					tree.current_scene.add_child(summary_modal)
				else:
					tree.root.add_child(summary_modal)
					
	if summary_modal != null:
		if summary_modal.has_method("open"):
			summary_modal.open()
		elif summary_modal.has_method("open_summary"):
			summary_modal.open_summary()
		elif summary_modal.has_method("show_modal"):
			summary_modal.show_modal()
		else:
			summary_modal.visible = true
