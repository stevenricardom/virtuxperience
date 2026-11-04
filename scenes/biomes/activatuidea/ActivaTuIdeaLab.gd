extends BiomeLab
class_name ActivaTuIdeaLab

## ActivaTuIdeaLab.gd — "Fábrica de Innovación & Taller de Prototipado" laboratory world.
## Inherits from BiomeLab.
## Room size: 640x360 px (40x23 cells of 16x16 px).
## Floor, walls, and industrial assembly lines built with 16x16 tiles (activatuidea_tileset.tres).
## Features:
## - Central Prototype Workbench at (320, 160)
## - Guardian NPC FORGE-X at (256, 176)
## - ExitPortal at (320, 320) returning to CampusHub at (1120, 608)
## - Thermal energy conduits (Line2D) with pulsing orange glow (#FF8C00) & traveling thermal packets
## - Octagonal floor rings under workbench and exit portal
## - Industrial spark / ember particles (CPUParticles2D)
## - Holographic world-space engineering labels

@onready var forge_x_npc: Area2D = get_node_or_null("Entities/FORGE_X_NPC")
@onready var prototype_workbench: StaticBody2D = get_node_or_null("Entities/PrototypeWorkbench")

var _anim_time: float = 0.0
var _thermal_lines: Array[Line2D] = []
var _thermal_packets: Array[Node2D] = []
var _thermal_paths: Array[Array] = []
var _terminal_status_label: Label = null

func _init() -> void:
	biome_id = "activatuidea"
	biome_name = "Fábrica de Innovación & Taller de Prototipado"
	data_path = "res://data/activatuidea.json"
	default_player_spawn = Vector2(320, 240)
	room_rect = Rect2i(0, 0, 640, 360)

func _ready() -> void:
	if forge_x_npc == null:
		forge_x_npc = get_node_or_null("Entities/FORGE_X_NPC")
	if guardian_npc == null:
		guardian_npc = forge_x_npc
	if prototype_workbench == null:
		prototype_workbench = get_node_or_null("Entities/PrototypeWorkbench")
	if terminal == null:
		terminal = prototype_workbench

	super._ready()

func init_guardian_dialogue() -> void:
	if not guardian_npc and forge_x_npc:
		guardian_npc = forge_x_npc
	if not guardian_npc and has_node("Entities/FORGE_X_NPC"):
		guardian_npc = get_node("Entities/FORGE_X_NPC") as Area2D

	if not guardian_npc:
		return

	if biome_data.is_empty() and not data_path.is_empty():
		biome_data = BiomeDataLoader.load_biome_data(data_path)

	if not biome_data.is_empty():
		var lines: Array[String] = BiomeDataLoader.extract_learning_capsule(biome_data)
		var g_dict: Dictionary = biome_data.get("guardian", {})
		var g_name: String = str(g_dict.get("name", "FORGE-X (Ingeniero Jefe de Prototipos)"))
		var raw_accent = biome_data.get("accent_color", "#FF8C00")
		var hex_col: String = str(raw_accent) if raw_accent is String and not str(raw_accent).is_empty() else "#FF8C00"
		var speaker_color: Color = Color.from_string(hex_col, Color("#FF8C00"))

		guardian_npc.set("dialogue_lines", lines)
		guardian_npc.set("npc_name", g_name)
		guardian_npc.set("speaker_color", speaker_color)
	else:
		super.init_guardian_dialogue()

	# Ensure FORGE-X sprite uses industrial mech unit texture
	var unit_tex = load("res://assets/neuromath/scifi_rts/PNG/Default size/Unit/scifiUnit_14.png") as Texture2D
	if guardian_npc and guardian_npc.has_node("NPCSprite") and unit_tex:
		var spr = guardian_npc.get_node("NPCSprite") as Sprite2D
		if spr:
			spr.texture = unit_tex

## Virtual hook called by BiomeLab to refresh completion status
func refresh_completion_state() -> void:
	var gs := _get_game_state()
	var is_completed: bool = false
	if gs and gs.has_method("has_fragment"):
		is_completed = gs.has_fragment("activatuidea")
	if _terminal_status_label:
		if is_completed:
			_terminal_status_label.text = "[NEXO ESTABILIZADO]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#00E676"))
		else:
			_terminal_status_label.text = "[MESA DE PROTOTIPADO: E]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#FFD700"))

## Virtual hook called by BiomeLab to set up factory ambient visuals
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

	# 1. Warm Amber Forge Halos under Assembly Lines & CAD Stations
	for hpos in [Vector2(120, 136), Vector2(520, 136), Vector2(120, 232), Vector2(520, 232)]:
		var halo := Polygon2D.new()
		halo.position = hpos
		halo.color = Color(1.0, 0.55, 0.0, 0.20)
		var pts := PackedVector2Array()
		for i in range(12):
			var a: float = TAU * float(i) / 12.0
			pts.append(Vector2(cos(a) * 28.0, sin(a) * 18.0))
		halo.polygon = pts
		fx_root.add_child(halo)

	# 2. Thermal energy conduit lines across the factory floor + traveling thermal packets
	var conduit_paths: Array[Array] = [
		[Vector2(144, 128), Vector2(200, 144), Vector2(280, 155), Vector2(300, 160)],
		[Vector2(496, 128), Vector2(440, 144), Vector2(360, 155), Vector2(340, 160)],
		[Vector2(144, 240), Vector2(210, 216), Vector2(290, 188), Vector2(310, 175)],
		[Vector2(496, 240), Vector2(430, 216), Vector2(350, 188), Vector2(330, 175)],
		[Vector2(320, 304), Vector2(320, 236), Vector2(320, 185)]
	]

	_thermal_lines.clear()
	_thermal_packets.clear()
	_thermal_paths = conduit_paths

	for pts in conduit_paths:
		var glow_line := Line2D.new()
		glow_line.width = 5.0
		glow_line.joint_mode = Line2D.LINE_JOINT_ROUND
		glow_line.default_color = Color(1.0, 0.45, 0.0, 0.20)
		for p in pts:
			glow_line.add_point(p)
		fx_root.add_child(glow_line)
		_thermal_lines.append(glow_line)

		var line := Line2D.new()
		line.width = 2.5
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.default_color = Color(1.0, 0.549, 0.0, 0.55)
		for p in pts:
			line.add_point(p)
		fx_root.add_child(line)
		_thermal_lines.append(line)

		var pkt := Polygon2D.new()
		pkt.color = Color(1.0, 0.85, 0.35, 0.95)
		pkt.polygon = PackedVector2Array([
			Vector2(-3.5, -3.5), Vector2(3.5, -3.5), Vector2(3.5, 3.5), Vector2(-3.5, 3.5)
		])
		fx_root.add_child(pkt)
		_thermal_packets.append(pkt)

	# 3. Industrial Spark / Ember particles
	var particles := CPUParticles2D.new()
	particles.name = "IndustrialSparks"
	particles.z_index = 2
	particles.position = Vector2(320, 180)
	particles.amount = 26
	particles.lifetime = 3.0
	particles.preprocess = 1.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(280, 140)
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 45.0
	particles.gravity = Vector2(0, 14)
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 24.0
	particles.scale_amount_min = 1.2
	particles.scale_amount_max = 2.2
	particles.color = Color(1.0, 0.75, 0.2, 0.78)
	fx_root.add_child(particles)

	# 4. Octagonal floor rings under Workbench and Exit Portal
	for center_pos in [Vector2(320, 164), Vector2(320, 320), Vector2(120, 128), Vector2(520, 128)]:
		var ring := Line2D.new()
		ring.position = center_pos
		ring.width = 2.0
		ring.closed = true
		ring.default_color = Color(1.0, 0.549, 0.0, 0.45)
		var radius: float = 36.0 if center_pos.x == 320 and center_pos.y < 200 else 22.0
		for i in range(8): # Strict octagonal geometry
			var angle: float = TAU * float(i) / 8.0
			ring.add_point(Vector2(cos(angle) * radius, sin(angle) * (radius * 0.75)))
		fx_root.add_child(ring)
		_thermal_lines.append(ring)

	# 5. Holographic world-space engineering labels (cleanly spaced)
	if has_node("StationLabels"):
		get_node("StationLabels").queue_free()
	var labels_root := Node2D.new()
	labels_root.name = "StationLabels"
	labels_root.z_index = 6
	add_child(labels_root)

	_create_world_label(labels_root, Vector2(320, 96), "FÁBRICA DE INNOVACIÓN & PROTOTIPADO", Color("#FF8C00"))
	_terminal_status_label = _create_world_label(labels_root, Vector2(320, 108), "[MESA DE PROTOTIPADO: E]", Color("#FFD700"))
	_create_world_label(labels_root, Vector2(108, 78), "LÍNEA DE ENSAMBLAJE AUTOMATIZADA", Color("#FFB74D"))
	_create_world_label(labels_root, Vector2(532, 78), "ESTACIÓN CAD & SIMULACIÓN 3D", Color("#FFB74D"))
	_create_world_label(labels_root, Vector2(244, 198), "FORGE-X (INGENIERO JEFE)", Color("#FF8C00"))
	_create_world_label(labels_root, Vector2(320, 344), "PORTAL AL CAMPUS", Color("#FF8C00"))

func _process(delta: float) -> void:
	_anim_time += delta

	# Pulsing alpha for thermal lines
	for i in range(_thermal_lines.size()):
		var line := _thermal_lines[i]
		if is_instance_valid(line):
			var pulse := 0.42 + 0.28 * sin(_anim_time * 2.8 + float(i) * 0.9)
			line.default_color.a = pulse

	# Animate thermal packets along conduits
	for i in range(_thermal_packets.size()):
		var pkt := _thermal_packets[i]
		if not is_instance_valid(pkt) or i >= _thermal_paths.size():
			continue
		var pts: Array = _thermal_paths[i]
		var t: float = fmod(_anim_time * 0.72 + float(i) * 0.24, 1.0)
		pkt.position = _sample_path(pts, t)
		pkt.modulate.a = 0.65 + 0.35 * sin(_anim_time * 6.0 + float(i))

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

## Populates 16x16 factory floor, industrial steel bulkhead walls, overhead pipelines,
## crane gantries, assembly lines, CAD stations, plasma coils & hazard stripes
func populate_tilemaps() -> void:
	if not layer0_floor or not layer1_walls:
		return

	layer0_floor.clear()
	layer1_walls.clear()
	if layer2_details:
		layer2_details.clear()

	var s_fac: int = 0

	# =========================================================================
	# LAYER 0: Industrial Steel Grid Floor + Ribbed Walkways + Metallic Platforms
	# =========================================================================
	for x in range(40):
		for y in range(23):
			var tile_pos := Vector2i(0, 0)
			if x == 0 or x == 39 or y <= 2 or y == 22:
				tile_pos = Vector2i(3, 0) if (x + y) % 3 != 0 else Vector2i(8, 2)
			else:
				tile_pos = Vector2i(0, 0) if (x + y) % 2 == 0 else Vector2i(1, 0)
			layer0_floor.set_cell(Vector2i(x, y), s_fac, tile_pos)

	# Ribbed Industrial Tech Walkways (2, 0) connecting West & East Assembly Wings to Central Workbench
	for x in range(10, 30):
		for y in range(10, 12):
			layer0_floor.set_cell(Vector2i(x, y), s_fac, Vector2i(2, 0))
		for y in range(16, 18):
			layer0_floor.set_cell(Vector2i(x, y), s_fac, Vector2i(2, 0))

	# West & East Assembly Sector Metallic Platforms (x=4..10, y=6..18 and x=29..35, y=6..18)
	_paint_factory_platform(layer0_floor, s_fac, Rect2i(4, 6, 7, 13))
	_paint_factory_platform(layer0_floor, s_fac, Rect2i(29, 6, 7, 13))

	# Central Corridor Steel Grating (Exit Portal to Prototype Workbench: x=18..21, y=12..21)
	for y in range(12, 21):
		for x in range(18, 22):
			layer0_floor.set_cell(Vector2i(x, y), s_fac, Vector2i(10, 3))

	# Central Prototyping Dais Metallic Platform around Workbench (x=15..24, y=7..12)
	_paint_factory_platform(layer0_floor, s_fac, Rect2i(15, 7, 10, 6))

	# =========================================================================
	# LAYER 1: Industrial Steel Bulkhead Walls, Overhead Steam Pipelines & Doors
	# =========================================================================
	layer1_walls.set_cell(Vector2i(0, 0), s_fac, Vector2i(9, 0))
	layer1_walls.set_cell(Vector2i(39, 0), s_fac, Vector2i(11, 0))
	layer1_walls.set_cell(Vector2i(0, 22), s_fac, Vector2i(9, 2))
	layer1_walls.set_cell(Vector2i(39, 22), s_fac, Vector2i(11, 2))

	for x in range(1, 39):
		# Row 0: Upper bulkhead
		layer1_walls.set_cell(Vector2i(x, 0), s_fac, Vector2i(10, 3))
		# Row 1: Overhead Thermal Pipeline running across the factory frieze
		var pipe_tile := Vector2i(10, 6)
		if x == 1:
			pipe_tile = Vector2i(6, 6)
		elif x == 38:
			pipe_tile = Vector2i(11, 6)
		elif x in [7, 15, 24, 32]:
			pipe_tile = Vector2i(7, 6) # Amber pipe coupling
		elif x in [11, 19, 20, 28]:
			pipe_tile = Vector2i(8, 6) # T-junction feeding downward
		elif x in [13, 26]:
			pipe_tile = Vector2i(10, 7) # Valve on pipe
		layer1_walls.set_cell(Vector2i(x, 1), s_fac, pipe_tile)

		# Row 2: Lower bulkhead wall with factory doors, reactor vents, and pipe intakes (visible below HUD)
		var lower_wall := Vector2i(10, 3) if x % 2 == 0 else Vector2i(11, 3)
		if x in [11, 19, 20, 28]:
			lower_wall = Vector2i(8, 7) # Pipe intake nozzle
		elif x == 5 or x == 33:
			lower_wall = Vector2i(10, 4) # Double bulkhead door left
		elif x == 6 or x == 34:
			lower_wall = Vector2i(11, 4) # Double bulkhead door right
		elif x in [14, 24]:
			lower_wall = Vector2i(10, 5) # Reactor vent left
		elif x in [15, 25]:
			lower_wall = Vector2i(11, 5) # Reactor vent right
		elif x in [9, 17, 22, 30]:
			lower_wall = Vector2i(9, 4) # Access locker / panel
		layer1_walls.set_cell(Vector2i(x, 2), s_fac, lower_wall)

		# Row 22: Bottom metallic border wall with hazard stripes around portal
		var bot_wall := Vector2i(10, 2)
		if x == 17:
			bot_wall = Vector2i(9, 9)
		elif x in [18, 19, 20, 21]:
			bot_wall = Vector2i(10, 9)
		elif x == 22:
			bot_wall = Vector2i(11, 9)
		layer1_walls.set_cell(Vector2i(x, 22), s_fac, bot_wall)

	for y in range(1, 22):
		layer1_walls.set_cell(Vector2i(0, y), s_fac, Vector2i(9, 1))
		layer1_walls.set_cell(Vector2i(39, y), s_fac, Vector2i(11, 1))

	# =========================================================================
	# LAYER 2: Conveyor Belts, Industrial Machinery, Crane Gantries & Crates
	# =========================================================================
	var prop_layer: TileMapLayer = layer2_details if layer2_details != null else layer1_walls
	_ensure_prop_collisions(s_fac)

	# 1. Yellow Overhead Crane Gantry Columns on West & East Flanks (x=2 and x=37, y=7..9 and y=14..16)
	for gy in [7, 14]:
		prop_layer.set_cell(Vector2i(2, gy), s_fac, Vector2i(7, 8))
		prop_layer.set_cell(Vector2i(2, gy + 1), s_fac, Vector2i(7, 9))
		prop_layer.set_cell(Vector2i(2, gy + 2), s_fac, Vector2i(7, 10))
		prop_layer.set_cell(Vector2i(37, gy), s_fac, Vector2i(7, 8))
		prop_layer.set_cell(Vector2i(37, gy + 1), s_fac, Vector2i(7, 9))
		prop_layer.set_cell(Vector2i(37, gy + 2), s_fac, Vector2i(7, 10))

	# 2. West Assembly Line Machinery & Conveyors (x=6..8, y=7..9 and y=14..16)
	for base_y in [7, 14]:
		prop_layer.set_cell(Vector2i(6, base_y), s_fac, Vector2i(1, 2))
		prop_layer.set_cell(Vector2i(7, base_y), s_fac, Vector2i(2, 2))
		prop_layer.set_cell(Vector2i(8, base_y), s_fac, Vector2i(3, 2))
		prop_layer.set_cell(Vector2i(6, base_y + 1), s_fac, Vector2i(3, 6))
		prop_layer.set_cell(Vector2i(7, base_y + 1), s_fac, Vector2i(4, 6))
		prop_layer.set_cell(Vector2i(8, base_y + 1), s_fac, Vector2i(5, 6))
		prop_layer.set_cell(Vector2i(6, base_y + 2), s_fac, Vector2i(3, 7))
		prop_layer.set_cell(Vector2i(7, base_y + 2), s_fac, Vector2i(4, 7))
		prop_layer.set_cell(Vector2i(8, base_y + 2), s_fac, Vector2i(5, 7))

	# 3. East CAD & Simulation Stations (x=31..33, y=7..9 and y=14..16)
	for base_y in [7, 14]:
		prop_layer.set_cell(Vector2i(31, base_y), s_fac, Vector2i(3, 8))
		prop_layer.set_cell(Vector2i(32, base_y), s_fac, Vector2i(4, 8))
		prop_layer.set_cell(Vector2i(33, base_y), s_fac, Vector2i(5, 8))
		prop_layer.set_cell(Vector2i(31, base_y + 1), s_fac, Vector2i(3, 6))
		prop_layer.set_cell(Vector2i(32, base_y + 1), s_fac, Vector2i(4, 6))
		prop_layer.set_cell(Vector2i(33, base_y + 1), s_fac, Vector2i(5, 6))
		prop_layer.set_cell(Vector2i(31, base_y + 2), s_fac, Vector2i(3, 7))
		prop_layer.set_cell(Vector2i(32, base_y + 2), s_fac, Vector2i(4, 7))
		prop_layer.set_cell(Vector2i(33, base_y + 2), s_fac, Vector2i(5, 7))

	# 4. Component & Prototype Storage Crates & Server Racks along North Wall (y=3..4)
	for sx in [2, 3, 16, 23, 36, 37]:
		prop_layer.set_cell(Vector2i(sx, 3), s_fac, Vector2i(0, 6))
		prop_layer.set_cell(Vector2i(sx, 4), s_fac, Vector2i(0, 7))
	for x in [7, 8, 12, 13, 26, 27, 31, 32]:
		var crate_col: int = 1 + (x % 2)
		prop_layer.set_cell(Vector2i(x, 3), s_fac, Vector2i(crate_col, 6))
		prop_layer.set_cell(Vector2i(x, 4), s_fac, Vector2i(crate_col, 7))

	# 5. Glowing Plasma Coils (10, 10), Warning Beacons (9, 10) & Hazard Stripes framing Workbench & Portal
	prop_layer.set_cell(Vector2i(14, 8), s_fac, Vector2i(10, 10))
	prop_layer.set_cell(Vector2i(25, 8), s_fac, Vector2i(10, 10))
	prop_layer.set_cell(Vector2i(14, 11), s_fac, Vector2i(9, 10))
	prop_layer.set_cell(Vector2i(25, 11), s_fac, Vector2i(9, 10))

	prop_layer.set_cell(Vector2i(18, 12), s_fac, Vector2i(9, 9))
	prop_layer.set_cell(Vector2i(19, 12), s_fac, Vector2i(10, 9))
	prop_layer.set_cell(Vector2i(20, 12), s_fac, Vector2i(10, 9))
	prop_layer.set_cell(Vector2i(21, 12), s_fac, Vector2i(11, 9))

	prop_layer.set_cell(Vector2i(17, 19), s_fac, Vector2i(9, 10))
	prop_layer.set_cell(Vector2i(22, 19), s_fac, Vector2i(9, 10))
	prop_layer.set_cell(Vector2i(17, 20), s_fac, Vector2i(10, 10))
	prop_layer.set_cell(Vector2i(22, 20), s_fac, Vector2i(10, 10))

func _paint_factory_platform(layer: TileMapLayer, source_id: int, rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cx: int = 10
			if x == rect.position.x:
				cx = 9
			elif x == rect.end.x - 1:
				cx = 11
			var cy: int = 1
			if y == rect.position.y:
				cy = 0
			elif y == rect.end.y - 1:
				cy = 2
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
		Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
		Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),
		Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7),
		Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8),
		Vector2i(7, 8), Vector2i(7, 9), Vector2i(7, 10),
		Vector2i(9, 10), Vector2i(10, 10)
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
