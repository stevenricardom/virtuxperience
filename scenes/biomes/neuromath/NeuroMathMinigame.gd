extends MinigameBase
class_name NeuroMathMinigame

## Minijuego de NeuroMath (lógica y razonamiento cuantitativo). Hereda de MinigameBase
## y lee los retos de res://data/neuromath.json.
## - 3 páginas de repaso con AXION-7 antes de empezar.
## - 3 retos: nm_gate_01 (circuito lógico), nm_calc_02 (proporciones) y
##   nm_saberpro_03 (estadística tipo Saber Pro, con cuenta regresiva de 60 s).
## - Pista: cuesta 10 XP (GameState.deduct_xp(10)), nunca baja de 0.
## - Si te equivocas muestra explanation_on_error.
## - Si fallas 3 veces seguidas (consecutive_failures >= 3) quita 2 opciones malas y da una pista gratis.
## - Al terminar da: fragment_neuromath, badge_arquitecto_cuantico, 150 XP y el skin samurai_blue.
## - Botón para volver a NeuroMathLab.tscn.

# constantes que usaban versiones anteriores
const DATA_PATH: String = "res://data/neuromath.json"
const LAB_SCENE_PATH: String = "res://scenes/biomes/neuromath/NeuroMathLab.tscn"

# nodo que dibuja el circuito
@onready var circuit_visualizer: Control = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CircuitVisualizer")

# acceso viejo a los datos
var _neuromath_data: Dictionary:
	get:
		return _biome_data
	set(val):
		_biome_data = val

func _init() -> void:
	biome_data_path = DATA_PATH
	lab_scene_path = LAB_SCENE_PATH
	biome_id = "neuromath"

## MinigameBase la llama al empezar o resolver un reto
func _render_current_challenge() -> void:
	_render_challenge_schematic()

## MinigameBase la llama para armar el texto final
func _format_completion_text(reward_data: Dictionary) -> String:
	var badge_name: String = str(reward_data.get("badge_name", "Arquitecto Cuántico"))
	var completion_xp: int = int(reward_data.get("completion_xp", 150))
	var unlock_cosmetic: String = str(reward_data.get("unlock_cosmetic", "samurai_blue"))

	return (
		"[center][b][color=#00E5FF]¡OBSERVATORIO CUÁNTICO NEUROMATH RESTAURADO![/color][/b][/center]\n\n" +
		"Has superado con éxito todos los nodos de razonamiento lógico y cuantitativo.\n\n" +
		"[color=#FFD700]RECOMPENSAS OBTENIDAS:[/color]\n" +
		"✦ [b]Fragmento Cian del Nexo:[/b] Restaurado en el Altar Central.\n" +
		"✦ [b]Insignia de Honor:[/b] %s.\n" % badge_name +
		"✦ [b]Experiencia Extra:[/b] +%d XP.\n" % completion_xp +
		"✦ [b]Nuevo Atuendo Desbloqueado:[/b] Samurái Cuántico (%s).\n\n" % unlock_cosmetic +
		"Regresa al Laboratorio y atraviesa el Portal para volver al Campus Nexus."
	)

# =========================================================================
# DIBUJO DEL CIRCUITO
# =========================================================================

func _render_challenge_schematic() -> void:
	if circuit_visualizer == null:
		circuit_visualizer = get_node_or_null("MainPanel/MarginContainer/VBoxContainer/ChallengeView/CircuitVisualizer") as Control
	if not circuit_visualizer:
		return

	var old_overlay := circuit_visualizer.get_node_or_null("SchematicOverlay")
	if old_overlay:
		old_overlay.free()

	var overlay := Control.new()
	overlay.name = "SchematicOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circuit_visualizer.add_child(overlay)

	# marco de afuera
	_add_box_outline(overlay, Rect2(0, 0, 584, 68), Color(0, 0.898, 1, 0.45))

	var cid: String = str(_current_challenge.get("id", "nm_gate_01"))
	if cid == "nm_gate_01":
		_build_logic_gate_diagram(overlay)
	elif cid == "nm_calc_02":
		_build_power_flow_diagram(overlay)
	else:
		_build_latency_stats_diagram(overlay)

func _build_logic_gate_diagram(parent_ctrl: Control) -> void:
	var c_val: String = "C = 1" if _challenge_solved else "C = ?"
	var c_col: Color = Color("#00E676") if _challenge_solved else Color("#FFD700")
	var p_str: String = "P = 1" if _challenge_solved else "P = ?"

	# cables
	_add_wire(parent_ctrl, Vector2(146, 16), Vector2(316, 24), Color("#00E5FF")) # A -> AND
	_add_wire(parent_ctrl, Vector2(146, 36), Vector2(210, 42), Color("#607D8B")) # B -> OR
	_add_wire(parent_ctrl, Vector2(146, 54), Vector2(210, 50), c_col)            # C -> OR
	_add_wire(parent_ctrl, Vector2(274, 46), Vector2(316, 36), c_col)            # OR -> AND
	_add_wire(parent_ctrl, Vector2(384, 30), Vector2(436, 30), Color("#00E676") if _challenge_solved else Color("#00E5FF")) # AND -> S

	# nodos y compuertas
	_add_diagram_chip(parent_ctrl, Rect2(86, 6, 60, 16), "A = 1", Color("#00E5FF"), Color(0.04, 0.16, 0.24, 0.95))
	_add_diagram_chip(parent_ctrl, Rect2(86, 26, 60, 16), "B = 0", Color("#90A4AE"), Color(0.08, 0.11, 0.15, 0.95))
	_add_diagram_chip(parent_ctrl, Rect2(86, 46, 60, 16), c_val, c_col, Color(0.18, 0.14, 0.04, 0.95))

	_add_diagram_chip(parent_ctrl, Rect2(210, 32, 64, 28), "OR (B,C)\n" + p_str, c_col, Color(0.06, 0.12, 0.2, 0.96))
	_add_diagram_chip(parent_ctrl, Rect2(316, 18, 68, 26), "AND (A,P)", Color("#00E5FF"), Color(0.04, 0.16, 0.26, 0.96))
	_add_diagram_chip(parent_ctrl, Rect2(436, 16, 68, 28), "S = 1\nREACTOR", Color("#00E676"), Color(0.04, 0.18, 0.12, 0.96))

func _build_power_flow_diagram(parent_ctrl: Control) -> void:
	var r3_text: String = "Rama 3 (5x): 60 TW" if _challenge_solved else "Rama 3 (5x): ? TW"
	var r3_col: Color = Color("#00E676") if _challenge_solved else Color("#FFD700")

	_add_diagram_chip(parent_ctrl, Rect2(84, 18, 96, 30), "CAUDAL TOTAL\n120 TW (2:3:5)", Color("#00E5FF"), Color(0.04, 0.16, 0.24, 0.96))

	_add_wire(parent_ctrl, Vector2(180, 34), Vector2(236, 15), Color("#80D8FF"))
	_add_wire(parent_ctrl, Vector2(180, 34), Vector2(236, 34), Color("#80D8FF"))
	_add_wire(parent_ctrl, Vector2(180, 34), Vector2(236, 53), r3_col)

	_add_diagram_chip(parent_ctrl, Rect2(236, 6, 160, 16), "Rama 1 (2 partes): 24 TW", Color("#80D8FF"), Color(0.05, 0.12, 0.2, 0.95))
	_add_diagram_chip(parent_ctrl, Rect2(236, 26, 160, 16), "Rama 2 (3 partes): 36 TW", Color("#80D8FF"), Color(0.05, 0.12, 0.2, 0.95))
	_add_diagram_chip(parent_ctrl, Rect2(236, 46, 160, 16), r3_text, r3_col, Color(0.16, 0.13, 0.04, 0.96))

	_add_diagram_chip(parent_ctrl, Rect2(408, 18, 96, 32), "10 PARTES\n1p = 12 TW", Color("#00E5FF"), Color(0.04, 0.14, 0.22, 0.95))

func _build_latency_stats_diagram(parent_ctrl: Control) -> void:
	var samples := [12, 15, 15, 18, 20, 16]
	var labels := ["12ms", "15ms", "15ms", "18ms", "20ms", "+16ms"]
	for i in range(samples.size()):
		var val: int = samples[i]
		var bar_h: float = float(val) * 1.8
		var bx: float = 92.0 + float(i) * 52.0
		var by: float = 52.0 - bar_h
		var is_sixth: bool = (i == 5)
		var bar_col: Color = (Color("#00E676") if _challenge_solved else Color("#FFD700")) if is_sixth else Color("#00E5FF")

		var bar := ColorRect.new()
		bar.position = Vector2(bx, by)
		bar.size = Vector2(36, bar_h)
		bar.color = Color(bar_col.r, bar_col.g, bar_col.b, 0.38)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent_ctrl.add_child(bar)
		_add_box_outline(parent_ctrl, Rect2(bx, by, 36, bar_h), bar_col)

		var lbl := Label.new()
		lbl.text = labels[i]
		lbl.position = Vector2(bx - 4, 53)
		lbl.size = Vector2(44, 12)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var font_res := load("res://assets/characters/ninja_adventure/theme/font_normal.ttf") as Font
		if font_res:
			lbl.add_theme_font_override("font", font_res)
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", bar_col)
		lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.95))
		lbl.add_theme_constant_override("outline_size", 2)
		parent_ctrl.add_child(lbl)

	# línea del promedio
	_add_wire(parent_ctrl, Vector2(86, 23), Vector2(400, 23), Color(1, 0.85, 0, 0.75))
	var summary_text: String = "MEDIA:\n16 ms" if _challenge_solved else "SUMA(5)=80\nMEDIA=16ms"
	_add_diagram_chip(parent_ctrl, Rect2(410, 14, 94, 38), summary_text, Color("#FFD700"), Color(0.06, 0.12, 0.2, 0.96))

func _add_diagram_chip(parent_ctrl: Control, rect: Rect2, text_str: String, border_col: Color, bg_col: Color) -> void:
	var bg := ColorRect.new()
	bg.position = rect.position
	bg.size = rect.size
	bg.color = bg_col
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_ctrl.add_child(bg)
	_add_box_outline(parent_ctrl, rect, border_col)

	var lbl := Label.new()
	lbl.text = text_str
	var line_count: int = text_str.count("\n") + 1
	var text_h: float = float(line_count) * 9.0
	lbl.position = Vector2(rect.position.x, rect.position.y + roundf((rect.size.y - text_h) * 0.5))
	lbl.size = Vector2(rect.size.x, text_h + 4.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var font_res := load("res://assets/characters/ninja_adventure/theme/font_normal.ttf") as Font
	if font_res:
		lbl.add_theme_font_override("font", font_res)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", border_col)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.95))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_constant_override("line_spacing", 1)
	parent_ctrl.add_child(lbl)

func _add_wire(parent_ctrl: Control, from_pt: Vector2, to_pt: Vector2, col: Color) -> void:
	var line := Line2D.new()
	line.width = 1.5
	line.default_color = col
	line.add_point(from_pt)
	line.add_point(Vector2((from_pt.x + to_pt.x) * 0.5, from_pt.y))
	line.add_point(Vector2((from_pt.x + to_pt.x) * 0.5, to_pt.y))
	line.add_point(to_pt)
	parent_ctrl.add_child(line)

func _add_box_outline(parent_ctrl: Control, rect: Rect2, col: Color) -> void:
	var line := Line2D.new()
	line.width = 1.0
	line.closed = true
	line.default_color = col
	line.add_point(rect.position)
	line.add_point(Vector2(rect.end.x, rect.position.y))
	line.add_point(rect.end)
	line.add_point(Vector2(rect.position.x, rect.end.y))
	parent_ctrl.add_child(line)
