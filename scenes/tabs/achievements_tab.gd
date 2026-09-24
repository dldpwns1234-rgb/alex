extends MarginContainer
## 업적 탭 (GDD 7.5절): 통계별로 묶은 업적 목록과 진행 막, 위에는 달성 수와 보너스 합계, 목록 맨 위에 도전 판(challenge_panel.gd). 줄은 코드로 생성한다.
## Achievements의 함수만 부르고 표시만 한다. 탭이 보이면 달성을 본 것으로 표시해 내비게이션의 점을 지운다. 상수는 배치용이다.

const TapScroll := preload("res://scenes/tabs/tap_scroll.gd")
const ChallengePanel := preload("res://scenes/tabs/challenge_panel.gd")

const TEXT_BLOCK_HEIGHT: float = 80.0  # 글 두 줄 높이
const MARGIN: int = 16
const GAP: int = 8
const ROW_PADDING: int = 10
const ROW_GAP: int = 4
const NOTE_FONT_SIZE: int = 22
const NOTE_COLOR := Color("b8b4c8")
const HEADER_COLOR := Color("ffe66d")
const DONE_COLOR := Color("ffe66d")
const SUMMARY_COLOR := Color("b8b4c8")
const BAR_HEIGHT: float = 12.0
const PROGRESS_WIDTH: float = 190.0

var _summary: Label
var _titles: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _progress: Array[Label] = []


func _ready() -> void:
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, MARGIN)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	add_child(column)

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(0.0, TEXT_BLOCK_HEIGHT)  # 두 줄로 접혀도 아래가 밀리지 않게
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary.add_theme_color_override("font_color", SUMMARY_COLOR)
	column.add_child(_summary)

	var scroll := TapScroll.new()  # 손가락으로 끌어 스크롤 (모바일)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", GAP)
	scroll.add_child(list)
	list.add_child(ChallengePanel.new())  # 도전 판은 환생 1회부터 목록 맨 위에 (GDD 7.9절)
	var last_stat := -1
	for i in Balance.ACHIEVEMENTS.size():
		var stat := Balance.achievement_stat(i)
		if stat != last_stat:
			last_stat = stat
			list.add_child(_make_header(Balance.stat_label(stat)))
		list.add_child(_make_row(i))
	scroll.release_buttons()

	Achievements.stat_changed.connect(_refresh.unbind(2))
	visibility_changed.connect(_on_visibility_changed)
	_refresh()


func _make_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HEADER_COLOR)
	return label


func _make_row(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, ROW_PADDING)
	panel.add_child(margin)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", ROW_GAP)
	margin.add_child(text)

	var title := Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text = Balance.achievement_name(index)
	text.add_child(title)
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "%s  ·  %s" % [
		Balance.achievement_goal_text(index, Num.format(Balance.achievement_goal(index))),
		Balance.achievement_reward_note(index)]
	note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	note.add_theme_color_override("font_color", NOTE_COLOR)
	text.add_child(note)

	# 진행 막과 "지금 / 목표". 글자가 길어져도 막이 밀리지 않게 글자 폭을 고정한다
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_PADDING)
	text.add_child(row)
	var bar := ProgressBar.new()
	bar.theme_type_variation = "GoalBar"
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var progress := Label.new()
	progress.custom_minimum_size = Vector2(PROGRESS_WIDTH, 0.0)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress.clip_text = true
	progress.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	progress.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	progress.add_theme_color_override("font_color", NOTE_COLOR)
	row.add_child(progress)

	_titles.append(title)
	_bars.append(bar)
	_progress.append(progress)
	return panel


func _on_visibility_changed() -> void:
	_refresh()


## 보일 때만 갱신한다. 보이는 동안의 달성은 (열려 있는 채로 달성한 것도) 본 것으로 친다
func _refresh() -> void:
	if not is_visible_in_tree():
		return
	if Achievements.has_unseen():
		Achievements.mark_seen()
	_summary.text = "달성 %d / %d  ·  모든 피해 +%d%%  ·  처치 골드 +%d%%" % [
		Achievements.unlocked_count(), Balance.ACHIEVEMENTS.size(),
		roundi((Achievements.damage_multiplier() - 1.0) * 100.0),
		roundi((Achievements.gold_multiplier() - 1.0) * 100.0)]
	for i in _titles.size():
		var done := Achievements.is_unlocked(i)
		_bars[i].value = Achievements.progress(i)
		if done:
			_titles[i].add_theme_color_override("font_color", DONE_COLOR)
			_progress[i].text = "달성"
		else:
			_titles[i].remove_theme_color_override("font_color")
			_progress[i].text = "%s / %s" % [
				Num.format(Achievements.value(Balance.achievement_stat(i))), Num.format(Balance.achievement_goal(i))]
