extends Node

## Guarda todo el estado del juego: XP, nivel (1 + floor(XP/100)), fragmentos (0/6),
## insignias, skins y dificultad adaptativa. Se guarda en user://virtuxperience_save.json.

signal xp_changed(new_xp: int, new_level: int)
signal fragment_awarded(biome_id: String, total_fragments: int)
signal fragment_collected(biome_id: String, total_fragments: int) # Compatible alias
signal badge_unlocked(badge_id: String)
signal cosmetic_unlocked(skin_id: String)
signal cosmetic_equipped(skin_id: String)
signal axis_xp_gained(axis: String, amount: int, new_total: int)
signal axis_xp_changed(axis: String, new_total: int)

const SAVE_PATH: String = "user://virtuxperience_save.json"
const TOTAL_BIOME_FRAGMENTS: int = 6

const CANONICAL_FRAGMENT_BIOMES: Array[String] = [
	"neuromath",
	"comunicarte",
	"gerencia",
	"activatuidea",
	"misionales",
	"voxcivitas"
]

const AXIS_CANONICAL_NAMES: Array[String] = [
	"Pensamiento Lógico y Numérico",
	"Competencia Léxica y Lectura Crítica",
	"Pensamiento Estratégico y Organizacional",
	"Innovación y Modelado de Emprendimiento",
	"Compromiso Ético y Responsabilidad Social",
	"Ciudadanía Activa y Habilidades para la Vida"
]

const AXIS_ALIASES: Dictionary = {
	# NeuroMath / Quantitative & Logic
	"quantitative_reasoning": "Pensamiento Lógico y Numérico",
	"neuromath": "Pensamiento Lógico y Numérico",
	"pensamiento lógico y numérico": "Pensamiento Lógico y Numérico",
	"pensamiento logico y numerico": "Pensamiento Lógico y Numérico",
	"razonamiento cuantitativo y lógica (neuromath)": "Pensamiento Lógico y Numérico",
	"pensamiento variacional y sistemas algebraicos": "Pensamiento Lógico y Numérico",
	"pensamiento numérico y variacional": "Pensamiento Lógico y Numérico",
	"pensamiento numerico y variacional": "Pensamiento Lógico y Numérico",
	"pensamiento aleatorio y razonamiento cuantitativo (saber pro)": "Pensamiento Lógico y Numérico",
	"logic_math": "Pensamiento Lógico y Numérico",

	# ComunicArte / Critical Reading & Lexical
	"critical_reading": "Competencia Léxica y Lectura Crítica",
	"comunicarte": "Competencia Léxica y Lectura Crítica",
	"competencia léxica y lectura crítica": "Competencia Léxica y Lectura Crítica",
	"competencia lexica y lectura critica": "Competencia Léxica y Lectura Crítica",
	"competencia léxica y lectura crítica (comunicarte)": "Competencia Léxica y Lectura Crítica",
	"competencia léxica, etimología y morfología": "Competencia Léxica y Lectura Crítica",
	"competencia lexica, etimologia y morfologia": "Competencia Léxica y Lectura Crítica",
	"cohesión, coherencia y sintaxis argumentativa": "Competencia Léxica y Lectura Crítica",
	"cohesion, coherencia y sintaxis argumentativa": "Competencia Léxica y Lectura Crítica",
	"lectura crítica y valoración argumentativa (saber pro)": "Competencia Léxica y Lectura Crítica",
	"lectura critica y valoracion argumentativa (saber pro)": "Competencia Léxica y Lectura Crítica",
	"lexical_reading": "Competencia Léxica y Lectura Crítica",

	# Gerencia+
	"gerencia": "Pensamiento Estratégico y Organizacional",
	"strategic_thinking": "Pensamiento Estratégico y Organizacional",
	"pensamiento estratégico y organizacional": "Pensamiento Estratégico y Organizacional",
	"pensamiento estrategico y organizacional": "Pensamiento Estratégico y Organizacional",
	"pensamiento estratégico y organizacional (gerencia+)": "Pensamiento Estratégico y Organizacional",
	"gestión estratégica y liderazgo": "Pensamiento Estratégico y Organizacional",
	"gestion estrategica y liderazgo": "Pensamiento Estratégico y Organizacional",
	"gestión estratégica y liderazgo (gerencia+)": "Pensamiento Estratégico y Organizacional",

	# ActivaTuIdea
	"activatuidea": "Innovación y Modelado de Emprendimiento",
	"innovation_entrepreneurship": "Innovación y Modelado de Emprendimiento",
	"innovación y modelado de emprendimiento": "Innovación y Modelado de Emprendimiento",
	"innovacion y modelado de emprendimiento": "Innovación y Modelado de Emprendimiento",
	"innovación y modelado de emprendimiento (activatuidea)": "Innovación y Modelado de Emprendimiento",

	# LatidoSocial / Misionales
	"misionales": "Compromiso Ético y Responsabilidad Social",
	"latidosocial": "Compromiso Ético y Responsabilidad Social",
	"ethical_commitment": "Compromiso Ético y Responsabilidad Social",
	"compromiso ético y responsabilidad social": "Compromiso Ético y Responsabilidad Social",
	"compromiso etico y responsabilidad social": "Compromiso Ético y Responsabilidad Social",
	"compromiso ético y responsabilidad social (latidosocial)": "Compromiso Ético y Responsabilidad Social",

	# VoxCivitas
	"voxcivitas": "Ciudadanía Activa y Habilidades para la Vida",
	"active_citizenship": "Ciudadanía Activa y Habilidades para la Vida",
	"ciudadanía activa y habilidades para la vida": "Ciudadanía Activa y Habilidades para la Vida",
	"ciudadania activa y habilidades para la vida": "Ciudadanía Activa y Habilidades para la Vida",
	"ciudadanía activa y habilidades para la vida (voxcivitas)": "Ciudadanía Activa y Habilidades para la Vida"
}

var xp_by_thought_axis: Dictionary = {
	"Pensamiento Lógico y Numérico": 0,
	"Competencia Léxica y Lectura Crítica": 0,
	"Pensamiento Estratégico y Organizacional": 0,
	"Innovación y Modelado de Emprendimiento": 0,
	"Compromiso Ético y Responsabilidad Social": 0,
	"Ciudadanía Activa y Habilidades para la Vida": 0
}

var total_xp: int = 0
var level: int = 1
var nexus_fragments: int = 0

var fragments_by_biome: Dictionary = {
	"neuromath": false,
	"comunicarte": false,
	"gerencia": false,
	"activatuidea": false,
	"misionales": false,
	"latidosocial": false,
	"voxcivitas": false
}

var badges_unlocked: Array[String] = []
var cosmetics_unlocked: Array[String] = ["ninja_blue"]
var equipped_cosmetic: String = "ninja_blue"

var biome_progress: Dictionary = {
	"neuromath": {
		"completed_challenges": [],
		"highest_streak": 0,
		"consecutive_failures": 0
	}
}

func _ready() -> void:
	load_game()

## Nivel según el XP, ej: 250 XP -> nivel 3
func calculate_level(xp: int) -> int:
	if xp < 0:
		return 1
	return 1 + int(float(xp) / 100.0)

## Suma XP, recalcula el nivel, avisa con xp_changed y guarda
func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	total_xp += amount
	level = calculate_level(total_xp)
	xp_changed.emit(total_xp, level)
	save_game()

## Resta XP (no baja de 0). Devuelve true si alcanzaba sin quedarse en negativo
func deduct_xp(amount: int) -> bool:
	if amount <= 0:
		return true
	var affordable: bool = total_xp >= amount
	total_xp = maxi(0, total_xp - amount)
	level = calculate_level(total_xp)
	xp_changed.emit(total_xp, level)
	save_game()
	return affordable

## Unifica los nombres de bioma (misionales y latidosocial son lo mismo)
func normalize_biome_id(biome_id: String) -> String:
	var clean := biome_id.strip_edges().to_lower()
	if clean == "misionales":
		return "latidosocial"
	return clean

## ¿Este bioma es el quinto fragmento del Nexo?
func _is_fifth_fragment_slot(biome_id: String) -> bool:
	var clean := biome_id.strip_edges().to_lower()
	return clean == "latidosocial" or clean == "misionales"

## Da el fragmento de un bioma (si ya lo tenía no pasa nada), avisa y guarda.
## Siempre son 6 fragmentos como máximo, nunca 7.
func award_fragment(biome_id: String) -> void:
	var clean_id := biome_id.strip_edges().to_lower()
	var is_fifth := _is_fifth_fragment_slot(clean_id)
	
	var already_awarded: bool = has_fragment(clean_id)
	if not already_awarded:
		if is_fifth:
			fragments_by_biome["misionales"] = true
			fragments_by_biome["latidosocial"] = true
		else:
			fragments_by_biome[clean_id] = true
		
		_recalculate_fragment_count()
		fragment_awarded.emit(biome_id, nexus_fragments)
		fragment_collected.emit(biome_id, nexus_fragments)
		save_game()

## Otro nombre para award_fragment
func award_biome_fragment(biome_id: String) -> void:
	award_fragment(biome_id)

## true si ya tiene ese fragmento (con cualquiera de sus dos nombres)
func has_fragment(biome_id: String) -> bool:
	var clean_id := biome_id.strip_edges().to_lower()
	if _is_fifth_fragment_slot(clean_id):
		return fragments_by_biome.get("misionales", false) == true or fragments_by_biome.get("latidosocial", false) == true
	return fragments_by_biome.get(clean_id, false) == true

func get_fragment_count() -> int:
	return nexus_fragments

## Vuelve a contar los fragmentos (entre 0 y 6)
func _recalculate_fragment_count() -> void:
	var count: int = 0
	for biome in CANONICAL_FRAGMENT_BIOMES:
		if has_fragment(biome):
			count += 1
	nexus_fragments = mini(TOTAL_BIOME_FRAGMENTS, count)

## Desbloquea una insignia (si ya la tenía no pasa nada)
func unlock_badge(badge_id: String) -> void:
	if not badges_unlocked.has(badge_id):
		badges_unlocked.append(badge_id)
		badge_unlocked.emit(badge_id)
		save_game()

func has_badge(badge_id: String) -> bool:
	return badges_unlocked.has(badge_id)

## Desbloquea un skin (si ya lo tenía no pasa nada)
func unlock_cosmetic(skin_id: String) -> void:
	if not cosmetics_unlocked.has(skin_id):
		cosmetics_unlocked.append(skin_id)
		cosmetic_unlocked.emit(skin_id)
		save_game()

func has_cosmetic(skin_id: String) -> bool:
	return cosmetics_unlocked.has(skin_id)

## Equipa un skin que ya esté desbloqueado
func equip_cosmetic(skin_id: String) -> bool:
	if not cosmetics_unlocked.has(skin_id):
		return false
	equipped_cosmetic = skin_id
	cosmetic_equipped.emit(skin_id)
	save_game()
	return true

func get_equipped_cosmetic() -> String:
	return equipped_cosmetic

## Seguimiento de la dificultad adaptativa
func _ensure_biome_progress(biome_id: String) -> void:
	var key := normalize_biome_id(biome_id)
	if not biome_progress.has(key):
		biome_progress[key] = {
			"completed_challenges": [],
			"highest_streak": 0,
			"consecutive_failures": 0
		}

func record_challenge_failure(biome_id: String = "neuromath") -> int:
	var key := normalize_biome_id(biome_id)
	_ensure_biome_progress(key)
	var current_failures: int = biome_progress[key].get("consecutive_failures", 0) + 1
	biome_progress[key]["consecutive_failures"] = current_failures
	save_game()
	return current_failures

func record_challenge_success(biome_id: String, challenge_id: String) -> void:
	var key := normalize_biome_id(biome_id)
	_ensure_biome_progress(key)
	biome_progress[key]["consecutive_failures"] = 0
	var completed: Array = biome_progress[key].get("completed_challenges", [])
	if not completed.has(challenge_id):
		completed.append(challenge_id)
		biome_progress[key]["completed_challenges"] = completed
	save_game()

func get_consecutive_failures(biome_id: String = "neuromath") -> int:
	var key := normalize_biome_id(biome_id)
	if not biome_progress.has(key):
		return 0
	return biome_progress[key].get("consecutive_failures", 0)

func is_adaptive_mode_active(biome_id: String = "neuromath", threshold: int = 3) -> bool:
	return get_consecutive_failures(biome_id) >= threshold

func reset_consecutive_failures(biome_id: String = "neuromath") -> void:
	var key := normalize_biome_id(biome_id)
	if biome_progress.has(key):
		biome_progress[key]["consecutive_failures"] = 0
		save_game()

## Convierte cualquier nombre de eje o tema al nombre oficial de la facultad
func canonicalize_axis(axis: String) -> String:
	var clean := axis.strip_edges()
	var lower := clean.to_lower()
	if AXIS_ALIASES.has(lower):
		return AXIS_ALIASES[lower]
	if AXIS_ALIASES.has(clean):
		return AXIS_ALIASES[clean]
	for canon in AXIS_CANONICAL_NAMES:
		if canon.to_lower() == lower:
			return canon
	return clean

## Suma XP a un eje de pensamiento, avisa y guarda
func add_axis_xp(axis: String, amount: int) -> void:
	if amount <= 0 or axis.is_empty():
		return
	var canon := canonicalize_axis(axis)
	var current: int = xp_by_thought_axis.get(canon, 0)
	var updated: int = current + amount
	xp_by_thought_axis[canon] = updated
	axis_xp_gained.emit(canon, amount, updated)
	axis_xp_changed.emit(canon, updated)
	save_game()

## XP acumulado de un eje. Devuelve 0 si nunca se usó
func get_axis_xp(axis: String) -> int:
	if axis.is_empty():
		return 0
	var canon := canonicalize_axis(axis)
	return xp_by_thought_axis.get(canon, 0)

## Pasa el estado a un Dictionary
func to_dictionary() -> Dictionary:
	return {
		"version": 1,
		"total_xp": total_xp,
		"level": level,
		"nexus_fragments": nexus_fragments,
		"fragments_by_biome": fragments_by_biome.duplicate(true),
		"badges_unlocked": badges_unlocked.duplicate(),
		"cosmetics_unlocked": cosmetics_unlocked.duplicate(),
		"equipped_cosmetic": equipped_cosmetic,
		"biome_progress": biome_progress.duplicate(true),
		"xp_by_thought_axis": xp_by_thought_axis.duplicate(true)
	}

## Lee el estado desde un Dictionary
func from_dictionary(data: Dictionary) -> void:
	total_xp = int(data.get("total_xp", 0))
	level = calculate_level(total_xp)
	
	var frags = data.get("fragments_by_biome", {})
	if frags is Dictionary:
		for biome in fragments_by_biome.keys():
			fragments_by_biome[biome] = frags.get(biome, false)
		var fifth_slot: bool = frags.get("misionales", false) == true or frags.get("latidosocial", false) == true
		if fifth_slot:
			fragments_by_biome["misionales"] = true
			fragments_by_biome["latidosocial"] = true
	_recalculate_fragment_count()
	
	var badges = data.get("badges_unlocked", [])
	if badges is Array:
		badges_unlocked.clear()
		for b in badges:
			badges_unlocked.append(str(b))
			
	var skins = data.get("cosmetics_unlocked", ["ninja_blue"])
	if skins is Array:
		cosmetics_unlocked.clear()
		for s in skins:
			cosmetics_unlocked.append(str(s))
	if not cosmetics_unlocked.has("ninja_blue"):
		cosmetics_unlocked.append("ninja_blue")
		
	equipped_cosmetic = str(data.get("equipped_cosmetic", "ninja_blue"))
	if not cosmetics_unlocked.has(equipped_cosmetic):
		equipped_cosmetic = "ninja_blue"
		
	var prog = data.get("biome_progress", {})
	if prog is Dictionary:
		biome_progress = prog.duplicate(true)
		if biome_progress.has("misionales") and not biome_progress.has("latidosocial"):
			biome_progress["latidosocial"] = biome_progress["misionales"].duplicate(true)
	_ensure_biome_progress("neuromath")

	var axes = data.get("xp_by_thought_axis", {})
	if axes is Dictionary:
		for key in axes.keys():
			var c_key := canonicalize_axis(str(key))
			xp_by_thought_axis[c_key] = int(axes[key])
	for c_axis in AXIS_CANONICAL_NAMES:
		if not xp_by_thought_axis.has(c_axis):
			xp_by_thought_axis[c_axis] = 0

## Guarda en disco (user://virtuxperience_save.json)
func save_game() -> void:
	var data := to_dictionary()
	var json_str := JSON.stringify(data, "\t")
	var tmp_path := SAVE_PATH + ".tmp"
	
	var f_tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f_tmp == null:
		push_error("GameState: Failed to open temp save file at: %s (Error: %d)" % [tmp_path, FileAccess.get_open_error()])
		# si falla, escribo directo
		var f_direct := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f_direct != null:
			f_direct.store_string(json_str)
			f_direct.close()
		return
	
	f_tmp.store_string(json_str)
	f_tmp.close()
	
	# reemplaza el archivo de guardado
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var err := DirAccess.rename_absolute(tmp_path, SAVE_PATH)
	if err != OK:
		# si no deja renombrar, escribo directo
		var f_direct := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f_direct != null:
			f_direct.store_string(json_str)
			f_direct.close()
		DirAccess.remove_absolute(tmp_path)

## Carga el guardado, o deja los valores por defecto si no hay
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_game()
		return
		
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("GameState: Could not read save file at %s, initializing defaults." % SAVE_PATH)
		save_game()
		return
		
	var content := f.get_as_text()
	f.close()
	
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		from_dictionary(parsed)
	else:
		push_warning("GameState: Corrupt save file at %s, reinitializing defaults." % SAVE_PATH)
		save_game()

## Deja todo como al principio
func reset_game_state() -> void:
	total_xp = 0
	level = 1
	nexus_fragments = 0
	for biome in fragments_by_biome:
		fragments_by_biome[biome] = false
	badges_unlocked.clear()
	cosmetics_unlocked = ["ninja_blue"]
	equipped_cosmetic = "ninja_blue"
	biome_progress = {
		"neuromath": {
			"completed_challenges": [],
			"highest_streak": 0,
			"consecutive_failures": 0
		}
	}
	xp_by_thought_axis.clear()
	for c_axis in AXIS_CANONICAL_NAMES:
		xp_by_thought_axis[c_axis] = 0
	save_game()
	xp_changed.emit(total_xp, level)
	fragment_awarded.emit("reset", 0)
	fragment_collected.emit("reset", 0)
