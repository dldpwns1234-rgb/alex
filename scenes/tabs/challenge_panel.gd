extends VBoxContainer
## 업적 탭 목록 맨 위의 도전 판 (GDD 7.9절): 이름과 상태, 제한과 목표, 보상, 버튼(도전 시작 / 포기 / 달성). 환생 1회 전에는 보이지 않는다.
## Challenges의 함수만 부르고 표시만 한다. 상수는 배치용이다.

const GAP: int = 8
const ROW_PADDING: int = 10
const ROW_HEIGHT: float = 128.0  # 세 줄. 글이 바뀌어도 줄 높이와 버튼 자리가 변하지 않는다
const NOTE_FONT_SIZE: int = 22
const NOTE_COLOR := Color("b8b4c8")
const HEADER_COLOR := Color("ffe66d")
const DONE_COLOR := Color("ffe66d")
const ACTIVE_COLOR := Color("ff8a80")
const BUTTON_SIZE := Vector2(170, 64)
const CONFIRM_SIZE := Vector2i(600, 400)

var _titles: Array[Label] = []
var _buttons: Array[Button] = []
var _confirm: ConfirmationDialog
var _pending: int = -1


func _ready() -> void:
	add_theme_constant_override("separation", GAP)
	var header := Label.new()
	header.text = "도전"
	header.add_theme_color_override("font_color", HEADER_COLOR)
	add_child(header)
	for i in Balance.CHALLENGES.size():
		add_child(_make_row(i))
	_confirm = ConfirmationDialog.new()
	_confirm.title = "도전"
	_confirm.ok_button_text = "시작한다"
	_confirm.cancel_button_text = "취소"
	_confirm.dialog_autowrap = true
	_confirm.confirmed.connect(_on_confirmed)
	add_child(_confirm)
	Challenges.challenge_changed.connect(_refresh)
	Rebirth.reborn.connect(_refresh.unbind(1))
	Game.stage_changed.connect(_refresh.unbind(1))
	_refresh()


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
	var title := _make_line(0, Color.WHITE)
	text.add_child(title)
	var rule := _make_line(NOTE_FONT_SIZE, NOTE_COLOR)
	rule.text = "%s · 스테이지 %d 도달" % [Balance.restriction_note(Balance.challenge_restriction(index)), Balance.challenge_goal(index)]
	text.add_child(rule)
	var reward := _make_line(NOTE_FONT_SIZE, NOTE_COLOR)
	reward.text = "보상: %s" % Balance.perk_note(Balance.challenge_perk(index))
	text.add_child(reward)
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_pressed.bind(index))
	row.add_child(button)
	_titles.append(title)
	_buttons.append(button)
	return panel


func _make_line(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	return label


## 진행 중이면 포기, 아니면 확인 창을 띄운다 (지금 판이 끝난다)
func _on_pressed(index: int) -> void:
	if Challenges.is_active(index):
		Challenges.give_up()
		return
	if not Challenges.can_start(index):
		return
	_pending = index
	var ending := "지금 판은 회귀로 끝납니다 (결정 +%s)." % Num.format(Prestige.crystal_reward()) if Prestige.can_prestige() else "지금 판은 보상 없이 끝납니다 (스테이지 %d 전)." % Balance.PRESTIGE_MIN_STAGE
	_confirm.dialog_text = "'%s' 도전을 시작합니다.\n%s\n\n제한: %s\n목표: 스테이지 %d 도달\n보상: %s (영구)" % [
		Balance.challenge_name(index), ending, Balance.restriction_note(Balance.challenge_restriction(index)),
		Balance.challenge_goal(index), Balance.perk_note(Balance.challenge_perk(index))]
	_confirm.popup_centered(CONFIRM_SIZE)


func _on_confirmed() -> void:
	if _pending >= 0:
		Challenges.start(_pending)
	_pending = -1


func _refresh() -> void:
	visible = Challenges.is_unlocked()
	for i in _buttons.size():
		var button := _buttons[i]
		var title := _titles[i]
		title.remove_theme_color_override("font_color")
		button.theme_type_variation = ""
		if Challenges.is_done(i):
			title.text = "%s · 달성" % Balance.challenge_name(i)
			title.add_theme_color_override("font_color", DONE_COLOR)
			button.text = "달성"
			button.disabled = true
		elif Challenges.is_active(i):
			title.text = "%s · 진행 중 (이번 판 최고 %d)" % [Balance.challenge_name(i), Game.highest_stage]
			title.add_theme_color_override("font_color", ACTIVE_COLOR)
			button.text = "포기"
			button.disabled = false
		else:
			title.text = Balance.challenge_name(i)
			button.text = "도전 시작"
			button.disabled = not Challenges.can_start(i)
			if not button.disabled:
				button.theme_type_variation = "AccentButton"
