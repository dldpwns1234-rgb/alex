extends PanelContainer
## 상단 바: 골드, 현재 스테이지 (GDD 9절). 기억의 결정은 M5, 보스 남은 시간은 M2에서 붙는다.
## Game의 시그널을 받아 표시만 한다.

const MARGIN: int = 24

var _gold_label: Label
var _stage_label: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, MARGIN)
	add_child(margin)

	var row := HBoxContainer.new()
	margin.add_child(row)

	_gold_label = Label.new()
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_gold_label)

	_stage_label = Label.new()
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_stage_label)

	Game.gold_changed.connect(_on_gold_changed)
	Game.stage_changed.connect(_on_stage_changed)
	# Game은 오토로드라 이미 준비돼 있으므로 현재 값을 직접 읽어 채운다
	_on_gold_changed(Game.gold)
	_on_stage_changed(Game.stage)


func _on_gold_changed(gold: float) -> void:
	_gold_label.text = "골드 %s" % Num.format(gold)


func _on_stage_changed(stage: int) -> void:
	_stage_label.text = "스테이지 %d" % stage
