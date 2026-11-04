extends Node2D
class_name CampusHub

## El campus: mapa de 80x45 celdas (1280x720 px) con 4 capas. Pone al jugador donde
## corresponde al volver de un bioma y conecta el altar, portales, NPCs, HUD y DialogModal.

@onready var layer0_ground: TileMapLayer = $Layer0_Ground
@onready var layer1_paths: TileMapLayer = $Layer1_PathsAndMarks
@onready var layer2_entities: Node2D = $Layer2_Entities
@onready var props_tilemap: TileMapLayer = $Layer2_Entities/Props_TileMap
@onready var layer3_canopy: TileMapLayer = $Layer3_RoofsAndCanopy
@onready var nexus_altar: StaticBody2D = $Layer2_Entities/NexusAltar
@onready var player: CharacterBody2D = $Layer2_Entities/Player
@onready var hud: CanvasLayer = $HUD
@onready var dialog_modal: CanvasLayer = $DialogModal
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

var _altar_status_label: Label = null
var _neuromath_portal_status_label: Label = null
var _comunicarte_portal_status_label: Label = null
var _gerencia_portal_status_label: Label = null
var _activatuidea_portal_status_label: Label = null
var _latidosocial_portal_status_label: Label = null
var _voxcivitas_portal_status_label: Label = null

var _hub_anim_time: float = 0.0
var _hub_ley_lines: Array[Line2D] = []
var _hub_ley_packets: Array[Node2D] = []
var _hub_ley_paths: Array[Array] = []
var _hub_water_ripples: Array[Line2D] = []

func _ensure_node_references() -> void:
	if layer0_ground == null:
		layer0_ground = get_node_or_null("Layer0_Ground") as TileMapLayer
	if layer1_paths == null:
		layer1_paths = get_node_or_null("Layer1_PathsAndMarks") as TileMapLayer
	if layer2_entities == null:
		layer2_entities = get_node_or_null("Layer2_Entities") as Node2D
	if props_tilemap == null:
		props_tilemap = get_node_or_null("Layer2_Entities/Props_TileMap") as TileMapLayer
	if layer3_canopy == null:
		layer3_canopy = get_node_or_null("Layer3_RoofsAndCanopy") as TileMapLayer
	if nexus_altar == null:
		nexus_altar = get_node_or_null("Layer2_Entities/NexusAltar") as StaticBody2D
	if player == null:
		player = get_node_or_null("Layer2_Entities/Player") as CharacterBody2D
	if hud == null:
		hud = get_node_or_null("HUD") as CanvasLayer
	if dialog_modal == null:
		dialog_modal = get_node_or_null("DialogModal") as CanvasLayer
	if background_music == null:
		background_music = get_node_or_null("BackgroundMusic") as AudioStreamPlayer

func _ready() -> void:
	_ensure_node_references()
	# que suene la música
	if background_music and is_inside_tree() and not background_music.playing:
		background_music.play()
		
	# nombre de zona en el HUD
	if hud and hud.has_method("set_zone"):
		hud.set_zone("CAMPUS NEXUS")
	else:
		var sm = _get_scene_manager()
		if sm and sm.has_method("set_zone_name"):
			sm.set_zone_name("CAMPUS NEXUS")
			
	# colisiones de cada capa
	_configure_layer_collisions()
	
	# siempre se regenera el mapa por código para que coincida con el script
	if layer0_ground and layer1_paths and props_tilemap and layer3_canopy:
		populate_tilemaps()
		
	# colisiones para edificios, piscinas y jardineras
	_ensure_campus_obstacles()
	
	# luces, líneas de energía, fuentes y partículas
	_setup_hub_ambient_fx()
	
	# letreros con la misma letra que NeuroMathLab
	_setup_hub_world_labels()
	_connect_game_state_signals()
	_refresh_hub_labels_state()
		
	# pone al jugador en SceneManager.hub_return_position (ej: (640, 368) si es la primera vez)
	_restore_player_position()

func _process(delta: float) -> void:
	_hub_anim_time += delta
	for i in range(_hub_ley_lines.size()):
		var l := _hub_ley_lines[i]
		if is_instance_valid(l):
			l.default_color.a = 0.24 + 0.14 * sin(_hub_anim_time * 2.6 + float(i) * 0.7)
	for i in range(_hub_ley_packets.size()):
		var pkt := _hub_ley_packets[i]
		if not is_instance_valid(pkt) or i >= _hub_ley_paths.size():
			continue
		var pts: Array = _hub_ley_paths[i]
		var t: float = fmod(_hub_anim_time * 0.32 + float(i) * 0.17, 1.0)
		pkt.position = _sample_hub_path(pts, t)
		pkt.modulate.a = 0.65 + 0.35 * sin(_hub_anim_time * 5.0 + float(i))
	for i in range(_hub_water_ripples.size()):
		var rip := _hub_water_ripples[i]
		if is_instance_valid(rip):
			var s: float = 0.85 + 0.22 * sin(_hub_anim_time * 2.4 + float(i) * 1.1)
			rip.scale = Vector2(s, s)
			rip.default_color.a = 0.25 + 0.20 * cos(_hub_anim_time * 2.4 + float(i) * 1.1)

func _sample_hub_path(pts: Array, t: float) -> Vector2:
	if pts.size() == 0:
		return Vector2.ZERO
	if pts.size() == 1:
		return pts[0]
	var total: float = 0.0
	var lens: Array[float] = []
	for i in range(pts.size() - 1):
		var d: float = (pts[i] as Vector2).distance_to(pts[i + 1] as Vector2)
		lens.append(d)
		total += d
	if total <= 0.001:
		return pts[0]
	var target: float = t * total
	var acc: float = 0.0
	for i in range(lens.size()):
		if acc + lens[i] >= target:
			var lt: float = (target - acc) / maxf(lens[i], 0.001)
			return (pts[i] as Vector2).lerp(pts[i + 1] as Vector2, lt)
		acc += lens[i]
	return pts[pts.size() - 1]

func _setup_hub_ambient_fx() -> void:
	if has_node("AmbientFX"):
		get_node("AmbientFX").queue_free()

	var fx_root := Node2D.new()
	fx_root.name = "AmbientFX"
	fx_root.z_index = 0
	add_child(fx_root)
	if layer1_paths:
		move_child(fx_root, layer1_paths.get_index() + 1)
	elif layer2_entities:
		move_child(fx_root, layer2_entities.get_index())

	_hub_ley_lines.clear()
	_hub_ley_packets.clear()
	_hub_ley_paths.clear()
	_hub_water_ripples.clear()

	# 1. 6 Color-Coded Nexus Ley-Line Conduits radiating from NexusAltar (640, 320) to all 6 Portals
	var altar_pos := Vector2(640, 320)
	var ley_configs: Array[Dictionary] = [
		{"col": Color("#4682B4"), "pts": [altar_pos, Vector2(640, 96)]},
		{"col": Color("#9C27B0"), "pts": [altar_pos, Vector2(640, 640)]},
		{"col": Color("#FF2A85"), "pts": [altar_pos, Vector2(640, 346), Vector2(160, 346), Vector2(160, 160)]},
		{"col": Color("#00E5FF"), "pts": [altar_pos, Vector2(640, 346), Vector2(1120, 346), Vector2(1120, 160)]},
		{"col": Color("#4CAF50"), "pts": [altar_pos, Vector2(640, 370), Vector2(160, 370), Vector2(160, 576)]},
		{"col": Color("#FF8C00"), "pts": [altar_pos, Vector2(640, 370), Vector2(1120, 370), Vector2(1120, 576)]}
	]
	for cfg in ley_configs:
		var c: Color = cfg["col"]
		var pts: Array = cfg["pts"]
		var glow := Line2D.new()
		glow.width = 5.0
		glow.joint_mode = Line2D.LINE_JOINT_ROUND
		glow.default_color = Color(c.r, c.g, c.b, 0.14)
		for p in pts:
			glow.add_point(p)
		fx_root.add_child(glow)

		var core := Line2D.new()
		core.width = 2.0
		core.joint_mode = Line2D.LINE_JOINT_ROUND
		core.default_color = Color(c.r, c.g, c.b, 0.38)
		for p in pts:
			core.add_point(p)
		fx_root.add_child(core)
		_hub_ley_lines.append(core)

		var pkt := Polygon2D.new()
		pkt.color = Color(c.lightened(0.35), 0.92)
		pkt.polygon = PackedVector2Array([
			Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)
		])
		fx_root.add_child(pkt)
		_hub_ley_packets.append(pkt)
		_hub_ley_paths.append(pts)

	# 2. Concentric Sanctuary Rings around NexusAltar (640, 320)
	for r in [46.0, 68.0]:
		var ring := Line2D.new()
		ring.position = altar_pos
		ring.width = 1.6
		ring.closed = true
		ring.default_color = Color(1.0, 0.843, 0.0, 0.32)
		for i in range(24):
			var a: float = TAU * float(i) / 24.0
			ring.add_point(Vector2(cos(a) * r, sin(a) * (r * 0.68)))
		fx_root.add_child(ring)
		_hub_ley_lines.append(ring)

	# 3. 24 Warm Golden Streetlamp Light Halos
	var lamp_coords: Array[Vector2i] = [
		Vector2i(36, 17), Vector2i(43, 17), Vector2i(36, 27), Vector2i(43, 27),
		Vector2i(36, 8), Vector2i(43, 8), Vector2i(36, 37), Vector2i(43, 37),
		Vector2i(66, 13), Vector2i(73, 13), Vector2i(6, 13), Vector2i(13, 13),
		Vector2i(66, 33), Vector2i(73, 33), Vector2i(6, 33), Vector2i(13, 33),
		Vector2i(50, 20), Vector2i(62, 20), Vector2i(16, 20), Vector2i(29, 20),
		Vector2i(50, 25), Vector2i(62, 25), Vector2i(16, 25), Vector2i(29, 25)
	]
	for lc in lamp_coords:
		var halo := Polygon2D.new()
		halo.z_index = 2
		halo.position = Vector2(float(lc.x) * 16.0 + 8.0, float(lc.y) * 16.0 - 4.0)
		halo.color = Color(1.0, 0.88, 0.42, 0.16)
		var hpts := PackedVector2Array()
		for i in range(12):
			var a: float = TAU * float(i) / 12.0
			hpts.append(Vector2(cos(a) * 28.0, sin(a) * 20.0))
		halo.polygon = hpts
		fx_root.add_child(halo)

	# 4. Water Fountain Ripples & Mist on the 3 Ornamental Pools
	var pool_centers: Array[Vector2] = [
		Vector2(552, 328),
		Vector2(728, 328),
		Vector2(904, 216)
	]
	for pc in pool_centers:
		for r in [10.0, 17.0]:
			var rip := Line2D.new()
			rip.position = pc
			rip.width = 1.2
			rip.closed = true
			rip.default_color = Color(0.65, 0.95, 1.0, 0.38)
			for i in range(12):
				var a: float = TAU * float(i) / 12.0
				rip.add_point(Vector2(cos(a) * r, sin(a) * (r * 0.75)))
			fx_root.add_child(rip)
			_hub_water_ripples.append(rip)

		var mist := CPUParticles2D.new()
		mist.z_index = 2
		mist.position = pc
		mist.amount = 8
		mist.lifetime = 1.8
		mist.preprocess = 1.0
		mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		mist.emission_rect_extents = Vector2(12, 10)
		mist.direction = Vector2(0, -1)
		mist.spread = 35.0
		mist.gravity = Vector2(0, 8)
		mist.initial_velocity_min = 6.0
		mist.initial_velocity_max = 14.0
		mist.scale_amount_min = 1.2
		mist.scale_amount_max = 2.0
		mist.color = Color(0.75, 0.96, 1.0, 0.65)
		fx_root.add_child(mist)

	# 5. Campus Sunlight Motes / Fireflies across the Central Plaza & Courtyards
	var motes := CPUParticles2D.new()
	motes.name = "CampusSunlightMotes"
	motes.z_index = 2
	motes.position = Vector2(640, 360)
	motes.amount = 36
	motes.lifetime = 4.5
	motes.preprocess = 2.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(540, 280)
	motes.direction = Vector2(0.2, -1.0)
	motes.spread = 30.0
	motes.gravity = Vector2(0, -3)
	motes.initial_velocity_min = 5.0
	motes.initial_velocity_max = 14.0
	motes.scale_amount_min = 1.4
	motes.scale_amount_max = 2.4
	motes.color = Color(1.0, 0.94, 0.55, 0.58)
	fx_root.add_child(motes)

func _configure_layer_collisions() -> void:
	if layer0_ground:
		layer0_ground.collision_enabled = false
	if layer1_paths:
		layer1_paths.collision_enabled = false
	if props_tilemap:
		props_tilemap.collision_enabled = true
	if layer3_canopy:
		layer3_canopy.collision_enabled = false

func _ensure_campus_obstacles() -> void:
	var obs := get_node_or_null("CampusObstacles") as StaticBody2D
	if obs == null:
		obs = StaticBody2D.new()
		obs.name = "CampusObstacles"
		obs.collision_layer = 1
		obs.collision_mask = 0
		add_child(obs)
	if obs.get_child_count() > 0:
		return
		
	# 1. 4 University Campus Faculty Pavilions (11x6 tiles = 176x96 px each)
	var pavilion_rects: Array[Rect2i] = [
		Rect2i(18, 4, 11, 6),
		Rect2i(51, 4, 11, 6),
		Rect2i(18, 36, 11, 6),
		Rect2i(51, 36, 11, 6)
	]
	for i in range(pavilion_rects.size()):
		_add_tile_rect_collider(obs, "Pavilion_%d" % (i + 1), pavilion_rects[i])
		
	# 2. 3 Ornamental Water Pools (3x3 tiles = 48x48 px each)
	var pool_tops: Array[Vector2i] = [
		Vector2i(33, 19),
		Vector2i(44, 19),
		Vector2i(55, 12)
	]
	for i in range(pool_tops.size()):
		var pt: Vector2i = pool_tops[i]
		_add_tile_rect_collider(obs, "WaterPool_%d" % (i + 1), Rect2i(pt.x, pt.y, 3, 3))
		
	# 3. 8 Raised Planter Beds (3x1 tiles = 48x16 px each)
	var planter_lefts: Array[Vector2i] = [
		Vector2i(33, 16), Vector2i(44, 16),
		Vector2i(33, 28), Vector2i(44, 28),
		Vector2i(19, 29), Vector2i(25, 29),
		Vector2i(52, 29), Vector2i(58, 29)
	]
	for i in range(planter_lefts.size()):
		var pl: Vector2i = planter_lefts[i]
		_add_tile_rect_collider(obs, "Planter_%d" % (i + 1), Rect2i(pl.x, pl.y, 3, 1))

func _add_tile_rect_collider(parent_body: StaticBody2D, col_name: String, tile_rect: Rect2i) -> CollisionShape2D:
	var col := CollisionShape2D.new()
	col.name = col_name
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tile_rect.size.x * 16.0, tile_rect.size.y * 16.0)
	col.shape = shape
	col.position = Vector2(
		(float(tile_rect.position.x) + float(tile_rect.size.x) * 0.5) * 16.0,
		(float(tile_rect.position.y) + float(tile_rect.size.y) * 0.5) * 16.0
	)
	parent_body.add_child(col)
	return col

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

func _connect_game_state_signals() -> void:
	var gs = _get_game_state()
	if gs:
		if gs.has_signal("fragment_awarded") and not gs.fragment_awarded.is_connected(_on_hub_fragment_updated):
			gs.fragment_awarded.connect(_on_hub_fragment_updated)
		if gs.has_signal("fragment_collected") and not gs.fragment_collected.is_connected(_on_hub_fragment_updated):
			gs.fragment_collected.connect(_on_hub_fragment_updated)

func _on_hub_fragment_updated(_biome_id: String, _total: int) -> void:
	_refresh_hub_labels_state()

func _refresh_hub_labels_state() -> void:
	var gs = _get_game_state()
	var frag_count: int = 0
	var nm_completed: bool = false
	var ca_completed: bool = false
	var ge_completed: bool = false
	var ac_completed: bool = false
	var ls_completed: bool = false
	var vc_completed: bool = false
	if gs:
		if gs.has_method("get_fragment_count"):
			frag_count = gs.get_fragment_count()
		if gs.has_method("has_fragment"):
			nm_completed = gs.has_fragment("neuromath")
			ca_completed = gs.has_fragment("comunicarte")
			ge_completed = gs.has_fragment("gerencia")
			ac_completed = gs.has_fragment("activatuidea")
			ls_completed = gs.has_fragment("latidosocial") or gs.has_fragment("misionales")
			vc_completed = gs.has_fragment("voxcivitas")
			
	if _altar_status_label:
		if frag_count >= 6:
			_altar_status_label.text = "[NEXO COMPLETADO: 6/6]"
			_altar_status_label.add_theme_color_override("font_color", Color("#00E676"))
		else:
			_altar_status_label.text = "[FRAGMENTOS: %d/6]" % frag_count
			_altar_status_label.add_theme_color_override("font_color", Color("#FFF8E1"))
			
	_update_portal_status_label(_neuromath_portal_status_label, nm_completed)
	_update_portal_status_label(_comunicarte_portal_status_label, ca_completed)
	_update_portal_status_label(_gerencia_portal_status_label, ge_completed)
	_update_portal_status_label(_activatuidea_portal_status_label, ac_completed)
	_update_portal_status_label(_latidosocial_portal_status_label, ls_completed)
	_update_portal_status_label(_voxcivitas_portal_status_label, vc_completed)

func _update_portal_status_label(lbl: Label, is_completed: bool) -> void:
	if not lbl:
		return
	if is_completed:
		lbl.text = "[NEXO ESTABILIZADO]"
		lbl.add_theme_color_override("font_color", Color("#00E676"))
	else:
		lbl.text = "[PORTAL ACTIVO: E]"
		lbl.add_theme_color_override("font_color", Color("#FFD700"))

func _setup_hub_world_labels() -> void:
	if has_node("HubLabels"):
		get_node("HubLabels").queue_free()
		
	var labels_root := Node2D.new()
	labels_root.name = "HubLabels"
	labels_root.z_index = 12
	add_child(labels_root)
	
	# altar del centro
	_create_world_label(labels_root, Vector2(640, 266), "ALTAR DEL NEXO", Color("#FFD700"))
	_altar_status_label = _create_world_label(labels_root, Vector2(640, 278), "[FRAGMENTOS: 0/6]", Color("#FFF8E1"))
	
	# Guide NPC & Active NeuroMath Portal (Northeast)
	_create_world_label(labels_root, Vector2(1088, 182), "GUÍA NEUROMATH", Color("#80D8FF"))
	_create_world_label(labels_root, Vector2(1120, 112), "OBSERVATORIO NEUROMATH", Color("#00E5FF"))
	_neuromath_portal_status_label = _create_world_label(labels_root, Vector2(1120, 124), "[PORTAL ACTIVO: E]", Color("#FFD700"))
	
	# Active Phase 2 & Phase 3 Biome Portals
	_create_world_label(labels_root, Vector2(192, 182), "GUÍA COMUNICARTE", Color("#FF80AB"))
	_create_world_label(labels_root, Vector2(160, 112), "COMUNICARTE", Color("#FF2A85"))
	_comunicarte_portal_status_label = _create_world_label(labels_root, Vector2(160, 124), "[PORTAL ACTIVO: E]", Color("#FFD700"))
	
	_create_world_label(labels_root, Vector2(608, 118), "GUÍA GERENCIA+", Color("#90CAF9"))
	_create_world_label(labels_root, Vector2(640, 48), "GERENCIA+", Color("#64B5F6"))
	_gerencia_portal_status_label = _create_world_label(labels_root, Vector2(640, 60), "[PORTAL ACTIVO: E]", Color("#FFD700"))
	
	_create_world_label(labels_root, Vector2(1088, 598), "GUÍA ACTIVATUIDEA", Color("#FFCC80"))
	_create_world_label(labels_root, Vector2(1120, 528), "ACTIVATUIDEA", Color("#FF8C00"))
	_activatuidea_portal_status_label = _create_world_label(labels_root, Vector2(1120, 540), "[PORTAL ACTIVO: E]", Color("#FFD700"))
	
	# Active Phase 4 Biome Portals & Guides
	_create_world_label(labels_root, Vector2(128, 598), "GUÍA LATIDOSOCIAL", Color("#A5D6A7"))
	_create_world_label(labels_root, Vector2(160, 528), "LATIDOSOCIAL", Color("#4CAF50"))
	_latidosocial_portal_status_label = _create_world_label(labels_root, Vector2(160, 540), "[PORTAL ACTIVO: E]", Color("#FFD700"))
	
	_create_world_label(labels_root, Vector2(608, 662), "GUÍA VOXCIVITAS", Color("#E1BEE7"))
	_create_world_label(labels_root, Vector2(640, 592), "VOXCIVITAS", Color("#CE93D8"))
	_voxcivitas_portal_status_label = _create_world_label(labels_root, Vector2(640, 604), "[PORTAL ACTIVO: E]", Color("#FFD700"))
	
	# 4 Campus Faculty Pavilions (centered on roof headers)
	_create_world_label(labels_root, Vector2(376, 72), "PABELLÓN DE ARTES Y CAFÉ", Color("#FFCC80"))
	_create_world_label(labels_root, Vector2(904, 72), "PABELLÓN DE CIENCIAS", Color("#80D8FF"))
	_create_world_label(labels_root, Vector2(376, 584), "PABELLÓN COMUNITARIO", Color("#A5D6A7"))
	_create_world_label(labels_root, Vector2(904, 584), "ESTUDIO DE INNOVACIÓN", Color("#FFE082"))

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
	lbl.size = Vector2(240, 14)
	lbl.position = pos - Vector2(120, 7)
	parent_node.add_child(lbl)
	return lbl

func _restore_player_position() -> void:
	if not player:
		player = get_node_or_null("Layer2_Entities/Player") as CharacterBody2D
	if not player:
		return
	var scene_manager = _get_scene_manager()
	if scene_manager and "hub_return_position" in scene_manager:
		var return_pos: Vector2 = scene_manager.hub_return_position
		if return_pos != Vector2.ZERO:
			player.global_position = return_pos
			player.position = return_pos

## Llena las 4 capas del mapa por código
func populate_tilemaps() -> void:
	if not layer0_ground or not layer1_paths or not props_tilemap or not layer3_canopy:
		return
		
	layer0_ground.clear()
	layer1_paths.clear()
	props_tilemap.clear()
	layer3_canopy.clear()
		
	var s: int = 0
	
	# =========================================================================
	# LAYER 0: Seamless Grass Lawn, Central Plaza & 4 Quadrant Courtyards
	# =========================================================================
	for x in range(80):
		for y in range(45):
			var grass_tile := Vector2i(1, 26)
			if (x * 13 + y * 7) % 19 == 0:
				grass_tile = Vector2i(0, 24)
			layer0_ground.set_cell(Vector2i(x, y), s, grass_tile)

	# Central Stone Plaza around (640, 360) -> x: 32..47, y: 15..29 (Light Stone B=16)
	_fill_slab_plaza(layer0_ground, s, Rect2i(32, 15, 16, 15), 16)
	# Inner darker stone sanctuary ring around Nexus Altar -> x: 37..42, y: 18..25 (Dark Stone B=8)
	_fill_slab_plaza(layer0_ground, s, Rect2i(37, 18, 6, 8), 8)

	# 4 Walkable Quadrant Courtyards paved with clean bordered stone/sandstone plazas
	# Northwest Quadrant: Arts & Café Sandstone Courtyard (x: 18..28, y: 10..17)
	_fill_bordered_walkway(layer0_ground, s, Rect2i(18, 10, 11, 8), 3)

	# Northeast Quadrant: Science & Botanical Courtyard (x: 51..61, y: 10..17)
	_fill_bordered_walkway(layer0_ground, s, Rect2i(51, 10, 11, 8), 0)
	# Inner botanical grass garden inside NE Courtyard
	for gx in range(52, 61):
		for gy in range(11, 16):
			layer0_ground.set_cell(Vector2i(gx, gy), s, Vector2i(0, 24))

	# Southwest Quadrant: Community Courtyard (x: 18..28, y: 28..35)
	_fill_bordered_walkway(layer0_ground, s, Rect2i(18, 28, 11, 8), 3)

	# Southeast Quadrant: Innovation Courtyard (x: 51..61, y: 28..35)
	_fill_bordered_walkway(layer0_ground, s, Rect2i(51, 28, 11, 8), 0)

	# =========================================================================
	# LAYER 1: Walkways, Portal Plazas, Campus Buildings, Fountains & Planters
	# =========================================================================
	# Gerencia+ (North): avenue x: 38..41, y: 6..15 & portal plaza x: 36..43, y: 3..8
	_fill_bordered_walkway(layer1_paths, s, Rect2i(36, 3, 8, 5), 0)
	for x in range(38, 42):
		for y in range(7, 16):
			var tx := Vector2i(1, 20)
			if x == 38: tx = Vector2i(0, 20)
			elif x == 41: tx = Vector2i(2, 20)
			layer1_paths.set_cell(Vector2i(x, y), s, tx)

	# VoxCivitas (South): avenue x: 38..41, y: 29..38 & portal plaza x: 36..43, y: 37..42
	_fill_bordered_walkway(layer1_paths, s, Rect2i(36, 37, 8, 6), 0)
	for x in range(38, 42):
		for y in range(29, 38):
			var tx := Vector2i(1, 20)
			if x == 38: tx = Vector2i(0, 20)
			elif x == 41: tx = Vector2i(2, 20)
			layer1_paths.set_cell(Vector2i(x, y), s, tx)

	# Main East-West thoroughfares
	for x in range(47, 72):
		for y in range(21, 25):
			var ty := Vector2i(1, 20)
			if y == 21: ty = Vector2i(1, 19)
			elif y == 24: ty = Vector2i(1, 22)
			layer1_paths.set_cell(Vector2i(x, y), s, ty)
	for x in range(8, 33):
		for y in range(21, 25):
			var ty := Vector2i(1, 20)
			if y == 21: ty = Vector2i(1, 19)
			elif y == 24: ty = Vector2i(1, 22)
			layer1_paths.set_cell(Vector2i(x, y), s, ty)

	# Sandstone walkways connecting East-West avenues into the 4 Quadrant Courtyards
	for y in range(17, 22):
		layer1_paths.set_cell(Vector2i(22, y), s, Vector2i(3, 20))
		layer1_paths.set_cell(Vector2i(23, y), s, Vector2i(4, 20))
		layer1_paths.set_cell(Vector2i(24, y), s, Vector2i(5, 20))
		layer1_paths.set_cell(Vector2i(55, y), s, Vector2i(3, 20))
		layer1_paths.set_cell(Vector2i(56, y), s, Vector2i(4, 20))
		layer1_paths.set_cell(Vector2i(57, y), s, Vector2i(5, 20))
	for y in range(24, 29):
		layer1_paths.set_cell(Vector2i(22, y), s, Vector2i(3, 20))
		layer1_paths.set_cell(Vector2i(23, y), s, Vector2i(4, 20))
		layer1_paths.set_cell(Vector2i(24, y), s, Vector2i(5, 20))
		layer1_paths.set_cell(Vector2i(55, y), s, Vector2i(3, 20))
		layer1_paths.set_cell(Vector2i(56, y), s, Vector2i(4, 20))
		layer1_paths.set_cell(Vector2i(57, y), s, Vector2i(5, 20))

	# Northeast branch to NeuroMath at (70, 10)
	_fill_bordered_walkway(layer1_paths, s, Rect2i(66, 7, 8, 6), 0)
	for x in range(68, 72):
		for y in range(12, 22):
			var tx := Vector2i(1, 20)
			if x == 68: tx = Vector2i(0, 20)
			elif x == 71: tx = Vector2i(2, 20)
			layer1_paths.set_cell(Vector2i(x, y), s, tx)

	# Northwest branch to ComunicArte at (10, 10)
	_fill_bordered_walkway(layer1_paths, s, Rect2i(6, 7, 8, 6), 0)
	for x in range(8, 12):
		for y in range(12, 22):
			var tx := Vector2i(1, 20)
			if x == 8: tx = Vector2i(0, 20)
			elif x == 11: tx = Vector2i(2, 20)
			layer1_paths.set_cell(Vector2i(x, y), s, tx)

	# Southeast branch to ActivaTuIdea at (70, 36)
	_fill_bordered_walkway(layer1_paths, s, Rect2i(66, 33, 8, 6), 0)
	for x in range(68, 72):
		for y in range(24, 34):
			var tx := Vector2i(1, 20)
			if x == 68: tx = Vector2i(0, 20)
			elif x == 71: tx = Vector2i(2, 20)
			layer1_paths.set_cell(Vector2i(x, y), s, tx)

	# Southwest branch to LatidoSocial at (10, 36)
	_fill_bordered_walkway(layer1_paths, s, Rect2i(6, 33, 8, 6), 0)
	for x in range(8, 12):
		for y in range(24, 34):
			var tx := Vector2i(1, 20)
			if x == 8: tx = Vector2i(0, 20)
			elif x == 11: tx = Vector2i(2, 20)
			layer1_paths.set_cell(Vector2i(x, y), s, tx)

	# 4 University Campus Faculty Pavilions (11x6 tiles matching CampusObstacles)
	# 1) NW Arts & Café Brick Pavilion (x: 18..28, y: 4..9): Red brick roof (B=0) & wall (W=0)
	_build_campus_pavilion(layer1_paths, props_tilemap, layer3_canopy, s, Rect2i(18, 4, 11, 6), 0, 0, true)
	# 2) NE Science & Research Stone Pavilion (x: 51..61, y: 4..9): Stone roof (B=8) & wall (W=4)
	_build_campus_pavilion(layer1_paths, props_tilemap, layer3_canopy, s, Rect2i(51, 4, 11, 6), 8, 4, false)
	# 3) SW Social Community Hall (x: 18..28, y: 36..41): Sandstone roof (B=24) & wall (W=8)
	_build_campus_pavilion(layer1_paths, props_tilemap, layer3_canopy, s, Rect2i(18, 36, 11, 6), 24, 8, false)
	# 4) SE Innovation Studio (x: 51..61, y: 36..41): Light stone roof (B=16) & wall (W=4)
	_build_campus_pavilion(layer1_paths, props_tilemap, layer3_canopy, s, Rect2i(51, 36, 11, 6), 16, 4, true)

	# Twin 3x3 Ornamental Water Fountains in Central Plaza (West & East of Altar)
	_place_water_pool_3x3(layer1_paths, s, Vector2i(33, 19))
	_place_water_pool_3x3(layer1_paths, s, Vector2i(44, 19))

	# Botanical Garden Reflecting Pool in NE Courtyard
	_place_water_pool_3x3(layer1_paths, s, Vector2i(55, 12))

	# Raised Planter Beds (3x1 hedges & flower beds)
	_place_planter_3x1(layer1_paths, s, Vector2i(33, 16), true)
	_place_planter_3x1(layer1_paths, s, Vector2i(44, 16), true)
	_place_planter_3x1(layer1_paths, s, Vector2i(33, 28), false)
	_place_planter_3x1(layer1_paths, s, Vector2i(44, 28), false)
	_place_planter_3x1(layer1_paths, s, Vector2i(19, 29), true)
	_place_planter_3x1(layer1_paths, s, Vector2i(25, 29), true)
	_place_planter_3x1(layer1_paths, s, Vector2i(52, 29), false)
	_place_planter_3x1(layer1_paths, s, Vector2i(58, 29), false)

	# =========================================================================
	# LAYER 2 (Props_TileMap) & LAYER 3 (RoofsAndCanopy)
	# =========================================================================
	# 1. 3-Tile Campus Streetlamps (pole base (5, 18) on Layer 2, upper shaft (5, 17) & double-arm head (4..6, 16) on Layer 3)
	var lamp_coords: Array[Vector2i] = [
		Vector2i(36, 17), Vector2i(43, 17), Vector2i(36, 27), Vector2i(43, 27),
		Vector2i(36, 8), Vector2i(43, 8), Vector2i(36, 37), Vector2i(43, 37),
		Vector2i(66, 13), Vector2i(73, 13), Vector2i(6, 13), Vector2i(13, 13),
		Vector2i(66, 33), Vector2i(73, 33), Vector2i(6, 33), Vector2i(13, 33),
		Vector2i(50, 20), Vector2i(62, 20), Vector2i(16, 20), Vector2i(29, 20),
		Vector2i(50, 25), Vector2i(62, 25), Vector2i(16, 25), Vector2i(29, 25)
	]
	for i in range(lamp_coords.size()):
		var c: Vector2i = lamp_coords[i]
		props_tilemap.set_cell(c, s, Vector2i(5, 18))
		layer3_canopy.set_cell(Vector2i(c.x, c.y - 1), s, Vector2i(5, 17))
		layer3_canopy.set_cell(Vector2i(c.x - 1, c.y - 2), s, Vector2i(4, 16))
		layer3_canopy.set_cell(Vector2i(c.x, c.y - 2), s, Vector2i(5, 16))
		layer3_canopy.set_cell(Vector2i(c.x + 1, c.y - 2), s, Vector2i(6, 16))

	# 2. True 2-Tile Wooden Park Benches: (17, 15) + (18, 15)
	var bench_coords: Array[Vector2i] = [
		Vector2i(33, 24), Vector2i(45, 24),
		Vector2i(52, 20), Vector2i(59, 20), Vector2i(18, 20), Vector2i(26, 20),
		Vector2i(52, 25), Vector2i(59, 25), Vector2i(18, 25), Vector2i(26, 25),
		Vector2i(19, 16), Vector2i(26, 16), Vector2i(52, 16), Vector2i(59, 16),
		Vector2i(19, 34), Vector2i(26, 34), Vector2i(52, 34), Vector2i(59, 34)
	]
	for c in bench_coords:
		props_tilemap.set_cell(c, s, Vector2i(17, 15))
		props_tilemap.set_cell(Vector2i(c.x + 1, c.y), s, Vector2i(18, 15))

	# 3. Campus Founder Statues (Pedestal on Layer 2, Statue top on Layer 3)
	var statue_coords: Array[Vector2i] = [
		Vector2i(35, 14), Vector2i(44, 14),
		Vector2i(23, 32), Vector2i(56, 32)
	]
	for i in range(statue_coords.size()):
		var sc: Vector2i = statue_coords[i]
		var st_col: int = 35 if (i % 2 == 0) else 36
		props_tilemap.set_cell(sc, s, Vector2i(st_col, 3))
		layer3_canopy.set_cell(Vector2i(sc.x, sc.y - 1), s, Vector2i(st_col, 2))

	# 4. Student Café Umbrella Kiosks in NW Patio & SE Terrace
	var kiosk_coords: Array[Vector2i] = [
		Vector2i(20, 13), Vector2i(23, 13), Vector2i(26, 13),
		Vector2i(53, 32), Vector2i(59, 32)
	]
	for i in range(kiosk_coords.size()):
		var kc: Vector2i = kiosk_coords[i]
		var k_col: int = 34 + (i % 3)
		props_tilemap.set_cell(kc, s, Vector2i(k_col, 15))
		layer3_canopy.set_cell(Vector2i(kc.x, kc.y - 1), s, Vector2i(k_col, 14))

	# 5. Decorative Bushes / Shrubs (row 13, cols 31..36)
	var bush_coords: Array[Vector2i] = [
		Vector2i(31, 15), Vector2i(48, 15), Vector2i(31, 29), Vector2i(48, 29),
		Vector2i(17, 10), Vector2i(29, 10), Vector2i(17, 17), Vector2i(29, 17),
		Vector2i(50, 10), Vector2i(62, 10), Vector2i(50, 17), Vector2i(62, 17),
		Vector2i(17, 28), Vector2i(29, 28), Vector2i(17, 35), Vector2i(29, 35),
		Vector2i(50, 28), Vector2i(62, 28), Vector2i(50, 35), Vector2i(62, 35),
		Vector2i(35, 4), Vector2i(44, 4), Vector2i(35, 41), Vector2i(44, 41)
	]
	for i in range(bush_coords.size()):
		var bc: Vector2i = bush_coords[i]
		var b_col: int = 31 + (i % 6)
		props_tilemap.set_cell(bc, s, Vector2i(b_col, 13))

	# 6. Seamless 3-Tile Campus Trees: Base+Trunk (col, 12) on Layer 2, Mid (col, 11) & Crown (col, 10) on Layer 3
	var tree_coords: Array[Vector2i] = [
		# Northern park belt
		Vector2i(3, 4), Vector2i(8, 4), Vector2i(15, 4), Vector2i(31, 4),
		Vector2i(48, 4), Vector2i(64, 4), Vector2i(71, 4), Vector2i(76, 4),
		# Upper quadrant groves flanking pavilions & courtyards
		Vector2i(15, 9), Vector2i(31, 9), Vector2i(48, 9), Vector2i(64, 9),
		Vector2i(15, 14), Vector2i(31, 14), Vector2i(48, 14), Vector2i(64, 14),
		Vector2i(15, 19), Vector2i(30, 19), Vector2i(49, 19), Vector2i(64, 19),
		# Lower quadrant groves flanking courtyards & pavilions
		Vector2i(15, 27), Vector2i(30, 27), Vector2i(49, 27), Vector2i(64, 27),
		Vector2i(15, 32), Vector2i(31, 32), Vector2i(48, 32), Vector2i(64, 32),
		Vector2i(15, 37), Vector2i(31, 37), Vector2i(48, 37), Vector2i(64, 37),
		# Southern park belt
		Vector2i(3, 42), Vector2i(8, 42), Vector2i(15, 42), Vector2i(31, 42),
		Vector2i(48, 42), Vector2i(64, 42), Vector2i(71, 42), Vector2i(76, 42),
		# East & West outer avenues
		Vector2i(3, 11), Vector2i(3, 18), Vector2i(3, 24), Vector2i(3, 30), Vector2i(3, 36),
		Vector2i(76, 11), Vector2i(76, 18), Vector2i(76, 24), Vector2i(76, 30), Vector2i(76, 36)
	]
	for i in range(tree_coords.size()):
		var tc: Vector2i = tree_coords[i]
		var t_col: int = 31 + (i % 6)
		props_tilemap.set_cell(tc, s, Vector2i(t_col, 12))
		layer3_canopy.set_cell(Vector2i(tc.x, tc.y - 1), s, Vector2i(t_col, 11))
		layer3_canopy.set_cell(Vector2i(tc.x, tc.y - 2), s, Vector2i(t_col, 10))

func _fill_slab_plaza(layer: TileMapLayer, source_id: int, rect: Rect2i, base_col: int) -> void:
	# Exact 9-slice coordinates from Kenney Modern City (cols B+0..B+3, rows 0..1):
	# TL = (B+0, 0), T = (B+2, 0), TR = (B+1, 0)
	# L  = (B+3, 0), C = (B+6, 0), R  = (B+3, 1)
	# BL = (B+0, 1), B = (B+2, 1), BR = (B+1, 1)
	var x0: int = rect.position.x
	var y0: int = rect.position.y
	var x1: int = x0 + rect.size.x - 1
	var y1: int = y0 + rect.size.y - 1
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var tile := Vector2i(base_col + 6, 0)
			if x == x0 and y == y0: tile = Vector2i(base_col + 0, 0)
			elif x == x1 and y == y0: tile = Vector2i(base_col + 1, 0)
			elif x == x0 and y == y1: tile = Vector2i(base_col + 0, 1)
			elif x == x1 and y == y1: tile = Vector2i(base_col + 1, 1)
			elif y == y0: tile = Vector2i(base_col + 2, 0)
			elif y == y1: tile = Vector2i(base_col + 2, 1)
			elif x == x0: tile = Vector2i(base_col + 3, 0)
			elif x == x1: tile = Vector2i(base_col + 3, 1)
			elif ((x - x0) % 3 == 2) and ((y - y0) % 3 == 2): tile = Vector2i(base_col + 7, 0)
			layer.set_cell(Vector2i(x, y), source_id, tile)

func _fill_bordered_walkway(layer: TileMapLayer, source_id: int, rect: Rect2i, base_col: int) -> void:
	_fill_bordered_box(layer, source_id, rect,
		Vector2i(base_col, 19), Vector2i(base_col + 1, 19), Vector2i(base_col + 2, 19),
		Vector2i(base_col, 20), Vector2i(base_col + 1, 20), Vector2i(base_col + 2, 20),
		Vector2i(base_col, 22), Vector2i(base_col + 1, 22), Vector2i(base_col + 2, 22))

func _build_campus_pavilion(layer_base: TileMapLayer, layer_props: TileMapLayer, layer_top: TileMapLayer,
		source_id: int, rect: Rect2i, roof_base_col: int, wall_base_col: int, has_awning: bool) -> void:
	var x0: int = rect.position.x
	var y0: int = rect.position.y
	var w: int = rect.size.x
	var x1: int = x0 + w - 1
	var mid_x: int = x0 + int(float(w) / 2.0)
	
	# Top 3 rows (y0..y0+2): Building Roof with seamless outer border
	_fill_slab_plaza(layer_base, source_id, Rect2i(x0, y0, w, 3), roof_base_col)
	# Rooftop vents & skylight on Layer 2
	layer_props.set_cell(Vector2i(x0 + 2, y0 + 1), source_id, Vector2i(25, 14))
	layer_props.set_cell(Vector2i(mid_x, y0 + 1), source_id, Vector2i(roof_base_col + 7, 1))
	layer_props.set_cell(Vector2i(x1 - 2, y0 + 1), source_id, Vector2i(26, 14))
	
	# 2-story Facade Wall:
	# y0 + 3: 2nd floor wall with stringcourse trim (row 6)
	# y0 + 4: 1st floor upper wall (row 5)
	# y0 + 5: 1st floor foundation wall with baseboard (row 10)
	for x in range(x0, x1 + 1):
		var col_offset: int = 1 + ((x - x0) % 2)
		if x == x0: col_offset = 0
		elif x == x1: col_offset = 3
		var wc: int = wall_base_col + col_offset
		layer_base.set_cell(Vector2i(x, y0 + 3), source_id, Vector2i(wc, 6))
		layer_base.set_cell(Vector2i(x, y0 + 4), source_id, Vector2i(wc, 5))
		layer_base.set_cell(Vector2i(x, y0 + 5), source_id, Vector2i(wc, 10))
		
	# 4-pane windows (26, 16) on 2nd floor (y0 + 3) and ground floor
	for wx in [x0 + 1, x0 + 2, x1 - 2, x1 - 1]:
		layer_props.set_cell(Vector2i(wx, y0 + 3), source_id, Vector2i(26, 16))
		if not has_awning:
			layer_props.set_cell(Vector2i(wx, y0 + 4), source_id, Vector2i(26, 16))
		else:
			layer_props.set_cell(Vector2i(wx, y0 + 5), source_id, Vector2i(26, 16))
			
	# Central double entrance door at (mid_x, y0 + 4..5)
	layer_props.set_cell(Vector2i(mid_x, y0 + 4), source_id, Vector2i(28, 15))
	layer_props.set_cell(Vector2i(mid_x, y0 + 5), source_id, Vector2i(28, 16))
	# Connected 3-tile faculty gallery window triptych (20..22, 11) on 2nd floor center
	layer_props.set_cell(Vector2i(mid_x - 1, y0 + 3), source_id, Vector2i(20, 11))
	layer_props.set_cell(Vector2i(mid_x, y0 + 3), source_id, Vector2i(21, 11))
	layer_props.set_cell(Vector2i(mid_x + 1, y0 + 3), source_id, Vector2i(22, 11))
	
	# Optional striped café awning over ground floor
	if has_awning:
		var aw_col: int = 23 if (roof_base_col == 0) else 27
		layer_top.set_cell(Vector2i(x0 + 1, y0 + 4), source_id, Vector2i(aw_col, 10))
		layer_top.set_cell(Vector2i(x0 + 2, y0 + 4), source_id, Vector2i(aw_col + 1, 10))
		layer_top.set_cell(Vector2i(x0 + 3, y0 + 4), source_id, Vector2i(aw_col + 3, 10))
		layer_top.set_cell(Vector2i(x1 - 3, y0 + 4), source_id, Vector2i(aw_col, 10))
		layer_top.set_cell(Vector2i(x1 - 2, y0 + 4), source_id, Vector2i(aw_col + 1, 10))
		layer_top.set_cell(Vector2i(x1 - 1, y0 + 4), source_id, Vector2i(aw_col + 3, 10))

func _fill_bordered_box(layer: TileMapLayer, source_id: int, rect: Rect2i,
		tl: Vector2i, t: Vector2i, top_r: Vector2i,
		l: Vector2i, c: Vector2i, r: Vector2i,
		bl: Vector2i, b: Vector2i, br: Vector2i) -> void:
	var x0: int = rect.position.x
	var y0: int = rect.position.y
	var x1: int = x0 + rect.size.x - 1
	var y1: int = y0 + rect.size.y - 1
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var tile: Vector2i = c
			if x == x0 and y == y0: tile = tl
			elif x == x1 and y == y0: tile = top_r
			elif x == x0 and y == y1: tile = bl
			elif x == x1 and y == y1: tile = br
			elif y == y0: tile = t
			elif y == y1: tile = b
			elif x == x0: tile = l
			elif x == x1: tile = r
			layer.set_cell(Vector2i(x, y), source_id, tile)

func _place_water_pool_3x3(layer: TileMapLayer, source_id: int, top_left: Vector2i) -> void:
	for dx in range(3):
		for dy in range(3):
			layer.set_cell(Vector2i(top_left.x + dx, top_left.y + dy), source_id, Vector2i(26 + dx, 4 + dy))

func _place_planter_3x1(layer: TileMapLayer, source_id: int, left_pos: Vector2i, is_green_hedge: bool) -> void:
	var row: int = 5 if is_green_hedge else 8
	for dx in range(3):
		layer.set_cell(Vector2i(left_pos.x + dx, left_pos.y), source_id, Vector2i(31 + dx, row))
