extends BiomeLab
class_name LatidoSocialLab

## LatidoSocialLab.gd — "Aldea del Bienestar & Plaza Comunitaria" laboratory world.
## Inherits from BiomeLab. Viewport 640x360 px (40x23 cells of 16x16 px).
## Features:
## - Central Community Well Terminal at (320, 168)
## - 3 Resource Stations: Health (160, 100), Food (480, 100), Network (320, 260)
## - Guardian NPC GAIA-4 at (256, 176)
## - ExitPortal at (320, 320) returning to CampusHub at (160, 608)
## - 72 BPM Vital Line2D pulse wave conduits (period = 0.8333s) + traveling vitality packets
## - Ambient leaf particles, warm golden sunbeams & station sanctuary halos
## - Holographic world-space status labels

@onready var gaia4_npc: Area2D = get_node_or_null("Entities/GAIA_4_NPC")
@onready var community_well: StaticBody2D = get_node_or_null("Entities/CommunityWellTerminal")

var _anim_time: float = 0.0
var _pulse_lines: Array[Line2D] = []
var _vital_packets: Array[Node2D] = []
var _vital_paths: Array[Array] = []
var _terminal_status_label: Label = null

func _init() -> void:
	biome_id = "latidosocial"
	biome_name = "Aldea del Bienestar & Plaza Comunitaria"
	data_path = "res://data/latidosocial.json"
	default_player_spawn = Vector2(320, 240)
	room_rect = Rect2i(0, 0, 640, 360)

func _ready() -> void:
	if gaia4_npc == null:
		gaia4_npc = get_node_or_null("Entities/GAIA_4_NPC")
	if guardian_npc == null:
		guardian_npc = gaia4_npc
	if community_well == null:
		community_well = get_node_or_null("Entities/CommunityWellTerminal")
	if terminal == null:
		terminal = community_well

	super._ready()

func init_guardian_dialogue() -> void:
	if not guardian_npc and gaia4_npc:
		guardian_npc = gaia4_npc
	if not guardian_npc and has_node("Entities/GAIA_4_NPC"):
		guardian_npc = get_node("Entities/GAIA_4_NPC") as Area2D

	if not guardian_npc:
		return

	if biome_data.is_empty() and not data_path.is_empty():
		biome_data = BiomeDataLoader.load_biome_data(data_path)

	if not biome_data.is_empty():
		var lines: Array[String] = BiomeDataLoader.extract_learning_capsule(biome_data)
		var g_dict: Dictionary = biome_data.get("guardian", {})
		var g_name: String = str(g_dict.get("name", "GAIA-4 (Guardián del Bienestar Comunitario)"))
		var raw_accent = biome_data.get("accent_color", "#4CAF50")
		var hex_col: String = str(raw_accent) if raw_accent is String and not str(raw_accent).is_empty() else "#4CAF50"
		var speaker_color: Color = Color.from_string(hex_col, Color("#4CAF50"))

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
		is_completed = gs.has_fragment("latidosocial") or gs.has_fragment("misionales")
	if _terminal_status_label:
		if is_completed:
			_terminal_status_label.text = "[NEXO ESTABILIZADO]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#00E676"))
		else:
			_terminal_status_label.text = "[POZO DE LA EMPATÍA: E]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#FFD700"))

## Virtual hook called by BiomeLab to set up plaza ambient visuals
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

	# 1. Warm Sanctuary Glow Halos under the 3 Community Resource Stations & Central Well
	var station_configs: Array[Dictionary] = [
		{"pos": Vector2(160, 100), "col": Color(0.506, 0.780, 0.518, 0.28), "r": 26.0},
		{"pos": Vector2(480, 100), "col": Color(1.0, 0.718, 0.302, 0.28), "r": 26.0},
		{"pos": Vector2(320, 260), "col": Color(0.392, 0.710, 0.965, 0.28), "r": 26.0},
		{"pos": Vector2(320, 168), "col": Color(0.298, 0.686, 0.314, 0.25), "r": 42.0}
	]
	for cfg in station_configs:
		var halo := Polygon2D.new()
		halo.position = cfg["pos"]
		halo.color = cfg["col"]
		var rad: float = cfg["r"]
		var pts := PackedVector2Array()
		for i in range(16):
			var a: float = TAU * float(i) / 16.0
			pts.append(Vector2(cos(a) * rad, sin(a) * (rad * 0.68)))
		halo.polygon = pts
		fx_root.add_child(halo)

	# 2. 72 BPM Vital pulse wave conduits (Period = 60.0 / 72.0 = 0.8333s)
	# Traced from the 3 resource stations directly to Central Well (320, 168)
	var well_center := Vector2(320, 168)
	var conduit_defs: Array[Array] = [
		[Vector2(160, 100), Vector2(224, 128), well_center],
		[Vector2(480, 100), Vector2(416, 128), well_center],
		[Vector2(320, 260), Vector2(320, 214), well_center]
	]

	_pulse_lines.clear()
	_vital_packets.clear()
	_vital_paths = conduit_defs

	for path_pts in conduit_defs:
		# Outer soft emerald glow trace
		var glow_line := Line2D.new()
		glow_line.width = 5.0
		glow_line.joint_mode = Line2D.LINE_JOINT_ROUND
		glow_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		glow_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		glow_line.default_color = Color(0.298, 0.686, 0.314, 0.18)
		for p in path_pts:
			glow_line.add_point(p)
		fx_root.add_child(glow_line)
		_pulse_lines.append(glow_line)

		# Core 72 BPM vitality line
		var line := Line2D.new()
		line.width = 2.2
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.default_color = Color(0.298, 0.686, 0.314, 0.45)
		for p in path_pts:
			line.add_point(p)
		fx_root.add_child(line)
		_pulse_lines.append(line)

		# Traveling empathy energy orb along conduit
		var orb := Polygon2D.new()
		orb.color = Color(0.65, 1.0, 0.72, 0.92)
		orb.polygon = PackedVector2Array([
			Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)
		])
		fx_root.add_child(orb)
		_vital_packets.append(orb)

	# 3. Concentric vitality rings beneath Central Well and Station Nodes
	for r in [28.0, 42.0]:
		var ring := Line2D.new()
		ring.position = well_center
		ring.width = 1.6
		ring.closed = true
		ring.default_color = Color(0.298, 0.686, 0.314, 0.35)
		for i in range(16):
			var angle: float = TAU * float(i) / 16.0
			ring.add_point(Vector2(cos(angle) * r, sin(angle) * (r * 0.7)))
		fx_root.add_child(ring)
		_pulse_lines.append(ring)

	for st_pos in [Vector2(160, 100), Vector2(480, 100), Vector2(320, 260)]:
		var s_ring := Line2D.new()
		s_ring.position = st_pos
		s_ring.width = 1.5
		s_ring.closed = true
		s_ring.default_color = Color(0.45, 0.88, 0.52, 0.35)
		for i in range(12):
			var angle: float = TAU * float(i) / 12.0
			s_ring.add_point(Vector2(cos(angle) * 20.0, sin(angle) * 14.0))
		fx_root.add_child(s_ring)
		_pulse_lines.append(s_ring)

	# 4. Ambient leaf particles drifting gently across the plaza
	var leaves := CPUParticles2D.new()
	leaves.name = "DriftingLeaves"
	leaves.z_index = 2
	leaves.position = Vector2(320, 180)
	leaves.amount = 26
	leaves.lifetime = 4.5
	leaves.preprocess = 2.0
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(280, 140)
	leaves.direction = Vector2(0.4, 1.0)
	leaves.spread = 25.0
	leaves.gravity = Vector2(4, 12)
	leaves.initial_velocity_min = 10.0
	leaves.initial_velocity_max = 24.0
	leaves.scale_amount_min = 1.5
	leaves.scale_amount_max = 2.5
	leaves.color = Color(0.506, 0.780, 0.518, 0.75)
	fx_root.add_child(leaves)

	# 5. Twin Warm Descending Sunbeams across the village plaza
	var rays := Polygon2D.new()
	rays.name = "Sunbeams"
	rays.z_index = 2
	rays.color = Color(1.0, 0.98, 0.78, 0.07)
	rays.polygon = PackedVector2Array([
		Vector2(90, 0), Vector2(175, 0), Vector2(345, 360), Vector2(260, 360)
	])
	fx_root.add_child(rays)

	var rays2 := Polygon2D.new()
	rays2.name = "SunbeamsEast"
	rays2.z_index = 2
	rays2.color = Color(1.0, 0.98, 0.78, 0.05)
	rays2.polygon = PackedVector2Array([
		Vector2(380, 0), Vector2(450, 0), Vector2(580, 360), Vector2(510, 360)
	])
	fx_root.add_child(rays2)

	# 6. Holographic world-space labels
	if has_node("StationLabels"):
		get_node("StationLabels").queue_free()
	var labels_root := Node2D.new()
	labels_root.name = "StationLabels"
	labels_root.z_index = 6
	add_child(labels_root)

	_create_world_label(labels_root, Vector2(320, 108), "ALDEA DEL BIENESTAR & PLAZA COMUNITARIA", Color("#B9F6CA"))
	_terminal_status_label = _create_world_label(labels_root, Vector2(320, 120), "[POZO DE LA EMPATÍA: E]", Color("#FFD700"))
	_create_world_label(labels_root, Vector2(148, 84), "CENTRO DE SALUD EMOCIONAL", Color("#A5D6A7"))
	_create_world_label(labels_root, Vector2(492, 84), "COMEDOR COMUNITARIO SOLIDARIO", Color("#FFE082"))
	_create_world_label(labels_root, Vector2(320, 276), "RED DE ESCUCHA Y APOYO MUTUO", Color("#90CAF9"))
	_create_world_label(labels_root, Vector2(246, 198), "GAIA-4 (BIENESTAR)", Color("#B9F6CA"))
	_create_world_label(labels_root, Vector2(320, 344), "PORTAL AL CAMPUS", Color("#B9F6CA"))

func _process(delta: float) -> void:
	_anim_time += delta

	# 72 BPM Heartbeat Vital Sign Formula (1.2 Hz -> Period = 0.8333s)
	var beat_phase: float = fmod(_anim_time, 0.8333) / 0.8333
	var systolic_pulse: float = pow(maxf(0.0, sin(beat_phase * PI)), 4.0)
	var dynamic_alpha: float = 0.25 + 0.55 * systolic_pulse

	for line in _pulse_lines:
		if is_instance_valid(line):
			line.default_color.a = dynamic_alpha
			line.width = 2.0 + systolic_pulse * 1.5

	for i in range(_vital_packets.size()):
		var orb := _vital_packets[i]
		if not is_instance_valid(orb) or i >= _vital_paths.size():
			continue
		var pts: Array = _vital_paths[i]
		var t: float = fmod(_anim_time * 0.75 + float(i) * 0.33, 1.0)
		orb.position = _sample_path(pts, t)
		var s: float = 0.9 + 0.35 * systolic_pulse
		orb.scale = Vector2(s, s)

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

## Populates the 16x16 village plaza: lush flower meadows, bordered dirt courtyards,
## cobblestone avenues, NW/NE village cottages, perimeter fences, trees, apiary & gardens.
func populate_tilemaps() -> void:
	if not layer0_floor or not layer1_walls:
		return

	layer0_floor.clear()
	layer1_walls.clear()
	if layer2_details:
		layer2_details.clear()

	var s_town: int = 0

	# =========================================================================
	# LAYER 0: Lush Meadow Grass, Wildflowers, Dirt Courtyards & Cobble Plazas
	# =========================================================================
	for x in range(40):
		for y in range(23):
			var g_tile := Vector2i(0, 0)
			var h: int = (x * 17 + y * 31) % 23
			if h == 0 or h == 7:
				g_tile = Vector2i(1, 0) # Grass tufts
			elif h == 3 or h == 14:
				g_tile = Vector2i(2, 0) # Wildflowers
			layer0_floor.set_cell(Vector2i(x, y), s_town, g_tile)

	# 1. Central Village Plaza around CommunityWellTerminal (320, 168) -> x=14..25, y=8..13
	_paint_dirt_plaza(layer0_floor, s_town, Rect2i(14, 8, 12, 6), true)

	# 2. NW Courtyard ("Centro de Salud Emocional" at 160, 100) -> x=6..13, y=5..8
	_paint_dirt_plaza(layer0_floor, s_town, Rect2i(6, 5, 8, 4), true)

	# 3. NE Courtyard ("Comedor Comunitario Solidario" at 480, 100) -> x=26..33, y=5..8
	_paint_dirt_plaza(layer0_floor, s_town, Rect2i(26, 5, 8, 4), true)

	# 4. South Promenade ("Red de Escucha y Apoyo Mutuo" at 320, 260 & ExitPortal at 320, 320) -> x=16..23, y=13..21
	_paint_dirt_plaza(layer0_floor, s_town, Rect2i(16, 13, 8, 9), true)

	# 5. Connecting Cobblestone & Dirt Walkways from NW & NE Courtyards to Central Plaza
	for x in range(11, 16):
		layer0_floor.set_cell(Vector2i(x, 6), s_town, Vector2i(1, 1))
		layer0_floor.set_cell(Vector2i(x, 7), s_town, Vector2i(7, 3))
		layer0_floor.set_cell(Vector2i(x, 8), s_town, Vector2i(7, 3))
		layer0_floor.set_cell(Vector2i(x, 9), s_town, Vector2i(1, 3))
	for x in range(24, 29):
		layer0_floor.set_cell(Vector2i(x, 6), s_town, Vector2i(1, 1))
		layer0_floor.set_cell(Vector2i(x, 7), s_town, Vector2i(7, 3))
		layer0_floor.set_cell(Vector2i(x, 8), s_town, Vector2i(7, 3))
		layer0_floor.set_cell(Vector2i(x, 9), s_town, Vector2i(1, 3))
	# Seamless cobblestone throat between Central Well Plaza and South Promenade
	for x in range(17, 23):
		layer0_floor.set_cell(Vector2i(x, 12), s_town, Vector2i(7, 3))
		layer0_floor.set_cell(Vector2i(x, 13), s_town, Vector2i(7, 3))
		layer0_floor.set_cell(Vector2i(x, 14), s_town, Vector2i(7, 3))

	# 6. SW Apiary Garden Patch (x=4..9, y=13..17) & SE Orchard Patch (x=30..35, y=13..17)
	_paint_dirt_plaza(layer0_floor, s_town, Rect2i(4, 13, 6, 5), false)
	_paint_dirt_plaza(layer0_floor, s_town, Rect2i(30, 13, 6, 5), false)

	# =========================================================================
	# LAYER 1: Perimeter Forest Canopy, Wooden Fences & Village Cottages
	# =========================================================================
	# Top Forest Canopy (y=0..1 across x=0..39)
	for x in range(40):
		var tree_col: int = 4 if (x % 3 != 0) else 3 # Alternate emerald pine (4) and autumn tree (3)
		layer1_walls.set_cell(Vector2i(x, 0), s_town, Vector2i(tree_col, 0))
		layer1_walls.set_cell(Vector2i(x, 1), s_town, Vector2i(tree_col, 1))

	# North Fence line at y=2 (with openings where the 2 cottages stand at x=7..12 and x=27..32)
	for x in range(1, 39):
		if (x >= 7 and x <= 12) or (x >= 27 and x <= 32):
			continue
		if x == 1 or x == 13 or x == 25 or x == 33:
			layer1_walls.set_cell(Vector2i(x, 2), s_town, Vector2i(8, 6)) # Fence left post
		elif x == 6 or x == 24 or x == 26 or x == 38:
			layer1_walls.set_cell(Vector2i(x, 2), s_town, Vector2i(10, 6)) # Fence right post
		else:
			layer1_walls.set_cell(Vector2i(x, 2), s_town, Vector2i(9, 6)) # Fence mid rail

	# NW Cottage: "Centro de Salud Emocional" (Blue-slate roof cottage at x=7..12, y=2..4)
	_build_village_cottage(layer1_walls, s_town, 7, 2, 0)

	# NE Cottage: "Comedor Comunitario Solidario" (Terracotta-red roof cottage at x=27..32, y=2..4)
	_build_village_cottage(layer1_walls, s_town, 27, 2, 4)

	# Left & Right Vertical Wooden Fences (x=0 and x=39, y=2..21)
	for y in range(2, 22):
		var v_row: int = 4
		if y == 2:
			v_row = 3
		elif y == 21:
			v_row = 5
		layer1_walls.set_cell(Vector2i(0, y), s_town, Vector2i(11, v_row))
		layer1_walls.set_cell(Vector2i(39, y), s_town, Vector2i(11, v_row))

	# Bottom Wooden Fence at y=22 with Stone Arch Pillars flanking South Portal (x=18..21)
	for x in range(40):
		if x == 0 or x == 39:
			layer1_walls.set_cell(Vector2i(x, 22), s_town, Vector2i(5, 0))
		elif x == 17:
			layer1_walls.set_cell(Vector2i(x, 22), s_town, Vector2i(10, 6))
		elif x == 22:
			layer1_walls.set_cell(Vector2i(x, 22), s_town, Vector2i(8, 6))
		elif x >= 18 and x <= 21:
			layer1_walls.set_cell(Vector2i(x, 22), s_town, Vector2i(9, 6))
		elif x == 1:
			layer1_walls.set_cell(Vector2i(x, 22), s_town, Vector2i(8, 6))
		elif x == 38:
			layer1_walls.set_cell(Vector2i(x, 22), s_town, Vector2i(10, 6))
		else:
			layer1_walls.set_cell(Vector2i(x, 22), s_town, Vector2i(9, 6))

	# =========================================================================
	# LAYER 2: Village Details, Corner Groves, Apiary, Orchard & Station Props
	# =========================================================================
	var prop_layer: TileMapLayer = layer2_details if layer2_details != null else layer1_walls

	# 1. Corner Woodland Groves (NW, NE, SW, SE outer corners)
	for tx in [2, 4, 35, 37]:
		var t_col: int = 3 if (tx % 2 == 0) else 4
		prop_layer.set_cell(Vector2i(tx, 3), s_town, Vector2i(t_col, 0))
		prop_layer.set_cell(Vector2i(tx, 4), s_town, Vector2i(t_col, 1))
	for tx in [2, 37]:
		var t_col: int = 4 if tx < 20 else 3
		prop_layer.set_cell(Vector2i(tx, 19), s_town, Vector2i(t_col, 0))
		prop_layer.set_cell(Vector2i(tx, 20), s_town, Vector2i(t_col, 1))

	# Decorative shrubs & saplings along outer margins
	for by in [6, 10, 14, 18]:
		prop_layer.set_cell(Vector2i(1, by), s_town, Vector2i(5, 0))
		prop_layer.set_cell(Vector2i(38, by), s_town, Vector2i(5, 0))
	prop_layer.set_cell(Vector2i(2, 8), s_town, Vector2i(4, 2))
	prop_layer.set_cell(Vector2i(37, 8), s_town, Vector2i(3, 2))
	prop_layer.set_cell(Vector2i(3, 20), s_town, Vector2i(5, 2)) # Red mushrooms
	prop_layer.set_cell(Vector2i(36, 20), s_town, Vector2i(5, 2))

	# 2. Central North Garden Divider (x=16..23, y=3..4) between the two cottages
	for gx in range(16, 24):
		prop_layer.set_cell(Vector2i(gx, 3), s_town, Vector2i(5, 0) if gx in [16, 23] else Vector2i(5, 1))
	prop_layer.set_cell(Vector2i(19, 3), s_town, Vector2i(10, 7)) # Central beehive
	prop_layer.set_cell(Vector2i(20, 3), s_town, Vector2i(10, 7))

	# 3. NW Station Props (Centro de Salud Emocional around 160, 100)
	prop_layer.set_cell(Vector2i(6, 7), s_town, Vector2i(11, 6))  # Wooden signpost
	prop_layer.set_cell(Vector2i(13, 7), s_town, Vector2i(11, 10)) # Fresh water bucket
	prop_layer.set_cell(Vector2i(5, 6), s_town, Vector2i(5, 1))   # Medicinal herb sprouts
	prop_layer.set_cell(Vector2i(5, 7), s_town, Vector2i(5, 1))

	# 4. NE Station Props (Comedor Comunitario Solidario around 480, 100)
	prop_layer.set_cell(Vector2i(26, 7), s_town, Vector2i(11, 6)) # Wooden signpost
	prop_layer.set_cell(Vector2i(33, 7), s_town, Vector2i(11, 8)) # Supply barrel
	prop_layer.set_cell(Vector2i(34, 6), s_town, Vector2i(10, 8)) # Stacked firewood logs
	prop_layer.set_cell(Vector2i(34, 7), s_town, Vector2i(9, 4))  # Community wheelbarrow

	# 5. SW Community Apiary & Herb Sanctuary (x=4..9, y=13..17)
	# Top & bottom fence rails with open east entry
	prop_layer.set_cell(Vector2i(4, 13), s_town, Vector2i(8, 3))
	for fx in range(5, 9):
		prop_layer.set_cell(Vector2i(fx, 13), s_town, Vector2i(9, 3))
	prop_layer.set_cell(Vector2i(9, 13), s_town, Vector2i(10, 3))
	for fy in range(14, 17):
		prop_layer.set_cell(Vector2i(4, fy), s_town, Vector2i(8, 4))
	prop_layer.set_cell(Vector2i(4, 17), s_town, Vector2i(8, 5))
	for fx in range(5, 9):
		prop_layer.set_cell(Vector2i(fx, 17), s_town, Vector2i(9, 5))
	prop_layer.set_cell(Vector2i(9, 17), s_town, Vector2i(10, 5))
	# Beehives & sprouts inside SW Apiary
	prop_layer.set_cell(Vector2i(5, 14), s_town, Vector2i(10, 7))
	prop_layer.set_cell(Vector2i(7, 14), s_town, Vector2i(10, 7))
	prop_layer.set_cell(Vector2i(6, 15), s_town, Vector2i(5, 1))
	prop_layer.set_cell(Vector2i(8, 15), s_town, Vector2i(5, 1))
	prop_layer.set_cell(Vector2i(5, 16), s_town, Vector2i(5, 2))

	# 6. SE Community Harvest & Mutual Aid Depot (x=30..35, y=13..17)
	prop_layer.set_cell(Vector2i(30, 13), s_town, Vector2i(8, 3))
	for fx in range(31, 35):
		prop_layer.set_cell(Vector2i(fx, 13), s_town, Vector2i(9, 3))
	prop_layer.set_cell(Vector2i(35, 13), s_town, Vector2i(10, 3))
	for fy in range(14, 17):
		prop_layer.set_cell(Vector2i(35, fy), s_town, Vector2i(10, 4))
	prop_layer.set_cell(Vector2i(30, 17), s_town, Vector2i(8, 5))
	for fx in range(31, 35):
		prop_layer.set_cell(Vector2i(fx, 17), s_town, Vector2i(9, 5))
	prop_layer.set_cell(Vector2i(35, 17), s_town, Vector2i(10, 5))
	# Barrels, logs, wheelbarrow & sprouts inside SE Depot
	prop_layer.set_cell(Vector2i(34, 14), s_town, Vector2i(11, 8))
	prop_layer.set_cell(Vector2i(32, 14), s_town, Vector2i(10, 8))
	prop_layer.set_cell(Vector2i(33, 16), s_town, Vector2i(9, 4))
	prop_layer.set_cell(Vector2i(31, 15), s_town, Vector2i(5, 1))
	prop_layer.set_cell(Vector2i(31, 16), s_town, Vector2i(5, 1))

	# 7. South Mutual Support Station & Portal Framing Props
	prop_layer.set_cell(Vector2i(15, 16), s_town, Vector2i(11, 6)) # Signpost West of South Station
	prop_layer.set_cell(Vector2i(24, 16), s_town, Vector2i(11, 8)) # Barrel East of South Station
	prop_layer.set_cell(Vector2i(16, 20), s_town, Vector2i(5, 0))  # Shrub framing ExitPortal West
	prop_layer.set_cell(Vector2i(23, 20), s_town, Vector2i(5, 0))  # Shrub framing ExitPortal East

func _paint_dirt_plaza(layer: TileMapLayer, source_id: int, rect: Rect2i, cobble_inner: bool) -> void:
	var x0: int = rect.position.x
	var y0: int = rect.position.y
	var x1: int = rect.end.x - 1
	var y1: int = rect.end.y - 1
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var cx: int = 1
			if x == x0:
				cx = 0
			elif x == x1:
				cx = 2
			var cy: int = 2
			if y == y0:
				cy = 1
			elif y == y1:
				cy = 3
			var tile := Vector2i(cx, cy)
			if cobble_inner and cx == 1 and cy == 2:
				tile = Vector2i(7, 3) # Warm cobblestone mosaic center
			layer.set_cell(Vector2i(x, y), source_id, tile)

func _build_village_cottage(layer: TileMapLayer, source_id: int, x0: int, y0: int, base_col: int) -> void:
	# 6-tile wide x 3-tile tall cottage using Tiny Town cols base_col..base_col+3, rows 4..7
	# Row y0: Upper pitched roof + gable
	layer.set_cell(Vector2i(x0 + 0, y0), source_id, Vector2i(base_col + 0, 4))
	layer.set_cell(Vector2i(x0 + 1, y0), source_id, Vector2i(base_col + 1, 4))
	layer.set_cell(Vector2i(x0 + 2, y0), source_id, Vector2i(base_col + 1, 4))
	layer.set_cell(Vector2i(x0 + 3, y0), source_id, Vector2i(base_col + 3, 4))
	layer.set_cell(Vector2i(x0 + 4, y0), source_id, Vector2i(base_col + 1, 4))
	layer.set_cell(Vector2i(x0 + 5, y0), source_id, Vector2i(base_col + 2, 4))
	# Row y0 + 1: Lower roof eaves + gable arch
	layer.set_cell(Vector2i(x0 + 0, y0 + 1), source_id, Vector2i(base_col + 0, 5))
	layer.set_cell(Vector2i(x0 + 1, y0 + 1), source_id, Vector2i(base_col + 1, 5))
	layer.set_cell(Vector2i(x0 + 2, y0 + 1), source_id, Vector2i(base_col + 1, 5))
	layer.set_cell(Vector2i(x0 + 3, y0 + 1), source_id, Vector2i(base_col + 3, 5))
	layer.set_cell(Vector2i(x0 + 4, y0 + 1), source_id, Vector2i(base_col + 1, 5))
	layer.set_cell(Vector2i(x0 + 5, y0 + 1), source_id, Vector2i(base_col + 2, 5))
	# Row y0 + 2: Timber/stone facade with windows and entrance doors
	layer.set_cell(Vector2i(x0 + 0, y0 + 2), source_id, Vector2i(base_col + 0, 6))
	layer.set_cell(Vector2i(x0 + 1, y0 + 2), source_id, Vector2i(base_col + 0, 7)) # Window
	layer.set_cell(Vector2i(x0 + 2, y0 + 2), source_id, Vector2i(base_col + 1, 6))
	layer.set_cell(Vector2i(x0 + 3, y0 + 2), source_id, Vector2i(base_col + 1, 7)) # Entrance Door
	layer.set_cell(Vector2i(x0 + 4, y0 + 2), source_id, Vector2i(base_col + 0, 7)) # Window
	layer.set_cell(Vector2i(x0 + 5, y0 + 2), source_id, Vector2i(base_col + 2, 6))
