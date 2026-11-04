extends BiomeLab
class_name VoxCivitasLab

## VoxCivitasLab.gd — "El Ágora Cívica & Foro Democrático" laboratory world.
## Inherits from BiomeLab. Viewport 640x360 px (40x23 cells of 16x16 px).
## Features:
## - Central Rostra Podium Terminal at (320, 156)
## - Guardian NPC CIVIS-1 at (256, 176)
## - ExitPortal at (320, 320) returning to CampusHub at (640, 672)
## - Classical marble & travertine forum pavement, north stoa colonnade, reflecting pools,
##   marble tribune statues, tiered assembly benches, and golden braziers
## - Concentric assembly semicircles + deliberative consensus pulse rays
## - Shimmering golden dust CPUParticles2D and divine sunlight rays
## - Holographic world-space status labels

@onready var civis1_npc: Area2D = get_node_or_null("Entities/CIVIS_1_NPC")
@onready var agora_terminal: StaticBody2D = get_node_or_null("Entities/AgoraPodiumTerminal")

var _anim_time: float = 0.0
var _concentric_lines: Array[Line2D] = []
var _consensus_packets: Array[Node2D] = []
var _consensus_paths: Array[Array] = []
var _terminal_status_label: Label = null

func _init() -> void:
	biome_id = "voxcivitas"
	biome_name = "El Ágora Cívica & Foro Democrático"
	data_path = "res://data/voxcivitas.json"
	default_player_spawn = Vector2(320, 240)
	room_rect = Rect2i(0, 0, 640, 360)

func _ready() -> void:
	if civis1_npc == null:
		civis1_npc = get_node_or_null("Entities/CIVIS_1_NPC")
	if guardian_npc == null:
		guardian_npc = civis1_npc
	if agora_terminal == null:
		agora_terminal = get_node_or_null("Entities/AgoraPodiumTerminal")
	if terminal == null:
		terminal = agora_terminal

	super._ready()

func init_guardian_dialogue() -> void:
	if not guardian_npc and civis1_npc:
		guardian_npc = civis1_npc
	if not guardian_npc and has_node("Entities/CIVIS_1_NPC"):
		guardian_npc = get_node("Entities/CIVIS_1_NPC") as Area2D

	if not guardian_npc:
		return

	if biome_data.is_empty() and not data_path.is_empty():
		biome_data = BiomeDataLoader.load_biome_data(data_path)

	if not biome_data.is_empty():
		var lines: Array[String] = BiomeDataLoader.extract_learning_capsule(biome_data)
		var g_dict: Dictionary = biome_data.get("guardian", {})
		var g_name: String = str(g_dict.get("name", "CIVIS-1 (Tribuno del Ágora Democrática)"))
		var raw_accent = biome_data.get("accent_color", "#9C27B0")
		var hex_col: String = str(raw_accent) if raw_accent is String and not str(raw_accent).is_empty() else "#9C27B0"
		var speaker_color: Color = Color.from_string(hex_col, Color("#9C27B0"))

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
		is_completed = gs.has_fragment("voxcivitas")
	if _terminal_status_label:
		if is_completed:
			_terminal_status_label.text = "[NEXO ESTABILIZADO]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#00E676"))
		else:
			_terminal_status_label.text = "[PODIO ROSTRA: E]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#FFD700"))

## Virtual hook called by BiomeLab to set up agora ambient visuals
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

	var rostra_center := Vector2(320, 156)

	# 1. Warm Golden Brazier Light Halos around the 6 Classical Candelabras
	var brazier_positions: Array[Vector2] = [
		Vector2(232, 128), Vector2(408, 128),
		Vector2(248, 64), Vector2(392, 64),
		Vector2(280, 312), Vector2(360, 312)
	]
	for bpos in brazier_positions:
		var halo := Polygon2D.new()
		halo.z_index = 2
		halo.position = bpos
		halo.color = Color(1.0, 0.82, 0.28, 0.22)
		var pts := PackedVector2Array()
		for i in range(12):
			var a: float = TAU * float(i) / 12.0
			pts.append(Vector2(cos(a) * 22.0, sin(a) * 16.0))
		halo.polygon = pts
		fx_root.add_child(halo)

	# 2. Concentric deliberative amphitheater rings around the Rostra podium
	_concentric_lines.clear()
	for r in [52.0, 96.0, 144.0]:
		var ring := Line2D.new()
		ring.position = rostra_center
		ring.width = 1.8
		ring.closed = true
		ring.default_color = Color(0.612, 0.153, 0.690, 0.32)
		for i in range(24):
			var angle: float = TAU * float(i) / 24.0
			ring.add_point(Vector2(cos(angle) * r, sin(angle) * (r * 0.62)))
		fx_root.add_child(ring)
		_concentric_lines.append(ring)

	# 3. Deliberative Consensus Conduits connecting West/East Assembly Sectors & North Stoa to Rostra
	var ray_defs: Array[Array] = [
		[Vector2(136, 224), Vector2(216, 192), rostra_center],
		[Vector2(504, 224), Vector2(424, 192), rostra_center],
		[Vector2(168, 96), Vector2(240, 128), rostra_center],
		[Vector2(472, 96), Vector2(400, 128), rostra_center],
		[Vector2(320, 308), Vector2(320, 232), rostra_center]
	]
	_consensus_packets.clear()
	_consensus_paths = ray_defs
	for pts in ray_defs:
		var ray_line := Line2D.new()
		ray_line.width = 2.0
		ray_line.joint_mode = Line2D.LINE_JOINT_ROUND
		ray_line.default_color = Color(0.85, 0.58, 0.95, 0.28)
		for p in pts:
			ray_line.add_point(p)
		fx_root.add_child(ray_line)
		_concentric_lines.append(ray_line)

		var pkt := Polygon2D.new()
		pkt.color = Color(1.0, 0.86, 0.28, 0.92)
		pkt.polygon = PackedVector2Array([
			Vector2(0, -3.5), Vector2(3.5, 0), Vector2(0, 3.5), Vector2(-3.5, 0)
		])
		fx_root.add_child(pkt)
		_consensus_packets.append(pkt)

	# 4. Shimmering Golden Dust particles drifting across marble pavement
	var dust := CPUParticles2D.new()
	dust.name = "GoldenDust"
	dust.z_index = 2
	dust.position = Vector2(320, 180)
	dust.amount = 28
	dust.lifetime = 4.0
	dust.preprocess = 2.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(280, 140)
	dust.direction = Vector2(0.0, -1.0)
	dust.spread = 20.0
	dust.gravity = Vector2(0, -6)
	dust.initial_velocity_min = 8.0
	dust.initial_velocity_max = 20.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 2.5
	dust.color = Color(1.0, 0.843, 0.0, 0.68) # #FFD700
	fx_root.add_child(dust)

	# 5. Translucent divine light rays (sunbeams) between northern colonnades
	var rays := Polygon2D.new()
	rays.name = "DivineRays"
	rays.z_index = 2
	rays.color = Color(1.0, 0.95, 0.72, 0.07)
	rays.polygon = PackedVector2Array([
		Vector2(110, 0), Vector2(190, 0), Vector2(360, 360), Vector2(280, 360)
	])
	fx_root.add_child(rays)

	var rays_east := Polygon2D.new()
	rays_east.name = "DivineRaysEast"
	rays_east.z_index = 2
	rays_east.color = Color(0.92, 0.78, 1.0, 0.06)
	rays_east.polygon = PackedVector2Array([
		Vector2(370, 0), Vector2(445, 0), Vector2(585, 360), Vector2(510, 360)
	])
	fx_root.add_child(rays_east)

	# 6. Holographic world-space labels
	if has_node("StationLabels"):
		get_node("StationLabels").queue_free()
	var labels_root := Node2D.new()
	labels_root.name = "StationLabels"
	labels_root.z_index = 6
	add_child(labels_root)

	_create_world_label(labels_root, Vector2(320, 96), "EL ÁGORA CÍVICA & FORO DEMOCRÁTICO", Color("#CE93D8"))
	_terminal_status_label = _create_world_label(labels_root, Vector2(320, 108), "[PODIO ROSTRA: E]", Color("#FFD700"))
	_create_world_label(labels_root, Vector2(160, 58), "COLONNADA NORTE — TRIBUNOS", Color("#EDE7F6"))
	_create_world_label(labels_root, Vector2(480, 58), "SENADO CONSTITUCIONAL", Color("#EDE7F6"))
	_create_world_label(labels_root, Vector2(124, 248), "ASAMBLEA POPULAR — OESTE", Color("#B39DDB"))
	_create_world_label(labels_root, Vector2(516, 248), "ASAMBLEA POPULAR — ESTE", Color("#B39DDB"))
	_create_world_label(labels_root, Vector2(246, 198), "CIVIS-1 (TRIBUNO CÍVICO)", Color("#CE93D8"))
	_create_world_label(labels_root, Vector2(320, 344), "PORTAL AL CAMPUS", Color("#9C27B0"))

func _process(delta: float) -> void:
	_anim_time += delta
	var pulse: float = 0.24 + 0.16 * sin(_anim_time * 2.8)
	for ring in _concentric_lines:
		if is_instance_valid(ring):
			ring.default_color.a = pulse

	for i in range(_consensus_packets.size()):
		var pkt := _consensus_packets[i]
		if not is_instance_valid(pkt) or i >= _consensus_paths.size():
			continue
		var pts: Array = _consensus_paths[i]
		var t: float = fmod(_anim_time * 0.6 + float(i) * 0.21, 1.0)
		pkt.position = _sample_path(pts, t)
		pkt.modulate.a = 0.65 + 0.35 * sin(_anim_time * 5.0 + float(i))

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

## Populates classical agora tilemaps: polished marble floor, travertine assembly wings,
## royal crimson/purple carpet avenue, north stoa colonnade, reflecting pools, marble statues,
## amphitheater seating benches, and golden braziers.
func populate_tilemaps() -> void:
	if not layer0_floor or not layer1_walls:
		return

	layer0_floor.clear()
	layer1_walls.clear()
	if layer2_details:
		layer2_details.clear()

	var s_city: int = 1
	var s_indoor: int = 2
	_ensure_agora_sources()

	# =========================================================================
	# LAYER 0: Polished Marble Forum, Travertine Assembly Wings & Royal Carpets
	# =========================================================================
	# 1. Dark Granite Outer Stoa Margin across entire 40x23 grid (base_col = 8)
	_fill_slab_plaza(layer0_floor, s_city, Rect2i(0, 0, 40, 23), 8)

	# 2. Main Agora Light Marble Pavement (x=2..37, y=3..21, base_col = 16)
	_fill_slab_plaza(layer0_floor, s_city, Rect2i(2, 3, 36, 19), 16)

	# 3. NW & NE Colonnade Sanctuaries (x=3..13, y=4..8 and x=26..36, y=4..8)
	_fill_bordered_walkway(layer0_floor, s_city, Rect2i(3, 4, 11, 5), 0)
	_fill_bordered_walkway(layer0_floor, s_city, Rect2i(26, 4, 11, 5), 0)

	# 4. West & East Popular Assembly Hemicycles in Warm Travertine (base_col = 24)
	_fill_slab_plaza(layer0_floor, s_city, Rect2i(3, 10, 10, 10), 24)
	_fill_slab_plaza(layer0_floor, s_city, Rect2i(27, 10, 10, 10), 24)

	# 5. East-West Deliberation Walkways connecting Assembly Wings to Central Rostra
	_fill_bordered_walkway(layer0_floor, s_city, Rect2i(13, 13, 14, 3), 3)

	# 6. Central Royal Carpet Processional Avenue (ExitPortal -> Rostra Podium: x=18..21, y=6..20)
	_paint_carpet(layer0_floor, s_indoor, Rect2i(18, 6, 4, 15), 23, 0)

	# 7. Grand Senate Carpet Dais beneath AgoraPodiumTerminal (x=15..24, y=7..12)
	_paint_carpet(layer0_floor, s_indoor, Rect2i(15, 7, 10, 6), 23, 0)

	# =========================================================================
	# LAYER 1: Classical North Stoa Facade & Perimeter Stone Colonnade Walls
	# =========================================================================
	for x in range(40):
		var col_offset: int = 1 + (x % 2)
		if x == 0:
			col_offset = 0
		elif x == 39:
			col_offset = 3
		var wc: int = 4 + col_offset
		# Classical Stone Stoa Entablature along North Wall (y=0..3 so rows 2..3 sit below HUD TopBar)
		layer1_walls.set_cell(Vector2i(x, 0), s_city, Vector2i(wc, 6))
		layer1_walls.set_cell(Vector2i(x, 1), s_city, Vector2i(wc, 6))
		layer1_walls.set_cell(Vector2i(x, 2), s_city, Vector2i(wc, 5))
		layer1_walls.set_cell(Vector2i(x, 3), s_city, Vector2i(wc, 10))
		# South Perimeter Stone Wall (y=22)
		layer1_walls.set_cell(Vector2i(x, 22), s_city, Vector2i(wc, 10))

	# West & East Perimeter Stone Walls (x=0 and x=39, y=1..21)
	for y in range(1, 22):
		layer1_walls.set_cell(Vector2i(0, y), s_city, Vector2i(4, 5))
		layer1_walls.set_cell(Vector2i(39, y), s_city, Vector2i(7, 5))

	# =========================================================================
	# LAYER 2: Statues, Reflecting Pools, Amphitheater Benches, Banners & Braziers
	# =========================================================================
	var prop_layer: TileMapLayer = layer2_details if layer2_details != null else layer1_walls

	# 1. North Stoa Framed Classical Friezes, Heraldic Shields & Senate Archway (y=2..3, visible below HUD)
	# Central Senate 2-tile Arched Entrance at x=19, 20
	prop_layer.set_cell(Vector2i(19, 2), s_city, Vector2i(21, 9))
	prop_layer.set_cell(Vector2i(20, 2), s_city, Vector2i(22, 9))
	prop_layer.set_cell(Vector2i(19, 3), s_city, Vector2i(21, 10))
	prop_layer.set_cell(Vector2i(20, 3), s_city, Vector2i(22, 10))

	# Flanking 3-tile Framed Classical Friezes & Tapestries on North Stoa (y=2)
	for b_start in [6, 15, 22, 31]:
		var f_row: int = 14 if (b_start in [6, 31]) else 15
		prop_layer.set_cell(Vector2i(b_start + 0, 2), s_indoor, Vector2i(16, f_row))
		prop_layer.set_cell(Vector2i(b_start + 1, 2), s_indoor, Vector2i(17, f_row))
		prop_layer.set_cell(Vector2i(b_start + 2, 2), s_indoor, Vector2i(18, f_row))

	# Royal Heraldic Shields flanking the Senate Entrance (x=18, 21 at y=2)
	prop_layer.set_cell(Vector2i(18, 2), s_indoor, Vector2i(22, 6))
	prop_layer.set_cell(Vector2i(21, 2), s_indoor, Vector2i(22, 7))

	# Classical Windows along North Stoa (y=2)
	for wx in [3, 4, 10, 11, 28, 29, 35, 36]:
		prop_layer.set_cell(Vector2i(wx, 2), s_city, Vector2i(26, 16))

	# 2. Twin 3x3 Classical Reflecting Pools in NW (x=4..6, y=5..7) & NE (x=33..35, y=5..7) Sanctuaries
	_place_water_pool_3x3(prop_layer, s_city, Vector2i(4, 5))
	_place_water_pool_3x3(prop_layer, s_city, Vector2i(33, 5))

	# 3. 4 Classical Marble Tribune Statues (2-tile tall: top row 2, pedestal row 3)
	var statue_bases: Array[Vector2i] = [
		Vector2i(9, 6), Vector2i(12, 6),
		Vector2i(27, 6), Vector2i(30, 6)
	]
	for i in range(statue_bases.size()):
		var sb: Vector2i = statue_bases[i]
		var st_col: int = 35 if (i % 2 == 0) else 36
		prop_layer.set_cell(Vector2i(sb.x, sb.y - 1), s_city, Vector2i(st_col, 2))
		prop_layer.set_cell(sb, s_city, Vector2i(st_col, 3))

	# 4. Flowering Marble Planters & Hedges framing the North Sanctuaries & South Portal
	_place_planter_3x1(prop_layer, s_city, Vector2i(8, 8), false)
	_place_planter_3x1(prop_layer, s_city, Vector2i(29, 8), false)
	_place_planter_3x1(prop_layer, s_city, Vector2i(8, 20), true)
	_place_planter_3x1(prop_layer, s_city, Vector2i(29, 20), true)

	# 5. West & East Popular Assembly Tiered Seating Benches (2-tile benches: 17,15 + 18,15)
	for by in [11, 14, 17]:
		# West Assembly Sector (2 columns of 2-tile benches)
		prop_layer.set_cell(Vector2i(4, by), s_city, Vector2i(17, 15))
		prop_layer.set_cell(Vector2i(5, by), s_city, Vector2i(18, 15))
		prop_layer.set_cell(Vector2i(9, by), s_city, Vector2i(17, 15))
		prop_layer.set_cell(Vector2i(10, by), s_city, Vector2i(18, 15))
		# East Assembly Sector (2 columns of 2-tile benches)
		prop_layer.set_cell(Vector2i(29, by), s_city, Vector2i(17, 15))
		prop_layer.set_cell(Vector2i(30, by), s_city, Vector2i(18, 15))
		prop_layer.set_cell(Vector2i(34, by), s_city, Vector2i(17, 15))
		prop_layer.set_cell(Vector2i(35, by), s_city, Vector2i(18, 15))

	# 6. Contiguous 2-tile Golden Candelabras / Civic Braziers framing Rostra, Stoa & Portal
	for cx in [14, 25]:
		prop_layer.set_cell(Vector2i(cx, 7), s_indoor, Vector2i(19, 4))
		prop_layer.set_cell(Vector2i(cx, 8), s_indoor, Vector2i(19, 5))
	for cx in [15, 24]:
		prop_layer.set_cell(Vector2i(cx, 3), s_indoor, Vector2i(19, 4))
		prop_layer.set_cell(Vector2i(cx, 4), s_indoor, Vector2i(19, 5))
	for cx in [17, 22]:
		prop_layer.set_cell(Vector2i(cx, 19), s_indoor, Vector2i(19, 4))
		prop_layer.set_cell(Vector2i(cx, 20), s_indoor, Vector2i(19, 5))

	# 7. Classical Laurel Urns along outer West & East Colonnades
	for py in [5, 11, 17]:
		prop_layer.set_cell(Vector2i(2, py), s_indoor, Vector2i(16, 0))
		prop_layer.set_cell(Vector2i(37, py), s_indoor, Vector2i(17, 0))

func _fill_slab_plaza(layer: TileMapLayer, source_id: int, rect: Rect2i, base_col: int) -> void:
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
	var x0: int = rect.position.x
	var y0: int = rect.position.y
	var x1: int = x0 + rect.size.x - 1
	var y1: int = y0 + rect.size.y - 1
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var cx: int = base_col + 1
			if x == x0: cx = base_col
			elif x == x1: cx = base_col + 2
			var cy: int = 20
			if y == y0: cy = 19
			elif y == y1: cy = 22
			layer.set_cell(Vector2i(x, y), source_id, Vector2i(cx, cy))

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

func _place_water_pool_3x3(layer: TileMapLayer, source_id: int, top_left: Vector2i) -> void:
	for dx in range(3):
		for dy in range(3):
			layer.set_cell(Vector2i(top_left.x + dx, top_left.y + dy), source_id, Vector2i(26 + dx, 4 + dy))

func _place_planter_3x1(layer: TileMapLayer, source_id: int, left_pos: Vector2i, is_green_hedge: bool) -> void:
	var row: int = 5 if is_green_hedge else 8
	for dx in range(3):
		layer.set_cell(Vector2i(left_pos.x + dx, left_pos.y), source_id, Vector2i(31 + dx, row))

func _ensure_agora_sources() -> void:
	if not layer0_floor or not layer0_floor.tile_set:
		return
	var ts: TileSet = layer0_floor.tile_set
	if not ts.has_source(1):
		var city_tex := load("res://assets/hub/modern_city/Tilemap/tilemap_packed.png") as Texture2D
		if city_tex:
			var atlas := TileSetAtlasSource.new()
			atlas.texture = city_tex
			atlas.texture_region_size = Vector2i(16, 16)
			ts.add_source(atlas, 1)
	if not ts.has_source(2):
		var ind_tex := load("res://assets/hub/indoors/Tilesheets/roguelikeIndoor_transparent.png") as Texture2D
		if ind_tex:
			var atlas2 := TileSetAtlasSource.new()
			atlas2.texture = ind_tex
			atlas2.texture_region_size = Vector2i(16, 16)
			atlas2.separation = Vector2i(1, 1)
			ts.add_source(atlas2, 2)
