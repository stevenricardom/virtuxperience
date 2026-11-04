extends BiomeLab
class_name NeuroMathLab

## Laboratorio de NeuroMath (lógica y razonamiento cuantitativo). Hereda de BiomeLab.
## Sala de 640x360 px (40x23 celdas de 16x16), armada con neuromath_tileset.tres.
## La Quantum Terminal queda en (320, 160). Aquí se conectan AXION-7, el portal de salida,
## la terminal, el HUD y el DialogModal, y se animan los cables de energía.

# nodos propios de este lab
@onready var axion7_npc: Area2D = $Entities/AXION7_NPC
@onready var quantum_terminal: StaticBody2D = $Entities/QuantumTerminal

var _anim_time: float = 0.0
var _pulse_packets: Array[Node2D] = []
var _pulse_paths: Array[Array] = []
var _holo_rings: Array[Node2D] = []
var _terminal_status_label: Label = null

func _init() -> void:
	biome_id = "neuromath"
	biome_name = "BIOMA: NEUROMATH"
	data_path = "res://data/neuromath.json"
	default_player_spawn = Vector2(320, 240)

func _ready() -> void:
	# el _ready del padre hace casi todo: música, cámara, posición del jugador, HUD, tilemap
	super._ready()

func init_guardian_dialogue() -> void:
	if not axion7_npc:
		return

	var file := FileAccess.open(data_path, FileAccess.READ)
	if file:
		var json_text := file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_text)
		if parsed is Dictionary and parsed.has("guardian"):
			var g_data: Dictionary = parsed["guardian"]
			var lines: Array = g_data.get("learning_capsule", [])
			var str_lines: Array[String] = []
			for l in lines:
				str_lines.append(str(l))
			axion7_npc.set("dialogue_lines", str_lines)
			axion7_npc.set("npc_name", str(g_data.get("name", "AXION-7 (Guardián Lógico)")))
			axion7_npc.set("speaker_color", Color("#00E5FF"))

## El padre (BiomeLab) la llama para refrescar si el bioma ya se completó
func refresh_completion_state() -> void:
	var gs = _get_game_state()
	var is_completed: bool = false
	if gs and gs.has_method("has_fragment"):
		is_completed = gs.has_fragment("neuromath")
	if _terminal_status_label:
		if is_completed:
			_terminal_status_label.text = "[NEXO ESTABILIZADO]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#00E676"))
		else:
			_terminal_status_label.text = "[ACTIVAR NODO: E]"
			_terminal_status_label.add_theme_color_override("font_color", Color("#FFD700"))

## El padre (BiomeLab) la llama para armar los efectos de ambiente
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

	# 1. cables brillantes en el piso (servidores, terminal, domos y portal)
	var circuit_defs: Array[Array] = [
		[Vector2(160, 112), Vector2(160, 160), Vector2(288, 160)],
		[Vector2(480, 112), Vector2(480, 160), Vector2(352, 160)],
		[Vector2(160, 256), Vector2(160, 216), Vector2(304, 216), Vector2(304, 184)],
		[Vector2(480, 256), Vector2(480, 216), Vector2(336, 216), Vector2(336, 184)],
		[Vector2(320, 184), Vector2(320, 304)]
	]

	_pulse_packets.clear()
	_pulse_paths = circuit_defs

	for path_pts in circuit_defs:
		# línea de brillo (la gruesa)
		var glow_line := Line2D.new()
		glow_line.width = 4.0
		glow_line.default_color = Color(0.0, 0.898, 1.0, 0.18)
		for pt in path_pts:
			glow_line.add_point(pt)
		fx_root.add_child(glow_line)

		# línea del centro
		var core_line := Line2D.new()
		core_line.width = 1.5
		core_line.default_color = Color(0.0, 0.92, 1.0, 0.55)
		for pt in path_pts:
			core_line.add_point(pt)
		fx_root.add_child(core_line)

		# bolita de energía que recorre el cable
		var pkt := Polygon2D.new()
		pkt.color = Color(0.55, 0.98, 1.0, 0.95)
		pkt.polygon = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
		])
		fx_root.add_child(pkt)
		_pulse_packets.append(pkt)

	# 2. anillos en el piso bajo la terminal y el portal
	_holo_rings.clear()
	for center_pos in [Vector2(320, 164), Vector2(320, 320), Vector2(160, 98), Vector2(480, 98)]:
		var ring := Line2D.new()
		ring.position = center_pos
		ring.width = 1.5
		ring.closed = true
		ring.default_color = Color(0.0, 0.9, 1.0, 0.4)
		var radius: float = 36.0 if center_pos.x == 320 and center_pos.y < 200 else 24.0
		for i in range(16):
			var angle: float = TAU * float(i) / 16.0
			ring.add_point(Vector2(cos(angle) * radius, sin(angle) * (radius * 0.65)))
		fx_root.add_child(ring)
		_holo_rings.append(ring)

	# 3. partículas flotando por la sala
	var particles := CPUParticles2D.new()
	particles.name = "QuantumParticles"
	particles.z_index = 2
	particles.position = Vector2(320, 180)
	particles.amount = 28
	particles.lifetime = 3.5
	particles.preprocess = 2.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(280, 140)
	particles.direction = Vector2(0, -1)
	particles.spread = 25.0
	particles.gravity = Vector2(0, -4)
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 10.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 2.5
	particles.color = Color(0.0, 0.92, 1.0, 0.45)
	fx_root.add_child(particles)

	# 4. letreros sobre las estaciones importantes
	if has_node("StationLabels"):
		get_node("StationLabels").queue_free()
	var labels_root := Node2D.new()
	labels_root.name = "StationLabels"
	labels_root.z_index = 6
	add_child(labels_root)

	_create_world_label(labels_root, Vector2(320, 94), "NÚCLEO CUÁNTICO", Color("#00E5FF"))
	_terminal_status_label = _create_world_label(labels_root, Vector2(320, 106), "[ACTIVAR NODO: E]", Color("#FFD700"))
	_create_world_label(labels_root, Vector2(160, 56), "SERVIDOR LÓGICO", Color("#80D8FF"))
	_create_world_label(labels_root, Vector2(480, 56), "CAPACITOR TW", Color("#80D8FF"))
	_create_world_label(labels_root, Vector2(246, 198), "AXION-7 (GUARDIÁN LÓGICO)", Color("#00E5FF"))
	_create_world_label(labels_root, Vector2(320, 344), "PORTAL AL CAMPUS", Color("#00E5FF"))

func _process(delta: float) -> void:
	_anim_time += delta

	# mueve las bolitas de energía por los cables
	for i in range(_pulse_packets.size()):
		var pkt := _pulse_packets[i]
		if not is_instance_valid(pkt):
			continue
		var path: Array = _pulse_paths[i]
		if path.size() < 2:
			continue
		var t: float = fmod(_anim_time * 0.65 + float(i) * 0.23, 1.0)
		pkt.position = _sample_polyline(path, t)
		pkt.modulate.a = 0.65 + 0.35 * sin(_anim_time * 6.0 + float(i))

	# los anillos laten suave
	for i in range(_holo_rings.size()):
		var ring := _holo_rings[i]
		if is_instance_valid(ring):
			var s: float = 1.0 + 0.04 * sin(_anim_time * 2.8 + float(i))
			ring.scale = Vector2(s, s)
			ring.modulate.a = 0.55 + 0.3 * sin(_anim_time * 3.2 + float(i))

func _sample_polyline(pts: Array, t: float) -> Vector2:
	var total_len: float = 0.0
	var seg_lens: Array[float] = []
	for i in range(pts.size() - 1):
		var d: float = (pts[i] as Vector2).distance_to(pts[i + 1] as Vector2)
		seg_lens.append(d)
		total_len += d
	if total_len <= 0.001:
		return pts[0]
	var target_d: float = t * total_len
	var accum: float = 0.0
	for i in range(seg_lens.size()):
		var sl: float = seg_lens[i]
		if accum + sl >= target_d:
			var local_t: float = (target_d - accum) / maxf(sl, 0.001)
			return (pts[i] as Vector2).lerp(pts[i + 1] as Vector2, local_t)
		accum += sl
	return pts[pts.size() - 1]

## Arma el piso, las paredes y los equipos del lab con tiles de 16x16
func populate_tilemaps() -> void:
	if not layer0_floor or not layer1_walls:
		return

	layer0_floor.clear()
	layer1_walls.clear()
	if layer2_details:
		layer2_details.clear()

	var s: int = 0

	# =========================================================================
	# CAPA 0: piso azul (40x23 celdas)
	# =========================================================================
	for x in range(40):
		for y in range(23):
			var tile_pos := Vector2i(0, 0)
			if x == 0 or x == 39 or y <= 2 or y == 22:
				# borde oscuro de afuera
				tile_pos = Vector2i(3, 0) if (x + y) % 3 != 0 else Vector2i(8, 2)
			else:
				# piso normal (tiles (0,0) y (1,0))
				tile_pos = Vector2i(0, 0) if (x + y) % 2 == 0 else Vector2i(1, 0)
			layer0_floor.set_cell(Vector2i(x, y), s, tile_pos)

	# Diagonal-ribbed tech walkways (2, 0) connecting stations
	# 1. Central North-South avenue (ExitPortal -> QuantumTerminal)
	for x in range(18, 22):
		for y in range(12, 20):
			layer0_floor.set_cell(Vector2i(x, y), s, Vector2i(2, 0))
	# 2. East-West cross avenue (West Wing <-> Central Terminal <-> East Wing)
	for x in range(6, 34):
		for y in range(13, 15):
			layer0_floor.set_cell(Vector2i(x, y), s, Vector2i(2, 0))
	# 3. West Server branch & East Server branch
	for y in range(7, 14):
		for x in range(8, 12):
			layer0_floor.set_cell(Vector2i(x, y), s, Vector2i(2, 0))
		for x in range(28, 32):
			layer0_floor.set_cell(Vector2i(x, y), s, Vector2i(2, 0))

	# Metallic Floor Plates (10, 1) under major quantum structures
	# Central Quantum Terminal platform
	for x in range(17, 23):
		for y in range(8, 12):
			layer0_floor.set_cell(Vector2i(x, y), s, Vector2i(10, 1))
	# West & East Auxiliary Server pads
	for x in range(8, 12):
		for y in range(5, 8):
			layer0_floor.set_cell(Vector2i(x, y), s, Vector2i(10, 1))
	for x in range(28, 32):
		for y in range(5, 8):
			layer0_floor.set_cell(Vector2i(x, y), s, Vector2i(10, 1))
	# South Portal pad
	for x in range(18, 22):
		for y in range(19, 22):
			layer0_floor.set_cell(Vector2i(x, y), s, Vector2i(10, 1))
	# South-West & South-East Quantum Relay pads
	for x in range(8, 12):
		for y in range(16, 19):
			layer0_floor.set_cell(Vector2i(x, y), s, Vector2i(10, 1))
	for x in range(28, 32):
		for y in range(16, 19):
			layer0_floor.set_cell(Vector2i(x, y), s, Vector2i(10, 1))

	# =========================================================================
	# CAPA 1: paredes de alrededor, tuberías y ventilas
	# =========================================================================
	# Corners
	layer1_walls.set_cell(Vector2i(0, 0), s, Vector2i(9, 0))
	layer1_walls.set_cell(Vector2i(39, 0), s, Vector2i(11, 0))
	layer1_walls.set_cell(Vector2i(0, 22), s, Vector2i(9, 2))
	layer1_walls.set_cell(Vector2i(39, 22), s, Vector2i(11, 2))

	# Top wall (y = 0, 1, 2) and Bottom wall (y = 22)
	for x in range(1, 39):
		# Row 0: Overhead Quantum Pipeline running across the ceiling
		var pipe_tile := Vector2i(10, 6)
		if x == 1:
			pipe_tile = Vector2i(6, 6)
		elif x == 38:
			pipe_tile = Vector2i(11, 6)
		elif x in [6, 14, 25, 33]:
			pipe_tile = Vector2i(7, 6) # Amber pipe coupling
		elif x in [10, 19, 20, 30]:
			pipe_tile = Vector2i(8, 6) # T-junction feeding downward
		elif x in [12, 27]:
			pipe_tile = Vector2i(10, 7) # Valve on pipe
		layer1_walls.set_cell(Vector2i(x, 0), s, pipe_tile)

		# Row 1: Upper metallic bulkhead wall panels & vertical feed pipes
		var upper_wall := Vector2i(10, 3) if x % 2 == 0 else Vector2i(11, 3)
		if x % 6 == 0:
			upper_wall = Vector2i(9, 3)
		if x in [10, 19, 20, 30]:
			upper_wall = Vector2i(11, 7) # Vertical pipe with coupling
		layer1_walls.set_cell(Vector2i(x, 1), s, upper_wall)

		# Row 2: Lower bulkhead wall with doors, reactor vents, and pipe intakes
		var lower_wall := Vector2i(10, 3) if x % 2 == 0 else Vector2i(11, 3)
		if x in [10, 19, 20, 30]:
			lower_wall = Vector2i(8, 7) # Pipe intake nozzle
		elif x == 5 or x == 34:
			lower_wall = Vector2i(10, 4) # Double bulkhead door left
		elif x == 6 or x == 35:
			lower_wall = Vector2i(11, 4) # Double bulkhead door right
		elif x in [14, 24]:
			lower_wall = Vector2i(10, 5) # Reactor vent left
		elif x in [15, 25]:
			lower_wall = Vector2i(11, 5) # Reactor vent right
		elif x in [8, 17, 22, 31]:
			lower_wall = Vector2i(9, 4) # Access locker / panel
		layer1_walls.set_cell(Vector2i(x, 2), s, lower_wall)

		# Row 22: Bottom metallic border wall with hazard stripes around portal
		var bot_wall := Vector2i(10, 2)
		if x == 17:
			bot_wall = Vector2i(9, 9)
		elif x in [18, 19, 20, 21]:
			bot_wall = Vector2i(10, 9)
		elif x == 22:
			bot_wall = Vector2i(11, 9)
		layer1_walls.set_cell(Vector2i(x, 22), s, bot_wall)

	# Left and Right perimeter walls (y = 1..21)
	for y in range(1, 22):
		layer1_walls.set_cell(Vector2i(0, y), s, Vector2i(9, 1))
		layer1_walls.set_cell(Vector2i(39, y), s, Vector2i(11, 1))

	# =========================================================================
	# CAPA 2: equipos, servidores, cápsulas y bobinas
	# =========================================================================
	var prop_layer: TileMapLayer = layer2_details if layer2_details != null else layer1_walls

	# 1. Tall Server Racks along the North Bulkhead (top at y=2, base at y=3)
	for sx in [2, 3, 16, 23, 36, 37]:
		prop_layer.set_cell(Vector2i(sx, 2), s, Vector2i(0, 6))
		prop_layer.set_cell(Vector2i(sx, 3), s, Vector2i(0, 7))

	# 2. West Wing Logic Gate Consoles (Cyan consoles) & Cryo-Pods
	prop_layer.set_cell(Vector2i(2, 6), s, Vector2i(3, 9))
	prop_layer.set_cell(Vector2i(3, 6), s, Vector2i(4, 9))
	prop_layer.set_cell(Vector2i(4, 6), s, Vector2i(5, 9))
	prop_layer.set_cell(Vector2i(5, 6), s, Vector2i(4, 10)) # Hologram screen

	prop_layer.set_cell(Vector2i(2, 9), s, Vector2i(2, 6))  # Cryo capsule
	prop_layer.set_cell(Vector2i(2, 10), s, Vector2i(2, 7)) # Glowing blue quantum pod
	prop_layer.set_cell(Vector2i(2, 12), s, Vector2i(2, 7))
	prop_layer.set_cell(Vector2i(2, 13), s, Vector2i(2, 6))

	prop_layer.set_cell(Vector2i(2, 15), s, Vector2i(6, 4)) # Catwalk railing left
	prop_layer.set_cell(Vector2i(3, 15), s, Vector2i(7, 4)) # Catwalk railing mid
	prop_layer.set_cell(Vector2i(4, 15), s, Vector2i(8, 4)) # Catwalk railing right

	prop_layer.set_cell(Vector2i(2, 18), s, Vector2i(3, 9))
	prop_layer.set_cell(Vector2i(3, 18), s, Vector2i(4, 9))
	prop_layer.set_cell(Vector2i(4, 18), s, Vector2i(5, 9))
	prop_layer.set_cell(Vector2i(5, 18), s, Vector2i(4, 10))

	# 3. East Wing Quantitative Consoles (Emerald & Cyan consoles) & Cryo-Pods
	prop_layer.set_cell(Vector2i(34, 6), s, Vector2i(4, 10))
	prop_layer.set_cell(Vector2i(35, 6), s, Vector2i(3, 8))
	prop_layer.set_cell(Vector2i(36, 6), s, Vector2i(4, 8))
	prop_layer.set_cell(Vector2i(37, 6), s, Vector2i(5, 8))

	prop_layer.set_cell(Vector2i(37, 9), s, Vector2i(2, 6))
	prop_layer.set_cell(Vector2i(37, 10), s, Vector2i(2, 7))
	prop_layer.set_cell(Vector2i(37, 12), s, Vector2i(2, 7))
	prop_layer.set_cell(Vector2i(37, 13), s, Vector2i(2, 6))

	prop_layer.set_cell(Vector2i(35, 15), s, Vector2i(6, 4))
	prop_layer.set_cell(Vector2i(36, 15), s, Vector2i(7, 4))
	prop_layer.set_cell(Vector2i(37, 15), s, Vector2i(8, 4))

	prop_layer.set_cell(Vector2i(34, 18), s, Vector2i(4, 10))
	prop_layer.set_cell(Vector2i(35, 18), s, Vector2i(3, 8))
	prop_layer.set_cell(Vector2i(36, 18), s, Vector2i(4, 8))
	prop_layer.set_cell(Vector2i(37, 18), s, Vector2i(5, 8))

	# 4. Glowing Cyan Plasma Coils (10, 10) & Telemetry Beacons (9, 10)
	prop_layer.set_cell(Vector2i(16, 9), s, Vector2i(10, 10))
	prop_layer.set_cell(Vector2i(23, 9), s, Vector2i(10, 10))
	prop_layer.set_cell(Vector2i(16, 11), s, Vector2i(9, 10))
	prop_layer.set_cell(Vector2i(23, 11), s, Vector2i(9, 10))

	prop_layer.set_cell(Vector2i(7, 6), s, Vector2i(10, 10))
	prop_layer.set_cell(Vector2i(12, 6), s, Vector2i(10, 10))
	prop_layer.set_cell(Vector2i(27, 6), s, Vector2i(10, 10))
	prop_layer.set_cell(Vector2i(32, 6), s, Vector2i(10, 10))

	# Portal flanking plasma coils & beacons
	prop_layer.set_cell(Vector2i(17, 20), s, Vector2i(10, 10))
	prop_layer.set_cell(Vector2i(22, 20), s, Vector2i(10, 10))
	prop_layer.set_cell(Vector2i(17, 19), s, Vector2i(9, 10))
	prop_layer.set_cell(Vector2i(22, 19), s, Vector2i(9, 10))

	# Hazard stripes framing the central terminal front step
	prop_layer.set_cell(Vector2i(18, 12), s, Vector2i(9, 9))
	prop_layer.set_cell(Vector2i(19, 12), s, Vector2i(10, 9))
	prop_layer.set_cell(Vector2i(20, 12), s, Vector2i(10, 9))
	prop_layer.set_cell(Vector2i(21, 12), s, Vector2i(11, 9))
