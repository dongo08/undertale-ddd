extends RichTextLabel
class_name TypewriterLabel

const DEFAULT_DELAY: float = 0.033

signal typing_end()
signal dialog_processed(index:int)
signal single_dialog_end(index:int)
@export var snd_txt: AudioStreamPlayer

var dialog_list: Array[BaseDialog]
var dialog_index: int = 0
var _running: bool = false

func _ready() -> void:
	set_process_input(false)
	set_physics_process(false)

func show_dialog(dialogs: Array[BaseDialog]):
	dialog_index = 0
	dialog_list = dialogs
	_running = false
	show()
	set_process_input(true)
	set_physics_process(true)
	_display_next_dialog()

func close():
	dialog_index = 0
	dialog_list = []
	hide()
	set_process_input(false)
	set_physics_process(false)
	visible_characters = 0
func _display_next_dialog():
	if _running:
		return
	if dialog_index >= dialog_list.size() or not dialog_list[dialog_index]:
		end()
		return
	dialog_processed.emit(dialog_index)
	var parsed = _parse(dialog_list[dialog_index].content)
	text = parsed.text
	visible_characters = 0
	_typewrite(parsed.pauses, parsed.speeds,dialog_index)
	dialog_index += 1

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("skip"):
		if _running:
			skip()
		else:
			_display_next_dialog()

func _parse(raw: String) -> Dictionary:
	var clean := ""
	var pauses := {}
	var speeds := {}
	var re := RegEx.new()
	re.compile("\\[([pw]):([\\d.]+)\\]")
	var last := 0
	for m in re.search_all(raw):
		clean += raw.substr(last, m.get_start() - last)
		var pos := clean.length()
		var kind := m.get_string(1)
		var val := float(m.get_string(2))
		match kind:
			"p": pauses[pos] = val
			"w": speeds[pos] = val
		last = m.get_end()
	clean += raw.substr(last)
	return {"text": clean, "pauses": pauses, "speeds": speeds}

func _typewrite(pauses: Dictionary, speeds: Dictionary,index:int):
	_running = true
	var total := get_total_character_count()
	var delay := DEFAULT_DELAY
	var i := 0
	while i < total and _running:
		visible_characters += 1
		if snd_txt and get_parsed_text()[i]!=" ":
			snd_txt.play()
		if speeds.has(i + 1):
			delay = speeds[i + 1]
		var d := delay
		if pauses.has(i + 1):
			d += pauses[i + 1]
		await get_tree().create_timer(d).timeout
		i += 1
	_running = false
	single_dialog_end.emit(index)

func skip():
	if _running:
		_running = false
	visible_ratio = 1

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("accept"):
		_display_next_dialog()
	elif event.is_action_pressed("cancel"):
		skip()
	



func end():
	_running = false
	typing_end.emit()
	set_process_input(false)
	set_physics_process(false)
	
