extends VBoxContainer
## 회귀 탭 목록 맨 위의 자동화 (GDD 7.7절): 자동 회귀, 결정 자동 구매, 스킬 자동 사용의 켜기·끄기.
## 운명의 상점에서 하나라도 해금하기 전에는 보이지 않고, 해금 전인 줄은 잠긴 채로 보인다. Automation의 함수만 부르고 표시만 한다.

const RefreshGate := preload("res://scenes/tabs/refresh_gate.gd")
const GAP: int = 10
const ROW_PADDING: int = 10
const ROW_HEIGHT: float = 92.0  # 제목 한 줄 + 설명 한 줄. 글이 바뀌어도 줄 높이가 변하지 않는다
const NOTE_FONT_SIZE: int = 20
const NOTE_COLOR := Color("b8b4c8")
const TOGGLE_SIZE := Vector2(130, 56)

var _gate: RefreshGate  # 시그널이 오면 표시만, 보일 때 프레임당 한 번 갱신
var _titles: Array[Label] = []
var _notes: Array[Label] = []
var _toggles: Array[CheckButton] = []


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self, true)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)
	for kind in Balance.AUTO_NAMES.size():
		add_child(_make_row(kind))
	Automation.settings_changed.connect(_gate.queue)
	Rebirth.fate_changed.connect(_gate.queue)
	Transcend.star_changed.connect(_gate.queue)  # 자동 환생은 별의 상점이 연다
	Transcend.transcended.connect(_gate.queue)
	_refresh()


func _make_row(kind: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, ROW_PADDING)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	var title := Label.new()
	title.text = Balance.AUTO_NAMES[kind]
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)
	var note := Label.new()
	note.clip_text = true
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	text.add_child(note)
	var toggle := CheckButton.new()  # 스위치 모양이라 켬/끔 상태가 한눈에 보인다 (테마의 CheckButton 아이콘)
	toggle.custom_minimum_size = TOGGLE_SIZE
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.toggled.connect(_on_toggled.bind(kind))
	row.add_child(toggle)
	_titles.append(title)
	_notes.append(note)
	_toggles.append(toggle)
	return panel


func _on_toggled(on: bool, kind: int) -> void:
	Automation.set_enabled(kind, on)


func _refresh() -> void:
	var any_unlocked := false
	for kind in _toggles.size():
		var unlocked := Automation.is_unlocked(kind)
		any_unlocked = any_unlocked or unlocked
		var toggle := _toggles[kind]
		toggle.set_pressed_no_signal(Automation.is_enabled(kind))
		toggle.disabled = not unlocked
		if not unlocked:
			var shop := "별의 상점에서 '%s'" % Balance.star_name(Balance.Star.AUTO_REBIRTH) if kind == Balance.Auto.REBIRTH \
				else "운명의 상점에서 '%s'" % Balance.fate_name(Balance.auto_fate(kind))
			_notes[kind].text = "%s을 사면 열린다" % shop
			toggle.text = "잠김"
			continue
		_notes[kind].text = Balance.auto_note(kind)
		toggle.text = "켬" if Automation.is_enabled(kind) else "끔"
	visible = any_unlocked
