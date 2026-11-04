extends CanvasLayer

## Cuadro de diálogo. Muestra el nombre de quien habla y el texto por páginas.
## Con E o click pasa a la siguiente página; en la última se cierra y avisa con dialog_finished.

signal dialog_finished

@onready var modal_box: NinePatchRect = $ModalBox
@onready var speaker_name: Label = $ModalBox/MarginContainer/VBoxContainer/SpeakerName
@onready var body_text: RichTextLabel = $ModalBox/MarginContainer/VBoxContainer/BodyText
@onready var prompt_indicator: Control = $ModalBox/MarginContainer/VBoxContainer/Footer/PromptIndicator

var _dialog_lines: Array[String] = []
var _current_page: int = 0
var _is_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialog_modal")
	# arranca escondido hasta que alguien llame start_dialog()
	visible = false
	_is_active = false
	
	if modal_box and not modal_box.gui_input.is_connected(_on_modal_box_gui_input):
		modal_box.gui_input.connect(_on_modal_box_gui_input)

func _process(_delta: float) -> void:
	# el [E] parpadea suave (alpha va de 0.3 a 1.0)
	if _is_active and is_instance_valid(prompt_indicator):
		prompt_indicator.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.007)

func _ensure_nodes() -> void:
	if modal_box == null:
		modal_box = get_node_or_null("ModalBox")
	if speaker_name == null:
		speaker_name = get_node_or_null("ModalBox/MarginContainer/VBoxContainer/SpeakerName")
	if body_text == null:
		body_text = get_node_or_null("ModalBox/MarginContainer/VBoxContainer/BodyText")
	if prompt_indicator == null:
		prompt_indicator = get_node_or_null("ModalBox/MarginContainer/VBoxContainer/Footer/PromptIndicator")

## Empieza un diálogo. Ej: start_dialog("AXION-7", ["Hola", "Chao"]) -> 2 páginas
func start_dialog(speaker: String, lines: Array[String], speaker_color: Color = Color.WHITE) -> void:
	_ensure_nodes()
	if lines.is_empty():
		close_dialog()
		return

	_dialog_lines = lines.duplicate()
	_current_page = 0
	_is_active = true
	visible = true

	if is_instance_valid(speaker_name):
		speaker_name.text = speaker
		speaker_name.modulate = speaker_color

	_display_current_page()

## Igual que start_dialog pero acepta un Array normal (por ejemplo de un JSON)
func show_dialog(speaker: String, lines: Array, speaker_color: Color = Color.WHITE) -> void:
	var typed_lines: Array[String] = []
	for item in lines:
		typed_lines.append(str(item))
	start_dialog(speaker, typed_lines, speaker_color)

## Pasa a la siguiente página; si no hay más, cierra
func advance_dialog() -> void:
	if not _is_active:
		return

	_current_page += 1
	if _current_page < _dialog_lines.size():
		_display_current_page()
	else:
		close_dialog()

## Cierra el cuadro y avisa con dialog_finished
func close_dialog() -> void:
	_is_active = false
	visible = false
	_dialog_lines.clear()
	_current_page = 0
	dialog_finished.emit()

func _display_current_page() -> void:
	_ensure_nodes()
	if _current_page < _dialog_lines.size() and is_instance_valid(body_text):
		body_text.text = _dialog_lines[_current_page]

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _is_active:
		return

	# tecla E
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		advance_dialog()
		return

	# click izquierdo en cualquier lado
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		advance_dialog()
		return

func _on_modal_box_gui_input(event: InputEvent) -> void:
	if not visible or not _is_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		advance_dialog()

func is_active() -> bool:
	return _is_active

func get_current_page() -> int:
	return _current_page

func get_total_pages() -> int:
	return _dialog_lines.size()
