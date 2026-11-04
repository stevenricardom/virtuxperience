extends CharacterBody2D
class_name Player

## El jugador: se mueve en 4 direcciones (vista desde arriba), cambia de skin según
## GameState.cosmetic_equipped y detecta cosas interactuables cercanas (capa de colisión 4).

signal interacted(target: Area2D)

const SPEED: float = 110.0
const DEFAULT_SKIN_PATH: String = "res://assets/characters/ninja_adventure/content/character/ninja_blue/sprite.png"
const COSMETICS_MAP: Dictionary = {
	"ninja_blue": "res://assets/characters/ninja_adventure/content/character/ninja_blue/sprite.png",
	"samurai_blue": "res://assets/characters/ninja_adventure/content/character/samurai_blue/sprite.png",
	"bard_magenta": "res://assets/characters/ninja_adventure/content/character/samurai_green/samurai_green.png",
	"innovator_orange": "res://assets/characters/ninja_adventure/content/character/ninja_blue/sprite.png",
	"strategist_steel": "res://assets/characters/ninja_adventure/content/character/samurai_blue/sprite.png",
	"samurai_green": "res://assets/characters/ninja_adventure/content/character/samurai_green/samurai_green.png",
	"empath_green": "res://assets/characters/ninja_adventure/content/character/samurai_green/samurai_green.png",
	"civic_violet": "res://assets/characters/ninja_adventure/content/character/samurai_blue/sprite.png"
}
const COSMETICS_TINT_MAP: Dictionary = {
	"ninja_blue": Color.WHITE,
	"samurai_blue": Color.WHITE,
	"bard_magenta": Color("#FF94C2"),
	"innovator_orange": Color("#FFB74D"),
	"strategist_steel": Color("#90CAF9"),
	"samurai_green": Color.WHITE,
	"empath_green": Color("#81C784"),
	"civic_violet": Color("#BA68C8")
}

@export var is_movement_locked: bool = false

@onready var body_sprite: Sprite2D = $BodySprite
@onready var shadow_sprite: Sprite2D = $ShadowSprite
@onready var collision_feet: CollisionShape2D = $CollisionFeet
@onready var interaction_detector: Area2D = $InteractionDetector
@onready var player_camera: Camera2D = $PlayerCamera
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var facing_direction: Vector2 = Vector2.DOWN
var nearby_interactables: Array[Area2D] = []
var current_interactable: Area2D = null
var _last_dialog_active_msec: int = -1000

func _ready() -> void:
	# pone el skin que tenga equipado el jugador (si GameState existe)
	_connect_game_state()
	
	# conecta las señales del detector de interacción
	if interaction_detector:
		if not interaction_detector.area_entered.is_connected(_on_interaction_area_entered):
			interaction_detector.area_entered.connect(_on_interaction_area_entered)
		if not interaction_detector.area_exited.is_connected(_on_interaction_area_exited):
			interaction_detector.area_exited.connect(_on_interaction_area_exited)
			
	# arranca con la animación de reposo
	_update_animation(Vector2.ZERO)

func _connect_game_state() -> void:
	var game_state_node: Node = null
	if Engine.has_singleton("GameState"):
		game_state_node = Engine.get_singleton("GameState")
	elif is_inside_tree() and has_node("/root/GameState"):
		game_state_node = get_node("/root/GameState")
	else:
		var loop = Engine.get_main_loop()
		if loop is SceneTree and loop.root and loop.root.has_node("GameState"):
			game_state_node = loop.root.get_node("GameState")
		
	if game_state_node != null:
		if game_state_node.has_signal("cosmetic_equipped"):
			if not game_state_node.cosmetic_equipped.is_connected(_on_cosmetic_equipped):
				game_state_node.cosmetic_equipped.connect(_on_cosmetic_equipped)
		if game_state_node.has_method("get_equipped_cosmetic"):
			update_cosmetic(game_state_node.get_equipped_cosmetic())
		else:
			update_cosmetic("ninja_blue")
	else:
		update_cosmetic("ninja_blue")

func _on_cosmetic_equipped(skin_id: String) -> void:
	update_cosmetic(skin_id)

## Carga la textura del skin y se la pone al sprite
func update_cosmetic(skin_id: String) -> void:
	var texture_path: String = COSMETICS_MAP.get(skin_id, DEFAULT_SKIN_PATH)
	if not ResourceLoader.exists(texture_path):
		texture_path = DEFAULT_SKIN_PATH
		
	if ResourceLoader.exists(texture_path):
		var tex := load(texture_path) as Texture2D
		var sprite: Sprite2D = body_sprite if body_sprite != null else get_node_or_null("BodySprite") as Sprite2D
		if tex and sprite:
			sprite.texture = tex
			sprite.modulate = COSMETICS_TINT_MAP.get(skin_id, Color.WHITE)

## Movimiento suave: NO redondear la posición con round() acá, se ve trabado en diagonal.
## velocity = dirección * SPEED, ej: dirección (1,1) normalizada -> (0.71, 0.71) * SPEED
func _physics_process(_delta: float) -> void:
	if is_movement_locked or _is_dialog_active():
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO)
		_update_current_interactable()
		return
		
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED
	move_and_slide()
	
	if direction != Vector2.ZERO:
		_update_facing_direction(direction)
		
	_update_animation(direction)
	_update_current_interactable()

func _is_dialog_active() -> bool:
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if not tree:
		return false
	var modal := tree.get_first_node_in_group("dialog_modal")
	if modal == null and tree.current_scene:
		modal = tree.current_scene.find_child("DialogModal", true, false)
	if modal and modal.has_method("is_active") and modal.is_active():
		_last_dialog_active_msec = Time.get_ticks_msec()
		return true
	return false

func _update_facing_direction(dir: Vector2) -> void:
	# en diagonal gana el eje que más pese, ej: (0.9, 0.3) -> mira a la derecha
	if absf(dir.x) > absf(dir.y):
		facing_direction = Vector2.RIGHT if dir.x > 0.0 else Vector2.LEFT
	else:
		facing_direction = Vector2.DOWN if dir.y > 0.0 else Vector2.UP

func _update_animation(dir: Vector2) -> void:
	var dir_str: String = "down"
	if facing_direction == Vector2.UP:
		dir_str = "up"
	elif facing_direction == Vector2.LEFT:
		dir_str = "left"
	elif facing_direction == Vector2.RIGHT:
		dir_str = "right"
		
	var anim_name: String
	if dir.length() > 0.05:
		anim_name = "walk_" + dir_str
	else:
		anim_name = "idle_" + dir_str
		
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
	else:
		_fallback_frame_update(dir_str, dir.length() > 0.05)

func _fallback_frame_update(dir_str: String, is_walking: bool) -> void:
	if not body_sprite:
		return
	var col: int = 0
	match dir_str:
		"down": col = 0
		"up": col = 1
		"left": col = 2
		"right": col = 3
	var row: int = 0
	if is_walking:
		# cambia de frame cada tanto (4 frames en total)
		var t: int = int(float(Time.get_ticks_msec()) / 125.0) % 4
		row = t
	body_sprite.frame = row * 4 + col

func _on_interaction_area_entered(area: Area2D) -> void:
	if not nearby_interactables.has(area):
		nearby_interactables.append(area)
		if area.has_method("set_prompt_visible"):
			area.set_prompt_visible(true)
		elif area.get_parent() and area.get_parent().has_method("set_prompt_visible"):
			area.get_parent().set_prompt_visible(true)
		elif area.has_node("PromptBadge"):
			area.get_node("PromptBadge").visible = true
	_update_current_interactable()

func _on_interaction_area_exited(area: Area2D) -> void:
	nearby_interactables.erase(area)
	if is_instance_valid(area):
		if area.has_method("set_prompt_visible"):
			area.set_prompt_visible(false)
		elif area.get_parent() and area.get_parent().has_method("set_prompt_visible"):
			area.get_parent().set_prompt_visible(false)
		elif area.has_node("PromptBadge"):
			area.get_node("PromptBadge").visible = false
	if current_interactable == area:
		current_interactable = null
	_update_current_interactable()

func _update_current_interactable() -> void:
	nearby_interactables = nearby_interactables.filter(func(a): return is_instance_valid(a))
	if nearby_interactables.is_empty():
		current_interactable = null
		return
		
	var closest: Area2D = null
	var min_dist: float = INF
	for a in nearby_interactables:
		var dist: float = global_position.distance_squared_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = a
	current_interactable = closest

func _unhandled_input(event: InputEvent) -> void:
	if _is_dialog_active():
		return
	if Time.get_ticks_msec() - _last_dialog_active_msec < 150:
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		if get_viewport():
			get_viewport().set_input_as_handled()
		trigger_interaction()

## Interactúa con lo más cercano que esté en rango
func trigger_interaction() -> void:
	_update_current_interactable()
	if current_interactable and is_instance_valid(current_interactable):
		interacted.emit(current_interactable)
		if current_interactable.has_method("interact"):
			current_interactable.interact()
		elif current_interactable.has_method("on_interact"):
			current_interactable.on_interact()
		elif current_interactable.get_parent() and current_interactable.get_parent().has_method("interact"):
			current_interactable.get_parent().interact()
		elif current_interactable.get_parent() and current_interactable.get_parent().has_method("on_interact"):
			current_interactable.get_parent().on_interact()

## Pone los límites de la cámara para cada mapa
func set_camera_limits(left: int, top: int, right: int, bottom: int) -> void:
	if player_camera:
		player_camera.limit_left = left
		player_camera.limit_top = top
		player_camera.limit_right = right
		player_camera.limit_bottom = bottom
