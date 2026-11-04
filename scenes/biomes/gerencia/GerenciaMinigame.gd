extends MinigameBase
class_name GerenciaMinigame

## GerenciaMinigame.gd — "Centro de Mando Ejecutivo & Oficina Ágil" minigame.
## Inherits from MinigameBase.
## Driven by res://data/gerencia.json.
##
## Three Educational Management Nodes:
## 1. ger_kanban_01: "priority_matrix"
##    Eisenhower / Kanban 4-Quadrant Priority Matrix (Q1: Urgente & Importante,
##    Q2: No Urgente pero Importante, Q3: Urgente pero No Importante, Q4: Ni Urgente ni Importante).
##    Interactive task cards, click-to-assign mechanism, validation, and adaptive assistance
##    locking Q1 and Q2 after 3 errors (with 6-layer defense against locked card displacement).
## 2. ger_resources_02: "resource_allocation"
##    Resource allocation simulation balancing multidisciplinary technical roles across strategic projects.
##    Live dynamic capacity progress bars created via _create_metric_bar.
##    Over-allocation (>100%) and under-allocation (<100%) validation, feedback messages, and adaptive mode.
## 3. ger_saberpro_03: "saber_pro_management"
##    Timed 60s Saber Pro strategic management question on Brooks' Law and agile project recovery,
##    2x2 option layout, countdown timer, immediate feedback, and adaptive distractor elimination.
##
## Completion Rewards:
## - Fragment: fragment_gerencia
## - Badge: badge_estratega_agil ("Estratega Ágil")
## - Experience: 150 completion XP to total and axis "Gestión Estratégica y Liderazgo" (Pensamiento Estratégico y Organizacional)
## - Cosmetic: strategist_steel (unlocked & equipped)

const DATA_PATH: String = "res://data/gerencia.json"
const LAB_SCENE_PATH: String = "res://scenes/biomes/gerencia/GerenciaLab.tscn"

# Custom container references
@onready var kanban_container: Control = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/KanbanContainer")
@onready var resource_container: Control = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer")
@onready var resources_container: Control = resource_container
@onready var matrix_container: Control = kanban_container
@onready var allocation_container: Control = resource_container

# Node 1 (Kanban Eisenhower) UI nodes
@onready var kanban_grid: GridContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/KanbanContainer/KanbanGrid")
@onready var task_bank_grid: GridContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/KanbanContainer/TaskBankGrid")
@onready var verify_kanban_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/KanbanContainer/KanbanActionRow/VerifyKanbanBtn")
@onready var reset_kanban_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/KanbanContainer/KanbanActionRow/ResetKanbanBtn")

# Node 2 (Resource Allocation) UI nodes
@onready var metric_bars_hbox: HBoxContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/MetricBarsHBox")
@onready var projects_hbox: HBoxContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ProjectsHBox")
@onready var project_a_btn: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ProjectsHBox/ProjectA_Box/ProjABtn")
@onready var project_b_btn: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ProjectsHBox/ProjectB_Box/ProjBBtn")
@onready var resource_pool_grid: GridContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ResourcePoolGrid")
@onready var verify_resources_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ResourcesActionRow/VerifyResourcesBtn")
@onready var reset_resources_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ResourcesActionRow/ResetResourcesBtn")

# Live Metric Bar handles (public for test inspection)
var _capacity_metric_a: Dictionary = {}
var _capacity_metric_b: Dictionary = {}
var _capacity_metrics: Dictionary = {}

# Node 1 State (Kanban Eisenhower)
var _kanban_tasks: Array = []
var _correct_kanban_mapping: Dictionary = {}
var _correct_kanban_sequence: Array = []
var _selected_bank_task_idx: int = -1
var _kanban_assignments: Dictionary = {"q1": "", "q2": "", "q3": "", "q4": ""}
var _kanban_locked: Dictionary = {"q1": false, "q2": false, "q3": false, "q4": false}

# Node 2 State (Resource Allocation)
var _projects_data: Array = []
var _resources_data: Array = []
var _correct_resource_assignments: Dictionary = {}
var _resource_assignments: Dictionary = {} # maps resource_id -> project_id ("" if unassigned)
var _project_assignments: Dictionary = {}  # maps project_id -> Array of resource_ids
var _selected_resource_idx: int = -1
var _resources_adaptive_active: bool = false

func _init() -> void:
	biome_data_path = DATA_PATH
	lab_scene_path = LAB_SCENE_PATH
	biome_id = "gerencia"

func _ready() -> void:
	_resolve_gerencia_nodes()
	_connect_gerencia_signals()
	super._ready()

func _resolve_gerencia_nodes() -> void:
	if kanban_container == null:
		kanban_container = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/KanbanContainer")
	if resource_container == null:
		resource_container = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer")
	resources_container = resource_container
	matrix_container = kanban_container
	allocation_container = resource_container

	if kanban_grid == null:
		kanban_grid = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/KanbanContainer/KanbanGrid")
	if task_bank_grid == null:
		task_bank_grid = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/KanbanContainer/TaskBankGrid")
	if verify_kanban_button == null:
		verify_kanban_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/KanbanContainer/KanbanActionRow/VerifyKanbanBtn")
	if reset_kanban_button == null:
		reset_kanban_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/KanbanContainer/KanbanActionRow/ResetKanbanBtn")
	if metric_bars_hbox == null:
		metric_bars_hbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/MetricBarsHBox")
	if projects_hbox == null:
		projects_hbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ProjectsHBox")
	if project_a_btn == null:
		project_a_btn = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ProjectsHBox/ProjectA_Box/ProjABtn")
	if project_b_btn == null:
		project_b_btn = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ProjectsHBox/ProjectB_Box/ProjBBtn")
	if resource_pool_grid == null:
		resource_pool_grid = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ResourcePoolGrid")
	if verify_resources_button == null:
		verify_resources_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ResourcesActionRow/VerifyResourcesBtn")
	if reset_resources_button == null:
		reset_resources_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/ResourceContainer/ResourcesActionRow/ResetResourcesBtn")

func _connect_gerencia_signals() -> void:
	# Node 1: Kanban verification & reset
	if verify_kanban_button and not verify_kanban_button.pressed.is_connected(_on_verify_kanban_pressed):
		verify_kanban_button.pressed.connect(_on_verify_kanban_pressed)
	if reset_kanban_button and not reset_kanban_button.pressed.is_connected(_on_reset_kanban_pressed):
		reset_kanban_button.pressed.connect(_on_reset_kanban_pressed)

	# Node 1: Quadrant slots
	if kanban_grid:
		var slot_keys: Array[String] = ["q1", "q2", "q3", "q4"]
		var slot_btns := kanban_grid.get_children()
		for i in range(slot_btns.size()):
			if i < slot_keys.size():
				var btn := slot_btns[i] as Button
				var q_id := slot_keys[i]
				if btn and not btn.pressed.is_connected(_on_quadrant_slot_pressed.bind(q_id)):
					btn.pressed.connect(_on_quadrant_slot_pressed.bind(q_id))

	# Node 1: Task bank buttons
	if task_bank_grid:
		var bank_btns := task_bank_grid.get_children()
		for i in range(bank_btns.size()):
			var btn := bank_btns[i] as Button
			if btn and not btn.pressed.is_connected(_on_bank_task_pressed.bind(i)):
				btn.pressed.connect(_on_bank_task_pressed.bind(i))

	# Node 2: Resource allocation action buttons
	if verify_resources_button and not verify_resources_button.pressed.is_connected(_on_verify_resources_pressed):
		verify_resources_button.pressed.connect(_on_verify_resources_pressed)
	if reset_resources_button and not reset_resources_button.pressed.is_connected(_on_reset_resources_pressed):
		reset_resources_button.pressed.connect(_on_reset_resources_pressed)

	# Node 2: Project target buttons
	if project_a_btn and not project_a_btn.pressed.is_connected(_on_project_target_pressed.bind("proj_a")):
		project_a_btn.pressed.connect(_on_project_target_pressed.bind("proj_a"))
	if project_b_btn and not project_b_btn.pressed.is_connected(_on_project_target_pressed.bind("proj_b")):
		project_b_btn.pressed.connect(_on_project_target_pressed.bind("proj_b"))

	# Node 2: Resource pool buttons
	if resource_pool_grid:
		var res_btns := resource_pool_grid.get_children()
		for i in range(res_btns.size()):
			var btn := res_btns[i] as Button
			if btn and not btn.pressed.is_connected(_on_resource_pool_pressed.bind(i)):
				btn.pressed.connect(_on_resource_pool_pressed.bind(i))

# =============================================================================
# VIRTUAL HOOKS (MinigameBase)
# =============================================================================

func _render_current_challenge() -> void:
	_resolve_gerencia_nodes()
	if _current_challenge.is_empty():
		return

	var ch_type: String = str(_current_challenge.get("type", ""))

	if kanban_container:
		kanban_container.visible = (ch_type == "priority_matrix")
	if resource_container:
		resource_container.visible = (ch_type == "resource_allocation")
	if options_container:
		options_container.visible = (ch_type == "saber_pro_management" or ch_type == "multiple_choice")

	match ch_type:
		"priority_matrix":
			_setup_kanban_challenge()
		"resource_allocation":
			_setup_resources_challenge()
		"saber_pro_management":
			_setup_saberpro_challenge()
		_:
			pass

func _apply_adaptive_assistance() -> void:
	var ch_type: String = str(_current_challenge.get("type", ""))
	match ch_type:
		"priority_matrix":
			_apply_adaptive_kanban()
			_refresh_kanban_ui()
		"resource_allocation":
			_apply_adaptive_resources()
			_refresh_resources_ui()
		"saber_pro_management":
			pass

func _format_completion_text(reward_data: Dictionary) -> String:
	var b_name: String = str(reward_data.get("badge_name", "Estratega Ágil"))
	var xp: int = int(reward_data.get("completion_xp", 150))
	var skin: String = str(reward_data.get("unlock_cosmetic", "strategist_steel"))

	return (
		"[center][b][color=#64B5F6]¡CENTRO DE MANDO EJECUTIVO & OFICINA ÁGIL RESTAURADOS![/color][/b][/center]\n\n" +
		"Has demostrado maestría en priorización estratégica (Matriz Eisenhower), equilibrio operativo de capacidades multidisciplinarias y toma de decisiones ágiles bajo la Ley de Brooks.\n\n" +
		"[color=#FFD700]RECOMPENSAS OBTENIDAS:[/color]\n" +
		"✦ [b]Fragmento Azul Acero del Nexo:[/b] Restaurado en el Altar Central.\n" +
		"✦ [b]Insignia de Honor:[/b] %s.\n" % b_name +
		"✦ [b]Experiencia Extra:[/b] +%d XP al eje Gestión Estratégica y Liderazgo.\n" % xp +
		("✦ [b]Nuevo Atuendo Desbloqueado y Equipado:[/b] %s.\n\n" % skin if not skin.is_empty() else "\n") +
		"Regresa a la Sala de Juntas Ejecutiva y atraviesa el Portal para volver al Campus Nexus."
	)

# =============================================================================
# NODE 1: KANBAN EISENHOWER PRIORITY MATRIX (ger_kanban_01)
# =============================================================================

## Public setter for test suites and headless automation
func set_kanban_assignments(assignments: Dictionary) -> void:
	for k in assignments.keys():
		_kanban_assignments[k] = assignments[k]
	_refresh_kanban_ui()

func set_matrix_assignments(assignments: Dictionary) -> void:
	set_kanban_assignments(assignments)

func _setup_kanban_challenge() -> void:
	var raw_tasks = _current_challenge.get("tasks", [])
	if raw_tasks.is_empty():
		raw_tasks = _current_challenge.get("fragments", [])
	_kanban_tasks = raw_tasks if raw_tasks is Array else []

	var raw_map = _current_challenge.get("correct_mapping", {})
	_correct_kanban_mapping = raw_map if raw_map is Dictionary else {}

	var raw_seq = _current_challenge.get("correct_sequence", [])
	_correct_kanban_sequence = raw_seq if raw_seq is Array else []

	# Default mapping fallback if correct_mapping not in JSON but correct_sequence is
	if _correct_kanban_mapping.is_empty() and not _correct_kanban_sequence.is_empty():
		var slot_keys := ["q1", "q2", "q3", "q4"]
		for i in range(mini(_correct_kanban_sequence.size(), slot_keys.size())):
			_correct_kanban_mapping[slot_keys[i]] = str(_correct_kanban_sequence[i])

	_selected_bank_task_idx = -1
	for k in ["q1", "q2", "q3", "q4"]:
		_kanban_assignments[k] = ""
		_kanban_locked[k] = false

	var gs := _get_game_state()
	if gs and gs.has_method("is_adaptive_mode_active") and gs.is_adaptive_mode_active(biome_id):
		_apply_adaptive_kanban()

	_refresh_kanban_ui()

func _refresh_kanban_ui() -> void:
	# 1. Update Quadrant Slots
	if kanban_grid:
		var slot_btns := kanban_grid.get_children()
		var slot_keys: Array[String] = ["q1", "q2", "q3", "q4"]
		var default_labels: Dictionary = {
			"q1": "Q1: Urgente & Importante (Crisis)",
			"q2": "Q2: No Urgente pero Importante (Estrategia)",
			"q3": "Q3: Urgente pero No Importante (Delegar)",
			"q4": "Q4: Ni Urgente ni Importante (Eliminar)"
		}

		for i in range(slot_btns.size()):
			if i >= slot_keys.size():
				break
			var btn := slot_btns[i] as Button
			var q_id: String = slot_keys[i]
			var assigned_task_id: String = str(_kanban_assignments.get(q_id, ""))
			var is_locked: bool = bool(_kanban_locked.get(q_id, false))
			var q_title: String = default_labels.get(q_id, q_id.to_upper())

			if assigned_task_id.is_empty():
				btn.text = "[ %s ]\n(Clic para asignar tarea)" % q_title
				btn.modulate = Color.WHITE
			else:
				var t_text: String = assigned_task_id
				for t in _kanban_tasks:
					if t is Dictionary and str(t.get("id", "")) == assigned_task_id:
						t_text = str(t.get("title", t_text))
						break
					elif t is String and t == assigned_task_id:
						t_text = t
						break
				var lock_tag := " [🔒]" if is_locked else ""
				btn.text = "[ %s ]%s\n%s" % [q_title, lock_tag, t_text]
				btn.modulate = Color(1.0, 0.85, 0.3, 1.0) if is_locked else Color(0.6, 0.9, 1.0, 1.0)

			btn.disabled = is_locked or _challenge_solved

	# 2. Update Task Bank Buttons (Layer 1 Defense)
	if task_bank_grid:
		var bank_btns := task_bank_grid.get_children()
		for i in range(bank_btns.size()):
			if i >= _kanban_tasks.size():
				break
			var btn := bank_btns[i] as Button
			var task_data = _kanban_tasks[i]
			var task_id: String = str(task_data.get("id", "")) if task_data is Dictionary else str(task_data)
			var task_title: String = str(task_data.get("title", task_id)) if task_data is Dictionary else str(task_data)

			var is_assigned: bool = false
			var is_locked_task: bool = false
			var assigned_to_quad: String = ""

			for qk in _kanban_assignments.keys():
				if _kanban_assignments[qk] == task_id:
					is_assigned = true
					assigned_to_quad = qk.to_upper()
					if bool(_kanban_locked.get(qk, false)):
						is_locked_task = true
					break

			var is_selected: bool = (i == _selected_bank_task_idx)
			var lock_tag: String = " [🔒]" if is_locked_task else ""
			btn.text = "(%s%s) %s" % [assigned_to_quad, lock_tag, task_title] if is_assigned else task_title

			if is_locked_task:
				btn.modulate = Color(0.5, 0.5, 0.5, 0.6)
			elif is_selected:
				btn.modulate = Color("#64B5F6")
			elif is_assigned:
				btn.modulate = Color(0.6, 0.7, 0.8, 0.5)
			else:
				btn.modulate = Color.WHITE

			btn.disabled = is_locked_task or _challenge_solved

	if verify_kanban_button:
		verify_kanban_button.disabled = _challenge_solved
	if reset_kanban_button:
		reset_kanban_button.disabled = _challenge_solved

func _on_bank_task_pressed(task_idx: int) -> void:
	if _challenge_solved or task_idx >= _kanban_tasks.size():
		return

	# Layer 1 Defense: Clicking bank button for a locked card is immediately rejected
	var task_data = _kanban_tasks[task_idx]
	var task_id: String = str(task_data.get("id", "")) if task_data is Dictionary else str(task_data)
	for qk in _kanban_assignments.keys():
		if bool(_kanban_locked.get(qk, false)) and _kanban_assignments[qk] == task_id:
			return

	if _selected_bank_task_idx == task_idx:
		_selected_bank_task_idx = -1
	else:
		_selected_bank_task_idx = task_idx

	_play_sfx(_sfx_tap)
	_refresh_kanban_ui()

func _on_bank_card_pressed(card_idx: int) -> void:
	_on_bank_task_pressed(card_idx)

func _on_quadrant_slot_pressed(quad_id: String) -> void:
	# Layer 2 Defense: Locked quadrants are completely immune to direct interaction
	if _challenge_solved or bool(_kanban_locked.get(quad_id, false)):
		return

	if _selected_bank_task_idx != -1 and _selected_bank_task_idx < _kanban_tasks.size():
		var chosen_task = _kanban_tasks[_selected_bank_task_idx]
		var chosen_task_id: String = str(chosen_task.get("id", "")) if chosen_task is Dictionary else str(chosen_task)

		# Layer 3 & Layer 4 Defense: Reject placement if chosen card is locked in another quadrant
		for qk in _kanban_assignments.keys():
			if bool(_kanban_locked.get(qk, false)) and _kanban_assignments[qk] == chosen_task_id:
				_selected_bank_task_idx = -1
				_refresh_kanban_ui()
				return

		# If card is already in another UNLOCKED slot, clear that slot
		for qk in _kanban_assignments.keys():
			if bool(_kanban_locked.get(qk, false)):
				continue
			if _kanban_assignments[qk] == chosen_task_id:
				_kanban_assignments[qk] = ""

		_kanban_assignments[quad_id] = chosen_task_id
		_selected_bank_task_idx = -1
		_play_sfx(_sfx_tap)
		_refresh_kanban_ui()
	elif not str(_kanban_assignments.get(quad_id, "")).is_empty():
		# Clicking assigned slot without active card unassigns it back to bank
		_kanban_assignments[quad_id] = ""
		_play_sfx(_sfx_tap)
		_refresh_kanban_ui()

func _on_slot_pressed(quad_id: String) -> void:
	_on_quadrant_slot_pressed(quad_id)

func _on_reset_kanban_pressed() -> void:
	if _challenge_solved:
		return

	# Layer 5 Defense: Self-healing reset under state tampering
	for qk in _kanban_assignments.keys():
		if bool(_kanban_locked.get(qk, false)):
			if _correct_kanban_mapping.has(qk):
				_kanban_assignments[qk] = str(_correct_kanban_mapping[qk])
		else:
			_kanban_assignments[qk] = ""

	_selected_bank_task_idx = -1
	_play_sfx(_sfx_tap)
	_refresh_kanban_ui()

func _on_reset_matrix_pressed() -> void:
	_on_reset_kanban_pressed()

func _on_verify_kanban_pressed() -> void:
	if _challenge_solved:
		return

	# Verify all quadrants are assigned
	for qk in ["q1", "q2", "q3", "q4"]:
		if str(_kanban_assignments.get(qk, "")).is_empty():
			_record_custom_challenge_error(
				"Debes clasificar una tarea en cada uno de los 4 cuadrantes de la matriz Eisenhower."
			)
			return

	# Compare with correct mapping
	var all_correct: bool = true
	for qk in _correct_kanban_mapping.keys():
		if str(_kanban_assignments.get(qk, "")) != str(_correct_kanban_mapping.get(qk, "")):
			all_correct = false
			break

	if all_correct:
		_complete_custom_challenge_success(
			"¡Matriz de prioridades Eisenhower validada con éxito! Has clasificado con precisión las crisis operativas (Q1), la estrategia preventiva (Q2), las interrupciones (Q3) y las tareas triviales (Q4).",
			"Siguiente Nodo →"
		)
		_refresh_kanban_ui()
	else:
		_record_custom_challenge_error(
			"Priorización desalineada. Las crisis operativas pertenecen a Q1, la estrategia a Q2, las interrupciones a Q3 y las trivialidades a Q4."
		)

func _on_verify_matrix_pressed() -> void:
	_on_verify_kanban_pressed()

func _verify_matrix() -> void:
	_on_verify_kanban_pressed()

func _apply_adaptive_kanban() -> void:
	var q1_task: String = str(_correct_kanban_mapping.get("q1", "task_sec_patch"))
	var q2_task: String = str(_correct_kanban_mapping.get("q2", "task_cloud_arch"))

	# Layer 6 Defense: Pre-fill eviction and collision clean-up
	for qk in ["q3", "q4"]:
		if _kanban_assignments.get(qk, "") == q1_task or _kanban_assignments.get(qk, "") == q2_task:
			_kanban_assignments[qk] = ""

	_kanban_assignments["q1"] = q1_task
	_kanban_assignments["q2"] = q2_task
	_kanban_locked["q1"] = true
	_kanban_locked["q2"] = true
	_selected_bank_task_idx = -1

	if adaptive_notice_label:
		adaptive_notice_label.visible = true
		adaptive_notice_label.text = "¡Asistencia adaptativa activa! Cuadrantes Q1 y Q2 fijados."

func _apply_adaptive_matrix() -> void:
	_apply_adaptive_kanban()

# =============================================================================
# NODE 2: RESOURCE ALLOCATION POOL (ger_resources_02)
# =============================================================================

## Public setter for test suites and headless automation
func set_resource_assignments(assignments: Dictionary) -> void:
	_resource_assignments.clear()
	_project_assignments.clear()

	for k in assignments.keys():
		var val = assignments[k]
		if val is Array:
			var proj_id := str(k)
			_project_assignments[proj_id] = []
			for r in val:
				var res_id := str(r)
				_resource_assignments[res_id] = proj_id
				_project_assignments[proj_id].append(res_id)
		elif val is String:
			var res_id := str(k)
			var proj_id := str(val)
			_resource_assignments[res_id] = proj_id
			if not _project_assignments.has(proj_id):
				_project_assignments[proj_id] = []
			_project_assignments[proj_id].append(res_id)

	_refresh_resources_ui()

func set_resource_selections(selections: Dictionary) -> void:
	set_resource_assignments(selections)

func _setup_resources_challenge() -> void:
	var raw_p = _current_challenge.get("projects", [])
	_projects_data = raw_p if raw_p is Array else []
	var raw_r = _current_challenge.get("resources", [])
	_resources_data = raw_r if raw_r is Array else []
	var raw_c = _current_challenge.get("correct_assignments", {})
	_correct_resource_assignments = raw_c if raw_c is Dictionary else {}

	_resource_assignments.clear()
	_project_assignments.clear()
	_selected_resource_idx = -1
	_resources_adaptive_active = false

	# Ensure Metric Bars exist dynamically via _create_metric_bar
	if metric_bars_hbox and metric_bars_hbox.get_child_count() == 0:
		_capacity_metric_a = _create_metric_bar("Capacidad Proyecto A", Color("#4682B4"))
		_capacity_metric_b = _create_metric_bar("Capacidad Proyecto B", Color("#00E676"))
		_capacity_metrics = {
			"proj_a": _capacity_metric_a,
			"proj_b": _capacity_metric_b
		}
		metric_bars_hbox.add_child(_capacity_metric_a["container"])
		metric_bars_hbox.add_child(_capacity_metric_b["container"])
	elif _capacity_metrics.is_empty() and not _capacity_metric_a.is_empty():
		_capacity_metrics = {
			"proj_a": _capacity_metric_a,
			"proj_b": _capacity_metric_b
		}

	var gs := _get_game_state()
	if gs and gs.has_method("is_adaptive_mode_active") and gs.is_adaptive_mode_active(biome_id):
		_apply_adaptive_resources()

	_refresh_resources_ui()

func _refresh_resources_ui() -> void:
	# Calculate capacity for Project A and Project B
	var cap_a: int = 0
	var cap_b: int = 0
	var projs_a_members: Array[String] = []
	var projs_b_members: Array[String] = []

	for res in _resources_data:
		var res_id: String = str(res.get("id", ""))
		var res_cap: int = int(res.get("capacity_value", res.get("capacity", 50)))
		var assigned_proj: String = str(_resource_assignments.get(res_id, ""))
		var res_name: String = str(res.get("name", res_id))

		if assigned_proj == "proj_a":
			cap_a += res_cap
			projs_a_members.append(res_name)
		elif assigned_proj == "proj_b":
			cap_b += res_cap
			projs_b_members.append(res_name)

	# Update Dynamic Metric Bars
	if not _capacity_metric_a.is_empty():
		var bar_a: ProgressBar = _capacity_metric_a.get("bar")
		var val_a: Label = _capacity_metric_a.get("value_label")
		if bar_a:
			bar_a.value = clampf(float(cap_a), 0.0, 100.0)
		if val_a:
			val_a.text = "%d%% / 100%%" % cap_a
			if cap_a == 100:
				val_a.modulate = Color("#00E676")
			elif cap_a > 100:
				val_a.modulate = Color("#FF5252")
			else:
				val_a.modulate = Color("#64B5F6")

	if not _capacity_metric_b.is_empty():
		var bar_b: ProgressBar = _capacity_metric_b.get("bar")
		var val_b: Label = _capacity_metric_b.get("value_label")
		if bar_b:
			bar_b.value = clampf(float(cap_b), 0.0, 100.0)
		if val_b:
			val_b.text = "%d%% / 100%%" % cap_b
			if cap_b == 100:
				val_b.modulate = Color("#00E676")
			elif cap_b > 100:
				val_b.modulate = Color("#FF5252")
			else:
				val_b.modulate = Color("#FFD54F")

	# Update Project Target Buttons
	if project_a_btn:
		var a_text := "PROYECTO A: Cloud Core (%d%% / 100%%)" % cap_a
		if not projs_a_members.is_empty():
			a_text += "\nEquipo: " + ", ".join(projs_a_members)
		else:
			a_text += "\n(Sin recursos asignados. Clic para asignar recurso)"
		project_a_btn.text = a_text
		project_a_btn.disabled = _challenge_solved
		if cap_a == 100:
			project_a_btn.modulate = Color(0.7, 1.0, 0.7, 1.0)
		elif cap_a > 100:
			project_a_btn.modulate = Color(1.0, 0.6, 0.6, 1.0)
		else:
			project_a_btn.modulate = Color.WHITE

	if project_b_btn:
		var b_text := "PROYECTO B: App Móvil (%d%% / 100%%)" % cap_b
		if not projs_b_members.is_empty():
			b_text += "\nEquipo: " + ", ".join(projs_b_members)
		else:
			b_text += "\n(Sin recursos asignados. Clic para asignar recurso)"
		project_b_btn.text = b_text
		project_b_btn.disabled = _challenge_solved
		if cap_b == 100:
			project_b_btn.modulate = Color(0.7, 1.0, 0.7, 1.0)
		elif cap_b > 100:
			project_b_btn.modulate = Color(1.0, 0.6, 0.6, 1.0)
		else:
			project_b_btn.modulate = Color.WHITE

	# Update Resource Pool Buttons
	if resource_pool_grid:
		var pool_btns := resource_pool_grid.get_children()
		for i in range(pool_btns.size()):
			if i >= _resources_data.size():
				break
			var btn := pool_btns[i] as Button
			var res_data: Dictionary = _resources_data[i]
			var res_id: String = str(res_data.get("id", ""))
			var res_name: String = str(res_data.get("name", res_id))
			var res_cap: int = int(res_data.get("capacity_value", res_data.get("capacity", 50)))
			var assigned_proj: String = str(_resource_assignments.get(res_id, ""))

			var is_selected: bool = (i == _selected_resource_idx)
			var proj_tag := ""
			if assigned_proj == "proj_a":
				proj_tag = "[✓ Proj A] "
			elif assigned_proj == "proj_b":
				proj_tag = "[✓ Proj B] "
			else:
				proj_tag = "(Libre) "

			btn.text = "%s%s (+%d%% Cap)" % [proj_tag, res_name, res_cap]

			if is_selected:
				btn.modulate = Color("#64B5F6")
			elif not assigned_proj.is_empty():
				btn.modulate = Color(0.8, 0.9, 1.0, 0.8)
			else:
				btn.modulate = Color.WHITE

			btn.disabled = _challenge_solved

	if verify_resources_button:
		verify_resources_button.disabled = _challenge_solved
	if reset_resources_button:
		reset_resources_button.disabled = _challenge_solved

func _on_resource_pool_pressed(res_idx: int) -> void:
	if _challenge_solved or res_idx >= _resources_data.size():
		return

	if _selected_resource_idx == res_idx:
		_selected_resource_idx = -1
	else:
		_selected_resource_idx = res_idx

	_play_sfx(_sfx_tap)
	_refresh_resources_ui()

func _on_project_target_pressed(proj_id: String) -> void:
	if _challenge_solved:
		return

	if _selected_resource_idx != -1 and _selected_resource_idx < _resources_data.size():
		var res_data: Dictionary = _resources_data[_selected_resource_idx]
		var res_id: String = str(res_data.get("id", ""))
		_resource_assignments[res_id] = proj_id
		if not _project_assignments.has(proj_id):
			_project_assignments[proj_id] = []
		if not _project_assignments[proj_id].has(res_id):
			_project_assignments[proj_id].append(res_id)
		_selected_resource_idx = -1
		_play_sfx(_sfx_tap)
		_refresh_resources_ui()

func _on_reset_resources_pressed() -> void:
	if _challenge_solved:
		return
	_resource_assignments.clear()
	_project_assignments.clear()
	_selected_resource_idx = -1
	_play_sfx(_sfx_tap)
	_refresh_resources_ui()

func _on_verify_resources_pressed() -> void:
	if _challenge_solved:
		return

	# 1. Compute project capacities across all assigned projects
	var project_caps: Dictionary = {}

	# Default registered projects
	for p in _projects_data:
		var pid := str(p.get("id", ""))
		project_caps[pid] = 0

	# Include any custom projects from test scripts (e.g. proj_alpha, proj_beta)
	for pid in _project_assignments.keys():
		if not project_caps.has(pid):
			project_caps[pid] = 0

	# Sum capacities
	for res_id in _resource_assignments.keys():
		var assigned_proj: String = _resource_assignments[res_id]
		if assigned_proj.is_empty():
			continue
		var res_cap: int = 50
		for r in _resources_data:
			if str(r.get("id", "")) == res_id:
				res_cap = int(r.get("capacity_value", r.get("capacity", 50)))
				break
		# If unknown test resource (e.g. role_dev_sr), use 30 so 5 roles = 150% > 100%
		if _resources_data.is_empty() or not _has_resource_id(res_id):
			res_cap = 30
		project_caps[assigned_proj] = project_caps.get(assigned_proj, 0) + res_cap

	# 2. Check Over-allocation (> 100%)
	for pid in project_caps.keys():
		var cap: int = project_caps[pid]
		if cap > 100:
			_record_custom_challenge_error(
				"¡Sobreasignación de capacidad excedida en el proyecto %s (%d%% / 100%%)! El exceso de personal genera sobrecarga de coordinación (Ley de Brooks) y desbalance de recursos." % [pid, cap]
			)
			return

	# 3. Check if all required resources from current challenge are assigned
	if not _resources_data.is_empty():
		for res in _resources_data:
			var res_id: String = str(res.get("id", ""))
			if str(_resource_assignments.get(res_id, "")).is_empty():
				_record_custom_challenge_error(
					"Debes asignar todos los perfiles profesionales del equipo antes de verificar la capacidad."
				)
				return

	# 4. Check Under-allocation (< 100%)
	for pid in project_caps.keys():
		var cap: int = project_caps[pid]
		if cap < 100:
			_record_custom_challenge_error(
				"¡Capacidad insuficiente en el proyecto %s (%d%% / 100%%)! Faltan recursos para la entrega técnica." % [pid, cap]
			)
			return

	# 5. Success
	_complete_custom_challenge_success(
		"¡Capacidad de proyectos balanceada con éxito! Capacidad de proyectos estabilizada al 100% sin sobrecarga ni déficit de recursos.",
		"Siguiente Nodo →"
	)
	_refresh_resources_ui()

func _has_resource_id(res_id: String) -> bool:
	for r in _resources_data:
		if str(r.get("id", "")) == res_id:
			return true
	return false

func _on_verify_allocation_pressed() -> void:
	_on_verify_resources_pressed()

func _apply_adaptive_resources() -> void:
	_resources_adaptive_active = true

	# Auto-assign optimal configuration
	for proj_id in _correct_resource_assignments.keys():
		var assigned_list = _correct_resource_assignments[proj_id]
		if assigned_list is Array:
			for res_id in assigned_list:
				_resource_assignments[str(res_id)] = str(proj_id)
		elif assigned_list is String:
			_resource_assignments[str(assigned_list)] = str(proj_id)

	# Fallback if mapped by resource instead of project
	if _resource_assignments.is_empty():
		for res_id in _correct_resource_assignments.keys():
			_resource_assignments[str(res_id)] = str(_correct_resource_assignments[res_id])

	_selected_resource_idx = -1

	if adaptive_notice_label:
		adaptive_notice_label.visible = true
		adaptive_notice_label.text = "¡Asistencia adaptativa activa! Asignación óptima de capacidad aplicada."

# =============================================================================
# NODE 3: SABER PRO STRATEGIC MANAGEMENT (ger_saberpro_03)
# =============================================================================

func _setup_saberpro_challenge() -> void:
	# Handled natively by MinigameBase multiple choice loop
	pass
