class_name BiomeDataLoader
extends RefCounted

## BiomeDataLoader.gd — Static loader and schema validator for VirtuXperience 2D biomes.
## Provides safe, defensive loading of JSON datasets located in res://data/*.json.
## Validates structure, guardian metadata, reward configurations, adaptive parameters,
## and challenge specifications with descriptive error logging and fallbacks.

const DEFAULT_CONSECUTIVE_FAILURES_TRIGGER: int = 3
const DEFAULT_ELIMINATED_OPTIONS_COUNT: int = 2
const DEFAULT_HINT_COST_XP: int = 10
const DEFAULT_COMPLETION_XP: int = 150

## Loads, parses, and validates a biome JSON file from disk.
## Returns the parsed Dictionary if valid, or an empty Dictionary if loading or parsing fails.
static func load_biome_data(file_path: String) -> Dictionary:
	if file_path.is_empty():
		push_error("BiomeDataLoader: Cannot load biome data from an empty file path.")
		return {}

	if not FileAccess.file_exists(file_path):
		push_error("BiomeDataLoader: Biome data file not found at: %s" % file_path)
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("BiomeDataLoader: Failed to open file '%s' (FileAccess error code: %d)" % [file_path, err])
		return {}

	var json_text := file.get_as_text()
	file.close()

	if json_text.strip_edges().is_empty():
		push_error("BiomeDataLoader: Biome data file '%s' is empty." % file_path)
		return {}

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		push_error("BiomeDataLoader: Root of JSON file '%s' must be a valid Dictionary." % file_path)
		return {}

	var data: Dictionary = parsed as Dictionary
	if not validate_biome_data(data):
		push_error("BiomeDataLoader: Schema validation failed for '%s'." % file_path)
		return {}

	return data

## Validates the top-level structure and all mandatory components of a biome dataset.
static func validate_biome_data(data: Dictionary) -> bool:
	if data.is_empty():
		push_error("BiomeDataLoader: Empty biome data dictionary provided.")
		return false

	var required_root_keys: Array[String] = [
		"biome_id", "biome_name", "accent_color", "guardian", "reward", "challenges"
	]

	for key in required_root_keys:
		if not data.has(key):
			push_error("BiomeDataLoader: Missing required root key '%s'." % key)
			return false

	# Validate types of root fields
	if not (data["biome_id"] is String) or (data["biome_id"] as String).strip_edges().is_empty():
		push_error("BiomeDataLoader: 'biome_id' must be a non-empty String.")
		return false

	if not (data["biome_name"] is String) or (data["biome_name"] as String).strip_edges().is_empty():
		push_error("BiomeDataLoader: 'biome_name' must be a non-empty String.")
		return false

	if not (data["accent_color"] is String):
		push_error("BiomeDataLoader: 'accent_color' must be a hex Color String.")
		return false

	# Validate Guardian block
	if not (data["guardian"] is Dictionary):
		push_error("BiomeDataLoader: 'guardian' must be a Dictionary.")
		return false
	var guardian: Dictionary = data["guardian"]
	if not guardian.has("name") or not (guardian["name"] is String):
		push_error("BiomeDataLoader: 'guardian.name' must be a String.")
		return false
	if not guardian.has("learning_capsule") or not (guardian["learning_capsule"] is Array):
		push_error("BiomeDataLoader: 'guardian.learning_capsule' must be an Array.")
		return false
	var capsule: Array = guardian["learning_capsule"]
	if capsule.is_empty():
		push_warning("BiomeDataLoader: 'guardian.learning_capsule' is empty.")

	# Validate Reward block
	if not (data["reward"] is Dictionary):
		push_error("BiomeDataLoader: 'reward' must be a Dictionary.")
		return false
	var reward: Dictionary = data["reward"]
	var required_reward_keys: Array[String] = [
		"fragment_id", "badge_id", "badge_name", "completion_xp", "unlock_cosmetic"
	]
	for rkey in required_reward_keys:
		if not reward.has(rkey):
			push_error("BiomeDataLoader: Missing required reward key '%s'." % rkey)
			return false

	# Validate Challenges block
	if not (data["challenges"] is Array):
		push_error("BiomeDataLoader: 'challenges' must be an Array.")
		return false
	var challenges: Array = data["challenges"]
	if challenges.is_empty():
		push_error("BiomeDataLoader: 'challenges' array must contain at least one challenge.")
		return false

	for i in range(challenges.size()):
		var ch = challenges[i]
		if not (ch is Dictionary):
			push_error("BiomeDataLoader: Challenge at index %d is not a Dictionary." % i)
			return false
		if not validate_challenge(ch as Dictionary):
			push_error("BiomeDataLoader: Challenge at index %d failed validation." % i)
			return false

	return true

## Validates an individual challenge definition within the biome dataset.
static func validate_challenge(challenge: Dictionary) -> bool:
	var required_challenge_keys: Array[String] = [
		"id", "type", "title", "prompt", "xp_reward"
	]
	for ckey in required_challenge_keys:
		if not challenge.has(ckey):
			push_error("BiomeDataLoader: Challenge missing required key '%s'." % ckey)
			return false

	if not (challenge["id"] is String) or (challenge["id"] as String).strip_edges().is_empty():
		push_error("BiomeDataLoader: Challenge 'id' must be a non-empty String.")
		return false

	if not (challenge["type"] is String) or (challenge["type"] as String).strip_edges().is_empty():
		push_error("BiomeDataLoader: Challenge 'type' must be a non-empty String.")
		return false

	if not (challenge["title"] is String):
		push_error("BiomeDataLoader: Challenge 'title' must be a String.")
		return false

	if not (challenge["prompt"] is String):
		push_error("BiomeDataLoader: Challenge 'prompt' must be a String.")
		return false

	var xp_val = challenge["xp_reward"]
	if not (xp_val is int or xp_val is float) or int(xp_val) <= 0:
		push_error("BiomeDataLoader: Challenge 'xp_reward' must be a positive integer.")
		return false

	# If options array is provided, validate each option entry
	if challenge.has("options"):
		if not (challenge["options"] is Array):
			push_error("BiomeDataLoader: Challenge 'options' must be an Array.")
			return false
		var options: Array = challenge["options"]
		for opt in options:
			if not (opt is Dictionary) or not opt.has("id") or not opt.has("label"):
				push_error("BiomeDataLoader: Option entry must be a Dictionary with 'id' and 'label'.")
				return false

		# If standard multiple choice, verify correct_option exists and matches
		if challenge.has("correct_option") and challenge["correct_option"] is String:
			var correct_id: String = challenge["correct_option"]
			var match_found: bool = false
			for opt in options:
				if (opt as Dictionary).get("id", "") == correct_id:
					match_found = true
					break
			if not match_found and not options.is_empty():
				push_error("BiomeDataLoader: 'correct_option' '%s' not found in options list." % correct_id)
				return false

	# Validate optional timer limit
	if challenge.has("time_limit_seconds"):
		var t_limit = challenge["time_limit_seconds"]
		if not (t_limit is int or t_limit is float) or int(t_limit) <= 0:
			push_warning("BiomeDataLoader: 'time_limit_seconds' should be a positive number if defined.")

	# Type-specific challenge schema validation (Phase 3 Extensions)
	var ch_type: String = challenge["type"] as String
	match ch_type:
		"business_canvas":
			if not challenge.has("blocks") or not (challenge["blocks"] is Array) or (challenge["blocks"] as Array).is_empty():
				push_error("BiomeDataLoader: Challenge 'business_canvas' requires non-empty 'blocks' Array.")
				return false
			if not challenge.has("cards") or not (challenge["cards"] is Array) or (challenge["cards"] as Array).is_empty():
				push_error("BiomeDataLoader: Challenge 'business_canvas' requires non-empty 'cards' Array.")
				return false
			if not challenge.has("correct_mapping") or not (challenge["correct_mapping"] is Dictionary) or (challenge["correct_mapping"] as Dictionary).is_empty():
				push_error("BiomeDataLoader: Challenge 'business_canvas' requires non-empty 'correct_mapping' Dictionary.")
				return false

		"tiny_factory_line":
			if not challenge.has("stations") or not (challenge["stations"] is Array) or (challenge["stations"] as Array).is_empty():
				push_error("BiomeDataLoader: Challenge 'tiny_factory_line' requires non-empty 'stations' Array.")
				return false
			if not challenge.has("max_budget") or not (challenge["max_budget"] is int or challenge["max_budget"] is float) or float(challenge["max_budget"]) <= 0.0:
				push_error("BiomeDataLoader: Challenge 'tiny_factory_line' requires positive 'max_budget'.")
				return false
			if not challenge.has("min_quality") or not (challenge["min_quality"] is int or challenge["min_quality"] is float) or float(challenge["min_quality"]) <= 0.0:
				push_error("BiomeDataLoader: Challenge 'tiny_factory_line' requires positive 'min_quality'.")
				return false
			if not challenge.has("optimal_selection") or not (challenge["optimal_selection"] is Dictionary or challenge["optimal_selection"] is Array):
				push_error("BiomeDataLoader: Challenge 'tiny_factory_line' requires 'optimal_selection' Dictionary or Array.")
				return false

		"priority_matrix":
			var has_tasks: bool = challenge.has("tasks") and (challenge["tasks"] is Array) and not (challenge["tasks"] as Array).is_empty()
			var has_fragments: bool = challenge.has("fragments") and (challenge["fragments"] is Array) and not (challenge["fragments"] as Array).is_empty()
			if not has_tasks and not has_fragments:
				push_error("BiomeDataLoader: Challenge 'priority_matrix' requires non-empty 'tasks' or 'fragments' Array.")
				return false
			if not challenge.has("correct_sequence") or not (challenge["correct_sequence"] is Array) or (challenge["correct_sequence"] as Array).is_empty():
				push_error("BiomeDataLoader: Challenge 'priority_matrix' requires non-empty 'correct_sequence' Array.")
				return false

		"resource_allocation":
			if not challenge.has("projects") or not (challenge["projects"] is Array) or (challenge["projects"] as Array).is_empty():
				push_error("BiomeDataLoader: Challenge 'resource_allocation' requires non-empty 'projects' Array.")
				return false
			if not challenge.has("resources") or not (challenge["resources"] is Array) or (challenge["resources"] as Array).is_empty():
				push_error("BiomeDataLoader: Challenge 'resource_allocation' requires non-empty 'resources' Array.")
				return false
			if not challenge.has("correct_assignments") or not (challenge["correct_assignments"] is Dictionary) or (challenge["correct_assignments"] as Dictionary).is_empty():
				push_error("BiomeDataLoader: Challenge 'resource_allocation' requires non-empty 'correct_assignments' Dictionary.")
				return false

		"empathy_plaza_action":
			if not challenge.has("stations") or not (challenge["stations"] is Array) or (challenge["stations"] as Array).is_empty():
				push_error("BiomeDataLoader: Challenge 'empathy_plaza_action' requires non-empty 'stations' Array.")
				return false
			for st in challenge["stations"]:
				if not (st is Dictionary) or not (st as Dictionary).has("id") or not (st as Dictionary).has("name") or not (st as Dictionary).has("position"):
					push_error("BiomeDataLoader: Challenge 'empathy_plaza_action' station entry must be a Dictionary with 'id', 'name', and 'position'.")
					return false
			if not challenge.has("passing_score") or not (challenge["passing_score"] is int or challenge["passing_score"] is float) or float(challenge["passing_score"]) <= 0.0:
				push_error("BiomeDataLoader: Challenge 'empathy_plaza_action' requires positive 'passing_score'.")
				return false

		"civic_agora_action":
			if not challenge.has("passing_legitimacy") or not (challenge["passing_legitimacy"] is int or challenge["passing_legitimacy"] is float) or float(challenge["passing_legitimacy"]) <= 0.0:
				push_error("BiomeDataLoader: Challenge 'civic_agora_action' requires positive 'passing_legitimacy'.")
				return false
			if not challenge.has("rounds") or not (challenge["rounds"] is Array) or (challenge["rounds"] as Array).is_empty():
				push_error("BiomeDataLoader: Challenge 'civic_agora_action' requires non-empty 'rounds' Array.")
				return false
			for r in challenge["rounds"]:
				if not (r is Dictionary):
					push_error("BiomeDataLoader: Challenge 'civic_agora_action' round entry must be a Dictionary.")
					return false

		"saber_pro_innovation", "saber_pro_management", "saber_pro_ethics", "saber_pro_citizenship":
			if not challenge.has("options") or not (challenge["options"] is Array) or (challenge["options"] as Array).is_empty():
				push_error("BiomeDataLoader: Challenge '%s' requires non-empty 'options' Array." % ch_type)
				return false
			if not challenge.has("correct_option") or not (challenge["correct_option"] is String) or (challenge["correct_option"] as String).strip_edges().is_empty():
				push_error("BiomeDataLoader: Challenge '%s' requires non-empty String 'correct_option'." % ch_type)
				return false

		_:
			# Non-extended or backward-compatible challenge types pass if common fields are valid.
			pass

	return true

## Extracts the learning capsule text pages from the guardian metadata.
static func extract_learning_capsule(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw_guardian = data.get("guardian", {})
	var guardian: Dictionary = raw_guardian if raw_guardian is Dictionary else {}
	var raw_capsule = guardian.get("learning_capsule", [])
	if raw_capsule is Array:
		for page in raw_capsule:
			result.append(str(page))
	return result

## Extracts reward configuration with robust fallbacks.
static func extract_reward_data(data: Dictionary) -> Dictionary:
	var raw_reward = data.get("reward", {})
	var raw_reward_dict: Dictionary = raw_reward if raw_reward is Dictionary else {}
	var raw_biome_id = data.get("biome_id", "biome")
	var biome_id: String = str(raw_biome_id) if raw_biome_id is String and not str(raw_biome_id).strip_edges().is_empty() else "biome"

	var raw_xp = raw_reward_dict.get("completion_xp", DEFAULT_COMPLETION_XP)
	var completion_xp: int = DEFAULT_COMPLETION_XP
	if (raw_xp is int or raw_xp is float) and int(raw_xp) > 0:
		completion_xp = int(raw_xp)

	return {
		"fragment_id": str(raw_reward_dict.get("fragment_id", "fragment_" + biome_id)),
		"badge_id": str(raw_reward_dict.get("badge_id", "badge_" + biome_id)),
		"badge_name": str(raw_reward_dict.get("badge_name", "Insignia de " + biome_id.capitalize())),
		"completion_xp": completion_xp,
		"unlock_cosmetic": str(raw_reward_dict.get("unlock_cosmetic", "samurai_blue"))
	}

## Extracts adaptive difficulty configuration with defaults.
static func extract_adaptive_parameters(data: Dictionary) -> Dictionary:
	var raw_params = data.get("adaptive_parameters", {})
	var raw_params_dict: Dictionary = raw_params if raw_params is Dictionary else {}

	var raw_failures = raw_params_dict.get("consecutive_failures_trigger", DEFAULT_CONSECUTIVE_FAILURES_TRIGGER)
	var consecutive_failures: int = DEFAULT_CONSECUTIVE_FAILURES_TRIGGER
	if (raw_failures is int or raw_failures is float) and int(raw_failures) > 0:
		consecutive_failures = int(raw_failures)

	var raw_elim = raw_params_dict.get("eliminated_options_count", DEFAULT_ELIMINATED_OPTIONS_COUNT)
	var eliminated_count: int = DEFAULT_ELIMINATED_OPTIONS_COUNT
	if (raw_elim is int or raw_elim is float) and int(raw_elim) >= 0:
		eliminated_count = int(raw_elim)

	var raw_hint = raw_params_dict.get("free_hint_enabled", true)
	var free_hint: bool = bool(raw_hint) if raw_hint is bool else true

	var raw_soft_reset = raw_params_dict.get("soft_reset_on_depletion", true)
	var soft_reset: bool = bool(raw_soft_reset) if raw_soft_reset is bool else true

	return {
		"consecutive_failures_trigger": consecutive_failures,
		"eliminated_options_count": eliminated_count,
		"free_hint_enabled": free_hint,
		"soft_reset_on_depletion": soft_reset
	}

## Finds and returns a specific challenge dictionary by its ID.
static func get_challenge_by_id(data: Dictionary, challenge_id: String) -> Dictionary:
	if challenge_id.strip_edges().is_empty():
		return {}
	var raw_challenges = data.get("challenges", [])
	if not (raw_challenges is Array):
		return {}
	var challenges: Array = raw_challenges
	for ch in challenges:
		if ch is Dictionary and str((ch as Dictionary).get("id", "")) == challenge_id:
			return ch as Dictionary
	return {}
