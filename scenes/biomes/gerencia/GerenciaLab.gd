extends BiomeLab
class_name GerenciaLab

## GerenciaLab.gd — "Distrito de Dirección & Gestión Estratégica" laboratory world.
## Inherits from BiomeLab.
## Room size: 640x360 px (40x23 cells of 16x16 px).
## Features:
## - Central Executive Board Table at (320, 160)
## - Guardian NPC KRONOS-4 at (256, 176)
## - ExitPortal at (320, 320) returning to CampusHub at (640, 128)
## - Executive War-Room floor architecture: crimson/emerald carpet runners, golden medallion dais,
##   north command credenzas & world maps, West Kanban & East KPI workstations
## - Data stream conduits (Line2D), animated KPI telemetry packets, and glowing rings (#4682B4)
## - Holographic world-space strategic labels

@onready var kronos4_npc: Area2D = get_node_or_null("Entities/KRONOS4_NPC")
@onready var executive_board_table: StaticBody2D = get_node_or_null("Entities/ExecutiveBoardTable")

var _anim_time: float = 0.0
var _data_lines: Array[Line2D] = []
var _kpi_packets: Array[Node2D] = []
var _kpi_paths: Array[Array] = []
var _terminal_status_label: Label = null

func _init() -> void:
	biome_id = "gerencia"
	biome_name = "Distrito de Dirección & Gestión Estratégica"
	data_path = "res://data/gerencia.json"
	default_player_spawn = Vector2(320, 240)
	room_rect = Rect2i(0, 0, 640, 360)

func _ready() -> void:
	if kronos4_npc == null:
		kronos4_npc = get_node_or_null("Entities/KRONOS4_NPC")
	if guardian_npc == null:
		guardian_npc = kronos4_npc
	if executive_board_table == null:
		executive_board_table = get_node_or_null("Entities/ExecutiveBoardTable")
	if terminal == null:
		terminal = executive_board_table

	super._ready()

func init_guardian_dialogue() -> void:
	if not guardian_npc and kronos4_npc:
		guardian_npc = kronos4_npc
	if not guardian_npc and has_node("Entities/KRONOS4_NPC"):
		guardian_npc = get_node("Entities/KRONOS4_NPC") as Area2D

	if not guardian_npc:
		return

	if biome_data.is_empty() and not data_path.is_empty():
		biome_data = BiomeDataLoader.load_biome_data(data_path)

	if not biome_data.is_empty():
		var lines: Array[String] = BiomeDataLoader.extract_learning_capsule(biome_data)
		var g_dict: Dictionary = biome_data.get("guardian", {})
		var g_name: String = str(g_dict.get("name", "KRONOS-4 (Director Ejecutivo de Estrategia)"))
		var raw_accent = biome_data.get("accent_color", "#4682B4")
		var hex_col: String = str(raw_accent) if raw_accent is String and not str(raw_accent).is_empty() else "#4682B4"
		var speaker_color: Color = Color.from_string(hex_col, Color("#4682B4"))

		guardian_npc.set("dialogue_lines", lines)
		guardian_npc.set("npc_name", g_name)
		guardian_npc.set("speaker_color", speaker_color)
	else:
		super.init_guardian_dialogue()

	# Ensure KRONOS-4 sprite uses tactical steel blue commander unit texture (humanoid unit 04)
	var unit_tex = load("res://assets/neuromath/scifi_rts/PNG/Default size/Unit/scifiUnit_04.png") as Texture2D
	if guardian_npc and guardian_npc.has_node("NPCSprite") and unit_tex:
		var spr = guardian_npc.get_node("NPCSprite") as Sprite2D
		if spr:
			spr.texture = unit_tex

	# Ensure ExecutiveBoardTable uses sleek domed command center structure
	var cmd_tex = load("res://assets/neuromath/scifi_rts/PNG/Default size/Structure/scifiStructure_07.png") as Texture2D
	if terminal and terminal.has_node("TerminalSprite") and cmd_tex:
		var tspr = terminal.get_node("TerminalSprite") as Sprite2D
		if tspr:
			tspr.region_enabled = false
			tspr.texture = cmd_tex

## Virtual hook called by BiomeLab to refresh completion status
func refresh_completion_state() -> void:
	var gs := _get_game_state()
	var is_completed: bool = false
	if gs and gs.has_method("has_fragment"):
		is_completed = gs.has_fragment("gerencia")
	if _terminal_status_label:
		if is_completed:
			_terminal_status_label.text = "[NEXO ESTABILIZADO]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#00E676"))
		else:
			_terminal_status_label.text = "[MESA DE DIRECCIÓN: E]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#FFD700"))

## Virtual hook called by BiomeLab to set up boardroom ambient visuals
func setup_ambient_fx() -> void:
	if has_node("AmbientFX"):
		get_node("AmbientFX").queue_free()

	var fx_root := Node2D.new()
	fx_root.name = "AmbientFX"
	fx_root.z_index = 0
	add_child(fx_root)
	if layer0_floor:
		move_child(fx_root, layer0_floor.get_index() + 1)
	elif has_node("Entities"):
		move_child(fx_root, get_node("Entities").get_index())

	# 1. Strategic Command Glow Halos under Kanban, KPI & Central War-Room Stations
	for hpos in [Vector2(104, 136), Vector2(536, 136), Vector2(104, 248), Vector2(536, 248)]:
		var halo := Polygon2D.new()
		halo.position = hpos
		halo.color = Color(0.2745, 0.5098, 0.7059, 0.22)
		var pts := PackedVector2Array()
		for i in range(12):
			var a: float = TAU * float(i) / 12.0
			pts.append(Vector2(cos(a) * 28.0, sin(a) * 18.0))
		halo.polygon = pts
		fx_root.add_child(halo)

	# 2. Data stream conduit lines across the boardroom floor + animated KPI packets
	var conduit_paths: Array[Array] = [
		[Vector2(112, 136), Vector2(196, 136), Vector2(264, 156), Vector2(300, 160)],
		[Vector2(528, 136), Vector2(444, 136), Vector2(376, 156), Vector2(340, 160)],
		[Vector2(112, 248), Vector2(204, 220), Vector2(284, 186), Vector2(310, 175)],
		[Vector2(528, 248), Vector2(436, 220), Vector2(356, 186), Vector2(330, 175)],
		[Vector2(320, 304), Vector2(320, 240), Vector2(320, 185)]
	]

	_data_lines.clear()
	_kpi_packets.clear()
	_kpi_paths = conduit_paths

	for pts in conduit_paths:
		var glow_line := Line2D.new()
		glow_line.width = 4.5
		glow_line.joint_mode = Line2D.LINE_JOINT_ROUND
		glow_line.default_color = Color(0.2745, 0.5098, 0.7059, 0.16)
		for p in pts:
			glow_line.add_point(p)
		fx_root.add_child(glow_line)
		_data_lines.append(glow_line)

		var line := Line2D.new()
		line.width = 2.0
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.default_color = Color(0.39, 0.71, 0.96, 0.45)
		for p in pts:
			line.add_point(p)
		fx_root.add_child(line)
		_data_lines.append(line)

		var pkt := Polygon2D.new()
		pkt.color = Color(0.56, 0.85, 1.0, 0.95)
		pkt.polygon = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
		])
		fx_root.add_child(pkt)
		_kpi_packets.append(pkt)

	# 3. Digital telemetry particles
	var particles := CPUParticles2D.new()
	particles.name = "DataTelemetryBits"
	particles.z_index = 2
	particles.position = Vector2(320, 180)
	particles.amount = 18
	particles.lifetime = 3.2
	particles.preprocess = 1.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(280, 140)
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 35.0
	particles.gravity = Vector2(0, -10)
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 20.0
	particles.scale_amount_min = 1.2
	particles.scale_amount_max = 2.2
	particles.color = Color(0.4, 0.75, 1.0, 0.65)
	fx_root.add_child(particles)

	# 4. KPI floor rings under Boardroom Table, Strategy Wings, and Exit Portal
	for center_pos in [Vector2(320, 164), Vector2(320, 320), Vector2(104, 136), Vector2(536, 136)]:
		var is_main: bool = center_pos.x == 320 and center_pos.y < 200
		var radii: Array = [36.0, 50.0] if is_main else [22.0]
		for r in radii:
			var ring := Line2D.new()
			ring.position = center_pos
			ring.width = 1.8
			ring.closed = true
			ring.default_color = Color(0.39, 0.71, 0.96, 0.35)
			for i in range(12):
				var angle: float = TAU * float(i) / 12.0
				ring.add_point(Vector2(cos(angle) * r, sin(angle) * (r * 0.7)))
			fx_root.add_child(ring)
			_data_lines.append(ring)

	# 5. Holographic world-space strategic labels (spaced cleanly)
	if has_node("StationLabels"):
		get_node("StationLabels").queue_free()
	var labels_root := Node2D.new()
	labels_root.name = "StationLabels"
	labels_root.z_index = 6
	add_child(labels_root)

	_create_world_label(labels_root, Vector2(320, 96), "CENTRO DE MANDO EJECUTIVO & ESTRATEGIA", Color("#64B5F6"))
	_terminal_status_label = _create_world_label(labels_root, Vector2(320, 108), "[MESA DE DIRECCIÓN: E]", Color("#FFD700"))
	_create_world_label(labels_root, Vector2(104, 78), "MURO KANBAN & FLUJO DE VALOR", Color("#90CAF9"))
	_create_world_label(labels_root, Vector2(536, 78), "HUB DE KPIs & BALANCE DE CAPACIDAD", Color("#90CAF9"))
	_create_world_label(labels_root, Vector2(236, 200), "KRONOS-4 (DIRECTOR EJECUTIVO)", Color("#64B5F6"))
	_create_world_label(labels_root, Vector2(320, 344), "PORTAL AL CAMPUS", Color("#4682B4"))

func _process(delta: float) -> void:
	_anim_time += delta

	# Pulsing alpha for data lines
	for i in range(_data_lines.size()):
		var line := _data_lines[i]
		if is_instance_valid(line):
			var pulse := 0.25 + 0.18 * sin(_anim_time * 2.8 + float(i) * 0.8)
			line.default_color.a = pulse

	# Animate KPI telemetry packets along conduits
	for i in range(_kpi_packets.size()):
		var pkt := _kpi_packets[i]
		if not is_instance_valid(pkt) or i >= _kpi_paths.size():
			continue
		var pts: Array = _kpi_paths[i]
		var t: float = fmod(_anim_time * 0.65 + float(i) * 0.22, 1.0)
		pkt.position = _sample_path(pts, t)
		pkt.modulate.a = 0.65 + 0.35 * sin(_anim_time * 5.5 + float(i))

func _sample_path(pts: Array, t: float) -> Vector2:
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

## Populates the 16x16 executive command center: slate-emerald stone floor, crimson & emerald
## executive carpets, north wall strategic credenzas & maps, West Kanban & East KPI wings.
func populate_tilemaps() -> void:
	if not layer0_floor or not layer1_walls:
		return

	layer0_floor.clear()
	layer1_walls.clear()
	if layer2_details:
		layer2_details.clear()

	var s_floor: int = _ensure_floor_atlas_source()
	var s_indoor: int = 0
	if s_floor < 0:
		return

	# =========================================================================
	# LAYER 0: Slate-Emerald Coffered Executive Floor + War-Room Carpet Architecture
	# =========================================================================
	var wall_tile := Vector2i(12, 13)
	for x in range(40):
		for y in range(23):
			var is_border: bool = x == 0 or x == 39 or y <= 2 or y == 22
			var floor_tile := Vector2i(12, 7)
			if not is_border:
				if x == 1 and y == 3: floor_tile = Vector2i(11, 6)
				elif x == 38 and y == 3: floor_tile = Vector2i(13, 6)
				elif x == 1 and y == 21: floor_tile = Vector2i(11, 8)
				elif x == 38 and y == 21: floor_tile = Vector2i(13, 8)
				elif y == 3: floor_tile = Vector2i(12, 6)
				elif y == 21: floor_tile = Vector2i(12, 8)
				elif x == 1: floor_tile = Vector2i(11, 7)
				elif x == 38: floor_tile = Vector2i(13, 7)
			layer0_floor.set_cell(Vector2i(x, y), s_floor, wall_tile if is_border else floor_tile)

	# West Kanban Wing Emerald Executive Carpets (x=4..9, y=6..10 and y=13..17)
	_paint_carpet(layer0_floor, s_indoor, Rect2i(4, 6, 6, 5), 23, 4)
	_paint_carpet(layer0_floor, s_indoor, Rect2i(4, 13, 6, 5), 23, 4)

	# East KPI Wing Emerald Executive Carpets (x=30..35, y=6..10 and y=13..17)
	_paint_carpet(layer0_floor, s_indoor, Rect2i(30, 6, 6, 5), 23, 4)
	_paint_carpet(layer0_floor, s_indoor, Rect2i(30, 13, 6, 5), 23, 4)

	# East-West Executive Carpet Runner connecting West Kanban <-> Central War-Room <-> East KPI
	_paint_carpet(layer0_floor, s_indoor, Rect2i(10, 9, 20, 3), 23, 0)

	# Central Processional Carpet Runner (ExitPortal -> ExecutiveBoardTable: x=18..21, y=7..20)
	_paint_carpet(layer0_floor, s_indoor, Rect2i(18, 7, 4, 14), 23, 0)

	# Central War-Room Carpet Dais around ExecutiveBoardTable (x=15..24, y=7..12)
	_paint_carpet(layer0_floor, s_indoor, Rect2i(15, 7, 10, 6), 23, 0)

	# =========================================================================
	# LAYER 1: Carved Executive Perimeter Walls & North Command Frieze
	# =========================================================================
	for x in range(40):
		layer1_walls.set_cell(Vector2i(x, 0), s_floor, wall_tile)
		layer1_walls.set_cell(Vector2i(x, 1), s_floor, Vector2i(1, 7) if x % 2 == 0 else Vector2i(2, 7))
		layer1_walls.set_cell(Vector2i(x, 2), s_floor, Vector2i(2, 7))
		layer1_walls.set_cell(Vector2i(x, 22), s_floor, wall_tile)
	for y in range(1, 22):
		layer1_walls.set_cell(Vector2i(0, y), s_floor, wall_tile)
		layer1_walls.set_cell(Vector2i(39, y), s_floor, wall_tile)

	# =========================================================================
	# LAYER 2: Executive Credenzas, Strategic Maps, Kanban/KPI Tables & Lamps
	# =========================================================================
	var prop_layer: TileMapLayer = layer2_details if layer2_details != null else layer1_walls
	_ensure_prop_collisions(s_indoor)

	# 1. Strategic World Maps & KPI Charts along visible North Wall Frieze (y=2)
	for mx in [5, 11, 18, 21, 28, 34]:
		prop_layer.set_cell(Vector2i(mx, 2), s_indoor, Vector2i(18, 0))
	prop_layer.set_cell(Vector2i(19, 2), s_indoor, Vector2i(19, 12))
	prop_layer.set_cell(Vector2i(20, 2), s_indoor, Vector2i(20, 12))

	# 2. North Wall Executive Credenzas & Document Archives flush against North Wall (y=3)
	for x in [3, 4, 5, 6, 9, 10, 11, 12, 27, 28, 29, 30, 33, 34, 35, 36]:
		var cab_col: int = 6 + (x % 3)
		prop_layer.set_cell(Vector2i(x, 3), s_indoor, Vector2i(cab_col, 15))

	# 3. West (Kanban) & East (KPI) Executive Workstations (rows 8 and 15) with Chairs
	for ty in [8, 15]:
		for i in range(3):
			prop_layer.set_cell(Vector2i(5 + i, ty), s_indoor, Vector2i(7 + i, 9))
			prop_layer.set_cell(Vector2i(32 + i, ty), s_indoor, Vector2i(i, 9))
		# Executive chairs flanking workstations
		prop_layer.set_cell(Vector2i(5, ty - 1), s_indoor, Vector2i(0, 2))
		prop_layer.set_cell(Vector2i(7, ty - 1), s_indoor, Vector2i(0, 2))
		prop_layer.set_cell(Vector2i(6, ty + 1), s_indoor, Vector2i(1, 2))
		prop_layer.set_cell(Vector2i(32, ty - 1), s_indoor, Vector2i(0, 2))
		prop_layer.set_cell(Vector2i(34, ty - 1), s_indoor, Vector2i(0, 2))
		prop_layer.set_cell(Vector2i(33, ty + 1), s_indoor, Vector2i(1, 2))

	# 4. Contiguous 2-tile Floor Lamps framing Board Table, North Portico, and Exit Portal
	for cx in [14, 25]:
		prop_layer.set_cell(Vector2i(cx, 7), s_indoor, Vector2i(19, 4))
		prop_layer.set_cell(Vector2i(cx, 8), s_indoor, Vector2i(19, 5))
	for cx in [16, 23]:
		prop_layer.set_cell(Vector2i(cx, 3), s_indoor, Vector2i(19, 4))
		prop_layer.set_cell(Vector2i(cx, 4), s_indoor, Vector2i(19, 5))
	for cx in [17, 22]:
		prop_layer.set_cell(Vector2i(cx, 19), s_indoor, Vector2i(19, 4))
		prop_layer.set_cell(Vector2i(cx, 20), s_indoor, Vector2i(19, 5))

	# 5. Executive Plants along West & East Perimeter Walls
	for py in [6, 12, 18]:
		prop_layer.set_cell(Vector2i(2, py), s_indoor, Vector2i(16, 0))
		prop_layer.set_cell(Vector2i(37, py), s_indoor, Vector2i(17, 0))

func _paint_carpet(layer: TileMapLayer, source_id: int, rect: Rect2i, base_col: int, base_row: int) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cx: int = base_col + 1
			if x == rect.position.x:
				cx = base_col
			elif x == rect.end.x - 1:
				cx = base_col + 2
			var cy: int = base_row + 1
			if y == rect.position.y:
				cy = base_row
			elif y == rect.end.y - 1:
				cy = base_row + 2
			layer.set_cell(Vector2i(x, y), source_id, Vector2i(cx, cy))

func _ensure_prop_collisions(source_id: int) -> void:
	if not layer0_floor or not layer0_floor.tile_set:
		return
	var ts: TileSet = layer0_floor.tile_set
	if not ts.has_source(source_id) or ts.get_physics_layers_count() == 0:
		return
	var atlas := ts.get_source(source_id) as TileSetAtlasSource
	if not atlas:
		return
	var solid_props: Array[Vector2i] = [
		Vector2i(6, 15), Vector2i(7, 15), Vector2i(8, 15),
		Vector2i(6, 16), Vector2i(7, 16), Vector2i(8, 16),
		Vector2i(6, 17), Vector2i(7, 17), Vector2i(8, 17),
		Vector2i(0, 9), Vector2i(1, 9), Vector2i(2, 9),
		Vector2i(7, 9), Vector2i(8, 9), Vector2i(9, 9),
		Vector2i(0, 2), Vector2i(1, 2),
		Vector2i(19, 4), Vector2i(19, 5),
		Vector2i(16, 0), Vector2i(17, 0)
	]
	for coord in solid_props:
		if not atlas.has_tile(coord):
			atlas.create_tile(coord)
		var td := atlas.get_tile_data(coord, 0)
		if td and td.get_collision_polygons_count(0) == 0:
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)
			]))

func _ensure_floor_atlas_source() -> int:
	if not layer0_floor or not layer0_floor.tile_set:
		return -1
	var ts: TileSet = layer0_floor.tile_set
	var atlas: TileSetAtlasSource = null
	if ts.has_source(1):
		var existing_atlas := ts.get_source(1) as TileSetAtlasSource
		if existing_atlas and existing_atlas.texture and existing_atlas.texture.resource_path.ends_with("tileset_interior_floor.png"):
			atlas = existing_atlas
		else:
			ts.remove_source(1)
	if atlas == null:
		var floor_tex := load("res://assets/characters/ninja_adventure/content/map/tileset_interior_floor.png") as Texture2D
		if not floor_tex:
			return -1
		atlas = TileSetAtlasSource.new()
		atlas.texture = floor_tex
		atlas.texture_region_size = Vector2i(16, 16)
		ts.add_source(atlas, 1)
	for coord in [
		Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6),
		Vector2i(11, 7), Vector2i(12, 7), Vector2i(13, 7),
		Vector2i(11, 8), Vector2i(12, 8), Vector2i(13, 8),
		Vector2i(15, 7), Vector2i(12, 13), Vector2i(1, 7), Vector2i(2, 7)
	]:
		if not atlas.has_tile(coord):
			atlas.create_tile(coord)
			if coord in [Vector2i(12, 13), Vector2i(1, 7), Vector2i(2, 7)] and ts.get_physics_layers_count() > 0:
				var td := atlas.get_tile_data(coord, 0)
				if td:
					td.add_collision_polygon(0)
					td.set_collision_polygon_points(0, 0, PackedVector2Array([
						Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
					]))
	return 1
