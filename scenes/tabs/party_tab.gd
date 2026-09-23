extends MarginContainer
## 동료 탭: 동료 4명의 고용과 레벨업, 승급 (GDD 6절·6.6절). 줄은 코드로 생성한다.
## Game·Party·Promotions의 시그널을 받아 표시만 하고, 구매는 Party.buy_companion()과 Promotions.promote()를 부른다.

const TapScroll := preload("res://scenes/tabs/tap_scroll.gd")
const PORTRAITS: Array[Texture2D] = [  # Balance.Companion 순서
	preload("res://assets/sprites/warrior.svg"),
	preload("res://assets/sprites/archer.svg"),
	preload("res://assets/sprites/mage.svg"),
	preload("res://assets/sprites/cleric.svg"),
]

const MARGIN: int = 16
const ROW_GAP: int = 8
const ROW_PADDING: int = 12
const NOTE_FONT_SIZE: int = 22
const NOTE_COLOR := Color("b8b4c8")
const BUTTON_SIZE := Vector2(250, 72)
const PROMOTE_SIZE := Vector2(250, 56)
const BUTTON_GAP: int = 6
const PORTRAIT_SIZE := Vector2(72, 72)
const LOCKED_PORTRAIT_COLOR := Color(0.5, 0.48, 0.6)

var _portraits: Array[TextureRect] = []
var _title_labels: Array[Label] = []
var _note_labels: Array[Label] = []
var _buttons: Array[Button] = []
var _promote_buttons: Array[Button] = []


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
	Promotions.promotion_changed.connect(_refresh.unbind(2))
	_refresh()


func _make_row(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, ROW_PADDING)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_PADDING)
	margin.add_child(row)

	var portrait := TextureRect.new()
	portrait.texture = PORTRAITS[index]
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)

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

	# 레벨업 버튼 아래에 승급 버튼 (고용한 동료만 보인다)
	var buttons := VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("separation", BUTTON_GAP)
	row.add_child(buttons)
	var button := _make_button(BUTTON_SIZE, _on_buy_pressed.bind(index))
	buttons.add_child(button)
	var promote := _make_button(PROMOTE_SIZE, _on_promote_pressed.bind(index))
	buttons.add_child(promote)

	_portraits.append(portrait)
	_title_labels.append(title)
	_note_labels.append(note)
	_buttons.append(button)
	_promote_buttons.append(promote)
	return panel


func _make_button(size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = size
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(callback)
	return button


func _on_buy_pressed(index: int) -> void:
	Party.buy_companion(index)


func _on_promote_pressed(index: int) -> void:
	Promotions.promote(index)


func _refresh() -> void:
	for i in _buttons.size():
		var name := Balance.companion_name(i)
		var level := Party.companion_levels[i]
		_portraits[i].self_modulate = Color.WHITE if level > 0 else LOCKED_PORTRAIT_COLOR
		_promote_buttons[i].visible = level > 0
		if not Party.is_companion_unlocked(i):
			_title_labels[i].text = "%s  (스테이지 %d에 합류)" % [name, Balance.companion_unlock_stage(i)]
			_note_labels[i].text = Balance.companion_note(i)
			_buttons[i].text = "잠김"
			_buttons[i].disabled = true
			continue
		var purchase := Party.companion_purchase(i)
		if level > 0:
			var stars := Balance.promotion_stars(Promotions.rank(i))
			_title_labels[i].text = "%s%s Lv %d  ·  DPS %s" % [
				name, " " + stars if not stars.is_empty() else "", level, Num.format(Party.companion_dps(i, false))]
			_refresh_promote(i)
		else:
			_title_labels[i].text = "%s  (미고용)" % name
		_note_labels[i].text = Balance.companion_note(i)
		var verb := "고용" if level == 0 else "레벨업"
		_buttons[i].text = "%s ×%d (%s 골드)" % [verb, purchase.count, Num.format(purchase.cost)]
		_buttons[i].disabled = not purchase.affordable


## 승급 버튼: 최고 단계, 레벨 부족, 살 수 있음(금색), 골드 부족
func _refresh_promote(index: int) -> void:
	var button := _promote_buttons[index]
	var next := Promotions.rank(index) + 1
	button.theme_type_variation = ""
	if Promotions.is_maxed(index):
		button.text = "최고 승급"
		button.disabled = true
	elif not Promotions.is_unlocked(index):
		button.text = "승급 %d단계: Lv %d 필요" % [next, Promotions.next_level(index)]
		button.disabled = true
	else:
		button.text = "승급 %d단계 (%s 골드)" % [next, Num.format(Promotions.cost(index))]
		button.disabled = not Promotions.can_promote(index)
		if not button.disabled:
			button.theme_type_variation = "AccentButton"
