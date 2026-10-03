extends RichTextLabel
class_name TypewriterLabel

const DEFAULT_DELAY: float = 0.033

signal typing_end()
signal dialog_processed(index:int)
signal single_dialog_end(index:int)
## 即将开始打字的这句对话，立绘节点靠它自动切换表情。
signal dialog_started(dialog: BaseDialog)
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
	var dialog := dialog_list[dialog_index]
	dialog_processed.emit(dialog_index)
	dialog_started.emit(dialog)
	var parsed = _parse(dialog.content)
	text = parsed.text
	visible_characters = 0
	_typewrite(parsed.pauses, parsed.speeds,dialog_index)
	dialog_index += 1

func _physics_process(_delta: float) -> void:
	# 输入统一从 BattleInput 按物理帧读（回放时也是从这里读，所以可复现）
	if BattleInput.pressed(&"skip"):
		if _running:
			skip()
		else:
			_display_next_dialog()
	if BattleInput.just_pressed(&"accept"):
		_display_next_dialog()
	if BattleInput.just_pressed(&"cancel"):
		skip()

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
		# 按物理帧等：打字速度也必须是 tick 驱动的，否则回放里“这一下 Z 是推进还是被忽略”会分叉
		await BattleClock.wait_seconds(d)
		i += 1
		total=get_total_character_count()
	_running = false
	single_dialog_end.emit(index)

func skip():
	if _running:
		_running = false
	visible_ratio = 1


func end():
	_running = false
	# 先关掉输入处理再发信号：可能有人在这个信号里立刻让同一个标签开下一段对话，
	# 关输入的收尾要是排在后面，新对话就再也按不动了
	set_process_input(false)
	set_physics_process(false)
	typing_end.emit()
	
