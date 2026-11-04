extends MinigameBase
class_name VoxCivitasMinigame

## VoxCivitasMinigame.gd — Real-Time Action Gameplay engine for VoxCivitas Biome.
## Inherits from MinigameBase.
## Challenge 0: 'civic_agora_action' — Two-round deliberative action loop:
##   - Round 1: Active signature collection from 5 citizen groups via in-situ [1]/[2] bubbles.
##   - Round 2: Proposal defense at Rostra podium against 3 incoming assembly debates.
## Challenge 1: 'saber_pro_citizenship' — Timed 60s Saber Pro evaluation.

# Action Arena UI Nodes
var action_arena: Control = null
var legitimacy_bar: ProgressBar = null
var legitimacy_label: Label = null
var progress_counter_label: Label = null
var round_badge_label: Label = null
var adaptive_banner: Label = null

# In-situ dialogue card nodes
var deliberation_card: PanelContainer = null
var speaker_title_label: Label = null
var dialogue_prompt_label: RichTextLabel = null
var opt1_btn: Button = null
var opt2_btn: Button = null

# Sub-round and Deliberation State
var _current_sub_round: int = 1 # 1: Signatures, 2: Rostra Defense
var _assembly_legitimacy: float = 100.0
var _legitimacy_decay_rate: float = 1.5
var _consecutive_fails: int = 0
var _adaptive_assistance_active: bool = false

# Round 1 State
var _signatures_collected: int = 0
var _target_signatures: int = 5
var _active_groups: Array[Dictionary] = []
var _current_group_idx: int = -1

# Round 2 State
var _consensus_score: float = 0.0
var _target_consensus: float = 80.0
var _incoming_debates: Array[Dictionary] = []
var _current_debate_idx: int = -1

func _init() -> void:
	biome_id = "voxcivitas"
	biome_data_path = "res://data/voxcivitas.json"
	lab_scene_path = "res://scenes/biomes/voxcivitas/VoxCivitasLab.tscn"
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

	var font_res := load("res://assets/characters/ninja_adventure/theme/font_normal.ttf") as Font

	# 1. Top HUD bar: Assembly Legitimacy Metric Bar
	var bar_data := _create_metric_bar("Legitimidad:", Color("#9C27B0"))
	var bar_container: HBoxContainer = bar_data["container"]
	legitimacy_bar = bar_data["bar"]
	legitimacy_label = bar_data["value_label"]
	bar_container.position = Vector2(10, 4)
	bar_container.size = Vector2(260, 18)
	action_arena.add_child(bar_container)

	# 2. Sub-round Badge Label
	round_badge_label = Label.new()
	round_badge_label.name = "RoundBadgeLabel"
	round_badge_label.position = Vector2(280, 4)
	round_badge_label.text = "[RONDA 1: FIRMAS]"
	if font_res:
		round_badge_label.add_theme_font_override("font", font_res)
	round_badge_label.add_theme_font_size_override("font_size", 8)
	round_badge_label.add_theme_color_override("font_color", Color("#CE93D8"))
	action_arena.add_child(round_badge_label)

	# 3. Progress Counter Label (Signatures / Consensus)
	progress_counter_label = Label.new()
	progress_counter_label.name = "ProgressCounterLabel"
	progress_counter_label.position = Vector2(420, 4)
	progress_counter_label.text = "Firmas: 0 / 5"
	if font_res:
		progress_counter_label.add_theme_font_override("font", font_res)
	progress_counter_label.add_theme_font_size_override("font_size", 8)
	progress_counter_label.add_theme_color_override("font_color", Color("#FFD700"))
	action_arena.add_child(progress_counter_label)

	# 4. Adaptive Mode Banner
	adaptive_banner = Label.new()
	adaptive_banner.name = "AdaptiveBanner"
	adaptive_banner.position = Vector2(10, 24)
	adaptive_banner.text = "⚡ Asistencia Adaptativa Activa: Drenaje ralentizado (-35%) & Umbral de consenso facilitado"
	if font_res:
		adaptive_banner.add_theme_font_override("font", font_res)
	adaptive_banner.add_theme_font_size_override("font_size", 7)
	adaptive_banner.add_theme_color_override("font_color", Color("#FFB74D"))
	adaptive_banner.visible = false
	action_arena.add_child(adaptive_banner)

	# 5. Interactive Deliberation Card (In-Situ [1] / [2] Micro-Decisions)
	deliberation_card = PanelContainer.new()
	deliberation_card.name = "DeliberationDialogueCard"
	deliberation_card.position = Vector2(10, 38)
	deliberation_card.size = Vector2(568, 108)
	action_arena.add_child(deliberation_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 3)
	deliberation_card.add_child(card_vbox)

	speaker_title_label = Label.new()
	speaker_title_label.name = "SpeakerTitleLabel"
	if font_res:
		speaker_title_label.add_theme_font_override("font", font_res)
	speaker_title_label.add_theme_font_size_override("font_size", 8)
	speaker_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	card_vbox.add_child(speaker_title_label)

	dialogue_prompt_label = RichTextLabel.new()
	dialogue_prompt_label.name = "DialoguePromptLabel"
	if font_res:
		dialogue_prompt_label.add_theme_font_override("normal_font", font_res)
	dialogue_prompt_label.add_theme_font_size_override("normal_font_size", 8)
	dialogue_prompt_label.custom_minimum_size = Vector2(560, 24)
	dialogue_prompt_label.bbcode_enabled = true
	dialogue_prompt_label.fit_content = true
	card_vbox.add_child(dialogue_prompt_label)

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

	if _current_challenge.get("type", "") == "civic_agora_action" and not _challenge_solved:
		_process_realtime_action(delta)

func _process_realtime_action(delta: float) -> void:
	var decay := _legitimacy_decay_rate * delta
	_assembly_legitimacy = maxf(0.0, _assembly_legitimacy - decay)
	_update_hud_meters()

	# Move citizen groups in Round 1
	if _current_sub_round == 1:
		for g in _active_groups:
			if not g.get("signed", false):
				var pos: Vector2 = g.get("pos", Vector2.ZERO)
				var vel: Vector2 = g.get("vel", Vector2.ZERO)
				pos += vel * delta
				if pos.x < 30.0 or pos.x > 550.0:
					vel.x *= -1.0
				if pos.y < 50.0 or pos.y > 180.0:
					vel.y *= -1.0
				g["pos"] = pos
				g["vel"] = vel

	if _assembly_legitimacy <= 0.0:
		_trigger_soft_round_reset()

func _render_current_challenge() -> void:
	var ch_type := str(_current_challenge.get("type", ""))

	if ch_type == "civic_agora_action":
		if action_arena:
			action_arena.visible = true
		if options_container:
			options_container.visible = false
		if _active_groups.is_empty() and _incoming_debates.is_empty():
			_init_civic_agora_challenge()
		else:
			_update_deliberation_card()
	else:
		if action_arena:
			action_arena.visible = false
		if options_container:
			options_container.visible = true

func _init_civic_agora_challenge() -> void:
	_current_sub_round = 1
	_consecutive_fails = 0
	_signatures_collected = 0
	_consensus_score = 0.0

	var rounds: Array = _current_challenge.get("rounds", [])
	if rounds.size() > 0:
		var r1: Dictionary = rounds[0]
		_target_signatures = int(r1.get("target_signatures", 5))
		_assembly_legitimacy = float(r1.get("initial_legitimacy", 100.0))
		_legitimacy_decay_rate = float(r1.get("legitimacy_decay_rate", 1.5))

		var raw_groups: Array = r1.get("citizen_groups", [])
		_active_groups.clear()
		var spawn_positions: Array[Vector2] = [
			Vector2(160, 120), Vector2(480, 120), Vector2(160, 260), Vector2(480, 260), Vector2(320, 220)
		]
		for i in range(raw_groups.size()):
			var g_dict: Dictionary = (raw_groups[i] as Dictionary).duplicate(true)
			g_dict["pos"] = spawn_positions[i % spawn_positions.size()]
			var vx: float = randf_range(12.0, 18.0) if randf() > 0.5 else randf_range(-18.0, -12.0)
			var vy: float = randf_range(8.0, 14.0) if randf() > 0.5 else randf_range(-14.0, -8.0)
			g_dict["vel"] = Vector2(vx, vy)
			g_dict["signed"] = false
			_active_groups.append(g_dict)

	if rounds.size() > 1:
		var r2: Dictionary = rounds[1]
		_target_consensus = float(r2.get("target_consensus", 80.0))
		var raw_debates: Array = r2.get("incoming_debates", [])
		_incoming_debates.clear()
		for d in raw_debates:
			_incoming_debates.append((d as Dictionary).duplicate(true))

	_current_group_idx = 0
	_current_debate_idx = -1
	_update_hud_meters()
	_update_deliberation_card()

func _update_deliberation_card() -> void:
	if not deliberation_card:
		return

	if _current_sub_round == 1:
		# Round 1: Citizen Group Micro-Decision
		if _current_group_idx < 0 or _current_group_idx >= _active_groups.size():
			deliberation_card.visible = false
			return

		var group: Dictionary = _active_groups[_current_group_idx]
		if group.get("signed", false):
			deliberation_card.visible = false
			return

		deliberation_card.visible = true
		if speaker_title_label:
			speaker_title_label.text = "✦ %s" % str(group.get("name", "Colectivo Ciudadano"))
		if dialogue_prompt_label:
			dialogue_prompt_label.text = "\"%s\"" % str(group.get("dialogue", ""))

		var opts: Array = group.get("options", [])
		if opt1_btn and opts.size() > 0:
			opt1_btn.text = str(opts[0].get("text", "[1] Opción A"))
			opt1_btn.disabled = false
		if opt2_btn and opts.size() > 1:
			opt2_btn.text = str(opts[1].get("text", "[2] Opción B"))
			opt2_btn.disabled = false

	else:
		# Round 2: Rostra Debate Challenge
		if _current_debate_idx < 0 or _current_debate_idx >= _incoming_debates.size():
			deliberation_card.visible = false
			return

		var deb: Dictionary = _incoming_debates[_current_debate_idx]
		deliberation_card.visible = true
		if speaker_title_label:
			speaker_title_label.text = "✦ %s" % str(deb.get("interpellant", "Tribuno Interpelante"))
		if dialogue_prompt_label:
			dialogue_prompt_label.text = "\"%s\"" % str(deb.get("objection", ""))

		var opts: Array = deb.get("options", [])
		if opt1_btn and opts.size() > 0:
			opt1_btn.text = str(opts[0].get("text", "[1] Opción A"))
			opt1_btn.disabled = false
		if opt2_btn and opts.size() > 1:
			opt2_btn.text = str(opts[1].get("text", "[2] Opción B"))
			opt2_btn.disabled = false

func select_in_situ_option(option_index: int) -> void:
	if _challenge_solved:
		return

	if _current_sub_round == 1:
		_handle_round_1_selection(option_index)
	else:
		_handle_round_2_selection(option_index)

	_update_hud_meters()
	_update_deliberation_card()

func _handle_round_1_selection(option_index: int) -> void:
	if _current_group_idx < 0 or _current_group_idx >= _active_groups.size():
		return

	var group: Dictionary = _active_groups[_current_group_idx]
	if group.get("signed", false):
		return

	var options: Array = group.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return

	var chosen_opt: Dictionary = options[option_index]
	var is_correct: bool = bool(chosen_opt.get("correct", false))
	var delta_leg: float = float(chosen_opt.get("legitimacy_delta", 0.0))
	var feedback: String = str(chosen_opt.get("feedback", ""))

	if is_correct:
		_play_sfx(_sfx_success)
		group["signed"] = true
		_signatures_collected += int(chosen_opt.get("signatures_gained", 1))
		_assembly_legitimacy = minf(100.0, _assembly_legitimacy + delta_leg)
		_consecutive_fails = 0

		if feedback_label:
			feedback_label.text = "[color=#00E676]¡ARGUMENTO CONSTITUCIONAL VÁLIDO![/color] %s" % feedback

		_advance_to_next_unsigned_group()

		if _signatures_collected >= _target_signatures:
			_advance_to_round_2()
	else:
		_play_sfx(_sfx_error)
		_assembly_legitimacy = maxf(0.0, _assembly_legitimacy + delta_leg)

		if feedback_label:
			feedback_label.text = "[color=#FF5252]¡ARGUMENTO DEMAGÓGICO O CLIENTELISTA![/color] %s" % feedback

		if _assembly_legitimacy <= 0.0:
			_trigger_soft_round_reset()
		else:
			_consecutive_fails += 1
			if _consecutive_fails >= 2:
				_apply_adaptive_assistance()

func _advance_to_next_unsigned_group() -> void:
	for i in range(_active_groups.size()):
		if not _active_groups[i].get("signed", false):
			_current_group_idx = i
			return
	_current_group_idx = -1

func _advance_to_round_2() -> void:
	_current_sub_round = 2
	_current_debate_idx = 0
	_consensus_score = 0.0
	_assembly_legitimacy = 70.0 # From round 2 data initial_legitimacy

	if feedback_label:
		feedback_label.text = "[color=#FFD700]¡QUÓRUM DE FIRMAS ALCANZADO![/color] Asciende al Podio Rostra y defiende la propuesta frente a los tribunos."

	if round_badge_label:
		round_badge_label.text = "[RONDA 2: PODIO ROSTRA]"
		round_badge_label.add_theme_color_override("font_color", Color("#FFD700"))

func _handle_round_2_selection(option_index: int) -> void:
	if _current_debate_idx < 0 or _current_debate_idx >= _incoming_debates.size():
		return

	var deb: Dictionary = _incoming_debates[_current_debate_idx]
	var options: Array = deb.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return

	var chosen_opt: Dictionary = options[option_index]
	var is_correct: bool = bool(chosen_opt.get("correct", false))
	var delta_cons: float = float(chosen_opt.get("consensus_delta", 0.0))
	var delta_leg: float = float(chosen_opt.get("legitimacy_delta", 0.0))
	var feedback: String = str(chosen_opt.get("feedback", ""))

	if is_correct:
		_play_sfx(_sfx_success)
		_consensus_score = minf(100.0, _consensus_score + delta_cons)
		_assembly_legitimacy = minf(100.0, _assembly_legitimacy + delta_leg)
		_consecutive_fails = 0

		if feedback_label:
			feedback_label.text = "[color=#00E676]¡RÉPLICA RIGUROSA Y MEDIADORA![/color] %s" % feedback

		_current_debate_idx += 1

		if _current_debate_idx >= _incoming_debates.size() or _consensus_score >= _target_consensus:
			_complete_custom_challenge_success("¡Has defendido con éxito la propuesta en el Podio Rostra y conquistado el consenso del Ágora!", "Siguiente: Reto Saber Pro →")
	else:
		_play_sfx(_sfx_error)
		_consensus_score = maxf(0.0, _consensus_score + delta_cons)
		_assembly_legitimacy = maxf(0.0, _assembly_legitimacy + delta_leg)

		if feedback_label:
			feedback_label.text = "[color=#FF5252]¡RÉPLICA POLARIZANTE O FALAZ![/color] %s" % feedback

		if _assembly_legitimacy <= 0.0:
			_trigger_soft_round_reset()
		else:
			_consecutive_fails += 1
			if _consecutive_fails >= 2:
				_apply_adaptive_assistance()

func _trigger_soft_round_reset() -> void:
	_play_sfx(_sfx_error)
	_consecutive_fails += 1

	if _current_sub_round == 1:
		_assembly_legitimacy = 100.0
		_signatures_collected = 0
		for g in _active_groups:
			g["signed"] = false
		_current_group_idx = 0
		if feedback_label:
			feedback_label.text = "[color=#FFB74D]¡RONDA DE FIRMAS REINICIADA![/color] La legitimidad del Ágora cayó a cero. Argumenta con base en derechos."
	else:
		_assembly_legitimacy = 70.0
		_consensus_score = 0.0
		_current_debate_idx = 0
		if feedback_label:
			feedback_label.text = "[color=#FFB74D]¡DEFENSA EN PODIO REINICIADA![/color] La asamblea desestimó la propuesta. Rebate con rigor constitucional."

	if _consecutive_fails >= 2:
		_apply_adaptive_assistance()

	_update_hud_meters()
	_update_deliberation_card()

func _apply_adaptive_assistance() -> void:
	_adaptive_assistance_active = true
	_legitimacy_decay_rate = 1.5 * 0.65 # -35% decay rate
	_target_consensus = 60.0 # Facilitated consensus threshold

	if adaptive_banner:
		adaptive_banner.visible = true

	var gs := _get_game_state()
	if gs and gs.has_method("activate_adaptive_mode"):
		gs.activate_adaptive_mode(biome_id)

func _update_hud_meters() -> void:
	if legitimacy_bar:
		legitimacy_bar.value = _assembly_legitimacy
		# Color-coding: Red < 30, Yellow < 70, Purple/Green >= 70
		var fill_col: Color
		if _assembly_legitimacy < 30.0:
			fill_col = Color("#FF5252")
		elif _assembly_legitimacy < 70.0:
			fill_col = Color("#FFB74D")
		else:
			fill_col = Color("#00E676") if _current_sub_round == 2 else Color("#9C27B0")

		var sb := legitimacy_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if sb:
			sb.bg_color = fill_col
		else:
			var new_sb := StyleBoxFlat.new()
			new_sb.bg_color = fill_col
			legitimacy_bar.add_theme_stylebox_override("fill", new_sb)

	if legitimacy_label:
		legitimacy_label.text = "%d%%" % int(round(_assembly_legitimacy))

	if progress_counter_label:
		if _current_sub_round == 1:
			progress_counter_label.text = "Firmas: %d / %d" % [_signatures_collected, _target_signatures]
		else:
			progress_counter_label.text = "Consenso: %d%% / %d%%" % [int(round(_consensus_score)), int(_target_consensus)]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			select_in_situ_option(0)
		elif event.keycode == KEY_2:
			select_in_situ_option(1)

func _format_completion_text(reward_data: Dictionary) -> String:
	var b_name: String = str(reward_data.get("badge_name", "Tribuno Democrático"))
	var xp: int = int(reward_data.get("completion_xp", 150))
	var skin: String = str(reward_data.get("unlock_cosmetic", "civic_violet"))

	return (
		"[center][b][color=#9C27B0]¡NEXO DE VOXCIVITAS ESTABILIZADO![/color][/b][/center]\n\n" +
		"Has demostrado maestría en la deliberación democrática, uniendo voluntades ciudadanas y defendiendo los derechos constitucionales en el Rostra del Conocimiento.\n\n" +
		"[color=#FFD700]RECOMPENSAS OBTENIDAS:[/color]\n" +
		"✦ [b]Fragmento Amatista del Nexo:[/b] Reencendido en el Altar Central.\n" +
		"✦ [b]Insignia:[/b] %s.\n" % b_name +
		"✦ [b]Experiencia:[/b] +%d XP (Eje Ciudadanía Activa y Habilidades para la Vida).\n" % xp +
		"✦ [b]Nuevo Atuendo Desbloqueado:[/b] %s (Toga Violeta del Tribuno Cívico).\n\n" % skin +
		"Regresa al Ágora y atraviesa el Portal para volver al Campus Nexus."
	)
