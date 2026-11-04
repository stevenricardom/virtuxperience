extends MinigameBase
class_name ActivaTuIdeaMinigame

## ActivaTuIdeaMinigame.gd — "Fábrica de Innovación & Taller de Prototipado" minigame.
## Inherits from MinigameBase.
## Driven by res://data/activatuidea.json.
##
## Three Educational Innovation Nodes:
## 1. act_canvas_01: "business_canvas"
##    Lean Canvas 2x2 matrix (Problema/Solución, Propuesta de Valor, Clientes/Canales, Costos/Ingresos).
##    Card buttons, click-to-assign mechanism, validation, and adaptive assistance locking Q1 & Q2 after 3 fails.
## 2. act_factory_02: "tiny_factory_line"
##    Interactive simulation of 3 stations (Design CAD, Assembly CNC, Quality QA).
##    Machine trade-offs with live Budget ($) and Quality (%) progress bars created via _create_metric_bar.
##    Validates max_budget ($10,000) and min_quality (80%). Adaptive mode highlights optimal combination.
## 3. act_saberpro_03: "saber_pro_innovation"
##    Timed 60s Saber Pro challenge on MVP validation, 2x2 answer grid, immediate pedagogical feedback,
##    and adaptive elimination of 2 distractors.
##
## Completion Rewards:
## - Fragment: fragment_activatuidea
## - Badge: badge_innovador_disruptivo
## - Experience: 150 XP to total and axis "Innovación y Modelado de Emprendimiento"
## - Cosmetic: innovator_orange (unlocked & equipped)

const DATA_PATH: String = "res://data/activatuidea.json"
const LAB_SCENE_PATH: String = "res://scenes/biomes/activatuidea/ActivaTuIdeaLab.tscn"

# Custom container references
@onready var canvas_container: Control = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CanvasContainer")
@onready var factory_container: Control = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/FactoryContainer")

# Node 1 (Canvas) nodes
@onready var canvas_grid: GridContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CanvasContainer/CanvasGrid")
@onready var card_bank_grid: GridContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CanvasContainer/CardBankGrid")
@onready var verify_canvas_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CanvasContainer/CanvasActionRow/VerifyCanvasBtn")
@onready var reset_canvas_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CanvasContainer/CanvasActionRow/ResetCanvasBtn")

# Node 2 (Factory) nodes
@onready var metric_bars_hbox: HBoxContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/FactoryContainer/MetricBarsHBox")
@onready var stations_hbox: HBoxContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/FactoryContainer/StationsHBox")
@onready var verify_factory_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/FactoryContainer/FactoryActionRow/VerifyFactoryBtn")
@onready var reset_factory_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/FactoryContainer/FactoryActionRow/ResetFactoryBtn")

# Metric Bar handles (public for test inspection)
var _budget_metric: Dictionary = {}
var _quality_metric: Dictionary = {}

# Node 1 State (Canvas)
var _canvas_blocks: Array = []
var _canvas_cards: Array = []
var _correct_canvas_mapping: Dictionary = {}
var _selected_bank_card_idx: int = -1
var _canvas_assignments: Dictionary = {"q1": "", "q2": "", "q3": "", "q4": ""}
var _canvas_locked: Dictionary = {"q1": false, "q2": false, "q3": false, "q4": false}

# Node 2 State (Factory)
var _factory_stations: Array = []
var _max_budget: int = 10000
var _min_quality: int = 80
var _optimal_selection: Dictionary = {}
var _selected_machines: Dictionary = {}
var _station_options_map: Dictionary = {}
var _factory_adaptive_active: bool = false

func _init() -> void:
	biome_data_path = DATA_PATH
	lab_scene_path = LAB_SCENE_PATH
	biome_id = "activatuidea"

func _ready() -> void:
	_resolve_activatuidea_nodes()
	_connect_activatuidea_signals()
	super._ready()

func _resolve_activatuidea_nodes() -> void:
	if canvas_container == null:
		canvas_container = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CanvasContainer")
	if factory_container == null:
		factory_container = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/FactoryContainer")
	if canvas_grid == null:
		canvas_grid = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CanvasContainer/CanvasGrid")
	if card_bank_grid == null:
		card_bank_grid = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CanvasContainer/CardBankGrid")
	if verify_canvas_button == null:
		verify_canvas_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CanvasContainer/CanvasActionRow/VerifyCanvasBtn")
	if reset_canvas_button == null:
		reset_canvas_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CanvasContainer/CanvasActionRow/ResetCanvasBtn")
	if metric_bars_hbox == null:
		metric_bars_hbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/FactoryContainer/MetricBarsHBox")
	if stations_hbox == null:
		stations_hbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/FactoryContainer/StationsHBox")
	if verify_factory_button == null:
		verify_factory_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/FactoryContainer/FactoryActionRow/VerifyFactoryBtn")
	if reset_factory_button == null:
		reset_factory_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/FactoryContainer/FactoryActionRow/ResetFactoryBtn")

func _connect_activatuidea_signals() -> void:
	# Canvas action buttons
	if verify_canvas_button and not verify_canvas_button.pressed.is_connected(_on_verify_canvas_pressed):
		verify_canvas_button.pressed.connect(_on_verify_canvas_pressed)
	if reset_canvas_button and not reset_canvas_button.pressed.is_connected(_on_reset_canvas_pressed):
		reset_canvas_button.pressed.connect(_on_reset_canvas_pressed)

	# Canvas quadrant slots
	if canvas_grid:
		var slot_keys: Array[String] = ["q1", "q2", "q3", "q4"]
		var slot_btns := canvas_grid.get_children()
		for i in range(slot_btns.size()):
			if i < slot_keys.size():
				var btn := slot_btns[i] as Button
				var q_id := slot_keys[i]
				if btn and not btn.pressed.is_connected(_on_quadrant_slot_pressed.bind(q_id)):
					btn.pressed.connect(_on_quadrant_slot_pressed.bind(q_id))

	# Canvas card bank buttons
	if card_bank_grid:
		var bank_btns := card_bank_grid.get_children()
		for i in range(bank_btns.size()):
			var btn := bank_btns[i] as Button
			if btn and not btn.pressed.is_connected(_on_bank_card_pressed.bind(i)):
				btn.pressed.connect(_on_bank_card_pressed.bind(i))

	# Factory action buttons
	if verify_factory_button and not verify_factory_button.pressed.is_connected(_on_verify_factory_pressed):
		verify_factory_button.pressed.connect(_on_verify_factory_pressed)
	if reset_factory_button and not reset_factory_button.pressed.is_connected(_on_reset_factory_pressed):
		reset_factory_button.pressed.connect(_on_reset_factory_pressed)

# =============================================================================
# VIRTUAL HOOKS (MinigameBase)
# =============================================================================

func _render_current_challenge() -> void:
	_resolve_activatuidea_nodes()
	if _current_challenge.is_empty():
		return

	var ch_type: String = str(_current_challenge.get("type", ""))

	if canvas_container:
		canvas_container.visible = (ch_type == "business_canvas")
	if factory_container:
		factory_container.visible = (ch_type == "tiny_factory_line")
	if options_container:
		options_container.visible = (ch_type == "saber_pro_innovation" or ch_type == "multiple_choice")

	match ch_type:
		"business_canvas":
			_setup_canvas_challenge()
		"tiny_factory_line":
			_setup_factory_challenge()
		"saber_pro_innovation":
			_setup_saber_pro_challenge()
		_:
			pass

func _apply_adaptive_assistance() -> void:
	var ch_type: String = str(_current_challenge.get("type", ""))
	match ch_type:
		"business_canvas":
			_apply_adaptive_canvas()
			_refresh_canvas_ui()
		"tiny_factory_line":
			_apply_adaptive_factory()
			_refresh_factory_ui()
		"saber_pro_innovation":
			pass

func _format_completion_text(reward_data: Dictionary) -> String:
	var b_name: String = str(reward_data.get("badge_name", "Innovador Disruptivo"))
	var xp: int = int(reward_data.get("completion_xp", 150))
	var skin: String = str(reward_data.get("unlock_cosmetic", "innovator_orange"))

	return (
		"[center][b][color=#FF8C00]¡FÁBRICA DE INNOVACIÓN Y TALLER DE PROTOTIPADO RESTAURADOS![/color][/b][/center]\n\n" +
		"Has demostrado maestría en diseño de modelos de negocio (Lean Canvas), optimización de líneas de fabricación y validación iterativa de MVPs.\n\n" +
		"[color=#FFD700]RECOMPENSAS OBTENIDAS:[/color]\n" +
		"✦ [b]Fragmento Naranja del Nexo:[/b] Restaurado en el Altar Central.\n" +
		"✦ [b]Insignia de Honor:[/b] %s.\n" % b_name +
		"✦ [b]Experiencia Extra:[/b] +%d XP al eje Innovación y Emprendimiento.\n" % xp +
		("✦ [b]Nuevo Atuendo Desbloqueado y Equipado:[/b] %s.\n\n" % skin if not skin.is_empty() else "\n") +
		"Regresa al Taller de Prototipado y atraviesa el Portal para volver al Campus Nexus."
	)

# =============================================================================
# NODE 1: LEAN CANVAS 2x2 (act_canvas_01)
# =============================================================================

func set_canvas_assignments(assignments: Dictionary) -> void:
	for k in assignments.keys():
		_canvas_assignments[k] = assignments[k]
	_refresh_canvas_ui()

func _setup_canvas_challenge() -> void:
	var raw_blocks = _current_challenge.get("blocks", [])
	_canvas_blocks = raw_blocks if raw_blocks is Array else []
	var raw_cards = _current_challenge.get("cards", [])
	_canvas_cards = raw_cards if raw_cards is Array else []
	var raw_map = _current_challenge.get("correct_mapping", {})
	_correct_canvas_mapping = raw_map if raw_map is Dictionary else {}

	_selected_bank_card_idx = -1
	for k in ["q1", "q2", "q3", "q4"]:
		_canvas_assignments[k] = ""
		_canvas_locked[k] = false

	var gs := _get_game_state()
	if gs and gs.has_method("is_adaptive_mode_active") and gs.is_adaptive_mode_active(biome_id):
		_apply_adaptive_canvas()

	_refresh_canvas_ui()

func _refresh_canvas_ui() -> void:
	# Update quadrant slot buttons
	if canvas_grid:
		var slot_btns := canvas_grid.get_children()
		var slot_keys: Array[String] = ["q1", "q2", "q3", "q4"]
		for i in range(slot_btns.size()):
			if i >= slot_keys.size():
				break
			var btn := slot_btns[i] as Button
			var q_id: String = slot_keys[i]
			var assigned_card_id: String = str(_canvas_assignments.get(q_id, ""))
			var is_locked: bool = bool(_canvas_locked.get(q_id, false))

			var q_title: String = "Cuadrante %s" % q_id.to_upper()
			for blk in _canvas_blocks:
				if str(blk.get("id", "")) == q_id:
					q_title = str(blk.get("label", q_title))
					break

			if assigned_card_id.is_empty():
				btn.text = "[ %s ]\n(Clic para asignar tarjeta)" % q_title
				btn.modulate = Color.WHITE
			else:
				var c_text: String = assigned_card_id
				for c in _canvas_cards:
					if str(c.get("id", "")) == assigned_card_id:
						c_text = str(c.get("text", c_text))
						break
				var lock_tag := " [🔒]" if is_locked else ""
				btn.text = "[ %s ]%s\n%s" % [q_title, lock_tag, c_text]
				btn.modulate = Color(1.0, 0.85, 0.3, 1.0) if is_locked else Color(0.7, 1.0, 0.7, 1.0)

			btn.disabled = is_locked or _challenge_solved

	# Update card bank buttons
	if card_bank_grid:
		var bank_btns := card_bank_grid.get_children()
		for i in range(bank_btns.size()):
			if i >= _canvas_cards.size():
				break
			var btn := bank_btns[i] as Button
			var card_data: Dictionary = _canvas_cards[i]
			var card_id: String = str(card_data.get("id", ""))
			var card_text: String = str(card_data.get("text", ""))

			var is_assigned: bool = false
			var is_locked_card: bool = false
			var assigned_to_quad: String = ""
			for qk in _canvas_assignments.keys():
				if _canvas_assignments[qk] == card_id:
					is_assigned = true
					assigned_to_quad = qk.to_upper()
					if bool(_canvas_locked.get(qk, false)):
						is_locked_card = true
					break

			var is_selected: bool = (i == _selected_bank_card_idx)
			var lock_tag: String = " [🔒]" if is_locked_card else ""
			btn.text = "(%s%s) %s" % [assigned_to_quad, lock_tag, card_text] if is_assigned else card_text

			if is_locked_card:
				btn.modulate = Color(0.5, 0.5, 0.5, 0.6)
			elif is_selected:
				btn.modulate = Color("#FF8C00")
			elif is_assigned:
				btn.modulate = Color(0.6, 0.6, 0.6, 0.5)
			else:
				btn.modulate = Color.WHITE

			btn.disabled = is_locked_card or _challenge_solved

	if verify_canvas_button:
		verify_canvas_button.disabled = _challenge_solved
	if reset_canvas_button:
		reset_canvas_button.disabled = _challenge_solved

func _on_bank_card_pressed(card_idx: int) -> void:
	if _challenge_solved or card_idx >= _canvas_cards.size():
		return

	var card_data: Dictionary = _canvas_cards[card_idx]
	var card_id: String = str(card_data.get("id", ""))
	for qk in _canvas_assignments.keys():
		if bool(_canvas_locked.get(qk, false)) and _canvas_assignments[qk] == card_id:
			# Card is locked in a quadrant; selection is rejected
			return

	if _selected_bank_card_idx == card_idx:
		_selected_bank_card_idx = -1
	else:
		_selected_bank_card_idx = card_idx

	_play_sfx(_sfx_tap)
	_refresh_canvas_ui()

func _on_quadrant_slot_pressed(quad_id: String) -> void:
	if _challenge_solved or bool(_canvas_locked.get(quad_id, false)):
		return

	if _selected_bank_card_idx != -1 and _selected_bank_card_idx < _canvas_cards.size():
		var chosen_card_id: String = str(_canvas_cards[_selected_bank_card_idx].get("id", ""))

		# Guard: If chosen_card_id is locked in another quadrant, abort placement
		for qk in _canvas_assignments.keys():
			if bool(_canvas_locked.get(qk, false)) and _canvas_assignments[qk] == chosen_card_id:
				_selected_bank_card_idx = -1
				_refresh_canvas_ui()
				return

		# If card is already in another UNLOCKED slot, clear that slot
		for qk in _canvas_assignments.keys():
			if bool(_canvas_locked.get(qk, false)):
				continue
			if _canvas_assignments[qk] == chosen_card_id:
				_canvas_assignments[qk] = ""

		_canvas_assignments[quad_id] = chosen_card_id
		_selected_bank_card_idx = -1
		_play_sfx(_sfx_tap)
		_refresh_canvas_ui()
	elif not str(_canvas_assignments.get(quad_id, "")).is_empty():
		# Clicking assigned slot without active card unassigns it
		_canvas_assignments[quad_id] = ""
		_play_sfx(_sfx_tap)
		_refresh_canvas_ui()

func _on_reset_canvas_pressed() -> void:
	if _challenge_solved:
		return
	for qk in _canvas_assignments.keys():
		if bool(_canvas_locked.get(qk, false)):
			if _correct_canvas_mapping.has(qk):
				_canvas_assignments[qk] = str(_correct_canvas_mapping[qk])
		else:
			_canvas_assignments[qk] = ""
	_selected_bank_card_idx = -1
	_play_sfx(_sfx_tap)
	_refresh_canvas_ui()

func _on_verify_canvas_pressed() -> void:
	if _challenge_solved:
		return

	# Verify all quadrants are assigned
	for qk in ["q1", "q2", "q3", "q4"]:
		if str(_canvas_assignments.get(qk, "")).is_empty():
			_record_custom_challenge_error(
				"Debes asignar una tarjeta a cada uno de los 4 cuadrantes del Lean Canvas para validar el modelo."
			)
			return

	# Compare with correct mapping
	var all_correct: bool = true
	for qk in _correct_canvas_mapping.keys():
		if str(_canvas_assignments.get(qk, "")) != str(_correct_canvas_mapping.get(qk, "")):
			all_correct = false
			break

	if all_correct:
		_complete_custom_challenge_success(
			"¡Lienzo Lean Canvas validado con éxito! Propuesta de valor, canales y finanzas articulados correctamente.",
			"Siguiente Nodo →"
		)
		_refresh_canvas_ui()
	else:
		_record_custom_challenge_error(
			"Estructura incoherente en el modelo de negocio. Revisa la coherencia entre el dolor del cliente (Q1), la propuesta de valor (Q2) y el flujo financiero (Q4)."
		)

func _apply_adaptive_canvas() -> void:
	# Lock q1 and q2 with correct cards
	var q1_card: String = str(_correct_canvas_mapping.get("q1", "card_prob_sol"))
	var q2_card: String = str(_correct_canvas_mapping.get("q2", "card_value_prop"))

	# Clear any conflicting assignments in unlocked quadrants (q3, q4)
	for qk in ["q3", "q4"]:
		if _canvas_assignments.get(qk, "") == q1_card or _canvas_assignments.get(qk, "") == q2_card:
			_canvas_assignments[qk] = ""

	_canvas_assignments["q1"] = q1_card
	_canvas_assignments["q2"] = q2_card
	_canvas_locked["q1"] = true
	_canvas_locked["q2"] = true
	_selected_bank_card_idx = -1

	if adaptive_notice_label:
		adaptive_notice_label.visible = true
		adaptive_notice_label.text = "¡Asistencia adaptativa activa! Cuadrantes Q1 y Q2 fijados."

# =============================================================================
# NODE 2: TINY FACTORY SIMULATION (act_factory_02)
# =============================================================================

func set_factory_selections(selections: Dictionary) -> void:
	_selected_machines = selections.duplicate()
	_refresh_factory_ui()

func _setup_factory_challenge() -> void:
	var raw_st = _current_challenge.get("stations", [])
	_factory_stations = raw_st if raw_st is Array else []
	_max_budget = int(_current_challenge.get("max_budget", 10000))
	_min_quality = int(_current_challenge.get("min_quality", 80))
	var raw_opt = _current_challenge.get("optimal_selection", {})
	_optimal_selection = raw_opt if raw_opt is Dictionary else {}
	_selected_machines.clear()
	_station_options_map.clear()
	_factory_adaptive_active = false

	# Ensure Metric Bars exist
	if metric_bars_hbox and metric_bars_hbox.get_child_count() == 0:
		_budget_metric = _create_metric_bar("Presupuesto ($)", Color("#FF8C00"))
		_quality_metric = _create_metric_bar("Calidad (%)", Color("#00E676"))
		metric_bars_hbox.add_child(_budget_metric["container"])
		metric_bars_hbox.add_child(_quality_metric["container"])

	# Build options map and connect station option buttons
	for st in _factory_stations:
		var st_id: String = str(st.get("id", ""))
		var opts: Array = st.get("options", [])
		for o in opts:
			var opt_id: String = str(o.get("id", ""))
			_station_options_map[opt_id] = {
				"station_id": st_id,
				"cost": int(o.get("cost", 0)),
				"quality": int(o.get("quality", 0)),
				"label": str(o.get("label", ""))
			}

	_connect_station_buttons()

	var gs := _get_game_state()
	if gs and gs.has_method("is_adaptive_mode_active") and gs.is_adaptive_mode_active(biome_id):
		_apply_adaptive_factory()

	_refresh_factory_ui()

func _connect_station_buttons() -> void:
	if not stations_hbox:
		return
	var cols := stations_hbox.get_children()
	for col_idx in range(cols.size()):
		if col_idx >= _factory_stations.size():
			break
		var col := cols[col_idx] as Control
		var st_data: Dictionary = _factory_stations[col_idx]
		var st_id: String = str(st_data.get("id", ""))
		var opts: Array = st_data.get("options", [])

		var btns: Array = []
		for child in col.get_children():
			if child is Button:
				btns.append(child)

		for b_idx in range(btns.size()):
			if b_idx < opts.size():
				var btn := btns[b_idx] as Button
				var opt_data: Dictionary = opts[b_idx]
				var opt_id: String = str(opt_data.get("id", ""))
				btn.set_meta("station_id", st_id)
				btn.set_meta("option_id", opt_id)
				if not btn.pressed.is_connected(_on_station_option_pressed.bind(st_id, opt_id)):
					btn.pressed.connect(_on_station_option_pressed.bind(st_id, opt_id))

func _on_station_option_pressed(station_id: String, option_id: String) -> void:
	if _challenge_solved:
		return
	_selected_machines[station_id] = option_id
	_play_sfx(_sfx_tap)
	_refresh_factory_ui()

func _refresh_factory_ui() -> void:
	# Calculate total cost and average quality
	var total_cost: int = 0
	var quality_sum: float = 0.0
	var selected_count: int = 0

	for st_id in _selected_machines.keys():
		var opt_id: String = _selected_machines[st_id]
		if _station_options_map.has(opt_id):
			var opt_info: Dictionary = _station_options_map[opt_id]
			total_cost += int(opt_info.get("cost", 0))
			quality_sum += float(opt_info.get("quality", 0))
			selected_count += 1

	var avg_quality: float = (quality_sum / float(selected_count)) if selected_count > 0 else 0.0

	# Update Metric Bars
	if not _budget_metric.is_empty():
		var b_bar: ProgressBar = _budget_metric.get("bar")
		var b_val: Label = _budget_metric.get("value_label")
		if b_bar:
			b_bar.value = clampf((float(total_cost) / float(_max_budget)) * 100.0, 0.0, 100.0)
		if b_val:
			b_val.text = "$%d / $%d" % [total_cost, _max_budget]
			b_val.modulate = Color("#FF5252") if total_cost > _max_budget else Color("#FF8C00")

	if not _quality_metric.is_empty():
		var q_bar: ProgressBar = _quality_metric.get("bar")
		var q_val: Label = _quality_metric.get("value_label")
		if q_bar:
			q_bar.value = clampf(avg_quality, 0.0, 100.0)
		if q_val:
			q_val.text = "%.1f%% (Mín %d%%)" % [avg_quality, _min_quality]
			q_val.modulate = Color("#00E676") if avg_quality >= float(_min_quality) else Color("#FFD54F")

	# Update Station Button visuals
	if stations_hbox:
		for col in stations_hbox.get_children():
			for child in col.get_children():
				if child is Button and child.has_meta("station_id") and child.has_meta("option_id"):
					var st_id: String = str(child.get_meta("station_id"))
					var opt_id: String = str(child.get_meta("option_id"))
					var is_selected: bool = (_selected_machines.get(st_id, "") == opt_id)
					var is_optimal: bool = (_factory_adaptive_active and _optimal_selection.get(st_id, "") == opt_id)

					var opt_info: Dictionary = _station_options_map.get(opt_id, {})
					var cost: int = int(opt_info.get("cost", 0))
					var qual: int = int(opt_info.get("quality", 0))
					var lbl: String = str(opt_info.get("label", opt_id))

					var prefix: String = ""
					if is_optimal:
						prefix = "[ÓPTIMO] "
						child.modulate = Color(1.0, 0.85, 0.2, 1.0)
					elif is_selected:
						prefix = "[✓] "
						child.modulate = Color("#FF8C00")
					else:
						child.modulate = Color.WHITE

					child.text = "%s%s ($%d | %d%%)" % [prefix, lbl, cost, qual]
					child.disabled = _challenge_solved

	if verify_factory_button:
		verify_factory_button.disabled = _challenge_solved
	if reset_factory_button:
		reset_factory_button.disabled = _challenge_solved

func _on_reset_factory_pressed() -> void:
	if _challenge_solved:
		return
	_selected_machines.clear()
	_play_sfx(_sfx_tap)
	_refresh_factory_ui()

func _on_verify_factory_pressed() -> void:
	if _challenge_solved:
		return

	if _selected_machines.size() < _factory_stations.size():
		_record_custom_challenge_error(
			"Debes seleccionar una máquina para cada una de las 3 estaciones de la línea de prototipado."
		)
		return

	var total_cost: int = 0
	var quality_sum: float = 0.0
	for st_id in _selected_machines.keys():
		var opt_id: String = _selected_machines[st_id]
		var opt_info: Dictionary = _station_options_map.get(opt_id, {})
		total_cost += int(opt_info.get("cost", 0))
		quality_sum += float(opt_info.get("quality", 0))

	var avg_quality: float = quality_sum / float(_selected_machines.size())

	if total_cost > _max_budget:
		_record_custom_challenge_error(
			"¡Presupuesto excedido! ($%d / $%d). Optimiza la selección de máquinas para reducir costos." % [total_cost, _max_budget]
		)
	elif avg_quality < float(_min_quality):
		_record_custom_challenge_error(
			"¡Calidad insuficiente! (%.1f%% / %d%%). Se requieren componentes de mayor precisión técnica." % [avg_quality, _min_quality]
		)
	else:
		_complete_custom_challenge_success(
			"¡Línea de Prototipado validada! Presupuesto: $%d/$%d | Calidad: %.1f%%/%d%%. Producción del MVP aprobada." % [total_cost, _max_budget, avg_quality, _min_quality],
			"Siguiente Nodo →"
		)
		_refresh_factory_ui()

func _apply_adaptive_factory() -> void:
	_factory_adaptive_active = true
	# Auto-select optimal configuration
	for st_id in _optimal_selection.keys():
		_selected_machines[st_id] = str(_optimal_selection[st_id])

	if adaptive_notice_label:
		adaptive_notice_label.visible = true
		adaptive_notice_label.text = "¡Asistencia adaptativa activa! Configuración óptima resaltada."

# =============================================================================
# NODE 3: SABER PRO INNOVATION (act_saberpro_03)
# =============================================================================

func _setup_saber_pro_challenge() -> void:
	# Handled natively by MinigameBase multiple choice loop
	pass
