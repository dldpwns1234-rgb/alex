extends MarginContainer
## 회귀 탭 (GDD 7절): 결정과 기록, 회귀 버튼과 확인 창, 기억의 상점 7종, 그 아래 환생(rebirth_panel.gd). 줄은 코드로 생성한다.
## Prestige의 함수만 부르고 표시만 한다. 아래 상수는 배치용이다.

const TapScroll := preload("res://scenes/tabs/tap_scroll.gd")
const RebirthPanel := preload("res://scenes/tabs/rebirth_panel.gd")

const MARGIN: int = 16
const GAP: int = 10
const ROW_PADDING: int = 10
const NOTE_FONT_SIZE: int = 22
const NOTE_COLOR := Color("b8b4c8")
const CRYSTAL_COLOR := Color("7fd1f0")
const BUTTON_HEIGHT: float = 72.0
const SHOP_BUTTON_SIZE := Vector2(210, 64)
const CONFIRM_SIZE := Vector2i(600, 300)

var _summary: Label
var _prestige_button: Button
var _confirm: ConfirmationDialog
var _titles: Array[Label] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, MARGIN)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	add_child(column)

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_color_override("font_color", CRYSTAL_COLOR)
	column.add_child(_summary)

	_prestige_button = Button.new()
	_prestige_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_prestige_button.clip_text = true
	_prestige_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_prestige_button.pressed.connect(_on_prestige_pressed)
	column.add_child(_prestige_button)

	var scroll := TapScroll.new()  # 버튼 위에서 시작한 드래그도 스크롤되게 (모바일)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var shop := VBoxContainer.new()
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.add_theme_constant_override("separation", GAP)
	scroll.add_child(shop)
	for i in Balance.MEMORIES.size():
		shop.add_child(_make_row(i))
	shop.add_child(RebirthPanel.new())  # 환생은 상점 아래에 이어진다 (GDD 7.7절)
	scroll.release_buttons()

	# 회귀 전에 받을 결정 수를 보여주는 확인 창 (GDD 7절)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "회귀"
	_confirm.ok_button_text = "회귀한다"
	_confirm.cancel_button_text = "취소"
	_confirm.confirmed.connect(Prestige.perform)
	add_child(_confirm)

	Prestige.crystals_changed.connect(_refresh.unbind(1))
	Prestige.memory_changed.connect(_refresh.unbind(2))
	Prestige.prestiged.connect(_refresh.unbind(1))
	Game.stage_changed.connect(_refresh.unbind(1))
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
	note.text = Balance.memory_note(index)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	text.add_child(note)

	var button := Button.new()
	button.custom_minimum_size = SHOP_BUTTON_SIZE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(Prestige.buy.bind(index))
	row.add_child(button)

	_titles.append(title)
	_buttons.append(button)
	return panel


func _on_prestige_pressed() -> void:
	if not Prestige.can_prestige():
		return
	_confirm.dialog_text = "기억의 결정 %s개를 받고 처음부터 시작합니다.\n\n초기화: 스테이지, 골드, 용사와 동료 레벨, 스킬 쿨타임\n유지: 기억의 결정, 상점 레벨, 기록" % Num.format(Prestige.crystal_reward())
	_confirm.popup_centered(CONFIRM_SIZE)


func _refresh() -> void:
	_summary.text = "기억의 결정 %s  ·  회귀 %d회  ·  역대 최고 스테이지 %d" % [
		Num.format(Prestige.crystals), Prestige.prestige_count, Prestige.best_stage]
	if Prestige.can_prestige():
		_prestige_button.text = "회귀  (결정 +%s)" % Num.format(Prestige.crystal_reward())
		_prestige_button.disabled = false
		_prestige_button.theme_type_variation = "AccentButton"
	else:
		_prestige_button.text = "회귀: 스테이지 %d 도달 시  (이번 판 최고 %d)" % [
			Balance.PRESTIGE_MIN_STAGE, Game.highest_stage]
		_prestige_button.disabled = true
		_prestige_button.theme_type_variation = ""
	for i in _buttons.size():
		var cap := Balance.memory_max_level(i)
		var level_text := "Lv %d / %d" % [Prestige.level(i), cap] if cap > 0 else "Lv %d" % Prestige.level(i)
		_titles[i].text = "%s  %s" % [Balance.memory_name(i), level_text]
		if Prestige.is_maxed(i):
			_buttons[i].text = "최대"
			_buttons[i].disabled = true
		else:
			_buttons[i].text = "구매 (%s 결정)" % Num.format(Prestige.memory_cost(i))
			_buttons[i].disabled = not Prestige.can_buy(i)
