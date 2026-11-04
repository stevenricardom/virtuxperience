extends Node

## Cambia de escena (hub, labs, minijuegos) y se acuerda de dónde volver.
## OJO: guarda hub_return_position antes de salir del hub, si no el jugador reaparece en el spawn.

signal scene_transition_started(target_scene: String)
signal scene_transition_finished(current_scene: String)

const HUB_SCENE_PATH: String = "res://scenes/hub/CampusHub.tscn"
const DEFAULT_HUB_SPAWN: Vector2 = Vector2(640, 368)

var hub_return_position: Vector2 = DEFAULT_HUB_SPAWN
var lab_return_position: Vector2 = Vector2.ZERO
var current_zone_name: String = "CAMPUS NEXUS"

## Cambia de escena. Si return_coords no es (0,0) lo guarda para la vuelta.
func change_scene(scene_path: String, return_coords: Vector2 = Vector2.ZERO) -> void:
	if scene_path.is_empty():
		push_error("SceneManager: Ruta de escena vacía, no hago nada.")
		return
		
	if return_coords != Vector2.ZERO:
		if "Minigame" in scene_path:
			lab_return_position = return_coords
		elif not "CampusHub" in scene_path:
			hub_return_position = return_coords
			lab_return_position = Vector2.ZERO
		
	scene_transition_started.emit(scene_path)
	
	# el nombre de la zona sale de la ruta, ej: .../NeuroMathLab.tscn -> "BIOMA: NEUROMATH"
	if "CampusHub" in scene_path:
		current_zone_name = "CAMPUS NEXUS"
	elif "NeuroMathLab" in scene_path:
		current_zone_name = "BIOMA: NEUROMATH"
	elif "NeuroMathMinigame" in scene_path:
		current_zone_name = "OBSERVATORIO NEUROMATH"
	elif "ComunicArte" in scene_path:
		current_zone_name = "BIOMA: COMUNICARTE"
	elif "Gerencia" in scene_path:
		current_zone_name = "BIOMA: GERENCIA+"
	elif "ActivaTuIdea" in scene_path:
		current_zone_name = "BIOMA: ACTIVATUIDEA"
		
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneManager: Failed to load scene '%s' (Error: %d)" % [scene_path, err])
		return
		
	scene_transition_finished.emit(scene_path)

## Vuelve al hub (la posición ya quedó guardada en hub_return_position).
func return_to_hub() -> void:
	current_zone_name = "CAMPUS NEXUS"
	scene_transition_started.emit(HUB_SCENE_PATH)
	var err := get_tree().change_scene_to_file(HUB_SCENE_PATH)
	if err != OK:
		push_error("SceneManager: Failed to return to hub '%s' (Error: %d)" % [HUB_SCENE_PATH, err])
		return
	scene_transition_finished.emit(HUB_SCENE_PATH)

## Cambia el título de zona que se ve en el HUD.
func set_zone_name(zone_name: String) -> void:
	current_zone_name = zone_name
