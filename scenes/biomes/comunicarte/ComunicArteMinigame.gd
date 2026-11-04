extends MinigameBase
class_name ComunicArteMinigame

## ComunicArteMinigame.gd — "La Gran Biblioteca y Taller Tipográfico" minigame.
## Inherits from MinigameBase.
## Driven by res://data/comunicarte.json.
##
## Three Educational Codices:
## 1. com_anagram_01: "anagram_tiles"
##    Reconstruct "RETORICA" with 32x32 letter tiles, slot placement,
##    verification, and adaptive assistance (locks first 2 letters 'R' and 'E' after 3 failures).
## 2. com_sentence_02: "sentence_builder"
##    Reorder 4 syntactic fragments (A-D) for discursive cohesion with marble tokens,
##    up/down controls, validation, and adaptive assistance (locks first 2 fragments 'A' and 'B').
## 3. com_saberpro_03: "saber_pro_reading"
##    Timed 60s critical reading comprehension on algorithmic echo chambers,
##    2x2 answer grid, immediate pedagogical explanation, and adaptive elimination of 2 distractors.
##
## Completion Rewards:
## - Fragment: fragment_comunicarte
## - Badge: badge_barda_del_verbo
## - Experience: 150 XP
## - Cosmetic: bard_magenta (unlocked & equipped)

const DATA_PATH: String = "res://data/comunicarte.json"
const LAB_SCENE_PATH: String = "res://scenes/biomes/comunicarte/ComunicArteLab.tscn"

# Custom container references
@onready var anagram_container: Control = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/AnagramContainer")
@onready var sentence_builder_container: Control = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/SentenceBuilderContainer")

# Anagram nodes
@onready var anagram_slots_hbox: HBoxContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/AnagramContainer/SlotsHBox")
@onready var anagram_bank_hbox: HBoxContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/AnagramContainer/BankHBox")
@onready var verify_anagram_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/AnagramContainer/AnagramActionRow/VerifyAnagramBtn")
@onready var reset_anagram_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/AnagramContainer/AnagramActionRow/ResetAnagramBtn")

# Sentence builder nodes
@onready var sentence_cards_vbox: VBoxContainer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/SentenceBuilderContainer/CardsVBox")
@onready var validate_sentence_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/SentenceBuilderContainer/SentenceActionRow/ValidateSentenceBtn")
@onready var reset_sentence_button: Button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/SentenceBuilderContainer/SentenceActionRow/ResetSentenceBtn")

# State for Codex 1: Anagram
var _bank_letters: Array[String] = []
var _bank_used: Array[bool] = []
var _slot_letters: Array[String] = []
var _slot_bank_map: Array[int] = []
var _slot_locked: Array[bool] = []

# State for Codex 2: Sentence Builder
var _sentence_fragments: Dictionary = {}
var _current_sentence_order: Array = []
var _sentence_locked: Array[bool] = [false, false, false, false]
var _sentence_initial_order: Array = ["C", "A", "D", "B"]

func _init() -> void:
	biome_data_path = DATA_PATH
	lab_scene_path = LAB_SCENE_PATH
	biome_id = "comunicarte"

func _ready() -> void:
	_resolve_comunicarte_nodes()
	_connect_comunicarte_signals()
	super._ready()

func _resolve_comunicarte_nodes() -> void:
	if anagram_container == null:
		anagram_container = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/AnagramContainer")
	if sentence_builder_container == null:
		sentence_builder_container = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/SentenceBuilderContainer")
	if anagram_slots_hbox == null:
		anagram_slots_hbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/AnagramContainer/SlotsHBox")
	if anagram_bank_hbox == null:
		anagram_bank_hbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/AnagramContainer/BankHBox")
	if verify_anagram_button == null:
		verify_anagram_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/AnagramContainer/AnagramActionRow/VerifyAnagramBtn")
	if reset_anagram_button == null:
		reset_anagram_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/AnagramContainer/AnagramActionRow/ResetAnagramBtn")
	if sentence_cards_vbox == null:
		sentence_cards_vbox = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/SentenceBuilderContainer/CardsVBox")
	if validate_sentence_button == null:
		validate_sentence_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/SentenceBuilderContainer/SentenceActionRow/ValidateSentenceBtn")
	if reset_sentence_button == null:
		reset_sentence_button = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/SentenceBuilderContainer/SentenceActionRow/ResetSentenceBtn")

func _connect_comunicarte_signals() -> void:
	if verify_anagram_button and not verify_anagram_button.pressed.is_connected(_on_verify_anagram_pressed):
		verify_anagram_button.pressed.connect(_on_verify_anagram_pressed)
	if reset_anagram_button and not reset_anagram_button.pressed.is_connected(_on_reset_anagram_pressed):
		reset_anagram_button.pressed.connect(_on_reset_anagram_pressed)
	if validate_sentence_button and not validate_sentence_button.pressed.is_connected(_on_validate_sentence_pressed):
		validate_sentence_button.pressed.connect(_on_validate_sentence_pressed)
	if reset_sentence_button and not reset_sentence_button.pressed.is_connected(_on_reset_sentence_pressed):
		reset_sentence_button.pressed.connect(_on_reset_sentence_pressed)

	# Connect anagram slot and bank buttons
	if anagram_slots_hbox:
		var slot_children := anagram_slots_hbox.get_children()
		for i in range(slot_children.size()):
			var btn := slot_children[i] as Button
			if btn and not btn.pressed.is_connected(_on_slot_button_pressed.bind(i)):
				btn.pressed.connect(_on_slot_button_pressed.bind(i))

	if anagram_bank_hbox:
		var bank_children := anagram_bank_hbox.get_children()
		for i in range(bank_children.size()):
			var btn := bank_children[i] as Button
			if btn and not btn.pressed.is_connected(_on_bank_button_pressed.bind(i)):
				btn.pressed.connect(_on_bank_button_pressed.bind(i))

## Helper to fetch letter tile textures
func _get_letter_texture(letter: String, style: String = "Wood") -> Texture2D:
	if letter.is_empty():
		return null
	var path := "res://assets/comunicarte/letter_tiles/PNG/%s/letter_%s.png" % [style, letter.to_upper()]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var blank_path := "res://assets/comunicarte/letter_tiles/PNG/%s/letter.png" % style
	if ResourceLoader.exists(blank_path):
		return load(blank_path) as Texture2D
	return null

## Virtual hook called by MinigameBase when starting or solving a challenge
func _render_current_challenge() -> void:
	_resolve_comunicarte_nodes()
	if _current_challenge.is_empty():
		return

	var ch_type: String = str(_current_challenge.get("type", ""))

	# Reset container visibilities
	if anagram_container:
		anagram_container.visible = (ch_type == "anagram_tiles")
	if sentence_builder_container:
		sentence_builder_container.visible = (ch_type == "sentence_builder")
	if options_container:
		options_container.visible = (ch_type == "saber_pro_reading" or ch_type == "multiple_choice")

	match ch_type:
		"anagram_tiles":
			_setup_anagram_challenge()
		"sentence_builder":
			_setup_sentence_builder_challenge()
		"saber_pro_reading":
			_setup_saber_pro_challenge()
		_:
			pass

## Virtual hook called by MinigameBase when adaptive difficulty triggers
func _apply_adaptive_assistance() -> void:
	var ch_type: String = str(_current_challenge.get("type", ""))
	match ch_type:
		"anagram_tiles":
			_apply_adaptive_anagram()
			_refresh_anagram_ui()
		"sentence_builder":
			_apply_adaptive_sentence()
			_refresh_sentence_ui()
		"saber_pro_reading":
			pass

## Virtual hook called by MinigameBase to format completion text
func _format_completion_text(reward_data: Dictionary) -> String:
	var b_name: String = str(reward_data.get("badge_name", "Barda del Verbo"))
	var xp: int = int(reward_data.get("completion_xp", 150))
	var skin: String = str(reward_data.get("unlock_cosmetic", "bard_magenta"))

	return (
		"[center][b][color=#FF2A85]¡GRAN BIBLIOTECA Y TALLER TIPOGRÁFICO RESTAURADOS![/color][/b][/center]\n\n" +
		"Has demostrado maestría en morfología léxica, cohesión argumentativa y lectura crítica.\n\n" +
		"[color=#FFD700]RECOMPENSAS OBTENIDAS:[/color]\n" +
		"✦ [b]Fragmento Magenta del Nexo:[/b] Restaurado en el Altar Central.\n" +
		"✦ [b]Insignia de Honor:[/b] %s.\n" % b_name +
		"✦ [b]Experiencia Extra:[/b] +%d XP.\n" % xp +
		("✦ [b]Nuevo Atuendo Desbloqueado y Equipado:[/b] Barda Magenta (%s).\n\n" % skin if not skin.is_empty() else "\n") +
		"Regresa al Taller Tipográfico y cruza el portal hacia el Campus Nexus."
	)

# =============================================================================
# CODEX 1: ANAGRAM TILES ("RETORICA")
# =============================================================================

func _setup_anagram_challenge() -> void:
	_bank_letters.clear()
	_bank_used.clear()
	_slot_letters.clear()
	_slot_bank_map.clear()
	_slot_locked.clear()

	var raw_scrambled = _current_challenge.get("scrambled_letters", ["O", "R", "E", "T", "I", "R", "C", "A"])
	var scrambled: Array = raw_scrambled if raw_scrambled is Array else ["O", "R", "E", "T", "I", "R", "C", "A"]
	for l in scrambled:
		_bank_letters.append(str(l))
		_bank_used.append(false)

	for i in range(8):
		_slot_letters.append("")
		_slot_bank_map.append(-1)
		_slot_locked.append(false)

	var gs := _get_game_state()
	if gs and gs.has_method("is_adaptive_mode_active") and gs.is_adaptive_mode_active(biome_id):
		_apply_adaptive_anagram()

	_refresh_anagram_ui()

func _refresh_anagram_ui() -> void:
	if anagram_slots_hbox:
		var slot_btns := anagram_slots_hbox.get_children()
		for i in range(slot_btns.size()):
			if i >= _slot_letters.size():
				break
			var btn := slot_btns[i] as Button
			var letter: String = _slot_letters[i]
			var is_locked: bool = _slot_locked[i]
			var tr: TextureRect = btn.get_node_or_null("TileIcon") as TextureRect

			btn.text = letter if not letter.is_empty() else ""
			if tr:
				if letter.is_empty():
					tr.texture = null
				else:
					var style: String = "Yellow" if is_locked else "Wood"
					tr.texture = _get_letter_texture(letter, style)

			if is_locked:
				btn.modulate = Color(1.0, 0.9, 0.4, 1.0) # Gold locked tint
			else:
				btn.modulate = Color.WHITE

	if anagram_bank_hbox:
		var bank_btns := anagram_bank_hbox.get_children()
		for i in range(bank_btns.size()):
			if i >= _bank_letters.size():
				break
			var btn := bank_btns[i] as Button
			var letter: String = _bank_letters[i]
			var is_used: bool = _bank_used[i]
			var tr: TextureRect = btn.get_node_or_null("TileIcon") as TextureRect

			btn.text = letter
			btn.disabled = is_used or _challenge_solved
			btn.modulate.a = 0.35 if is_used else 1.0
			if tr and tr.texture == null:
				tr.texture = _get_letter_texture(letter, "Wood")

	if verify_anagram_button:
		verify_anagram_button.disabled = _challenge_solved
	if reset_anagram_button:
		reset_anagram_button.disabled = _challenge_solved

func _on_bank_button_pressed(bank_idx: int) -> void:
	if _challenge_solved or bank_idx >= _bank_letters.size() or _bank_used[bank_idx]:
		return

	# Place letter in first available unlocked slot
	var target_slot: int = -1
	for s in range(_slot_letters.size()):
		if _slot_letters[s].is_empty() and not _slot_locked[s]:
			target_slot = s
			break

	if target_slot == -1:
		return # No free slots

	_slot_letters[target_slot] = _bank_letters[bank_idx]
	_slot_bank_map[target_slot] = bank_idx
	_bank_used[bank_idx] = true
	_play_sfx(_sfx_tap)
	_refresh_anagram_ui()

func _on_slot_button_pressed(slot_idx: int) -> void:
	if _challenge_solved or slot_idx >= _slot_letters.size() or _slot_locked[slot_idx]:
		return

	if _slot_letters[slot_idx].is_empty():
		return

	var bank_idx: int = _slot_bank_map[slot_idx]
	if bank_idx >= 0 and bank_idx < _bank_used.size():
		_bank_used[bank_idx] = false

	_slot_letters[slot_idx] = ""
	_slot_bank_map[slot_idx] = -1
	_play_sfx(_sfx_tap)
	_refresh_anagram_ui()

func _on_reset_anagram_pressed() -> void:
	if _challenge_solved:
		return

	for s in range(_slot_letters.size()):
		if not _slot_locked[s]:
			var bank_idx: int = _slot_bank_map[s]
			if bank_idx >= 0 and bank_idx < _bank_used.size():
				_bank_used[bank_idx] = false
			_slot_letters[s] = ""
			_slot_bank_map[s] = -1

	_play_sfx(_sfx_tap)
	_refresh_anagram_ui()

func _on_verify_anagram_pressed() -> void:
	if _challenge_solved:
		return

	var formed_word: String = "".join(_slot_letters).to_upper()
	var target_word: String = str(_current_challenge.get("target_word", "RETORICA")).to_upper()
	var challenge_id: String = str(_current_challenge.get("id", "com_anagram_01"))
	var gs := _get_game_state()

	if formed_word == target_word:
		# CORRECT
		_challenge_solved = true
		_play_sfx(_sfx_success)
		var xp: int = int(_current_challenge.get("xp_reward", 50))
		if gs:
			if gs.has_method("record_challenge_success"):
				gs.record_challenge_success(biome_id, challenge_id)
			if gs.has_method("add_xp"):
				gs.add_xp(xp)
			var axis: String = str(_current_challenge.get("thought_axis", ""))
			if not axis.is_empty() and gs.has_method("add_axis_xp"):
				gs.add_axis_xp(axis, xp)

		if feedback_label:
			feedback_label.text = "[color=#00E676]¡CORRECTO![/color] Has descifrado la raíz de la elocuencia (RETÓRICA). [b]+%d XP[/b]" % xp

		if next_button:
			next_button.visible = true
			next_button.text = "Siguiente Códice →"

		_refresh_anagram_ui()
		challenge_answered.emit(true, xp)
		challenge_result_recorded.emit(challenge_id, true, xp)
	else:
		# INCORRECT
		_play_sfx(_sfx_error)
		var failures: int = 1
		if gs and gs.has_method("record_challenge_failure"):
			failures = gs.record_challenge_failure(biome_id)

		var explanation: String = str(_current_challenge.get("explanation_on_error", "Palabra incorrecta."))
		if feedback_label:
			feedback_label.text = "[color=#FF5252]¡INCORRECTO![/color] %s" % explanation

		if failures >= adaptive_threshold:
			_apply_adaptive_mode(false)

		challenge_answered.emit(false, 0)
		challenge_result_recorded.emit(challenge_id, false, 0)

func _apply_adaptive_anagram() -> void:
	if _slot_locked.size() < 2 or _bank_letters.is_empty():
		return

	# Reset slots 0 and 1
	for s in [0, 1]:
		if _slot_bank_map[s] >= 0 and _slot_bank_map[s] < _bank_used.size():
			_bank_used[_slot_bank_map[s]] = false

	# Set slot 0 to "R" and slot 1 to "E"
	_slot_letters[0] = "R"
	_slot_letters[1] = "E"
	_slot_locked[0] = true
	_slot_locked[1] = true
	_slot_bank_map[0] = -1
	_slot_bank_map[1] = -1

	# Mark the corresponding letters in bank as used
	var target_chars: Array[String] = ["R", "E"]
	for tc in target_chars:
		for i in range(_bank_letters.size()):
			if _bank_letters[i] == tc and not _bank_used[i]:
				_bank_used[i] = true
				break

	if adaptive_notice_label:
		adaptive_notice_label.visible = true
		adaptive_notice_label.text = "¡Asistencia adaptativa activa! Primeras 2 letras bloqueadas."

# =============================================================================
# CODEX 2: SENTENCE BUILDER (A, B, C, D)
# =============================================================================

func _setup_sentence_builder_challenge() -> void:
	_sentence_fragments.clear()
	var raw_fragments = _current_challenge.get("fragments", [])
	if raw_fragments is Array:
		for frag in raw_fragments:
			if frag is Dictionary:
				var f_id: String = str(frag.get("id", ""))
				var f_text: String = str(frag.get("text", ""))
				_sentence_fragments[f_id] = f_text

	_current_sentence_order = _sentence_initial_order.duplicate()
	_sentence_locked = [false, false, false, false]

	var gs := _get_game_state()
	if gs and gs.has_method("is_adaptive_mode_active") and gs.is_adaptive_mode_active(biome_id):
		_apply_adaptive_sentence()

	_refresh_sentence_ui()

func _refresh_sentence_ui() -> void:
	if not sentence_cards_vbox:
		return

	var cards := sentence_cards_vbox.get_children()
	for i in range(cards.size()):
		if i >= _current_sentence_order.size():
			break
		var card := cards[i] as Control
		var frag_id: String = _current_sentence_order[i]
		var frag_text: String = str(_sentence_fragments.get(frag_id, ""))
		var is_locked: bool = _sentence_locked[i]

		var icon: TextureRect = card.find_child("TokenIcon", true, false) as TextureRect
		if icon:
			icon.texture = _get_letter_texture(frag_id, "Marble")

		var text_lbl: Label = card.find_child("FragmentLabel", true, false) as Label
		if text_lbl:
			text_lbl.text = frag_text

		var btn_up: Button = card.find_child("MoveUpButton", true, false) as Button
		if btn_up:
			btn_up.disabled = (i == 0 or is_locked or (i > 0 and _sentence_locked[i - 1]) or _challenge_solved)
			if not btn_up.pressed.is_connected(_move_sentence_card.bind(i, -1)):
				btn_up.pressed.connect(_move_sentence_card.bind(i, -1))

		var btn_down: Button = card.find_child("MoveDownButton", true, false) as Button
		if btn_down:
			btn_down.disabled = (i == cards.size() - 1 or is_locked or (i < cards.size() - 1 and _sentence_locked[i + 1]) or _challenge_solved)
			if not btn_down.pressed.is_connected(_move_sentence_card.bind(i, 1)):
				btn_down.pressed.connect(_move_sentence_card.bind(i, 1))

		if is_locked:
			card.modulate = Color(0.7, 1.0, 0.7, 1.0) # Soft green locked tint
		else:
			card.modulate = Color.WHITE

	if validate_sentence_button:
		validate_sentence_button.disabled = _challenge_solved
	if reset_sentence_button:
		reset_sentence_button.disabled = _challenge_solved

func _move_sentence_card(index: int, direction: int) -> void:
	if _challenge_solved:
		return

	var target_index := index + direction
	if target_index < 0 or target_index >= _current_sentence_order.size():
		return

	if _sentence_locked[index] or _sentence_locked[target_index]:
		return

	var temp: String = _current_sentence_order[index]
	_current_sentence_order[index] = _current_sentence_order[target_index]
	_current_sentence_order[target_index] = temp

	_play_sfx(_sfx_tap)
	_refresh_sentence_ui()

func _on_reset_sentence_pressed() -> void:
	if _challenge_solved:
		return

	_current_sentence_order = _sentence_initial_order.duplicate()
	if _sentence_locked[0] and _sentence_locked[1]:
		_apply_adaptive_sentence()

	_play_sfx(_sfx_tap)
	_refresh_sentence_ui()

func _on_validate_sentence_pressed() -> void:
	if _challenge_solved:
		return

	var correct_sequence: Array = _current_challenge.get("correct_sequence", ["A", "B", "C", "D"])
	var is_correct: bool = true

	if _current_sentence_order.size() != correct_sequence.size():
		is_correct = false
	else:
		for i in range(correct_sequence.size()):
			if _current_sentence_order[i] != str(correct_sequence[i]):
				is_correct = false
				break

	var challenge_id: String = str(_current_challenge.get("id", "com_sentence_02"))
	var gs := _get_game_state()

	if is_correct:
		# CORRECT
		_challenge_solved = true
		_play_sfx(_sfx_success)
		var xp: int = int(_current_challenge.get("xp_reward", 50))
		if gs:
			if gs.has_method("record_challenge_success"):
				gs.record_challenge_success(biome_id, challenge_id)
			if gs.has_method("add_xp"):
				gs.add_xp(xp)
			var axis: String = str(_current_challenge.get("thought_axis", ""))
			if not axis.is_empty() and gs.has_method("add_axis_xp"):
				gs.add_axis_xp(axis, xp)

		if feedback_label:
			feedback_label.text = "[color=#00E676]¡EXCELENTE![/color] Cohesión discursiva y argumentativa establecida con rigor. [b]+%d XP[/b]" % xp

		if next_button:
			next_button.visible = true
			next_button.text = "Siguiente Códice →"

		_refresh_sentence_ui()
		challenge_answered.emit(true, xp)
		challenge_result_recorded.emit(challenge_id, true, xp)
	else:
		# INCORRECT
		_play_sfx(_sfx_error)
		var failures: int = 1
		if gs and gs.has_method("record_challenge_failure"):
			failures = gs.record_challenge_failure(biome_id)

		var explanation: String = str(_current_challenge.get("explanation_on_error", "Secuencia sintáctica incorrecta."))
		if feedback_label:
			feedback_label.text = "[color=#FF5252]¡INCORRECTO![/color] %s" % explanation

		if failures >= adaptive_threshold:
			_apply_adaptive_mode(false)

		challenge_answered.emit(false, 0)
		challenge_result_recorded.emit(challenge_id, false, 0)

func _apply_adaptive_sentence() -> void:
	# Lock positions 0 and 1 to "A" and "B"
	_sentence_locked[0] = true
	_sentence_locked[1] = true

	# Rearrange current order to ensure "A" is at 0 and "B" is at 1
	var remaining: Array[String] = []
	for frag in _current_sentence_order:
		if frag != "A" and frag != "B":
			remaining.append(frag)

	_current_sentence_order = ["A", "B"]
	for r in remaining:
		_current_sentence_order.append(r)

	if adaptive_notice_label:
		adaptive_notice_label.visible = true
		adaptive_notice_label.text = "¡Asistencia adaptativa activa! Primeras 2 proposiciones aseguradas."

# =============================================================================
# CODEX 3: SABER PRO READING COMPREHENSION
# =============================================================================

func _setup_saber_pro_challenge() -> void:
	# Base setup handles multiple choice options and countdown timer
	_setup_options()
