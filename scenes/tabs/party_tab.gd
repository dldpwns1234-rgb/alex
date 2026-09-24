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
const ROW_HEIGHT: float = 158.0  # 버튼 두 개 높이. 글이 바뀌어도 줄 높이와 버튼 자리가 변하지 않는다
const PORTRAIT_SIZE := Vector2(72, 72)
const LOCKED_PORTRAIT_COLOR := Color(0.5, 0.48, 0.6)

var _portraits: Array[TextureRect] = []
var _title_labels: Array[Label] = []
var _dps_labels: Array[Label] = []
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
	panel.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
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

	# 이름과 별, 레벨과 DPS, 특수 효과를 각각 한 줄에 둔다. 숫자가 길어져도 접히지 않고(말줄임) DPS 자리가 고정된다
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	var title := _make_line(0, Color.WHITE)
	text.add_child(title)
	var dps := _make_line(0, Color.WHITE)
	text.add_child(dps)
	var note := _make_line(NOTE_FONT_SIZE, NOTE_COLOR)
	text.add_child(note)

	# 레벨업 버튼 아래에 승급 버튼. 고용 전에도 자리를 차지해 줄 안의 배치가 변하지 않는다
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
	_dps_labels.append(dps)
	_note_labels.append(note)
	_buttons.append(button)
	_promote_buttons.append(promote)
	return panel


## 한 줄 라벨. font_size 0이면 기본 크기, 색이 흰색이면 테마 색
func _make_line(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	return label


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
		_note_labels[i].text = Balance.companion_note(i)
		_refresh_promote(i)
		if not Party.is_companion_unlocked(i):
			_title_labels[i].text = name
			_dps_labels[i].text = "스테이지 %d에 합류" % Balance.companion_unlock_stage(i)
			_buttons[i].text = "잠김"
			_buttons[i].disabled = true
			continue
		var purchase := Party.companion_purchase(i)
		var stars := Balance.promotion_stars(Promotions.rank(i))
		_title_labels[i].text = name + (" " + stars if not stars.is_empty() else "")
		_dps_labels[i].text = "Lv %d · DPS %s" % [level, Num.format(Party.companion_dps(i, false))]
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
