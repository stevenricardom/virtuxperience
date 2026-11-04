extends MinigameBase
class_name LatidoSocialMinigame

## LatidoSocialMinigame.gd — Real-Time Action Gameplay engine for LatidoSocial Biome.
## Inherits from MinigameBase.
## Challenge 0: 'empathy_plaza_action' — Real-time citizen guidance via [1]/[2] micro-decisions.
## Challenge 1: 'saber_pro_ethics' — Timed 60s Saber Pro evaluation.

# Action Arena UI Nodes
var action_arena: Control = null
var community_wellbeing_bar: ProgressBar = null
var community_wellbeing_label: Label = null
var citizens_helped_label: Label = null
var adaptive_banner: Label = null

# In-situ dialogue card nodes
var citizen_card: PanelContainer = null
var citizen_name_label: Label = null
var citizen_dialogue_label: RichTextLabel = null
var opt1_btn: Button = null
var opt2_btn: Button = null

# Real-time state
var _community_wellbeing: float = 100.0
var _wellbeing_decay_rate: float = 2.0
var _citizens_helped: int = 0
var _target_citizens_helped: int = 4
var _consecutive_fails: int = 0
var _adaptive_assistance_active: bool = false
var _active_citizens: Array[Dictionary] = []
var _current_dialogue_citizen_idx: int = -1

# Station definitions matching latidosocial.json
var _station_data: Array = []

func _init() -> void:
	biome_id = "latidosocial"
	biome_data_path = "res://data/latidosocial.json"
	lab_scene_path = "res://scenes/biomes/latidosocial/LatidoSocialLab.tscn"
	adaptive_threshold = 2

func _ready() -> void:
	super._ready()
	_setup_action_arena()

func _setup_action_arena() -> void:
	if challenge_view == null:
		challenge_view = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView")
	if challenge_view == null:
		return

	if challenge_view.has_node("ActionArena"):
		action_arena = challenge_view.get_node("ActionArena") as Control
		return

	# Dedicated full-width action container for Challenge 0
	action_arena = Control.new()
	action_arena.name = "ActionArena"
	action_arena.custom_minimum_size = Vector2(580, 150)
	action_arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_arena.visible = false
	challenge_view.add_child(action_arena)
	if options_container:
		challenge_view.move_child(action_arena, options_container.get_index())

	# 1. Top HUD bar: Community Harmony / Wellbeing metric bar
	var bar_data := _create_metric_bar("Armonía Colectiva:", Color("#4CAF50"))
	var bar_container: HBoxContainer = bar_data["container"]
	community_wellbeing_bar = bar_data["bar"]
	community_wellbeing_label = bar_data["value_label"]
	bar_container.position = Vector2(10, 4)
	bar_container.size = Vector2(280, 18)
	action_arena.add_child(bar_container)

	# 2. Citizens helped counter
	citizens_helped_label = Label.new()
	citizens_helped_label.name = "CitizensHelpedLabel"
	citizens_helped_label.position = Vector2(310, 4)
	citizens_helped_label.text = "Atendidos: 0 / 4"
	var font_res := load("res://assets/characters/ninja_adventure/theme/font_normal.ttf") as Font
	if font_res:
		citizens_helped_label.add_theme_font_override("font", font_res)
	citizens_helped_label.add_theme_font_size_override("font_size", 8)
	citizens_helped_label.add_theme_color_override("font_color", Color("#81C784"))
	action_arena.add_child(citizens_helped_label)

	# 3. Adaptive Mode Banner
	adaptive_banner = Label.new()
	adaptive_banner.name = "AdaptiveBanner"
	adaptive_banner.position = Vector2(10, 24)
	adaptive_banner.text = "⚡ Asistencia Adaptativa Activa: Drenaje ralentizado (-35%) & Orientación pedagógica"
	if font_res:
		adaptive_banner.add_theme_font_override("font", font_res)
	adaptive_banner.add_theme_font_size_override("font_size", 7)
	adaptive_banner.add_theme_color_override("font_color", Color("#FFB74D"))
	adaptive_banner.visible = false
	action_arena.add_child(adaptive_banner)

	# 4. Interactive Citizen Dialogue Box (In-Situ [1] / [2] Micro-Decisions)
	citizen_card = PanelContainer.new()
	citizen_card.name = "CitizenDialogueCard"
	citizen_card.position = Vector2(10, 38)
	citizen_card.size = Vector2(568, 108)
	action_arena.add_child(citizen_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 3)
	citizen_card.add_child(card_vbox)

	citizen_name_label = Label.new()
	citizen_name_label.name = "CitizenNameLabel"
	if font_res:
		citizen_name_label.add_theme_font_override("font", font_res)
	citizen_name_label.add_theme_font_size_override("font_size", 8)
	citizen_name_label.add_theme_color_override("font_color", Color("#FFD700"))
	card_vbox.add_child(citizen_name_label)

	citizen_dialogue_label = RichTextLabel.new()
	citizen_dialogue_label.name = "CitizenDialogueLabel"
	if font_res:
		citizen_dialogue_label.add_theme_font_override("normal_font", font_res)
	citizen_dialogue_label.add_theme_font_size_override("normal_font_size", 8)
	citizen_dialogue_label.custom_minimum_size = Vector2(560, 24)
	citizen_dialogue_label.bbcode_enabled = true
	citizen_dialogue_label.fit_content = true
	card_vbox.add_child(citizen_dialogue_label)

	var btn_vbox := VBoxContainer.new()
	btn_vbox.name = "DecisionButtons"
	btn_vbox.add_theme_constant_override("separation", 2)
	card_vbox.add_child(btn_vbox)

	opt1_btn = Button.new()
	opt1_btn.name = "Option1Button"
	if font_res:
		opt1_btn.add_theme_font_override("font", font_res)
	opt1_btn.add_theme_font_size_override("font_size", 8)
	opt1_btn.custom_minimum_size = Vector2(560, 20)
	opt1_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	opt1_btn.pressed.connect(func(): select_in_situ_option(0))
	btn_vbox.add_child(opt1_btn)

	opt2_btn = Button.new()
	opt2_btn.name = "Option2Button"
	if font_res:
		opt2_btn.add_theme_font_override("font", font_res)
	opt2_btn.add_theme_font_size_override("font_size", 8)
	opt2_btn.custom_minimum_size = Vector2(560, 20)
	opt2_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	opt2_btn.pressed.connect(func(): select_in_situ_option(1))
	btn_vbox.add_child(opt2_btn)

func _process(delta: float) -> void:
	super._process(delta)

	if _current_challenge.get("type", "") == "empathy_plaza_action" and not _challenge_solved:
		_process_realtime_action(delta)

func _process_realtime_action(delta: float) -> void:
	var decay := _wellbeing_decay_rate * delta
	_community_wellbeing = maxf(0.0, _community_wellbeing - decay)
	_update_hud_meters()

	for c in _active_citizens:
		if not c.get("helped", false):
			var pos: Vector2 = c.get("pos", Vector2.ZERO)
			var vel: Vector2 = c.get("vel", Vector2.ZERO)
			pos += vel * delta
			if pos.x < 30.0 or pos.x > 550.0:
				vel.x *= -1.0
			if pos.y < 50.0 or pos.y > 180.0:
				vel.y *= -1.0
			c["pos"] = pos
			c["vel"] = vel

	if _community_wellbeing <= 0.0:
		_trigger_soft_round_reset()

func _render_current_challenge() -> void:
	var ch_type := str(_current_challenge.get("type", ""))

	if ch_type == "empathy_plaza_action":
		if action_arena:
			action_arena.visible = true
		if options_container:
			options_container.visible = false
		if _active_citizens.is_empty():
			_init_plaza_action_challenge()
		else:
			_update_citizen_card()
	else:
		if action_arena:
			action_arena.visible = false
		if options_container:
			options_container.visible = true

func _init_plaza_action_challenge() -> void:
	_community_wellbeing = float(_current_challenge.get("initial_wellbeing", 100.0))
	_wellbeing_decay_rate = float(_current_challenge.get("wellbeing_decay_rate", 2.0))
	_target_citizens_helped = int(_current_challenge.get("target_citizens_helped", 4))
	_citizens_helped = 0
	_station_data = _current_challenge.get("stations", [])

	var raw_citizens: Array = _current_challenge.get("citizens", [])
	_active_citizens.clear()
	var spawn_positions: Array[Vector2] = [
		Vector2(140, 90), Vector2(420, 90), Vector2(240, 150), Vector2(340, 140)
	]

	for i in range(raw_citizens.size()):
		var cit_dict: Dictionary = (raw_citizens[i] as Dictionary).duplicate(true)
		cit_dict["pos"] = spawn_positions[i % spawn_positions.size()]
		cit_dict["vel"] = Vector2(randf_range(-20.0, 20.0), randf_range(-15.0, 15.0))
		cit_dict["helped"] = false
		cit_dict["wellbeing"] = 70.0
		_active_citizens.append(cit_dict)

	_current_dialogue_citizen_idx = 0
	_update_hud_meters()
	_update_citizen_card()

func _update_citizen_card() -> void:
	if not citizen_card:
		return

	if _current_dialogue_citizen_idx < 0 or _current_dialogue_citizen_idx >= _active_citizens.size():
		citizen_card.visible = false
		return

	var cit: Dictionary = _active_citizens[_current_dialogue_citizen_idx]
	if cit.get("helped", false):
		citizen_card.visible = false
		return

	citizen_card.visible = true
	var name_str: String = str(cit.get("name", "Ciudadano"))
	var emotion: String = str(cit.get("emotion", "inquietud"))
	if citizen_name_label:
		citizen_name_label.text = "✦ %s — Estado Emocional: [%s]" % [name_str, emotion.to_upper()]

	if citizen_dialogue_label:
		citizen_dialogue_label.text = "\"%s\"" % str(cit.get("dialogue", ""))

	var opts: Array = cit.get("options", [])
	if opt1_btn and opts.size() > 0:
		opt1_btn.text = str(opts[0].get("text", "[1] Opción A"))
		opt1_btn.disabled = false
	if opt2_btn and opts.size() > 1:
		opt2_btn.text = str(opts[1].get("text", "[2] Opción B"))
		opt2_btn.disabled = false

func select_in_situ_option(option_index: int) -> void:
	if _challenge_solved or _current_dialogue_citizen_idx < 0 or _current_dialogue_citizen_idx >= _active_citizens.size():
		return

	var citizen: Dictionary = _active_citizens[_current_dialogue_citizen_idx]
	if citizen.get("helped", false):
		return

	var options: Array = citizen.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return

	var chosen_opt: Dictionary = options[option_index]
	var is_correct: bool = bool(chosen_opt.get("correct", false))
	var delta_wb: float = float(chosen_opt.get("wellbeing_delta", 0.0))
	var feedback: String = str(chosen_opt.get("feedback", ""))

	if is_correct:
		_play_sfx(_sfx_success)
		citizen["helped"] = true
		citizen["wellbeing"] = 100.0
		_community_wellbeing = minf(100.0, _community_wellbeing + delta_wb)
		_citizens_helped += 1
		_consecutive_fails = 0

		if feedback_label:
			feedback_label.text = "[color=#00E676]¡ACCIÓN ÉTICA CORRECTA![/color] %s" % feedback

		_advance_to_next_unhelped_citizen()

		if _citizens_helped >= _target_citizens_helped:
			_community_wellbeing = maxf(_community_wellbeing, float(_current_challenge.get("passing_score", 100.0)))
			_complete_custom_challenge_success("¡Has estabilizado la Plaza de la Empatía y canalizado a todos los ciudadanos con éxito!", "Siguiente: Reto Saber Pro →")
	else:
		_play_sfx(_sfx_error)
		_community_wellbeing = maxf(0.0, _community_wellbeing + delta_wb)

		if feedback_label:
			feedback_label.text = "[color=#FF5252]¡DECISIÓN INADECUADA![/color] %s" % feedback

		if _community_wellbeing <= 0.0:
			_trigger_soft_round_reset()
		else:
			_consecutive_fails += 1
			if _consecutive_fails >= 2:
				_apply_adaptive_assistance()

	_update_hud_meters()
	_update_citizen_card()

func _advance_to_next_unhelped_citizen() -> void:
	for i in range(_active_citizens.size()):
		if not _active_citizens[i].get("helped", false):
			_current_dialogue_citizen_idx = i
			return
	_current_dialogue_citizen_idx = -1

func _trigger_soft_round_reset() -> void:
	_play_sfx(_sfx_error)
	_consecutive_fails += 1
	_community_wellbeing = float(_current_challenge.get("initial_wellbeing", 100.0))
	_citizens_helped = 0

	for c in _active_citizens:
		c["helped"] = false
		c["wellbeing"] = 65.0

	_current_dialogue_citizen_idx = 0

	if feedback_label:
		feedback_label.text = "[color=#FFB74D]¡RONDA REINICIADA SUAVEMENTE![/color] El bienestar de la plaza cayó a cero. Escucha con empatía y canaliza a los ciudadanos."

	if _consecutive_fails >= 2:
		_apply_adaptive_assistance()

	_update_hud_meters()
	_update_citizen_card()

func _apply_adaptive_assistance() -> void:
	_adaptive_assistance_active = true
	_wellbeing_decay_rate = float(_current_challenge.get("wellbeing_decay_rate", 2.0)) * 0.65

	if adaptive_banner:
		adaptive_banner.visible = true

	var gs := _get_game_state()
	if gs and gs.has_method("activate_adaptive_mode"):
		gs.activate_adaptive_mode(biome_id)

func _update_hud_meters() -> void:
	if community_wellbeing_bar:
		community_wellbeing_bar.value = _community_wellbeing
	if community_wellbeing_label:
		community_wellbeing_label.text = "%d%%" % int(round(_community_wellbeing))
	if citizens_helped_label:
		citizens_helped_label.text = "Atendidos: %d / %d" % [_citizens_helped, _target_citizens_helped]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			select_in_situ_option(0)
		elif event.keycode == KEY_2:
			select_in_situ_option(1)

func _format_completion_text(reward_data: Dictionary) -> String:
	var b_name: String = str(reward_data.get("badge_name", "Tejedor de Bienestar"))
	var xp: int = int(reward_data.get("completion_xp", 150))
	var skin: String = str(reward_data.get("unlock_cosmetic", "empath_green"))

	return (
		"[center][b][color=#4CAF50]¡NEXO DE LATIDOSOCIAL ESTABILIZADO![/color][/b][/center]\n\n" +
		"Has demostrado un profundo compromiso ético, restaurando la armonía comunitaria y canalizando las necesidades colectivas hacia las redes de bienestar.\n\n" +
		"[color=#FFD700]RECOMPENSAS OBTENIDAS:[/color]\n" +
		"✦ [b]Fragmento Esmeralda del Nexo:[/b] Restaurado en el Altar Central.\n" +
		"✦ [b]Insignia:[/b] %s.\n" % b_name +
		"✦ [b]Experiencia:[/b] +%d XP (Eje Compromiso Ético y Responsabilidad Social).\n" % xp +
		"✦ [b]Nuevo Atuendo Desbloqueado:[/b] %s (Túnica Esmeralda de la Empatía).\n\n" % skin +
		"Regresa a la Aldea del Bienestar y atraviesa el Portal para volver al Campus Nexus."
	)
