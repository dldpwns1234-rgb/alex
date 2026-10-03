extends VBoxContainer
## 회귀 탭 환생 절 아래의 초월 (GDD 7.12절): 별의 파편과 초월 횟수, 이번 삶의 시간, 초월 버튼과 확인 창, 별의 상점 6종.
## 최후의 마왕을 한 번이라도 잡기 전(그리고 초월한 적이 없으면)은 보이지 않는다. Transcend의 함수만 부르고 표시만 한다.

const RefreshGate := preload("res://scenes/tabs/refresh_gate.gd")
const TEXT_BLOCK_HEIGHT: float = 80.0  # 글 두 줄 높이
const GAP: int = 10
const ROW_PADDING: int = 10
const NOTE_FONT_SIZE: int = 20
const NOTE_COLOR := Color("b8b4c8")
const STAR_COLOR := Color("fff3b0")
const BUTTON_HEIGHT: float = 72.0
const SHOP_BUTTON_SIZE := Vector2(210, 64)
const CONFIRM_SIZE := Vector2i(600, 380)
const REFRESH_INTERVAL: float = 1.0  # 초. 이번 삶의 시간과 받을 파편을 다시 적는다

var _gate: RefreshGate  # 시그널이 오면 표시만, 보일 때 프레임당 한 번 갱신
var _summary: Label
var _button: Button
var _confirm: ConfirmationDialog
var _titles: Array[Label] = []
var _buttons: Array[Button] = []
var _refresh_left: float = 0.0


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self, true)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(0.0, TEXT_BLOCK_HEIGHT)  # 두 줄로 접혀도 아래가 밀리지 않게
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary.add_theme_color_override("font_color", STAR_COLOR)
	add_child(_summary)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_button.clip_text = true
	_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_button.pressed.connect(_on_pressed)
	add_child(_button)
	for i in Balance.STARS.size():
		add_child(_make_row(i))

	_confirm = ConfirmationDialog.new()
	_confirm.title = "초월"
	_confirm.ok_button_text = "초월한다"
	_confirm.cancel_button_text = "취소"
	_confirm.dialog_autowrap = true
	_confirm.confirmed.connect(Transcend.perform)
	add_child(_confirm)

	Transcend.stars_changed.connect(_gate.queue)
	Transcend.star_changed.connect(_gate.queue)
	Transcend.ready_changed.connect(_gate.queue)
	Achievements.stat_changed.connect(_gate.queue)
	_refresh()


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0 and visible:
		_refresh_left = REFRESH_INTERVAL
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
	note.text = Balance.star_note(index)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	text.add_child(note)
	var button := Button.new()
	button.custom_minimum_size = SHOP_BUTTON_SIZE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(Transcend.buy.bind(index))
	row.add_child(button)
	_titles.append(title)
	_buttons.append(button)
	return panel


func _on_pressed() -> void:
	if not Transcend.can_transcend():
		return
	_confirm.dialog_text = "별의 파편 %s개를 받고 운명까지 내려놓습니다. 이번 삶 %s.\n\n내려놓음: 운명의 실과 운명의 상점, 환생 횟수, 기억의 결정과 기억의 상점, 회귀 기록, 판 전체, 시련의 탑 최고층\n유지: 별의 파편과 별의 상점, 장비와 강화석, 업적, 기억 조각, 도전 달성, 자동화 해금, 설정" % [
		Num.format(Transcend.star_reward()), Num.format_duration(Transcend.cycle_seconds)]
	_confirm.popup_centered(CONFIRM_SIZE)


func _refresh() -> void:
	visible = Transcend.count > 0 or Achievements.value(Balance.Stat.FINAL) > 0.0
	if not visible:
		return
	_summary.text = "별의 파편 %s  ·  초월 %d회  ·  이번 삶 %s" % [
		Num.format(Transcend.stars), Transcend.count, Num.format_duration(Transcend.cycle_seconds)]
	if Transcend.can_transcend():
		_button.text = "초월  (별의 파편 +%s)" % Num.format(Transcend.star_reward())
		_button.disabled = false
		_button.theme_type_variation = "AccentButton"
	else:
		_button.text = "초월: 이번 삶에서 최후의 마왕(스테이지 %d) 처치 시" % Balance.FINAL_STAGE
		_button.disabled = true
		_button.theme_type_variation = ""
	for i in _buttons.size():
		var cap := Balance.star_max_level(i)
		var level_text := "Lv %d / %d" % [Transcend.level(i), cap] if cap > 0 else "Lv %d" % Transcend.level(i)
		var total := Balance.star_total(i, Transcend.level(i))
		_titles[i].text = "%s  %s" % [Balance.star_name(i), level_text] + ("  ·  지금 " + total if not total.is_empty() else "")
		if Transcend.is_maxed(i):
			_buttons[i].text = "최대"
			_buttons[i].disabled = true
		else:
			_buttons[i].text = "구매 (%s 파편)" % Num.format(Transcend.star_cost(i))
			_buttons[i].disabled = not Transcend.can_buy(i)
