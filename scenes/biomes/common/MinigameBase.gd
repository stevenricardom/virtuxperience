class_name MinigameBase
extends Control

## MinigameBase.gd — Standardized 3-phase minigame engine for VirtuXperience 2D.
## Manages learning capsule pagination, challenge progression loop, countdown timers,
## hint deductions, adaptive difficulty, and atomic GameState reward distribution.

signal minigame_completed(summary: Dictionary)
signal challenge_answered(is_correct: bool, xp_earned: int)
signal challenge_result_recorded(challenge_id: String, is_correct: bool, xp_earned: int)

@export var biome_data_path: String = ""
@export var lab_scene_path: String = ""
@export var biome_id: String = ""

# Dependency injection for isolated headless unit tests
var custom_game_state: Node = null
var custom_scene_manager: Node = null

# Core UI Node references (resilient lookup with null guards)
@onready var title_label: Label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/Header/TitleLabel"]) as Label
@onready var node_indicator_label: Label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/Header/NodeIndicatorLabel"]) as Label
@onready var timer_label: Label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/Header/TimerLabel"]) as Label
@onready var return_button: Button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/Header/ReturnButton"]) as Button

# Phase 1: Capsule nodes
@onready var capsule_panel: Control = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel"]) as Control
@onready var capsule_title: Label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel/CapsuleTitle"]) as Label
@onready var capsule_text: RichTextLabel = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel/CapsuleText"]) as RichTextLabel
@onready var capsule_page_label: Label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel/CapsuleFooter/PageLabel"]) as Label
@onready var capsule_prev_button: Button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel/CapsuleFooter/PrevButton"]) as Button
@onready var capsule_next_button: Button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel/CapsuleFooter/NextButton"]) as Button

# Phase 2: Challenge nodes
@onready var challenge_view: Control = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView"]) as Control
@onready var thought_axis_label: Label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/ThoughtAxisLabel"]) as Label
@onready var prompt_text: RichTextLabel = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/PromptText"]) as RichTextLabel
@onready var options_container: Control = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/OptionsContainer"]) as Control
@onready var option_buttons: Array[Button] = _resolve_option_buttons()
@onready var feedback_label: RichTextLabel = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/FeedbackBar/FeedbackLabel"]) as RichTextLabel
@onready var hint_button: Button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/FeedbackBar/ButtonsRow/HintButton"]) as Button
@onready var adaptive_notice_label: Label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/FeedbackBar/ButtonsRow/AdaptiveNoticeLabel"]) as Label
@onready var next_button: Button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/FeedbackBar/ButtonsRow/NextButton"]) as Button

# Phase 3: Completion nodes
@onready var completion_panel: Control = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CompletionPanel"]) as Control
@onready var completion_details: RichTextLabel = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CompletionPanel/CompletionDetails"]) as RichTextLabel
@onready var return_to_lab_button: Button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CompletionPanel/ReturnToLabButton"]) as Button

# SFX Player & Audio resources
@onready var sfx_player: AudioStreamPlayer = _resolve_node(["SFXPlayer"]) as AudioStreamPlayer
var _sfx_click: AudioStream = preload("res://assets/ui/ui_pack/Sounds/click-a.ogg")
var _sfx_error: AudioStream = preload("res://assets/ui/ui_pack/Sounds/click-b.ogg")
var _sfx_success: AudioStream = preload("res://assets/ui/ui_pack/Sounds/switch-a.ogg")
var _sfx_tap: AudioStream = preload("res://assets/ui/ui_pack/Sounds/tap-a.ogg")

# Internal state
var _biome_data: Dictionary = {}
var _capsule_pages: Array[String] = []
var _current_capsule_page: int = 0
var _challenges: Array = []
var _current_challenge_index: int = 0
var _current_challenge: Dictionary = {}

var _timer_active: bool = false
var _time_left: float = 60.0
var _hint_used_this_challenge: bool = false
var _challenge_solved: bool = false
var adaptive_threshold: int = 3
var eliminated_count: int = 2

# Compatibility getters/setters
var biome_data: Dictionary:
	get: return _biome_data
	set(val): _biome_data = val

var capsule_pages: Array[String]:
	get: return _capsule_pages
	set(val): _capsule_pages = val

var current_capsule_page: int:
	get: return _current_capsule_page
	set(val): _current_capsule_page = val

var challenges: Array:
	get: return _challenges
	set(val): _challenges = val

var current_challenge_index: int:
	get: return _current_challenge_index
	set(val): _current_challenge_index = val

var current_challenge: Dictionary:
	get: return _current_challenge
	set(val): _current_challenge = val

var is_timer_active: bool:
	get: return _timer_active
	set(val): _timer_active = val

var time_left: float:
	get: return _time_left
	set(val): _time_left = val

var hint_used_this_challenge: bool:
	get: return _hint_used_this_challenge
	set(val): _hint_used_this_challenge = val

var is_challenge_solved: bool:
	get: return _challenge_solved
	set(val): _challenge_solved = val

func _ready() -> void:
	custom_minimum_size = Vector2(640, 360)
	_ensure_node_references()
	_load_data()
	_connect_base_signals()
	_show_learning_capsule()

func _ensure_node_references() -> void:
	if title_label == null:
		title_label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/Header/TitleLabel"]) as Label
	if node_indicator_label == null:
		node_indicator_label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/Header/NodeIndicatorLabel"]) as Label
	if timer_label == null:
		timer_label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/Header/TimerLabel"]) as Label
	if return_button == null:
		return_button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/Header/ReturnButton"]) as Button
	if capsule_panel == null:
		capsule_panel = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel"]) as Control
	if capsule_title == null:
		capsule_title = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel/CapsuleTitle"]) as Label
	if capsule_text == null:
		capsule_text = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel/CapsuleText"]) as RichTextLabel
	if capsule_page_label == null:
		capsule_page_label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel/CapsuleFooter/PageLabel"]) as Label
	if capsule_prev_button == null:
		capsule_prev_button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel/CapsuleFooter/PrevButton"]) as Button
	if capsule_next_button == null:
		capsule_next_button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CapsulePanel/CapsuleFooter/NextButton"]) as Button
	if challenge_view == null:
		challenge_view = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView"]) as Control
	if thought_axis_label == null:
		thought_axis_label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/ThoughtAxisLabel"]) as Label
	if prompt_text == null:
		prompt_text = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/PromptText"]) as RichTextLabel
	if options_container == null:
		options_container = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/OptionsContainer"]) as Control
	if option_buttons.is_empty():
		option_buttons = _resolve_option_buttons()
	if feedback_label == null:
		feedback_label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/FeedbackBar/FeedbackLabel"]) as RichTextLabel
	if hint_button == null:
		hint_button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/FeedbackBar/ButtonsRow/HintButton"]) as Button
	if adaptive_notice_label == null:
		adaptive_notice_label = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/FeedbackBar/ButtonsRow/AdaptiveNoticeLabel"]) as Label
	if next_button == null:
		next_button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/ChallengeView/FeedbackBar/ButtonsRow/NextButton"]) as Button
	if completion_panel == null:
		completion_panel = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CompletionPanel"]) as Control
	if completion_details == null:
		completion_details = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CompletionPanel/CompletionDetails"]) as RichTextLabel
	if return_to_lab_button == null:
		return_to_lab_button = _resolve_node(["MainPanel/MarginContainer/VBoxContainer/CompletionPanel/ReturnToLabButton"]) as Button
	if sfx_player == null:
		sfx_player = _resolve_node(["SFXPlayer"]) as AudioStreamPlayer

func _resolve_node(paths: Array[String]) -> Node:
	for p in paths:
		var n := get_node_or_null(p)
		if n != null:
			return n
	return null

func _resolve_option_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for opt_name in ["OptionA", "OptionB", "OptionC", "OptionD"]:
		var b := get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/OptionsContainer/" + opt_name) as Button
		if b != null:
			result.append(b)
	return result

func _load_data() -> void:
	if not biome_data_path.is_empty():
		_biome_data = BiomeDataLoader.load_biome_data(biome_data_path)
		if not _biome_data.is_empty():
			_capsule_pages = BiomeDataLoader.extract_learning_capsule(_biome_data)
			var raw_challenges = _biome_data.get("challenges", [])
			_challenges = raw_challenges if raw_challenges is Array else []
			if biome_id.is_empty():
				biome_id = str(_biome_data.get("biome_id", "biome"))
			var adapt_params := BiomeDataLoader.extract_adaptive_parameters(_biome_data)
			adaptive_threshold = adapt_params.get("consecutive_failures_trigger", 3)
			eliminated_count = adapt_params.get("eliminated_options_count", 2)

func _connect_base_signals() -> void:
	if return_button and not return_button.pressed.is_connected(_on_return_pressed):
		return_button.pressed.connect(_on_return_pressed)
	if return_to_lab_button and not return_to_lab_button.pressed.is_connected(_on_return_pressed):
		return_to_lab_button.pressed.connect(_on_return_pressed)

	if capsule_prev_button and not capsule_prev_button.pressed.is_connected(_on_capsule_prev_pressed):
		capsule_prev_button.pressed.connect(_on_capsule_prev_pressed)
	if capsule_next_button and not capsule_next_button.pressed.is_connected(_on_capsule_next_pressed):
		capsule_next_button.pressed.connect(_on_capsule_next_pressed)

	if hint_button and not hint_button.pressed.is_connected(_on_hint_pressed):
		hint_button.pressed.connect(_on_hint_pressed)
	if next_button and not next_button.pressed.is_connected(_on_next_challenge_pressed):
		next_button.pressed.connect(_on_next_challenge_pressed)

	for i in range(option_buttons.size()):
		var btn := option_buttons[i]
		if btn and not btn.pressed.is_connected(_on_option_button_pressed.bind(i)):
			btn.pressed.connect(_on_option_button_pressed.bind(i))

func _process(delta: float) -> void:
	if _timer_active:
		_time_left -= delta
		if timer_label:
			timer_label.text = "TIEMPO: %02ds" % maxi(0, int(ceil(_time_left)))
			timer_label.modulate = Color("#FF5252") if _time_left <= 10.0 else Color("#00E5FF")

		if _time_left <= 0.0:
			_on_timer_timeout()

# =============================================================================
# PHASE 1: LEARNING CAPSULE
# =============================================================================

func _show_learning_capsule() -> void:
	if capsule_panel:
		capsule_panel.visible = true
	if challenge_view:
		challenge_view.visible = false
	if completion_panel:
		completion_panel.visible = false
	if timer_label:
		timer_label.visible = false
	if node_indicator_label:
		var raw_g = _biome_data.get("guardian", {})
		var g_dict: Dictionary = raw_g if raw_g is Dictionary else {}
		var g_name: String = str(g_dict.get("name", "CÁPSULA"))
		node_indicator_label.text = "ORIENTACIÓN: %s" % g_name

	_current_capsule_page = 0
	_render_capsule_page()

func _render_capsule_page() -> void:
	if _capsule_pages.is_empty():
		_start_challenge(0)
		return

	if capsule_text:
		capsule_text.text = _capsule_pages[_current_capsule_page]
	if capsule_page_label:
		capsule_page_label.text = "Página %d de %d" % [_current_capsule_page + 1, _capsule_pages.size()]
	if capsule_prev_button:
		capsule_prev_button.disabled = (_current_capsule_page == 0)

	if capsule_next_button:
		if _current_capsule_page == _capsule_pages.size() - 1:
			capsule_next_button.text = "Iniciar Retos →"
		else:
			capsule_next_button.text = "Siguiente →"

func _on_capsule_prev_pressed() -> void:
	_play_sfx(_sfx_tap)
	if _current_capsule_page > 0:
		_current_capsule_page -= 1
		_render_capsule_page()

func _on_capsule_next_pressed() -> void:
	_play_sfx(_sfx_tap)
	if _current_capsule_page < _capsule_pages.size() - 1:
		_current_capsule_page += 1
		_render_capsule_page()
	else:
		_start_challenge(0)

# =============================================================================
# PHASE 2: CHALLENGE LOOP
# =============================================================================

func _start_challenge(index: int) -> void:
	if index >= _challenges.size():
		_complete_minigame()
		return

	_current_challenge_index = index
	_current_challenge = _challenges[index] as Dictionary
	_challenge_solved = false
	_hint_used_this_challenge = false

	if capsule_panel:
		capsule_panel.visible = false
	if challenge_view:
		challenge_view.visible = true
	if completion_panel:
		completion_panel.visible = false
	if next_button:
		next_button.visible = false

	if node_indicator_label:
		node_indicator_label.text = "NODO: %d/%d" % [_current_challenge_index + 1, _challenges.size()]
	if thought_axis_label:
		thought_axis_label.text = "Eje: %s" % _current_challenge.get("thought_axis", "Razonamiento Académico")
	if prompt_text:
		prompt_text.text = "[b]%s[/b]\n%s" % [
			_current_challenge.get("title", "Reto"),
			_current_challenge.get("prompt", "")
		]

	if feedback_label:
		feedback_label.text = ""
	if adaptive_notice_label:
		adaptive_notice_label.visible = false
	if hint_button:
		hint_button.disabled = false
		var cost: int = int(_current_challenge.get("hint_cost_xp", 10))
		hint_button.text = "Pista (-%d XP)" % cost

	# Timer setup for timed challenges
	var time_limit: int = int(_current_challenge.get("time_limit_seconds", 0))
	if time_limit > 0:
		_time_left = float(time_limit)
		_timer_active = true
		if timer_label:
			timer_label.visible = true
			timer_label.modulate = Color("#00E5FF")
			timer_label.text = "TIEMPO: %02ds" % int(_time_left)
	else:
		_timer_active = false
		if timer_label:
			timer_label.visible = false

	# Setup multiple choice option buttons
	_setup_options()

	# Check persistent adaptive difficulty
	var gs := _get_game_state()
	if gs and gs.has_method("is_adaptive_mode_active") and gs.is_adaptive_mode_active(biome_id):
		_apply_adaptive_mode(true)

	# Virtual hook for child class challenge rendering
	_render_current_challenge()

func _setup_options() -> void:
	var raw_opts = _current_challenge.get("options", [])
	var options: Array = raw_opts if raw_opts is Array else []
	for i in range(option_buttons.size()):
		var btn := option_buttons[i]
		if not btn:
			continue
		if i < options.size():
			var opt_data: Dictionary = options[i]
			btn.visible = true
			btn.disabled = false
			btn.text = "%s) %s" % [str(opt_data.get("id", "")).to_upper(), str(opt_data.get("label", ""))]
			btn.set_meta("option_id", str(opt_data.get("id", "")))
		else:
			btn.visible = false

func _on_option_button_pressed(button_index: int) -> void:
	if _challenge_solved or button_index >= option_buttons.size():
		return

	var btn := option_buttons[button_index]
	var chosen_id: String = str(btn.get_meta("option_id", ""))
	_handle_option_selected(chosen_id)

## Handles option validation and triggers success/failure actions.
func _handle_option_selected(option_data: Variant) -> void:
	var chosen_id := str(option_data)
	var correct_id := str(_current_challenge.get("correct_option", ""))
	var challenge_id := str(_current_challenge.get("id", ""))
	var gs := _get_game_state()

	if chosen_id == correct_id:
		# CORRECT
		_challenge_solved = true
		_timer_active = false
		_play_sfx(_sfx_success)

		var reward_xp: int = int(_current_challenge.get("xp_reward", 50))
		if gs:
			if gs.has_method("record_challenge_success"):
				gs.record_challenge_success(biome_id, challenge_id)
			if gs.has_method("add_xp"):
				gs.add_xp(reward_xp)
			var axis: String = str(_current_challenge.get("thought_axis", ""))
			if not axis.is_empty() and gs.has_method("add_axis_xp"):
				gs.add_axis_xp(axis, reward_xp)

		if feedback_label:
			feedback_label.text = "[color=#00E676]¡CORRECTO![/color] Has estabilizado el nodo. [b]+%d XP[/b]" % reward_xp

		for b in option_buttons:
			if b:
				b.disabled = true

		if next_button:
			next_button.visible = true
			if _current_challenge_index >= _challenges.size() - 1:
				next_button.text = "Finalizar y Obtener Fragmento →"
			else:
				next_button.text = "Siguiente Nodo →"

		_render_current_challenge()
		challenge_answered.emit(true, reward_xp)
		challenge_result_recorded.emit(challenge_id, true, reward_xp)
	else:
		# INCORRECT
		_play_sfx(_sfx_error)
		for btn in option_buttons:
			if btn and str(btn.get_meta("option_id", "")) == chosen_id:
				btn.disabled = true

		var failures: int = 1
		if gs and gs.has_method("record_challenge_failure"):
			failures = gs.record_challenge_failure(biome_id)

		var explanation: String = str(_current_challenge.get("explanation_on_error", "Respuesta errónea."))
		if feedback_label:
			feedback_label.text = "[color=#FF5252]¡INCORRECTO![/color] %s" % explanation

		if failures >= adaptive_threshold:
			_apply_adaptive_mode(false)

		challenge_answered.emit(false, 0)
		challenge_result_recorded.emit(challenge_id, false, 0)

func _on_timer_timeout() -> void:
	_timer_active = false
	_play_sfx(_sfx_error)

	var gs := _get_game_state()
	var failures: int = 1
	if gs and gs.has_method("record_challenge_failure"):
		failures = gs.record_challenge_failure(biome_id)

	var explanation: String = str(_current_challenge.get("explanation_on_error", "Tiempo agotado."))
	if feedback_label:
		feedback_label.text = "[color=#FF5252]¡TIEMPO AGOTADO![/color] %s\nSelecciona una de las opciones disponibles." % explanation

	if failures >= adaptive_threshold:
		_apply_adaptive_mode(false)

	var cid: String = str(_current_challenge.get("id", ""))
	challenge_answered.emit(false, 0)
	challenge_result_recorded.emit(cid, false, 0)

## Triggers adaptive mode: disables wrong options and reveals free hint.
func _apply_adaptive_mode(was_already_active: bool) -> void:
	if adaptive_notice_label:
		adaptive_notice_label.visible = true
		adaptive_notice_label.text = "¡Asistencia adaptativa activa!"

	var correct_id: String = str(_current_challenge.get("correct_option", ""))
	var count_eliminated: int = 0
	for btn in option_buttons:
		if btn and btn.visible and str(btn.get_meta("option_id", "")) != correct_id and not btn.disabled:
			btn.disabled = true
			count_eliminated += 1
			if count_eliminated >= eliminated_count:
				break

	var hint_text: String = str(_current_challenge.get("hint", ""))
	if not _hint_used_this_challenge and not hint_text.is_empty():
		_hint_used_this_challenge = true
		if hint_button:
			hint_button.disabled = true
			hint_button.text = "Pista Otorgada"
		var prefix: String = "[color=#FFD700]Pista Adaptativa (Gratis):[/color] " if not was_already_active else "[color=#FFD700]Pista:[/color] "
		if feedback_label:
			feedback_label.text += "\n" + prefix + hint_text

	_apply_adaptive_assistance()

func _on_hint_pressed() -> void:
	if _hint_used_this_challenge:
		return

	var hint_text: String = str(_current_challenge.get("hint", ""))
	var hint_cost: int = int(_current_challenge.get("hint_cost_xp", 10))
	var gs := _get_game_state()

	_play_sfx(_sfx_tap)
	_hint_used_this_challenge = true
	if hint_button:
		hint_button.disabled = true
		hint_button.text = "Pista Revelada"

	if gs:
		var is_adaptive: bool = gs.has_method("is_adaptive_mode_active") and gs.is_adaptive_mode_active(biome_id)
		if is_adaptive:
			if feedback_label:
				feedback_label.text += "\n[color=#FFD700]Pista (Gratis por Modo Adaptativo):[/color] %s" % hint_text
		else:
			var affordable: bool = true
			if gs.has_method("deduct_xp"):
				affordable = gs.deduct_xp(hint_cost)
			if feedback_label:
				var status_str := "Pista (-%d XP):" % hint_cost if affordable else "Pista (-%d XP, saldo en 0):" % hint_cost
				feedback_label.text += "\n[color=#00E5FF]%s[/color] %s" % [status_str, hint_text]
	else:
		if feedback_label:
			feedback_label.text += "\n[color=#00E5FF]Pista:[/color] %s" % hint_text

func _on_next_challenge_pressed() -> void:
	_play_sfx(_sfx_tap)
	_start_challenge(_current_challenge_index + 1)

# =============================================================================
# PHASE 3: COMPLETION & REWARDS
# =============================================================================

func _complete_minigame() -> void:
	_timer_active = false
	if challenge_view:
		challenge_view.visible = false
	if capsule_panel:
		capsule_panel.visible = false
	if completion_panel:
		completion_panel.visible = true
	if timer_label:
		timer_label.visible = false
	if node_indicator_label:
		node_indicator_label.text = "¡BIOMA COMPLETADO!"

	var reward_data := BiomeDataLoader.extract_reward_data(_biome_data)
	var fragment_id: String = reward_data.get("fragment_id", "fragment_" + biome_id)
	var badge_id: String = reward_data.get("badge_id", "badge_" + biome_id)
	var completion_xp: int = int(reward_data.get("completion_xp", 150))
	var unlock_cosmetic: String = str(reward_data.get("unlock_cosmetic", ""))

	var gs := _get_game_state()
	var already_completed: bool = false
	if gs and gs.has_method("has_fragment"):
		already_completed = gs.has_fragment(biome_id)

	if gs:
		if gs.has_method("award_fragment"):
			gs.award_fragment(biome_id)
		if gs.has_method("unlock_badge"):
			gs.unlock_badge(badge_id)
		if not already_completed and gs.has_method("add_xp"):
			gs.add_xp(completion_xp)
		if not already_completed and gs.has_method("add_axis_xp"):
			gs.add_axis_xp(biome_id, completion_xp)
		if not unlock_cosmetic.is_empty():
			if gs.has_method("unlock_cosmetic"):
				gs.unlock_cosmetic(unlock_cosmetic)
			if gs.has_method("equip_cosmetic"):
				gs.equip_cosmetic(unlock_cosmetic)

	_play_sfx(_sfx_success)

	if completion_details:
		completion_details.text = _format_completion_text(reward_data)

	var summary: Dictionary = {
		"biome_id": biome_id,
		"fragment_awarded": fragment_id,
		"badge_unlocked": badge_id,
		"xp_awarded": completion_xp if not already_completed else 0,
		"cosmetic_unlocked": unlock_cosmetic
	}
	minigame_completed.emit(summary)

## Virtual hook: Generates the completion celebration BBCode text.
func _format_completion_text(reward_data: Dictionary) -> String:
	var b_name: String = str(reward_data.get("badge_name", "Insignia"))
	var xp: int = int(reward_data.get("completion_xp", 150))
	var skin: String = str(reward_data.get("unlock_cosmetic", ""))

	return (
		"[center][b][color=#00E5FF]¡NEXO DE %s COMPLETADO![/color][/b][/center]\n\n" % biome_id.to_upper() +
		"Has superado con éxito todos los desafíos pedagógicos.\n\n" +
		"[color=#FFD700]RECOMPENSAS OBTENIDAS:[/color]\n" +
		"✦ [b]Fragmento del Nexo:[/b] Restaurado en el Altar Central.\n" +
		"✦ [b]Insignia:[/b] %s.\n" % b_name +
		"✦ [b]Experiencia:[/b] +%d XP.\n" % xp +
		("✦ [b]Nuevo Atuendo Desbloqueado:[/b] %s.\n\n" % skin if not skin.is_empty() else "\n") +
		"Regresa al Laboratorio y atraviesa el Portal para volver al Campus Nexus."
	)

# =============================================================================
# NAVIGATION & AUDIO HELPERS
# =============================================================================

func _on_return_pressed() -> void:
	_play_sfx(_sfx_tap)
	if lab_scene_path.is_empty():
		push_error("MinigameBase: No lab_scene_path defined.")
		return

	var sm := _get_scene_manager()
	if sm and sm.has_method("change_scene"):
		sm.change_scene(lab_scene_path)
	elif is_inside_tree() and get_tree():
		get_tree().change_scene_to_file(lab_scene_path)

func _play_sfx(stream: AudioStream) -> void:
	if sfx_player and stream and is_inside_tree() and sfx_player.is_inside_tree():
		sfx_player.stream = stream
		sfx_player.play()

func _get_game_state() -> Node:
	if custom_game_state != null:
		return custom_game_state
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var root = loop.root
		if root and root.has_node("GameState"):
			return root.get_node("GameState")
	if is_inside_tree():
		if has_node("/root/GameState"):
			return get_node("/root/GameState")
	return null

func _get_scene_manager() -> Node:
	if custom_scene_manager != null:
		return custom_scene_manager
	if Engine.has_singleton("SceneManager"):
		return Engine.get_singleton("SceneManager")
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var root = loop.root
		if root and root.has_node("SceneManager"):
			return root.get_node("SceneManager")
	if is_inside_tree():
		if has_node("/root/SceneManager"):
			return get_node("/root/SceneManager")
	return null

# =============================================================================
# PROTECTED HELPER METHODS FOR SUBCLASSES (CUSTOM CHALLENGES & UI)
# =============================================================================

## Completes a custom interactive challenge with success.
## Updates internal state, stops timer, plays success SFX, updates GameState
## (XP, thought axis, challenge history), configures next button, and emits signals.
func _complete_custom_challenge_success(feedback_msg: String = "", next_btn_text: String = "Siguiente Nodo →") -> void:
	_challenge_solved = true
	_timer_active = false
	_play_sfx(_sfx_success)

	var challenge_id: String = str(_current_challenge.get("id", ""))
	var reward_xp: int = int(_current_challenge.get("xp_reward", 50))
	var gs := _get_game_state()

	if gs:
		if gs.has_method("record_challenge_success"):
			gs.record_challenge_success(biome_id, challenge_id)
		if gs.has_method("add_xp"):
			gs.add_xp(reward_xp)
		var axis: String = str(_current_challenge.get("thought_axis", ""))
		if not axis.is_empty() and gs.has_method("add_axis_xp"):
			gs.add_axis_xp(axis, reward_xp)

	if feedback_label:
		if feedback_msg.is_empty():
			feedback_label.text = "[color=#00E676]¡CORRECTO![/color] Has estabilizado el nodo. [b]+%d XP[/b]" % reward_xp
		else:
			var display_text := feedback_msg
			if not ("[color=" in display_text):
				display_text = "[color=#00E676]¡CORRECTO![/color] " + display_text
			if not ("XP" in display_text) and reward_xp > 0:
				display_text += " [b]+%d XP[/b]" % reward_xp
			feedback_label.text = display_text

	for b in option_buttons:
		if b:
			b.disabled = true

	if hint_button:
		hint_button.disabled = true

	if next_button:
		next_button.visible = true
		if _challenges.is_empty() or _current_challenge_index >= _challenges.size() - 1:
			next_button.text = "Finalizar y Obtener Fragmento →"
		else:
			next_button.text = next_btn_text

	_render_current_challenge()
	challenge_answered.emit(true, reward_xp)
	challenge_result_recorded.emit(challenge_id, true, reward_xp)

## Records an error in a custom interactive challenge.
## Plays error SFX, increments consecutive failures in GameState, formats feedback,
## checks the adaptive assistance threshold, and emits result signals.
func _record_custom_challenge_error(custom_explanation: String = "") -> void:
	_play_sfx(_sfx_error)

	var gs := _get_game_state()
	var failures: int = 1
	if gs and gs.has_method("record_challenge_failure"):
		failures = gs.record_challenge_failure(biome_id)

	var explanation: String = custom_explanation
	if explanation.is_empty():
		explanation = str(_current_challenge.get("explanation_on_error", "Respuesta errónea."))

	if feedback_label:
		if "[color=" in explanation:
			feedback_label.text = explanation
		else:
			feedback_label.text = "[color=#FF5252]¡INCORRECTO![/color] %s" % explanation

	if failures >= adaptive_threshold:
		_apply_adaptive_mode(false)

	var challenge_id: String = str(_current_challenge.get("id", ""))
	challenge_answered.emit(false, 0)
	challenge_result_recorded.emit(challenge_id, false, 0)

## Programmatically builds a compact, pixel-art styled metric progress bar with
## title label and numeric value readout, optimized for the 640x360 viewport.
## Returns a Dictionary with keys: {"container", "label", "bar", "value_label"}.
func _create_metric_bar(label_text: String, fill_color: Color) -> Dictionary:
	var container := HBoxContainer.new()
	container.name = "MetricBarContainer"
	container.add_theme_constant_override("separation", 6)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.custom_minimum_size = Vector2(0, 16)

	var label := Label.new()
	label.name = "MetricLabel"
	label.text = label_text
	label.custom_minimum_size = Vector2(75, 0)
	label.add_theme_font_size_override("font_size", 8)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)

	var bar := ProgressBar.new()
	bar.name = "MetricProgressBar"
	bar.custom_minimum_size = Vector2(100, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color("#1A1D24")
	sb_bg.border_width_left = 1
	sb_bg.border_width_top = 1
	sb_bg.border_width_right = 1
	sb_bg.border_width_bottom = 1
	sb_bg.border_color = Color("#2D3748")
	sb_bg.corner_radius_top_left = 2
	sb_bg.corner_radius_top_right = 2
	sb_bg.corner_radius_bottom_right = 2
	sb_bg.corner_radius_bottom_left = 2
	bar.add_theme_stylebox_override("background", sb_bg)

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = fill_color
	sb_fill.corner_radius_top_left = 2
	sb_fill.corner_radius_top_right = 2
	sb_fill.corner_radius_bottom_right = 2
	sb_fill.corner_radius_bottom_left = 2
	bar.add_theme_stylebox_override("fill", sb_fill)
	container.add_child(bar)

	var value_label := Label.new()
	value_label.name = "MetricValueLabel"
	value_label.text = "0%"
	value_label.custom_minimum_size = Vector2(48, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 8)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(value_label)

	return {
		"container": container,
		"label": label,
		"bar": bar,
		"value_label": value_label
	}

# =============================================================================
# VIRTUAL HOOKS FOR SUBCLASSES
# =============================================================================

## Virtual hook: Override to render custom schematic diagrams or custom UI elements.
func _render_current_challenge() -> void:
	pass

## Virtual hook: Override to provide custom handling for adaptive mode assistance.
func _apply_adaptive_assistance() -> void:
	pass
