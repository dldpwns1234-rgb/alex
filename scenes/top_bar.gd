extends PanelContainer
## 상단 바: 골드, 현재 스테이지, 보스전이면 남은 시간 (GDD 9절). 기억의 결정은 M5에서 붙는다.
## Game의 시그널을 받아 표시만 한다.

const MARGIN: int = 24
const GAP: int = 24
const TIMER_COLOR := Color("ff8c42")

var _gold_label: Label
var _timer_label: Label
var _stage_label: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, MARGIN)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	margin.add_child(row)

	_gold_label = Label.new()
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_gold_label)

	_timer_label = Label.new()
	_timer_label.add_theme_color_override("font_color", TIMER_COLOR)
	row.add_child(_timer_label)

	_stage_label = Label.new()
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_stage_label)

	Game.gold_changed.connect(_on_gold_changed)
	Game.stage_changed.connect(_on_stage_changed)
	Game.boss_timer_changed.connect(_on_boss_timer_changed)
	Game.monster_spawned.connect(_refresh_timer.unbind(2))
	Game.monster_killed.connect(_refresh_timer.unbind(1))
	Game.boss_failed.connect(_refresh_timer)
	# Game은 오토로드라 이미 준비돼 있으므로 현재 값을 직접 읽어 채운다
	_on_gold_changed(Game.gold)
	_on_stage_changed(Game.stage)
	_refresh_timer()


func _on_gold_changed(gold: float) -> void:
	_gold_label.text = "골드 %s" % Num.format(gold)


func _on_stage_changed(stage: int) -> void:
	_stage_label.text = "스테이지 %d" % stage


func _on_boss_timer_changed(seconds_left: float) -> void:
	_timer_label.text = "보스 %d초" % ceili(seconds_left)


## 보스가 살아 있는 동안만 남은 시간을 보인다
func _refresh_timer() -> void:
	_timer_label.visible = Game.is_boss_stage() and Game.is_monster_alive()
	if _timer_label.visible:
		_on_boss_timer_changed(Game.boss_time_left)
