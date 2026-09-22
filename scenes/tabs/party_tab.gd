extends MarginContainer
## 동료 탭: 동료 4명의 고용과 레벨업 (GDD 6절). 줄은 코드로 생성한다.
## Game·Party의 시그널을 받아 표시만 하고, 구매는 Party.buy_companion()을 부른다.

const TapScroll := preload("res://scenes/tabs/tap_scroll.gd")

const MARGIN: int = 16
const ROW_GAP: int = 8
const ROW_PADDING: int = 12
const NOTE_FONT_SIZE: int = 22
const NOTE_COLOR := Color("b8b4c8")
const BUTTON_SIZE := Vector2(250, 72)

var _title_labels: Array[Label] = []
var _note_labels: Array[Label] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, MARGIN)

	var scroll := TapScroll.new()  # 버튼 위에서 시작한 드래그도 스크롤되게 (모바일)
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", ROW_GAP)
	scroll.add_child(column)
	for i in Balance.COMPANIONS.size():
		column.add_child(_make_row(i))
	scroll.release_buttons()

	Game.gold_changed.connect(_refresh.unbind(1))
	Game.stage_changed.connect(_refresh.unbind(1))
	Party.companion_changed.connect(_refresh.unbind(2))
	Party.buy_mode_changed.connect(_refresh.unbind(1))
	_refresh()


func _make_row(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
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
	text.add_child(title)
	var note := Label.new()
	note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	text.add_child(note)

	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_buy_pressed.bind(index))
	row.add_child(button)

	_title_labels.append(title)
	_note_labels.append(note)
	_buttons.append(button)
	return panel


func _on_buy_pressed(index: int) -> void:
	Party.buy_companion(index)


func _refresh() -> void:
	for i in _buttons.size():
		var name := Balance.companion_name(i)
		var level := Party.companion_levels[i]
		if not Party.is_companion_unlocked(i):
			_title_labels[i].text = "%s  (스테이지 %d에 합류)" % [name, Balance.companion_unlock_stage(i)]
			_note_labels[i].text = Balance.companion_note(i)
			_buttons[i].text = "잠김"
			_buttons[i].disabled = true
			continue
		var purchase := Party.companion_purchase(i)
		if level > 0:
			_title_labels[i].text = "%s Lv %d  ·  DPS %s" % [name, level, Num.format(Party.companion_dps(i, false))]
		else:
			_title_labels[i].text = "%s  (미고용)" % name
		_note_labels[i].text = Balance.companion_note(i)
		var verb := "고용" if level == 0 else "레벨업"
		_buttons[i].text = "%s ×%d (%s 골드)" % [verb, purchase.count, Num.format(purchase.cost)]
		_buttons[i].disabled = not purchase.affordable
