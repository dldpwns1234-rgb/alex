extends VBoxContainer
## 업적 탭 도전 절 아래의 별자리 시련 (GDD 7.12절): 이름과 단계(별 다섯), 제한 둘과 이번 목표, 단계 보상, 버튼(시련 시작 / 포기 / 완성).
## 초월 1회 전에는 보이지 않는다. Trials의 함수만 부르고 표시만 한다. 상수는 배치용이다.

const RefreshGate := preload("res://scenes/tabs/refresh_gate.gd")
const GAP: int = 8
const ROW_PADDING: int = 10
const ROW_HEIGHT: float = 128.0  # 세 줄. 글이 바뀌어도 줄 높이와 버튼 자리가 변하지 않는다
const NOTE_FONT_SIZE: int = 20
const NOTE_COLOR := Color("b8b4c8")
const DONE_COLOR := Color("fff3b0")
const ACTIVE_COLOR := Color("ff8a80")
const BUTTON_SIZE := Vector2(170, 64)
const CONFIRM_SIZE := Vector2i(600, 420)

var _gate: RefreshGate  # 시그널이 오면 표시만, 보일 때 프레임당 한 번 갱신
var _titles: Array[Label] = []
var _rules: Array[Label] = []
var _buttons: Array[Button] = []
var _confirm: ConfirmationDialog
var _pending: int = -1


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self, true)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)
	for i in Balance.TRIALS.size():
		add_child(_make_row(i))
	_confirm = ConfirmationDialog.new()
	_confirm.title = "별자리 시련"
	_confirm.ok_button_text = "시작한다"
	_confirm.cancel_button_text = "취소"
	_confirm.dialog_autowrap = true
	_confirm.confirmed.connect(_on_confirmed)
	add_child(_confirm)
	Trials.trial_changed.connect(_gate.queue)
	Challenges.challenge_changed.connect(_gate.queue)
	Transcend.transcended.connect(_gate.queue)
	Game.stage_changed.connect(_gate.queue)
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
	text.add_child(rule)
	var reward := _make_line(NOTE_FONT_SIZE, NOTE_COLOR)
	reward.text = "보상: %s" % Balance.trial_reward_note(index)
	text.add_child(reward)
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_pressed.bind(index))
	row.add_child(button)
	_titles.append(title)
	_rules.append(rule)
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


## 줄에는 짧은 이름 ("스킬 봉인 + 보스 시간 절반"), 확인 창에는 긴 설명
func _rule_text(index: int, long: bool = false) -> String:
	var notes: PackedStringArray = []
	for restriction: int in Balance.trial_restrictions(index):
		notes.append(Balance.restriction_note(restriction) if long else Balance.restriction_short(restriction))
	return " + ".join(notes)


## 진행 중이면 포기, 아니면 확인 창을 띄운다 (지금 판이 끝난다)
func _on_pressed(index: int) -> void:
	if Trials.active == index:
		Trials.give_up()
		return
	if not Trials.can_start(index):
		return
	_pending = index
	var ending := "지금 판은 회귀로 끝납니다 (결정 +%s)." % Num.format(Prestige.crystal_reward()) if Prestige.can_prestige() else "지금 판은 보상 없이 끝납니다 (스테이지 %d 전)." % Balance.PRESTIGE_MIN_STAGE
	_confirm.dialog_text = "'%s' %d단계를 시작합니다.\n%s\n\n제한: %s\n목표: 스테이지 %d 도달\n보상: %s (영구, 초월해도 남는다)" % [
		Balance.trial_name(index), Trials.tiers[index] + 1, ending, _rule_text(index, true), Trials.goal(index), Balance.trial_reward_note(index)]
	_confirm.popup_centered(CONFIRM_SIZE)


func _on_confirmed() -> void:
	if _pending >= 0:
		Trials.start(_pending)
	_pending = -1


func _refresh() -> void:
	visible = Trials.is_unlocked()
	if not visible:
		return
	var tier_count := Balance.TRIAL_TIER_SCALES.size()
	for i in _buttons.size():
		var button := _buttons[i]
		var title := _titles[i]
		var stars := "★".repeat(Trials.tiers[i]) + "☆".repeat(tier_count - Trials.tiers[i])
		title.remove_theme_color_override("font_color")
		button.theme_type_variation = ""
		if Trials.is_maxed(i):
			title.text = "%s %s" % [Balance.trial_name(i), stars]
			title.add_theme_color_override("font_color", DONE_COLOR)
			_rules[i].text = _rule_text(i)
			button.text = "완성"
			button.disabled = true
			continue
		_rules[i].text = "%s · 목표 %d" % [_rule_text(i), Trials.goal(i)]
		if Trials.active == i:
			title.text = "%s %s · 진행 중 (최고 %d)" % [Balance.trial_name(i), stars, Game.highest_stage]
			title.add_theme_color_override("font_color", ACTIVE_COLOR)
			button.text = "포기"
			button.disabled = false
		else:
			title.text = "%s %s" % [Balance.trial_name(i), stars]
			button.text = "%d단계 시작" % (Trials.tiers[i] + 1)
			button.disabled = not Trials.can_start(i)
			if not button.disabled:
				button.theme_type_variation = "AccentButton"
