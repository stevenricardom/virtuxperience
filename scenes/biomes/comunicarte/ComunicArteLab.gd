extends BiomeLab
class_name ComunicArteLab

## ComunicArteLab.gd — "La Gran Biblioteca y Taller Tipográfico" laboratory world.
## Inherits from BiomeLab.
## Room size: 640x360 px (40x23 cells of 16x16 px).
## Floor, walls, and library props built with 16x16 tiles (comunicarte_tileset.tres).
## Features:
## - Central Typographic Lectern at (320, 160)
## - Guardian NPC LIRA-9 at (256, 176)
## - ExitPortal at (320, 320) returning to CampusHub at (160, 192)
## - Calligraphic ink flow lines (Line2D) with pulsing alpha & animated ink droplets
## - Warm golden candlelight halos around the 6 library candelabras
## - Floating leaf/parchment particles (CPUParticles2D)
## - Holographic world-space typography labels

@onready var lira9_npc: Area2D = get_node_or_null("Entities/LIRA9_NPC")
@onready var typographic_lectern: StaticBody2D = get_node_or_null("Entities/TypographicLectern")

var _anim_time: float = 0.0
var _ink_lines: Array[Line2D] = []
var _ink_drops: Array[Node2D] = []
var _ink_paths: Array[Array] = []
var _terminal_status_label: Label = null

func _init() -> void:
	biome_id = "comunicarte"
	biome_name = "La Gran Biblioteca y Taller Tipográfico"
	data_path = "res://data/comunicarte.json"
	default_player_spawn = Vector2(320, 240)
	room_rect = Rect2i(0, 0, 640, 360)

func _ready() -> void:
	if lira9_npc == null:
		lira9_npc = get_node_or_null("Entities/LIRA9_NPC")
	if guardian_npc == null:
		guardian_npc = lira9_npc
	if typographic_lectern == null:
		typographic_lectern = get_node_or_null("Entities/TypographicLectern")
	if terminal == null:
		terminal = typographic_lectern

	super._ready()

func init_guardian_dialogue() -> void:
	if not guardian_npc and lira9_npc:
		guardian_npc = lira9_npc
	if not guardian_npc and has_node("Entities/LIRA9_NPC"):
		guardian_npc = get_node("Entities/LIRA9_NPC") as Area2D

	if not guardian_npc:
		return

	if biome_data.is_empty() and not data_path.is_empty():
		biome_data = BiomeDataLoader.load_biome_data(data_path)

	if not biome_data.is_empty():
		var lines: Array[String] = BiomeDataLoader.extract_learning_capsule(biome_data)
		var g_dict: Dictionary = biome_data.get("guardian", {})
		var g_name: String = str(g_dict.get("name", "LIRA-9 (Barda del Verbo)"))
		var raw_accent = biome_data.get("accent_color", "#FF2A85")
		var hex_col: String = str(raw_accent) if raw_accent is String and not str(raw_accent).is_empty() else "#FF2A85"
		var speaker_color: Color = Color.from_string(hex_col, Color("#FF2A85"))

		guardian_npc.set("dialogue_lines", lines)
		guardian_npc.set("npc_name", g_name)
		guardian_npc.set("speaker_color", speaker_color)
	else:
		super.init_guardian_dialogue()

## Virtual hook called by BiomeLab to refresh completion status
func refresh_completion_state() -> void:
	var gs := _get_game_state()
	var is_completed: bool = false
	if gs and gs.has_method("has_fragment"):
		is_completed = gs.has_fragment("comunicarte")
	if _terminal_status_label:
		if is_completed:
			_terminal_status_label.text = "[NEXO ESTABILIZADO]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#00E676"))
		else:
			_terminal_status_label.text = "[CONSULTAR CÓDICES: E]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#FFD700"))

## Virtual hook called by BiomeLab to set up library ambient visuals
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

	# 1. Warm Golden Candlelight Halos around the 6 Library Candelabras
	var candle_positions: Array[Vector2] = [
		Vector2(248, 128), Vector2(392, 128),
		Vector2(248, 64), Vector2(392, 64),
		Vector2(280, 312), Vector2(360, 312)
	]
	for cpos in candle_positions:
		var halo := Polygon2D.new()
		halo.z_index = 2
		halo.position = cpos
		halo.color = Color(1.0, 0.84, 0.35, 0.22)
		var pts := PackedVector2Array()
		for i in range(12):
			var a: float = TAU * float(i) / 12.0
			pts.append(Vector2(cos(a) * 22.0, sin(a) * 16.0))
		halo.polygon = pts
		fx_root.add_child(halo)

	# 2. Calligraphic ink flow lines across the library floor + animated magenta ink droplets
	var ink_paths: Array[Array] = [
		[Vector2(112, 120), Vector2(200, 140), Vector2(280, 155), Vector2(300, 160)],
		[Vector2(528, 120), Vector2(440, 140), Vector2(360, 155), Vector2(340, 160)],
		[Vector2(112, 248), Vector2(210, 220), Vector2(290, 190), Vector2(310, 175)],
		[Vector2(528, 248), Vector2(430, 220), Vector2(350, 190), Vector2(330, 175)],
		[Vector2(320, 300), Vector2(320, 230), Vector2(320, 185)]
	]

	_ink_lines.clear()
	_ink_drops.clear()
	_ink_paths = ink_paths

	for pts in ink_paths:
		var glow_line := Line2D.new()
		glow_line.width = 5.0
		glow_line.joint_mode = Line2D.LINE_JOINT_ROUND
		glow_line.default_color = Color(1.0, 0.165, 0.522, 0.18)
		for p in pts:
			glow_line.add_point(p)
		fx_root.add_child(glow_line)
		_ink_lines.append(glow_line)

		var line := Line2D.new()
		line.width = 2.5
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.default_color = Color(1.0, 0.165, 0.522, 0.55)
		for p in pts:
			line.add_point(p)
		fx_root.add_child(line)
		_ink_lines.append(line)

		var drop := Polygon2D.new()
		drop.color = Color(1.0, 0.55, 0.78, 0.95)
		drop.polygon = PackedVector2Array([
			Vector2(0, -3.5), Vector2(3.5, 0), Vector2(0, 3.5), Vector2(-3.5, 0)
		])
		fx_root.add_child(drop)
		_ink_drops.append(drop)

	# 3. Floating pink leaf / parchment page particles
	var leaf_sheet := load("res://assets/characters/ninja_adventure/content/particle/particle_leaf_pink.png") as Texture2D
	var leaf_atlas := AtlasTexture.new()
	if leaf_sheet:
		leaf_atlas.atlas = leaf_sheet
		leaf_atlas.region = Rect2(0, 0, 12, 7)
	var particles := CPUParticles2D.new()
	particles.name = "LeafParticles"
	particles.z_index = 2
	particles.position = Vector2(320, 180)
	particles.amount = 20
	particles.lifetime = 4.5
	particles.preprocess = 2.0
	if leaf_sheet:
		particles.texture = leaf_atlas
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(280, 140)
	particles.direction = Vector2(-0.8, 1.0)
	particles.spread = 35.0
	particles.gravity = Vector2(-6, 12)
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 16.0
	particles.angular_velocity_min = 15.0
	particles.angular_velocity_max = 35.0
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.0
	particles.color = Color(1.0, 0.65, 0.82, 0.68)
	fx_root.add_child(particles)

	# 4. Typographic filigree rings under Lectern and Exit Portal
	for center_pos in [Vector2(320, 164), Vector2(320, 320), Vector2(104, 116), Vector2(536, 116)]:
		var ring := Line2D.new()
		ring.position = center_pos
		ring.width = 2.0
		ring.closed = true
		ring.default_color = Color(1.0, 0.165, 0.522, 0.45)
		var radius: float = 34.0 if center_pos.x == 320 and center_pos.y < 200 else 22.0
		for i in range(16):
			var angle: float = TAU * float(i) / 16.0
			ring.add_point(Vector2(cos(angle) * radius, sin(angle) * (radius * 0.65)))
		fx_root.add_child(ring)
		_ink_lines.append(ring)

	# 5. Holographic world-space typography labels (cleanly spaced)
	if has_node("StationLabels"):
		get_node("StationLabels").queue_free()
	var labels_root := Node2D.new()
	labels_root.name = "StationLabels"
	labels_root.z_index = 6
	add_child(labels_root)

	_create_world_label(labels_root, Vector2(320, 96), "TALLER TIPOGRÁFICO Y BIBLIOTECA", Color("#FF2A85"))
	_terminal_status_label = _create_world_label(labels_root, Vector2(320, 108), "[CONSULTAR CÓDICES: E]", Color("#FFD700"))
	_create_world_label(labels_root, Vector2(108, 78), "ESTANTERÍA DE INCUNABLES", Color("#FF80AB"))
	_create_world_label(labels_root, Vector2(532, 78), "PRENSA GUTENBERG & RETÓRICA", Color("#FF80AB"))
	_create_world_label(labels_root, Vector2(244, 198), "LIRA-9 (BARDA DEL VERBO)", Color("#FF2A85"))
	_create_world_label(labels_root, Vector2(320, 344), "PORTAL AL CAMPUS", Color("#FF2A85"))

func _process(delta: float) -> void:
	_anim_time += delta

	# Pulsing alpha for ink lines
	for i in range(_ink_lines.size()):
		var line := _ink_lines[i]
		if is_instance_valid(line):
			var pulse := 0.45 + 0.28 * sin(_anim_time * 2.8 + float(i) * 0.9)
			line.default_color.a = pulse

	# Animate ink droplets along calligraphic paths
	for i in range(_ink_drops.size()):
		var drop := _ink_drops[i]
		if not is_instance_valid(drop) or i >= _ink_paths.size():
			continue
		var pts: Array = _ink_paths[i]
		var t: float = fmod(_anim_time * 0.65 + float(i) * 0.23, 1.0)
		drop.position = _sample_path(pts, t)
		drop.modulate.a = 0.65 + 0.35 * sin(_anim_time * 5.5 + float(i))

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

## Populates 16x16 library floor, perimeter walls, bookshelves, and desks
func populate_tilemaps() -> void:
	if not layer0_floor or not layer1_walls:
		return

	layer0_floor.clear()
	layer1_walls.clear()
	if layer2_details:
		layer2_details.clear()

	var s_lib: int = 0
	var s_floor: int = _ensure_floor_atlas_source()

	# =========================================================================
	# LAYER 0: Warm Golden Wood Coffered Floor + Crimson & Emerald Library Rugs
	# =========================================================================
	for x in range(40):
		for y in range(23):
			if s_floor >= 0:
				var is_border: bool = x == 0 or x == 39 or y <= 2 or y == 22
				var f_tile := Vector2i(12, 1)
				if is_border:
					f_tile = Vector2i(12, 13)
				else:
					if x == 1 and y == 3: f_tile = Vector2i(11, 0)
					elif x == 38 and y == 3: f_tile = Vector2i(13, 0)
					elif x == 1 and y == 21: f_tile = Vector2i(11, 2)
					elif x == 38 and y == 21: f_tile = Vector2i(13, 2)
					elif y == 3: f_tile = Vector2i(12, 0)
					elif y == 21: f_tile = Vector2i(12, 2)
					elif x == 1: f_tile = Vector2i(11, 1)
					elif x == 38: f_tile = Vector2i(13, 1)
				layer0_floor.set_cell(Vector2i(x, y), s_floor, f_tile)
			else:
				layer0_floor.set_cell(Vector2i(x, y), s_lib, Vector2i(24, 1))

	# West Scriptorium Emerald Carpets (x=4..9, y=6..10 and y=13..17)
	_paint_carpet(layer0_floor, s_lib, Rect2i(4, 6, 6, 5), 23, 4)
	_paint_carpet(layer0_floor, s_lib, Rect2i(4, 13, 6, 5), 23, 4)

	# East Forum Emerald Carpets (x=30..35, y=6..10 and y=13..17)
	_paint_carpet(layer0_floor, s_lib, Rect2i(30, 6, 6, 5), 23, 4)
	_paint_carpet(layer0_floor, s_lib, Rect2i(30, 13, 6, 5), 23, 4)

	# East-West Carpet Runner connecting Scriptorium <-> Central Lectern <-> East Forum
	_paint_carpet(layer0_floor, s_lib, Rect2i(10, 9, 20, 3), 23, 0)

	# Central Crimson Carpet Avenue (Portal -> Typographic Lectern: x=18..21, y=7..20)
	_paint_carpet(layer0_floor, s_lib, Rect2i(18, 7, 4, 14), 23, 0)

	# Central Dais Crimson Carpet around Typographic Lectern at (320, 160) -> (x=15..24, y=7..12)
	_paint_carpet(layer0_floor, s_lib, Rect2i(15, 7, 10, 6), 23, 0)

	# =========================================================================
	# LAYER 1: Warm Library Perimeter Walls & Upper Frieze
	# =========================================================================
	for x in range(40):
		if s_floor >= 0:
			layer1_walls.set_cell(Vector2i(x, 0), s_floor, Vector2i(12, 13))
			layer1_walls.set_cell(Vector2i(x, 1), s_floor, Vector2i(1, 7) if x % 2 == 0 else Vector2i(2, 7))
			layer1_walls.set_cell(Vector2i(x, 2), s_floor, Vector2i(2, 7))
			layer1_walls.set_cell(Vector2i(x, 22), s_floor, Vector2i(12, 13))
		else:
			layer1_walls.set_cell(Vector2i(x, 0), s_lib, Vector2i(1, 0))
			layer1_walls.set_cell(Vector2i(x, 1), s_lib, Vector2i(1, 1))
			layer1_walls.set_cell(Vector2i(x, 2), s_lib, Vector2i(1, 2))
			layer1_walls.set_cell(Vector2i(x, 22), s_lib, Vector2i(1, 2))

	for y in range(1, 22):
		if s_floor >= 0:
			layer1_walls.set_cell(Vector2i(0, y), s_floor, Vector2i(12, 13))
			layer1_walls.set_cell(Vector2i(39, y), s_floor, Vector2i(12, 13))
		else:
			layer1_walls.set_cell(Vector2i(0, y), s_lib, Vector2i(0, 1))
			layer1_walls.set_cell(Vector2i(39, y), s_lib, Vector2i(7, 1))

	# =========================================================================
	# LAYER 2: Bookshelves, Reading Tables, Chamber Organ, Candelabras & Maps
	# =========================================================================
	var prop_layer: TileMapLayer = layer2_details if layer2_details != null else layer1_walls
	_ensure_prop_collisions(s_lib)

	# 1. Framed Maps & Classical Paintings on visible North Frieze (y=2)
	for px in [5, 11, 18, 21, 28, 34]:
		prop_layer.set_cell(Vector2i(px, 2), s_lib, Vector2i(18, 0))
	prop_layer.set_cell(Vector2i(19, 2), s_lib, Vector2i(19, 12))
	prop_layer.set_cell(Vector2i(20, 2), s_lib, Vector2i(20, 12))

	# 2. Grand Library Bookshelves flush against North Wall (x=2..14 and x=25..37 at y=3)
	for x in range(2, 15):
		var shelf_col: int = 6 + (x % 3)
		prop_layer.set_cell(Vector2i(x, 3), s_lib, Vector2i(shelf_col, 15))

	for x in range(25, 38):
		var shelf_col: int = 6 + (x % 3)
		prop_layer.set_cell(Vector2i(x, 3), s_lib, Vector2i(shelf_col, 15))

	# 3. West Scriptorium Reading Tables (Terracotta Cloth) & Library Chairs
	for ty in [8, 15]:
		prop_layer.set_cell(Vector2i(5, ty), s_lib, Vector2i(0, 9))
		prop_layer.set_cell(Vector2i(6, ty), s_lib, Vector2i(1, 9))
		prop_layer.set_cell(Vector2i(7, ty), s_lib, Vector2i(2, 9))
		prop_layer.set_cell(Vector2i(5, ty - 1), s_lib, Vector2i(0, 2))
		prop_layer.set_cell(Vector2i(7, ty - 1), s_lib, Vector2i(0, 2))
		prop_layer.set_cell(Vector2i(6, ty + 1), s_lib, Vector2i(1, 2))

	# 4. East Rhetoric Forum Reading Tables (Emerald Cloth) & Library Chairs
	for ty in [8, 15]:
		prop_layer.set_cell(Vector2i(32, ty), s_lib, Vector2i(7, 9))
		prop_layer.set_cell(Vector2i(33, ty), s_lib, Vector2i(8, 9))
		prop_layer.set_cell(Vector2i(34, ty), s_lib, Vector2i(9, 9))
		prop_layer.set_cell(Vector2i(32, ty - 1), s_lib, Vector2i(0, 2))
		prop_layer.set_cell(Vector2i(34, ty - 1), s_lib, Vector2i(0, 2))
		prop_layer.set_cell(Vector2i(33, ty + 1), s_lib, Vector2i(1, 2))

	# 5. Bard's Chamber Organ in North Center-East Alcove (x=21..22, y=3..4)
	prop_layer.set_cell(Vector2i(21, 3), s_lib, Vector2i(23, 8))
	prop_layer.set_cell(Vector2i(22, 3), s_lib, Vector2i(24, 8))
	prop_layer.set_cell(Vector2i(21, 4), s_lib, Vector2i(23, 9))
	prop_layer.set_cell(Vector2i(22, 4), s_lib, Vector2i(24, 9))

	# 6. Contiguous 2-tile Golden Candelabras & Library Plants framing Lectern, North Alcove & Portal
	for cx in [14, 25]:
		prop_layer.set_cell(Vector2i(cx, 7), s_lib, Vector2i(19, 4))
		prop_layer.set_cell(Vector2i(cx, 8), s_lib, Vector2i(19, 5))
	for cx in [16, 23]:
		prop_layer.set_cell(Vector2i(cx, 3), s_lib, Vector2i(19, 4))
		prop_layer.set_cell(Vector2i(cx, 4), s_lib, Vector2i(19, 5))
	for cx in [17, 22]:
		prop_layer.set_cell(Vector2i(cx, 19), s_lib, Vector2i(19, 4))
		prop_layer.set_cell(Vector2i(cx, 20), s_lib, Vector2i(19, 5))

	for py in [6, 12, 18]:
		prop_layer.set_cell(Vector2i(2, py), s_lib, Vector2i(16, 0))
		prop_layer.set_cell(Vector2i(37, py), s_lib, Vector2i(17, 0))

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
		Vector2i(23, 8), Vector2i(24, 8), Vector2i(23, 9), Vector2i(24, 9),
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
		Vector2i(11, 0), Vector2i(12, 0), Vector2i(13, 0),
		Vector2i(11, 1), Vector2i(12, 1), Vector2i(13, 1),
		Vector2i(11, 2), Vector2i(12, 2), Vector2i(13, 2),
		Vector2i(15, 1), Vector2i(16, 2), Vector2i(17, 2),
		Vector2i(1, 7), Vector2i(2, 7), Vector2i(12, 13)
	]:
		if not atlas.has_tile(coord):
			atlas.create_tile(coord)
			if coord in [Vector2i(1, 7), Vector2i(2, 7), Vector2i(12, 13)] and ts.get_physics_layers_count() > 0:
				var td := atlas.get_tile_data(coord, 0)
				if td:
					td.add_collision_polygon(0)
					td.set_collision_polygon_points(0, 0, PackedVector2Array([
						Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
					]))
	return 1
