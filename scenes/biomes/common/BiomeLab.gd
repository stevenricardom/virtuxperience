class_name BiomeLab
extends Node2D

## BiomeLab.gd — Base laboratory room architecture for VirtuXperience 2D.
## Manages 640x360 px room constraints, TileMapLayer collision defaults,
## strict camera clamping, player spawn restoration, HUD zone syncing,
## guardian dialogue setup, and lifecycle virtual hooks.

@export var biome_id: String = ""
@export var biome_name: String = ""
@export var data_path: String = ""
@export var default_player_spawn: Vector2 = Vector2(320, 280)
@export var room_rect: Rect2i = Rect2i(0, 0, 640, 360)

# Resilient node references with hierarchical fallbacks
@onready var layer0_floor: TileMapLayer = _resolve_node(["Layer0_Floor", "TileLayers/Layer0_Floor"]) as TileMapLayer
@onready var layer1_walls: TileMapLayer = _resolve_node(["Layer1_Walls", "TileLayers/Layer1_Walls"]) as TileMapLayer
@onready var layer2_details: TileMapLayer = _resolve_node(["Layer2_Details", "TileLayers/Layer2_Details"]) as TileMapLayer
@onready var player: CharacterBody2D = _resolve_node(["Entities/Player", "Player"]) as CharacterBody2D
@onready var guardian_npc: Area2D = _resolve_node(["Entities/GuardianNPC", "Entities/AXION7_NPC", "GuardianNPC"]) as Area2D
@onready var terminal: StaticBody2D = _resolve_node(["Entities/Terminal", "Entities/QuantumTerminal", "Entities/TypographicLectern", "Terminal"]) as StaticBody2D
@onready var exit_portal: Area2D = _resolve_node(["Entities/ExitPortal", "ExitPortal"]) as Area2D
@onready var hud: CanvasLayer = _resolve_node(["HUD"]) as CanvasLayer
@onready var dialog_modal: CanvasLayer = _resolve_node(["DialogModal"]) as CanvasLayer
@onready var background_music: AudioStreamPlayer = _resolve_node(["BackgroundMusic"]) as AudioStreamPlayer

var biome_data: Dictionary = {}
var is_lab_ready: bool = false

func _ready() -> void:
	_ensure_node_references()

	# 1. Background audio playback
	if background_music and is_inside_tree() and not background_music.playing:
		background_music.play()

	# 2. Camera clamping strictly to the 640x360 viewport boundary
	_setup_camera_limits()

	# 3. Restore player spawn position from SceneManager or fallback to default
	_restore_player_spawn()

	# 4. Configure TileMapLayer collision properties
	_setup_tilemap_layers()

	# 5. Load and validate biome JSON data
	_load_biome_data()

	# 6. Initialize HUD zone banner
	_setup_hud_zone()

	# 7. Configure Guardian NPC dialogue from parsed data
	init_guardian_dialogue()

	# 8. Virtual hooks for subclass specialization
	setup_ambient_fx()
	refresh_completion_state()

	is_lab_ready = true

## Ensures node references are assigned even if _ready is called manually outside the tree
func _ensure_node_references() -> void:
	if layer0_floor == null:
		layer0_floor = _resolve_node(["Layer0_Floor", "TileLayers/Layer0_Floor"]) as TileMapLayer
	if layer1_walls == null:
		layer1_walls = _resolve_node(["Layer1_Walls", "TileLayers/Layer1_Walls"]) as TileMapLayer
	if layer2_details == null:
		layer2_details = _resolve_node(["Layer2_Details", "TileLayers/Layer2_Details"]) as TileMapLayer
	if player == null:
		player = _resolve_node(["Entities/Player", "Player"]) as CharacterBody2D
	if guardian_npc == null:
		guardian_npc = _resolve_node(["Entities/GuardianNPC", "Entities/AXION7_NPC", "GuardianNPC"]) as Area2D
	if terminal == null:
		terminal = _resolve_node(["Entities/Terminal", "Entities/QuantumTerminal", "Entities/TypographicLectern", "Terminal"]) as StaticBody2D
	if exit_portal == null:
		exit_portal = _resolve_node(["Entities/ExitPortal", "ExitPortal"]) as Area2D
	if hud == null:
		hud = _resolve_node(["HUD"]) as CanvasLayer
	if dialog_modal == null:
		dialog_modal = _resolve_node(["DialogModal"]) as CanvasLayer
	if background_music == null:
		background_music = _resolve_node(["BackgroundMusic"]) as AudioStreamPlayer

## Resolves a node by iterating candidate relative paths
func _resolve_node(candidate_paths: Array[String]) -> Node:
	for path in candidate_paths:
		var n := get_node_or_null(path)
		if n != null:
			return n
	return null

## Configures camera limits on the Player instance.
func _setup_camera_limits() -> void:
	var cam: Camera2D = null
	if player:
		cam = player.get_node_or_null("PlayerCamera") as Camera2D
		if "player_camera" in player and player.player_camera == null and cam != null:
			player.player_camera = cam
		if player.has_method("set_camera_limits"):
			player.set_camera_limits(room_rect.position.x, room_rect.position.y, room_rect.end.x, room_rect.end.y)
	if cam:
		cam.limit_left = room_rect.position.x
		cam.limit_top = room_rect.position.y
		cam.limit_right = room_rect.end.x
		cam.limit_bottom = room_rect.end.y

## Restores player position if returning from a minigame, or uses default_player_spawn.
func _restore_player_spawn() -> void:
	if not player:
		return

	var sm := _get_scene_manager()
	var restored: bool = false
	if sm and "lab_return_position" in sm:
		var ret_pos: Vector2 = sm.lab_return_position
		if ret_pos != Vector2.ZERO:
			player.global_position = ret_pos
			restored = true

	if not restored:
		player.global_position = default_player_spawn

	var cam := player.get_node_or_null("PlayerCamera") as Camera2D
	if cam:
		cam.reset_smoothing()

## Configures TileMapLayer collision and triggers self-healing population if empty.
func _setup_tilemap_layers() -> void:
	if layer0_floor:
		layer0_floor.collision_enabled = false
	if layer1_walls:
		layer1_walls.collision_enabled = true
	if layer2_details:
		layer2_details.collision_enabled = true

	if layer0_floor:
		populate_tilemaps()

## Loads biome data via BiomeDataLoader.
func _load_biome_data() -> void:
	if not data_path.is_empty():
		biome_data = BiomeDataLoader.load_biome_data(data_path)

## Initializes HUD zone text and SceneManager tracking.
func _setup_hud_zone() -> void:
	var display_title: String = ""
	if not biome_name.is_empty():
		display_title = biome_name
	elif biome_data.has("biome_name"):
		display_title = str(biome_data["biome_name"])
	elif not biome_id.is_empty():
		display_title = "BIOMA: " + biome_id.to_upper()
	else:
		display_title = "LABORATORIO ACADÉMICO"

	if hud and hud.has_method("set_zone"):
		hud.set_zone(display_title)

	var sm := _get_scene_manager()
	if sm and sm.has_method("set_zone_name"):
		sm.set_zone_name(display_title)

## Injects parsed dialogue lines and colors into the Guardian NPC.
func init_guardian_dialogue() -> void:
	if not guardian_npc or biome_data.is_empty():
		return

	var raw_guardian = biome_data.get("guardian", {})
	var guardian_dict: Dictionary = raw_guardian if raw_guardian is Dictionary else {}
	if guardian_dict.is_empty():
		return

	var lines: Array[String] = BiomeDataLoader.extract_learning_capsule(biome_data)
	var g_name: String = str(guardian_dict.get("name", "Guardián Académico"))
	var raw_accent = biome_data.get("accent_color", "#00E5FF")
	var hex_col: String = str(raw_accent) if raw_accent is String and not str(raw_accent).is_empty() else "#00E5FF"
	var speaker_color: Color = Color.from_string(hex_col, Color("#00E5FF"))

	guardian_npc.set("dialogue_lines", lines)
	guardian_npc.set("npc_name", g_name)
	guardian_npc.set("speaker_color", speaker_color)

## Helper to create stylized world-space labels in laboratories
func _create_world_label(parent_node: Node2D, pos: Vector2, text_str: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text_str
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font_res := load("res://assets/characters/ninja_adventure/theme/font_normal.ttf") as Font
	if font_res:
		lbl.add_theme_font_override("font", font_res)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.95))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.size = Vector2(320, 14)
	lbl.position = pos - Vector2(160, 7)
	parent_node.add_child(lbl)
	return lbl

## Resolves SceneManager singleton or tree fallback.
func _get_scene_manager() -> Node:
	if Engine.has_singleton("SceneManager"):
		return Engine.get_singleton("SceneManager")
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var root = loop.root
		if root and root.has_node("SceneManager"):
			return root.get_node("SceneManager")
	if is_inside_tree() and has_node("/root/SceneManager"):
		return get_node("/root/SceneManager")
	return null

## Resolves GameState singleton or tree fallback.
func _get_game_state() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var root = loop.root
		if root and root.has_node("GameState"):
			return root.get_node("GameState")
	if is_inside_tree() and has_node("/root/GameState"):
		return get_node("/root/GameState")
	return null

# Backward-compatibility aliases
func _restore_player_lab_position() -> void:
	_restore_player_spawn()

func _setup_ambient_cyber_fx() -> void:
	setup_ambient_fx()

func _refresh_lab_completion_state() -> void:
	refresh_completion_state()

# =============================================================================
# VIRTUAL HOOKS FOR SUBCLASSES
# =============================================================================

## Virtual hook: Override to instantiate and configure visual FX, Line2Ds, and particles.
func setup_ambient_fx() -> void:
	pass

## Virtual hook: Override to programmatically populate TileMapLayers if cells are empty.
func populate_tilemaps() -> void:
	pass

## Virtual hook: Override to refresh terminal labels, lights, or indicators based on GameState.
func refresh_completion_state() -> void:
	pass
