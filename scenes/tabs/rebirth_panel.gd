extends VBoxContainer
## 회귀 탭 아래쪽의 환생 (GDD 7.7절): 운명의 실과 환생 횟수, 환생 버튼과 확인 창, 운명의 상점 3종. 줄은 코드로 생성한다.
## Rebirth의 함수만 부르고 표시만 한다. 상수는 배치용이다.

const TEXT_BLOCK_HEIGHT: float = 80.0  # 글 두 줄 높이
const GAP: int = 10
const ROW_PADDING: int = 10
const NOTE_FONT_SIZE: int = 22
const NOTE_COLOR := Color("b8b4c8")
const HEADER_COLOR := Color("ffe66d")
const THREAD_COLOR := Color("f0a8ff")
const BUTTON_HEIGHT: float = 72.0
const SHOP_BUTTON_SIZE := Vector2(210, 64)
const CONFIRM_SIZE := Vector2i(600, 360)

var _summary: Label
var _button: Button
var _confirm: ConfirmationDialog
var _titles: Array[Label] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", GAP)
	var header := Label.new()
	header.text = "환생"
	header.add_theme_color_override("font_color", HEADER_COLOR)
	add_child(header)

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(0.0, TEXT_BLOCK_HEIGHT)  # 두 줄로 접혀도 아래가 밀리지 않게
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary.add_theme_color_override("font_color", THREAD_COLOR)
	add_child(_summary)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_button.clip_text = true
	_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_button.pressed.connect(_on_pressed)
	add_child(_button)
	for i in Balance.FATES.size():
		add_child(_make_row(i))

	# 환생 전에 받을 실과 내려놓는 것을 보여주는 확인 창
	_confirm = ConfirmationDialog.new()
	_confirm.title = "환생"
	_confirm.ok_button_text = "환생한다"
	_confirm.cancel_button_text = "취소"
	_confirm.confirmed.connect(Rebirth.perform)
	add_child(_confirm)

	Rebirth.threads_changed.connect(_refresh.unbind(1))
	Rebirth.fate_changed.connect(_refresh.unbind(2))
	Rebirth.reborn.connect(_refresh.unbind(1))
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
	note.text = Balance.fate_note(index)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	text.add_child(note)
	var button := Button.new()
	button.custom_minimum_size = SHOP_BUTTON_SIZE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(Rebirth.buy.bind(index))
	row.add_child(button)
	_titles.append(title)
	_buttons.append(button)
	return panel


func _on_pressed() -> void:
	if not Rebirth.can_rebirth():
		return
	_confirm.dialog_text = "운명의 실 %s개를 받고 새 삶을 시작합니다.\n\n내려놓음: 기억의 결정, 기억의 상점, 회귀 기록, 스테이지, 골드, 용사와 동료, 단련, 승급, 스킬 쿨타임\n유지: 운명의 실과 운명의 상점, 환생 횟수, 업적, 장비, 설정" % Num.format(Rebirth.thread_reward())
	_confirm.popup_centered(CONFIRM_SIZE)


func _refresh() -> void:
	_summary.text = "운명의 실 %s  ·  환생 %d회  ·  역대 최고 스테이지 %d" % [
		Num.format(Rebirth.threads), Rebirth.rebirth_count, Rebirth.best_stage()]
	if Rebirth.can_rebirth():
		_button.text = "환생  (운명의 실 +%s)" % Num.format(Rebirth.thread_reward())
		_button.disabled = false
		_button.theme_type_variation = "AccentButton"
	else:
		_button.text = "환생: 역대 최고 스테이지 %d 도달 시" % Balance.REBIRTH_MIN_STAGE
		_button.disabled = true
		_button.theme_type_variation = ""
	for i in _buttons.size():
		var cap := Balance.fate_max_level(i)
		var level_text := "Lv %d / %d" % [Rebirth.level(i), cap] if cap > 0 else "Lv %d" % Rebirth.level(i)
		_titles[i].text = "%s  %s" % [Balance.fate_name(i), level_text]
		if Rebirth.is_maxed(i):
			_buttons[i].text = "최대"
			_buttons[i].disabled = true
		else:
			_buttons[i].text = "구매 (%s 실)" % Num.format(Rebirth.fate_cost(i))
			_buttons[i].disabled = not Rebirth.can_buy(i)
