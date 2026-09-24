extends MarginContainer
## 단련 탭 (GDD 6.5절): 주인별로 묶은 단련 25종의 해금·강화. 줄은 코드로 생성한다.
## Training의 함수만 부르고 표시만 한다. 아래 상수는 배치용이다.

const TapScroll := preload("res://scenes/tabs/tap_scroll.gd")

const MARGIN: int = 16
const GAP: int = 8
const ROW_PADDING: int = 10
const NOTE_FONT_SIZE: int = 22
const NOTE_COLOR := Color("b8b4c8")
const LOCKED_COLOR := Color("7a7690")
const HEADER_COLOR := Color("ffe66d")
const BUTTON_SIZE := Vector2(230, 64)
const ROW_HEIGHT: float = 128.0  # 설명이 두 줄이 되어도 줄 높이가 변하지 않게 (버튼 자리가 움직이면 누르기 불편하다)

var _titles: Array[Label] = []
var _notes: Array[Label] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, MARGIN)
	var scroll := TapScroll.new()  # 버튼 위에서 시작한 드래그도 스크롤되게 (모바일)
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", GAP)
	scroll.add_child(column)

	var last_owner := -2
	for i in Balance.TRAININGS.size():
		var owner := Balance.training_owner(i)
		if owner != last_owner:
			last_owner = owner
			column.add_child(_make_header(Balance.owner_name(owner)))
		column.add_child(_make_row(i))
	scroll.release_buttons()

	Game.gold_changed.connect(_refresh.unbind(1))
	Training.training_changed.connect(_refresh.unbind(2))
	Party.hero_changed.connect(_refresh.unbind(1))
	Party.companion_changed.connect(_refresh.unbind(2))
	Party.buy_mode_changed.connect(_refresh.unbind(1))
	_refresh()


func _make_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HEADER_COLOR)
	return label


func _make_row(index: int) -> PanelContainer:
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
	# 글자가 길어져도 줄이 화면보다 넓어지지 않도록 라벨은 줄바꿈하고 버튼은 폭을 고정한다
	var title := Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title)
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	text.add_child(note)

	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(Training.buy.bind(index))
	row.add_child(button)

	_titles.append(title)
	_notes.append(note)
	_buttons.append(button)
	return panel


func _refresh() -> void:
	for i in _buttons.size():
		var level := Training.levels[i]
		var cap := Balance.training_max_level(i)
		_titles[i].text = "%s  Lv %d / %d" % [Balance.training_name(i), level, cap]
		var note := "%s/레벨" % Balance.training_note(i)
		if level > 0:
			note += "  ·  지금 %s" % Balance.training_amount(i, level)
		_notes[i].text = note
		if not Training.is_unlocked(i):
			var owner := Balance.owner_name(Balance.training_owner(i))
			_buttons[i].text = "%s Lv %d 해금" % [owner, Balance.training_unlock_level(i)]
			_buttons[i].disabled = true
			_titles[i].add_theme_color_override("font_color", LOCKED_COLOR)
			continue
		_titles[i].remove_theme_color_override("font_color")
		if Training.is_maxed(i):
			_buttons[i].text = "최대"
			_buttons[i].disabled = true
			continue
		var purchase := Training.purchase(i)
		_buttons[i].text = "강화 ×%d (%s 골드)" % [purchase.count, Num.format(purchase.cost)]
		_buttons[i].disabled = not purchase.affordable
