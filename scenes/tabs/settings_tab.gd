extends MarginContainer
## 설정 탭 (GDD 9절): 저장 문자열 내보내기(TextEdit와 복사 버튼), 가져오기, 데이터 초기화(두 번 확인).
## Save의 함수만 부르고 결과를 표시한다. 아래 상수는 배치용이다.

const MARGIN: int = 16
const GAP: int = 12
const TEXT_HEIGHT: float = 180.0
const BUTTON_HEIGHT: float = 72.0
const RESET_ARM_SECONDS: float = 6.0   # 확인을 기다리는 시간. 지나면 처음으로 돌아간다
const RESET_STEPS: PackedStringArray = ["데이터 초기화", "정말 초기화할까요?", "마지막 확인: 한 번 더"]
const STATUS_COLOR := Color("b8b4c8")
const DANGER_COLOR := Color("ff8c42")

var _text: TextEdit
var _status: Label
var _reset_button: Button
var _reset_step: int = 0
var _reset_left: float = 0.0


func _ready() -> void:
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, MARGIN)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	add_child(column)

	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(0.0, TEXT_HEIGHT)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.placeholder_text = "내보내기를 누르면 저장 문자열이 여기에 나타납니다. 가져오려면 여기에 붙여넣으세요"
	column.add_child(_text)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	column.add_child(row)
	row.add_child(_make_button("내보내기", _on_export_pressed))
	row.add_child(_make_button("복사", _on_copy_pressed))
	row.add_child(_make_button("가져오기", _on_import_pressed))

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", STATUS_COLOR)
	column.add_child(_status)
	column.add_child(HSeparator.new())

	var danger_row := HBoxContainer.new()
	danger_row.add_theme_constant_override("separation", GAP)
	column.add_child(danger_row)
	danger_row.add_child(_make_button("지금 저장", Save.save_game))
	_reset_button = _make_button(RESET_STEPS[0], _on_reset_pressed)
	danger_row.add_child(_reset_button)

	Save.saved.connect(_on_saved)


## 초기화 확인은 시간이 지나면 풀린다
func _process(delta: float) -> void:
	if _reset_step == 0:
		return
	_reset_left -= delta
	if _reset_left <= 0.0:
		_set_reset_step(0)
		_status.text = "초기화를 취소했습니다"


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _on_export_pressed() -> void:
	_text.text = Save.export_string()
	_status.text = "내보냈습니다. 복사해서 안전한 곳에 보관하세요"


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_text.text)
	_status.text = "복사했습니다" if not _text.text.is_empty() else "복사할 내용이 없습니다"


func _on_import_pressed() -> void:
	if Save.import_string(_text.text):
		_status.text = "가져왔습니다"
	else:
		_status.text = "잘못된 저장 문자열입니다"


func _on_saved() -> void:
	_status.text = "저장했습니다 · %s" % Time.get_time_string_from_system()


## 세 번 눌러야 지운다: 초기화 → 정말? → 마지막 확인
func _on_reset_pressed() -> void:
	if _reset_step < RESET_STEPS.size() - 1:
		_set_reset_step(_reset_step + 1)
		_status.text = "%d초 안에 계속 누르면 모든 데이터가 사라집니다" % roundi(RESET_ARM_SECONDS)
		return
	_set_reset_step(0)
	Save.reset_data()
	_text.text = ""
	_status.text = "초기화했습니다. 새 판을 시작합니다"


func _set_reset_step(step: int) -> void:
	_reset_step = step
	_reset_left = RESET_ARM_SECONDS
	_reset_button.text = RESET_STEPS[step]
	if step > 0:
		_reset_button.add_theme_color_override("font_color", DANGER_COLOR)
	else:
		_reset_button.remove_theme_color_override("font_color")
