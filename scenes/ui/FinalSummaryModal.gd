class_name FinalSummaryModal
extends CanvasLayer

## FinalSummaryModal.gd — Academic Graduation & Thought Axes Certification for VirtuXperience 2D.
## Displays Level, Total XP, Fragments count, 6 Thought Axis progress bars,
## and exports local standalone printable HTML certificates (user://certificado_virtuxperience.html)
## plus clipboard extracts with SHA256 checksums.

signal modal_closed
signal certificate_generated(file_path: String)
signal extract_copied(text: String)

const CERT_FILE_PATH: String = "user://certificado_virtuxperience.html"
const TARGET_AXIS_XP: float = 310.0

const AXIS_DISPLAY_DATA: Array[Dictionary] = [
	{
		"name": "Pensamiento Lógico y Numérico",
		"sub": "(NeuroMath)",
		"color": Color("#00E5FF")
	},
	{
		"name": "Competencia Léxica y Lectura Crítica",
		"sub": "(ComunicArte)",
		"color": Color("#FF2A85")
	},
	{
		"name": "Pensamiento Estratégico y Organizacional",
		"sub": "(Gerencia+)",
		"color": Color("#4682B4")
	},
	{
		"name": "Innovación y Modelado de Emprendimiento",
		"sub": "(ActivaTuIdea)",
		"color": Color("#FF8C00")
	},
	{
		"name": "Compromiso Ético y Responsabilidad Social",
		"sub": "(LatidoSocial)",
		"color": Color("#4CAF50")
	},
	{
		"name": "Ciudadanía Activa y Habilidades para la Vida",
		"sub": "(VoxCivitas)",
		"color": Color("#9C27B0")
	}
]

const HTML_CERTIFICATE_TEMPLATE: String = """<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>Certificado de Honor - VirtuXperience UNIMINUTO</title>
  <style>
    @page {
      size: A4 landscape;
      margin: 12mm;
    }
    * { box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      margin: 0;
      padding: 24px;
      background: #0d1117;
      color: #e6edf3;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
    }
    .cert-container {
      width: 100%;
      max-width: 960px;
      border: 6px double #d4af37;
      background: linear-gradient(135deg, #161b22 0%, #0e1626 100%);
      padding: 36px 48px;
      border-radius: 8px;
      box-shadow: 0 0 30px rgba(212, 175, 55, 0.25);
      position: relative;
    }
    .header-logo {
      text-align: center;
      letter-spacing: 3px;
      color: #8b949e;
      font-size: 13px;
      text-transform: uppercase;
      margin-bottom: 8px;
    }
    h1 {
      text-align: center;
      color: #ffd700;
      font-size: 28px;
      margin: 4px 0 16px 0;
      letter-spacing: 1px;
      font-weight: 700;
      border-bottom: 1px solid rgba(212, 175, 55, 0.3);
      padding-bottom: 12px;
    }
    .prose {
      text-align: center;
      font-size: 15px;
      line-height: 1.6;
      color: #c9d1d9;
      margin: 18px 0;
    }
    .highlight-name {
      font-size: 20px;
      color: #58a6ff;
      font-weight: bold;
    }
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 16px;
      margin: 24px 0;
      background: rgba(255, 255, 255, 0.03);
      padding: 16px;
      border-radius: 6px;
      border: 1px solid rgba(255, 255, 255, 0.08);
      text-align: center;
    }
    .metric-value {
      font-size: 22px;
      font-weight: bold;
      color: #00e5ff;
    }
    .metric-label {
      font-size: 11px;
      text-transform: uppercase;
      color: #8b949e;
      margin-top: 4px;
    }
    .axes-section {
      margin-top: 20px;
      text-align: left;
    }
    .axes-title {
      font-size: 13px;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: #d4af37;
      margin-bottom: 10px;
      font-weight: 600;
    }
    .axis-row {
      display: flex;
      justify-content: space-between;
      margin-bottom: 6px;
      font-size: 13px;
    }
    .axis-bar-container {
      width: 55%;
      height: 8px;
      background: #21262d;
      border-radius: 4px;
      overflow: hidden;
      margin-top: 4px;
    }
    .axis-bar-fill {
      height: 100%;
      background: linear-gradient(90deg, #ff2a85, #00e5ff);
    }
    .footer {
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      margin-top: 32px;
      padding-top: 16px;
      border-top: 1px dashed rgba(212, 175, 55, 0.3);
      font-size: 11px;
      color: #8b949e;
    }
    .seal-box {
      text-align: center;
      border: 2px solid #d4af37;
      border-radius: 50%;
      width: 72px;
      height: 72px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 9px;
      color: #ffd700;
      font-weight: bold;
      text-transform: uppercase;
    }
    @media print {
      body { background: #ffffff; color: #111111; }
      .cert-container { background: #ffffff; box-shadow: none; border-color: #333333; }
      h1 { color: #111111; border-color: #333333; }
      .metric-value { color: #005577; }
      .prose { color: #222222; }
      .axis-bar-container { background: #e0e0e0; }
      .axis-bar-fill { background: #333333; }
    }
  </style>
</head>
<body>
  <div class="cert-container">
    <div class="header-logo">Corporación Universitaria Minuto de Dios — UNIMINUTO</div>
    <h1>CERTIFICADO DE MAESTRÍA COGNITIVA</h1>
    <div class="prose">
      Por haber demostrado perseverancia y excelencia en el entorno de aprendizaje lúdico<br>
      se confiere el presente reconocimiento al estudiante de <span class="highlight-name">VirtuXperience 2D</span>
      tras restaurar con éxito la armonía y conocimiento en los 6 biomas de la isla universitaria.
    </div>

    <div class="metrics-grid">
      <div>
        <div class="metric-value">NIVEL {{LEVEL}}</div>
        <div class="metric-label">Rango Académico</div>
      </div>
      <div>
        <div class="metric-value">{{TOTAL_XP}} XP</div>
        <div class="metric-label">Experiencia Total</div>
      </div>
      <div>
        <div class="metric-value">{{FRAGMENTS_COUNT}} / 6</div>
        <div class="metric-label">Fragmentos del Nexo</div>
      </div>
    </div>

    <div class="axes-section">
      <div class="axes-title">Dominio de Ejes de Pensamiento y Competencias</div>
      <div class="axis-row">
        <span>Razonamiento Cuantitativo y Lógica (NeuroMath)</span>
        <div class="axis-bar-container"><div class="axis-bar-fill" style="width: {{XP_PERCENT_NEUROMATH}}%;"></div></div>
        <span>{{XP_NEUROMATH}} XP</span>
      </div>
      <div class="axis-row">
        <span>Competencia Léxica y Lectura Crítica (ComunicArte)</span>
        <div class="axis-bar-container"><div class="axis-bar-fill" style="width: {{XP_PERCENT_COMUNICARTE}}%;"></div></div>
        <span>{{XP_COMUNICARTE}} XP</span>
      </div>
      <div class="axis-row">
        <span>Pensamiento Estratégico y Organizacional (Gerencia+)</span>
        <div class="axis-bar-container"><div class="axis-bar-fill" style="width: {{XP_PERCENT_GERENCIA}}%;"></div></div>
        <span>{{XP_GERENCIA}} XP</span>
      </div>
      <div class="axis-row">
        <span>Innovación y Modelado de Emprendimiento (ActivaTuIdea)</span>
        <div class="axis-bar-container"><div class="axis-bar-fill" style="width: {{XP_PERCENT_ACTIVATUIDEA}}%;"></div></div>
        <span>{{XP_ACTIVATUIDEA}} XP</span>
      </div>
      <div class="axis-row">
        <span>Compromiso Ético y Responsabilidad Social (LatidoSocial)</span>
        <div class="axis-bar-container"><div class="axis-bar-fill" style="width: {{XP_PERCENT_LATIDOSOCIAL}}%;"></div></div>
        <span>{{XP_LATIDOSOCIAL}} XP</span>
      </div>
      <div class="axis-row">
        <span>Ciudadanía Activa y Habilidades para la Vida (VoxCivitas)</span>
        <div class="axis-bar-container"><div class="axis-bar-fill" style="width: {{XP_PERCENT_VOXCIVITAS}}%;"></div></div>
        <span>{{XP_VOXCIVITAS}} XP</span>
      </div>
    </div>

    <div class="footer">
      <div>
        <strong>Fecha de Certificación:</strong> {{DATE_STRING}}<br>
        <strong>Código Único de Verificación:</strong> VX2D-{{VERIFICATION_HASH}}
      </div>
      <div class="seal-box">
        SELLO<br>NEXO
      </div>
      <div style="text-align: right;">
        <strong>VirtuXperience 2D Platform</strong><br>
        Consejo Académico de Gamificación
      </div>
    </div>
  </div>
</body>
</html>"""

@onready var close_button: Button = $ModalBox/MarginContainer/VBox/Header/CloseButton
@onready var preview_banner: PanelContainer = $ModalBox/MarginContainer/VBox/PreviewBanner
@onready var banner_label: Label = $ModalBox/MarginContainer/VBox/PreviewBanner/BannerLabel
@onready var level_val: Label = $ModalBox/MarginContainer/VBox/MetricsGrid/CardLevel/VBox/Val
@onready var xp_val: Label = $ModalBox/MarginContainer/VBox/MetricsGrid/CardXP/VBox/Val
@onready var frags_val: Label = $ModalBox/MarginContainer/VBox/MetricsGrid/CardFragments/VBox/Val
@onready var axes_list: VBoxContainer = $ModalBox/MarginContainer/VBox/AxesList
@onready var generate_cert_button: Button = $ModalBox/MarginContainer/VBox/ButtonsRow/GenerateCertButton
@onready var copy_clipboard_button: Button = $ModalBox/MarginContainer/VBox/ButtonsRow/CopyClipboardButton
@onready var feedback_label: Label = $ModalBox/MarginContainer/VBox/FeedbackLabel

var custom_game_state: Node = null
var _row_controls: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	add_to_group("final_summary_modal")
	add_to_group("ui_modal")
	visible = false

	_ensure_nodes()

	if close_button and not close_button.pressed.is_connected(close_summary):
		close_button.pressed.connect(close_summary)
	if generate_cert_button and not generate_cert_button.pressed.is_connected(_on_generate_cert_pressed):
		generate_cert_button.pressed.connect(_on_generate_cert_pressed)
	if copy_clipboard_button and not copy_clipboard_button.pressed.is_connected(_on_copy_clipboard_pressed):
		copy_clipboard_button.pressed.connect(_on_copy_clipboard_pressed)

	_build_axes_ui()

func _ensure_nodes() -> void:
	if close_button == null:
		close_button = get_node_or_null("ModalBox/MarginContainer/VBox/Header/CloseButton")
	if preview_banner == null:
		preview_banner = get_node_or_null("ModalBox/MarginContainer/VBox/PreviewBanner")
	if banner_label == null:
		banner_label = get_node_or_null("ModalBox/MarginContainer/VBox/PreviewBanner/BannerLabel")
	if level_val == null:
		level_val = get_node_or_null("ModalBox/MarginContainer/VBox/MetricsGrid/CardLevel/VBox/Val")
	if xp_val == null:
		xp_val = get_node_or_null("ModalBox/MarginContainer/VBox/MetricsGrid/CardXP/VBox/Val")
	if frags_val == null:
		frags_val = get_node_or_null("ModalBox/MarginContainer/VBox/MetricsGrid/CardFragments/VBox/Val")
	if axes_list == null:
		axes_list = get_node_or_null("ModalBox/MarginContainer/VBox/AxesList")
	if generate_cert_button == null:
		generate_cert_button = get_node_or_null("ModalBox/MarginContainer/VBox/ButtonsRow/GenerateCertButton")
	if copy_clipboard_button == null:
		copy_clipboard_button = get_node_or_null("ModalBox/MarginContainer/VBox/ButtonsRow/CopyClipboardButton")
	if feedback_label == null:
		feedback_label = get_node_or_null("ModalBox/MarginContainer/VBox/FeedbackLabel")

func _get_game_state() -> Node:
	if custom_game_state != null:
		return custom_game_state
	if is_inside_tree():
		if has_node("/root/GameState"):
			return get_node("/root/GameState")
		var tree := get_tree()
		if tree and tree.root and tree.root.has_node("GameState"):
			return tree.root.get_node("GameState")
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null

func _build_axes_ui() -> void:
	_ensure_nodes()
	if axes_list == null:
		return

	# Clear existing dynamic rows if any
	for child in axes_list.get_children():
		child.queue_free()
	_row_controls.clear()

	for item in AXIS_DISPLAY_DATA:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var name_lbl := Label.new()
		name_lbl.text = "%s %s" % [item.name, item.sub]
		name_lbl.custom_minimum_size = Vector2(190, 0)
		name_lbl.add_theme_font_size_override("font_size", 7)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(210, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Flat styleboxes for crisp pixel-art appearance
		var sb_bg := StyleBoxFlat.new()
		sb_bg.bg_color = Color("#21262D")
		sb_bg.corner_radius_top_left = 3
		sb_bg.corner_radius_top_right = 3
		sb_bg.corner_radius_bottom_right = 3
		sb_bg.corner_radius_bottom_left = 3
		bar.add_theme_stylebox_override("background", sb_bg)

		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = item.color
		sb_fill.corner_radius_top_left = 3
		sb_fill.corner_radius_top_right = 3
		sb_fill.corner_radius_bottom_right = 3
		sb_fill.corner_radius_bottom_left = 3
		bar.add_theme_stylebox_override("fill", sb_fill)

		row.add_child(bar)

		var val_lbl := Label.new()
		val_lbl.text = "0 XP (0%)"
		val_lbl.custom_minimum_size = Vector2(85, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_font_size_override("font_size", 7)
		val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(val_lbl)

		axes_list.add_child(row)
		_row_controls.append({
			"axis_name": item.name,
			"bar": bar,
			"val_lbl": val_lbl
		})

## Opens the summary modal and populates fresh data from GameState.
func open_summary(gs: Node = null) -> void:
	if gs != null:
		custom_game_state = gs
	_ensure_nodes()
	if _row_controls.is_empty():
		_build_axes_ui()
	_refresh_data()
	visible = true

func open(gs: Node = null) -> void:
	open_summary(gs)

func show_modal() -> void:
	open_summary()

func close_summary() -> void:
	visible = false
	modal_closed.emit()

func close() -> void:
	close_summary()

func is_open() -> bool:
	return visible

func _refresh_data() -> void:
	_ensure_nodes()
	var gs := _get_game_state()
	var lvl: int = gs.level if gs and "level" in gs else 1
	var xp: int = gs.total_xp if gs and "total_xp" in gs else 0
	var frags: int = gs.get_fragment_count() if gs and gs.has_method("get_fragment_count") else 0

	if level_val:
		level_val.text = "NIVEL %d" % lvl
	if xp_val:
		xp_val.text = "%d XP" % xp
	if frags_val:
		frags_val.text = "%d / 6" % frags

	var is_culmination: bool = frags >= 6

	if preview_banner:
		preview_banner.visible = not is_culmination
		if is_culmination:
			if banner_label:
				banner_label.text = "¡MAESTRÍA COGNITIVA ALCANZADA! Todos los biomas han sido restaurados."
		else:
			if banner_label:
				banner_label.text = "MODO VISTA PREVIA: Completa los 6 biomas para emitir tu certificación de honor oficial."

	if generate_cert_button:
		if is_culmination:
			generate_cert_button.disabled = false
			generate_cert_button.text = "GENERAR CERTIFICADO HTML (IMPRIMIBLE)"
			generate_cert_button.modulate = Color(1.0, 0.9, 0.4)
		else:
			generate_cert_button.disabled = true
			generate_cert_button.text = "CERTIFICADO (Requiere 6/6 Fragmentos)"
			generate_cert_button.modulate = Color(0.7, 0.7, 0.7, 0.8)

	if feedback_label:
		feedback_label.text = ""

	# Refresh thought axes bars
	for row_dict in _row_controls:
		var ax_name: String = row_dict["axis_name"]
		var bar: ProgressBar = row_dict["bar"]
		var val_lbl: Label = row_dict["val_lbl"]
		var axis_xp: int = gs.get_axis_xp(ax_name) if gs and gs.has_method("get_axis_xp") else 0
		var pct: int = clampi(int(round((float(axis_xp) / TARGET_AXIS_XP) * 100.0)), 0, 100)

		if bar:
			bar.value = pct
		if val_lbl:
			val_lbl.text = "%d XP (%d%%)" % [axis_xp, pct]

## Static helper to produce the completed standalone HTML document string.
static func generate_html_certificate(gs: Node = null) -> String:
	var lvl: int = gs.level if gs and "level" in gs else 1
	var xp: int = gs.total_xp if gs and "total_xp" in gs else 0
	var frags: int = gs.get_fragment_count() if gs and gs.has_method("get_fragment_count") else 0

	var xp_nm: int = gs.get_axis_xp("Pensamiento Lógico y Numérico") if gs and gs.has_method("get_axis_xp") else 0
	var xp_ca: int = gs.get_axis_xp("Competencia Léxica y Lectura Crítica") if gs and gs.has_method("get_axis_xp") else 0
	var xp_ge: int = gs.get_axis_xp("Pensamiento Estratégico y Organizacional") if gs and gs.has_method("get_axis_xp") else 0
	var xp_ac: int = gs.get_axis_xp("Innovación y Modelado de Emprendimiento") if gs and gs.has_method("get_axis_xp") else 0
	var xp_ls: int = gs.get_axis_xp("Compromiso Ético y Responsabilidad Social") if gs and gs.has_method("get_axis_xp") else 0
	if xp_ls == 0 and gs and gs.has_method("get_axis_xp"):
		xp_ls = max(gs.get_axis_xp("latidosocial"), gs.get_axis_xp("misionales"))
	var xp_vc: int = gs.get_axis_xp("Ciudadanía Activa y Habilidades para la Vida") if gs and gs.has_method("get_axis_xp") else 0
	if xp_vc == 0 and gs and gs.has_method("get_axis_xp"):
		xp_vc = gs.get_axis_xp("voxcivitas")

	var pct_nm: int = clampi(int(round((float(xp_nm) / TARGET_AXIS_XP) * 100.0)), 0, 100)
	var pct_ca: int = clampi(int(round((float(xp_ca) / TARGET_AXIS_XP) * 100.0)), 0, 100)
	var pct_ge: int = clampi(int(round((float(xp_ge) / TARGET_AXIS_XP) * 100.0)), 0, 100)
	var pct_ac: int = clampi(int(round((float(xp_ac) / TARGET_AXIS_XP) * 100.0)), 0, 100)
	var pct_ls: int = clampi(int(round((float(xp_ls) / TARGET_AXIS_XP) * 100.0)), 0, 100)
	var pct_vc: int = clampi(int(round((float(xp_vc) / TARGET_AXIS_XP) * 100.0)), 0, 100)

	var dt := Time.get_datetime_dict_from_system()
	var date_str := "%02d/%02d/%04d" % [dt.day, dt.month, dt.year]

	var raw_payload := "VX2D|LVL:%d|XP:%d|FRAGS:%d|NM:%d|CA:%d|GE:%d|AC:%d|LS:%d|VC:%d|DATE:%s" % [
		lvl, xp, frags, xp_nm, xp_ca, xp_ge, xp_ac, xp_ls, xp_vc, date_str
	]
	var v_hash := raw_payload.sha256_text().substr(0, 12).to_upper()

	var html := HTML_CERTIFICATE_TEMPLATE
	html = html.replace("{{LEVEL}}", str(lvl))
	html = html.replace("{{TOTAL_XP}}", str(xp))
	html = html.replace("{{FRAGMENTS_COUNT}}", str(frags))
	html = html.replace("{{XP_NEUROMATH}}", str(xp_nm))
	html = html.replace("{{XP_COMUNICARTE}}", str(xp_ca))
	html = html.replace("{{XP_GERENCIA}}", str(xp_ge))
	html = html.replace("{{XP_ACTIVATUIDEA}}", str(xp_ac))
	html = html.replace("{{XP_LATIDOSOCIAL}}", str(xp_ls))
	html = html.replace("{{XP_VOXCIVITAS}}", str(xp_vc))
	html = html.replace("{{XP_PERCENT_NEUROMATH}}", str(pct_nm))
	html = html.replace("{{XP_PERCENT_COMUNICARTE}}", str(pct_ca))
	html = html.replace("{{XP_PERCENT_GERENCIA}}", str(pct_ge))
	html = html.replace("{{XP_PERCENT_ACTIVATUIDEA}}", str(pct_ac))
	html = html.replace("{{XP_PERCENT_LATIDOSOCIAL}}", str(pct_ls))
	html = html.replace("{{XP_PERCENT_VOXCIVITAS}}", str(pct_vc))
	html = html.replace("{{DATE_STRING}}", date_str)
	html = html.replace("{{VERIFICATION_HASH}}", v_hash)

	return html

## Saves HTML certificate to user://certificado_virtuxperience.html and returns the native absolute OS path.
static func export_html_certificate_to_file(gs: Node = null) -> String:
	var html_str := generate_html_certificate(gs)
	var file := FileAccess.open(CERT_FILE_PATH, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("FinalSummaryModal: Cannot open %s for writing. Error: %d" % [CERT_FILE_PATH, err])
		return ""
	file.store_string(html_str)
	file.close()

	return ProjectSettings.globalize_path(CERT_FILE_PATH)

## Static helper to generate the official summary clipboard text.
static func generate_clipboard_extract(gs: Node = null) -> String:
	var lvl: int = gs.level if gs and "level" in gs else 1
	var xp: int = gs.total_xp if gs and "total_xp" in gs else 0
	var frags: int = gs.get_fragment_count() if gs and gs.has_method("get_fragment_count") else 0
	var dt := Time.get_datetime_dict_from_system()
	var date_str := "%02d/%02d/%04d" % [dt.day, dt.month, dt.year]

	var axes_lines: Array[String] = []
	for item in AXIS_DISPLAY_DATA:
		var ax_name: String = item.name
		var ax_xp: int = gs.get_axis_xp(ax_name) if gs and gs.has_method("get_axis_xp") else 0
		var pct: int = clampi(int(round((float(ax_xp) / TARGET_AXIS_XP) * 100.0)), 0, 100)
		axes_lines.append("  ✦ %s %s: %d XP (%d%%)" % [ax_name, item.sub, ax_xp, pct])

	var raw_payload := "VX2D|LVL:%d|XP:%d|FRAGS:%d|DATE:%s" % [lvl, xp, frags, date_str]
	var v_hash := raw_payload.sha256_text().substr(0, 12).to_upper()

	return (
		"==========================================================\n" +
		"  GRAN LOGIA DEL CONOCIMIENTO — VIRTUXPERIENCE 2D\n" +
		"         CERTIFICADO DE MAESTRÍA COGNITIVA\n" +
		"==========================================================\n" +
		"Institución : Corporación Universitaria Minuto de Dios — UNIMINUTO\n" +
		"Fecha       : %s\n" % date_str +
		"Rango       : Nivel %d\n" % lvl +
		"Total XP    : %d XP\n" % xp +
		"Fragmentos  : %d / 6\n\n" % frags +
		"DOMINIO POR EJES DE PENSAMIENTO:\n" +
		"\n".join(axes_lines) + "\n\n" +
		"CÓDIGO ÚNICO DE VERIFICACIÓN:\n" +
		"VX2D-%s\n" % v_hash +
		"=========================================================="
	)

func _on_generate_cert_pressed() -> void:
	var gs := _get_game_state()
	var abs_path := export_html_certificate_to_file(gs)
	if abs_path.is_empty():
		if feedback_label:
			feedback_label.text = "Error al escribir archivo de certificado."
			feedback_label.modulate = Color("#FF5252")
		return

	var err := OS.shell_open(abs_path)
	if err != OK:
		# Fallback if shell_open is not supported or running in headless mode
		push_warning("FinalSummaryModal: OS.shell_open returned code %d. File saved at %s" % [err, abs_path])

	if feedback_label:
		feedback_label.text = "¡Certificado HTML generado con éxito!"
		feedback_label.modulate = Color("#00E676")

	certificate_generated.emit(abs_path)

static var _last_clipboard_text: String = ""

static func copy_to_clipboard(text: String) -> void:
	_last_clipboard_text = text
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(text)

static func get_clipboard_text() -> String:
	if DisplayServer.get_name() != "headless":
		var cb := DisplayServer.clipboard_get()
		if not cb.is_empty():
			return cb
	return _last_clipboard_text

func _on_copy_clipboard_pressed() -> void:
	var gs := _get_game_state()
	var extract_str := generate_clipboard_extract(gs)
	copy_to_clipboard(extract_str)

	if feedback_label:
		feedback_label.text = "¡Extracto oficial copiado al portapapeles!"
		feedback_label.modulate = Color("#00E676")

	extract_copied.emit(extract_str)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if get_viewport():
			get_viewport().set_input_as_handled()
		close_summary()
