extends MarginContainer
## 용사 탭: 레벨, 클릭 피해, 레벨업 버튼, 그 아래 장비 3칸(GDD 7.6절)과 강화석. 구매 배수는 탭 패널 위의 BuyBar가 정한다.
## Game·Party·Equipment의 시그널을 받아 표시만 하고, 구매는 Party.buy_hero()와 Equipment.enhance()를 부른다. 상수는 배치용이다.

const TapScroll := preload("res://scenes/tabs/tap_scroll.gd")
const HERO_TEXTURE := preload("res://assets/sprites/hero.svg")

const MARGIN: int = 16
const ROW_GAP: int = 12
const ROW_PADDING: int = 10
const BUTTON_HEIGHT: float = 88.0
const PORTRAIT_SIZE := Vector2(120, 120)
const NOTE_FONT_SIZE: int = 22
const NOTE_COLOR := Color("b8b4c8")
const HEADER_COLOR := Color("ffe66d")
const EMPTY_COLOR := Color("7a7690")
const ENHANCE_BUTTON_SIZE := Vector2(230, 64)
const ROW_HEIGHT: float = 128.0  # 장비 설명이 두 줄이 되어도 줄 높이가 변하지 않게

var _level_label: Label
var _damage_label: Label
var _buy_button: Button
var _stones_label: Label
var _slot_titles: Array[Label] = []
var _slot_notes: Array[Label] = []
var _enhance_buttons: Array[Button] = []


func _ready() -> void:
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, MARGIN)
	var scroll := TapScroll.new()  # 장비 칸까지 한 화면에 안 들어가면 끌어 스크롤
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", ROW_GAP)
	scroll.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(header)
	var portrait := TextureRect.new()
	portrait.texture = HERO_TEXTURE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.custom_minimum_size = PORTRAIT_SIZE
	header.add_child(portrait)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", ROW_GAP)
	header.add_child(text)
	_level_label = Label.new()
	text.add_child(_level_label)
	_damage_label = Label.new()
	text.add_child(_damage_label)

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_buy_button.pressed.connect(Party.buy_hero)
	column.add_child(_buy_button)

	# 장비: 제목 줄 오른쪽에 강화석, 칸마다 한 줄
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	title_row.add_child(_make_label("장비", HEADER_COLOR))
	_stones_label = _make_label("", NOTE_COLOR)
	_stones_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stones_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(_stones_label)
	for slot in Balance.SLOT_LABELS.size():
		column.add_child(_make_slot_row(slot))
	scroll.release_buttons()

	Game.gold_changed.connect(_refresh.unbind(1))
	Party.hero_changed.connect(_refresh.unbind(1))
	Party.buy_mode_changed.connect(_refresh.unbind(1))
	Equipment.equipment_changed.connect(_refresh.unbind(1))
	Equipment.stones_changed.connect(_refresh.unbind(1))
	_refresh()


func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


func _make_slot_row(slot: int) -> PanelContainer:
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
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title)
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	text.add_child(note)
	var button := Button.new()
	button.custom_minimum_size = ENHANCE_BUTTON_SIZE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(Equipment.enhance.bind(slot))
	row.add_child(button)
	_slot_titles.append(title)
	_slot_notes.append(note)
	_enhance_buttons.append(button)
	return panel


func _refresh() -> void:
	var purchase := Party.hero_purchase()
	_level_label.text = "용사 Lv %d" % Party.hero_level
	_damage_label.text = "클릭 피해 %s" % Num.format(Party.click_damage())
	_buy_button.text = "레벨업 ×%d  (비용 %s 골드)" % [purchase.count, Num.format(purchase.cost)]
	_buy_button.disabled = not purchase.affordable
	_stones_label.text = "강화석 %s" % Num.format(Equipment.stones)
	for slot in _slot_titles.size():
		_refresh_slot(slot)


## 칸 하나: 빈 칸, 장비(등급 색 이름, 효과, 떨어진 스테이지, 강화), 강화 버튼(최대·비용·부족)
func _refresh_slot(slot: int) -> void:
	var button := _enhance_buttons[slot]
	if not Equipment.has_item(slot):
		_slot_titles[slot].text = "%s  ·  비어 있음" % Balance.slot_label(slot)
		_slot_titles[slot].add_theme_color_override("font_color", EMPTY_COLOR)
		_slot_notes[slot].text = "보스가 떨어뜨린다  ·  %s" % Balance.slot_effect_label(slot)
		button.text = "강화"
		button.disabled = true
		return
	var grade := Equipment.item_grade(slot)
	_slot_titles[slot].text = "%s  ·  %s %s" % [
		Balance.slot_label(slot), Balance.grade_label(grade), Balance.item_name(slot, grade)]
	_slot_titles[slot].add_theme_color_override("font_color", Balance.grade_color(grade))
	_slot_notes[slot].text = "%s  ·  스테이지 %d  ·  강화 +%d" % [
		Balance.equipment_note(slot, Equipment.effect(slot)), Equipment.item_stage(slot), Equipment.enhance_levels[slot]]
	if Equipment.is_enhance_maxed(slot):
		button.text = "강화 최대"
		button.disabled = true
	else:
		button.text = "강화 +%d (%s 강화석)" % [Equipment.enhance_levels[slot] + 1, Num.format(Equipment.enhance_cost(slot))]
		button.disabled = not Equipment.can_enhance(slot)
