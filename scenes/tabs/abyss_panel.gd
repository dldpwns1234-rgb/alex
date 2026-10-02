extends VBoxContainer
## 회귀 탭 초월 절 아래의 심연 (GDD 7.13절): 심연석, 최고 깊이와 오늘의 최고, 남은 원정, 심연 각인 3종(심연 안에서만 듣는 영구 강화).
## 첫 초월 전에는 보이지 않는다. 입구는 전투 화면(battle/abyss_controls.gd)에 있다. Abyss의 함수만 부르고 표시만 한다.

const TEXT_BLOCK_HEIGHT: float = 80.0  # 글 두 줄 높이
const GAP: int = 10
const ROW_PADDING: int = 10
const NOTE_FONT_SIZE: int = 20
const NOTE_COLOR := Color("b8b4c8")
const HEADER_COLOR := Color("ffe66d")
const ABYSS_COLOR := Color("b9a2ff")
const SHOP_BUTTON_SIZE := Vector2(210, 64)

var _summary: Label
var _titles: Array[Label] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", GAP)
	var header := Label.new()
	header.text = "심연 각인"
	header.add_theme_color_override("font_color", HEADER_COLOR)
	add_child(header)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(0.0, TEXT_BLOCK_HEIGHT)  # 두 줄로 접혀도 아래가 밀리지 않게
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary.add_theme_color_override("font_color", ABYSS_COLOR)
	add_child(_summary)
	for i in Balance.MARKS.size():
		add_child(_make_row(i))
	Abyss.abyss_changed.connect(_refresh)
	Abyss.stones_changed.connect(_refresh.unbind(1))
	Abyss.mark_changed.connect(_refresh.unbind(2))
	Transcend.transcended.connect(_refresh.unbind(1))
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
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title)
	var note := Label.new()
	note.text = Balance.mark_note(index)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	text.add_child(note)
	var button := Button.new()
	button.custom_minimum_size = SHOP_BUTTON_SIZE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(Abyss.buy.bind(index))
	row.add_child(button)
	_titles.append(title)
	_buttons.append(button)
	return panel


func _refresh() -> void:
	visible = Abyss.is_unlocked()
	if not visible:
		return
	_summary.text = "심연석 %s  ·  최고 %d층 · 오늘 %d층  ·  원정 %d / %d" % [
		Num.format(Abyss.stones), Abyss.best_floor, Abyss.today_best, Abyss.runs, Balance.ABYSS_RUNS_PER_DAY]
	for i in _buttons.size():
		var cap := Balance.mark_max_level(i)
		var level := Abyss.level(i)
		var level_text := "Lv %d / %d" % [level, cap] if cap > 0 else "Lv %d" % level
		var total := ""
		if level > 0 and i == Balance.Mark.POWER:
			total = "  ·  지금 " + Num.multiplier(Balance.mark_power_multiplier(level))
		elif level > 0 and i == Balance.Mark.STORM_COOLDOWN:
			total = "  ·  지금 −%d%%" % roundi(Balance.MARK_STORM_COOLDOWN_CUT * level * 100.0)
		elif level > 0 and i == Balance.Mark.STORM_DURATION:
			total = "  ·  지금 %d초" % roundi(Skills.duration(Balance.Skill.STORM_SLASH))
		_titles[i].text = "%s  %s%s" % [Balance.mark_name(i), level_text, total]
		if Abyss.is_maxed(i):
			_buttons[i].text = "최대"
			_buttons[i].disabled = true
		else:
			_buttons[i].text = "구매 (%s 심연석)" % Num.format(Abyss.mark_cost(i))
			_buttons[i].disabled = not Abyss.can_buy(i)
