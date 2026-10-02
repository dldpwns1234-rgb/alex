extends VBoxContainer
## 설정 탭 맨 위의 소리 (GDD 9절): 효과음·배경음 줄마다 켜기·끄기 스위치와 음량(−/+ 10%씩).
## Prefs의 함수만 부르고 audio_changed를 받아 표시한다. 음량은 Sfx가 버스에 건다. 끌어 스크롤하는 목록 안에 있어 슬라이더 대신 버튼을 쓴다.

enum Kind { SFX, MUSIC }

const TITLES: PackedStringArray = ["효과음", "배경음"]
const GAP: int = 12
const ROW_HEIGHT: float = 64.0
const STEP: float = 0.1  # 버튼 한 번에 바뀌는 음량
const STEP_BUTTON_SIZE := Vector2(72, 56)
const PERCENT_WIDTH: float = 96.0  # "100%"가 들어가는 폭. 숫자가 바뀌어도 버튼이 움직이지 않는다
const TOGGLE_SIZE := Vector2(130, 56)
const DIM_COLOR := Color("7a7690")

var _toggles: Array[CheckButton] = []
var _percents: Array[Label] = []
var _minus: Array[Button] = []
var _plus: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", GAP)
	for kind in TITLES.size():
		add_child(_make_row(kind))
	Prefs.audio_changed.connect(_refresh)
	_refresh()


func _make_row(kind: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", GAP)
	var title := Label.new()
	title.text = TITLES[kind]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	_minus.append(_make_step_button(row, "−", kind, -STEP))
	var percent := Label.new()
	percent.custom_minimum_size = Vector2(PERCENT_WIDTH, 0.0)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(percent)
	_percents.append(percent)
	_plus.append(_make_step_button(row, "+", kind, STEP))
	var toggle := CheckButton.new()  # 자동화 토글과 같은 스위치 모양 (테마의 CheckButton 아이콘)
	toggle.custom_minimum_size = TOGGLE_SIZE
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.toggled.connect(_on_toggled.bind(kind))
	row.add_child(toggle)
	_toggles.append(toggle)
	return row


func _make_step_button(row: HBoxContainer, text: String, kind: int, delta: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = STEP_BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_step.bind(kind, delta))
	row.add_child(button)
	return button


func _volume(kind: int) -> float:
	return Prefs.sfx_volume if kind == Kind.SFX else Prefs.music_volume


func _is_on(kind: int) -> bool:
	return Prefs.sfx_on if kind == Kind.SFX else Prefs.music_on


## 10% 단위로 맞춰 올리고 내린다. 효과음은 바뀐 크기를 바로 들려준다
func _on_step(kind: int, delta: float) -> void:
	var volume := snappedf(_volume(kind) + delta, STEP)
	if kind == Kind.SFX:
		Prefs.set_sfx_volume(volume)
		Sfx.play("buy")
	else:
		Prefs.set_music_volume(volume)


func _on_toggled(on: bool, kind: int) -> void:
	if kind == Kind.SFX:
		Prefs.set_sfx_on(on)
	else:
		Prefs.set_music_on(on)


func _refresh() -> void:
	for kind in TITLES.size():
		var volume := _volume(kind)
		var on := _is_on(kind)
		_toggles[kind].set_pressed_no_signal(on)
		_toggles[kind].text = "켬" if on else "끔"
		_percents[kind].text = "%d%%" % roundi(volume * 100.0)
		if on:
			_percents[kind].remove_theme_color_override("font_color")
		else:
			_percents[kind].add_theme_color_override("font_color", DIM_COLOR)
		_minus[kind].disabled = volume <= 0.0
		_plus[kind].disabled = volume >= 1.0
