extends PanelContainer
## 상단 바: 골드, 기억의 결정, 현재 스테이지, 보스전이면 남은 시간 (GDD 9절).
## Game·Prestige의 시그널을 받아 표시만 한다.

const COIN_ICON := preload("res://assets/sprites/ui/coin.svg")
const CRYSTAL_ICON := preload("res://assets/sprites/ui/crystal.svg")

const MARGIN: int = 20
const GAP: int = 16
const ICON_SIZE := Vector2(36, 36)
const CRYSTAL_COLOR := Color("7fd1f0")
const TIMER_WIDTH: float = 150.0   # 보스 시간 알림 자리. 보스전이 아닐 때도 비워 두어 결정 아이콘이 움직이지 않는다
const STAGE_WIDTH: float = 190.0   # "스테이지 999"까지 자릿수가 늘어도 다른 것이 밀리지 않는 폭

var _gold_label: Label
var _crystal_label: Label
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

	# 숫자가 아무리 길어져도 상단 바가 화면보다 넓어지지 않도록 두 라벨은 잘라 보인다
	row.add_child(_make_icon(COIN_ICON))
	_gold_label = _make_value_label()
	row.add_child(_gold_label)

	row.add_child(_make_icon(CRYSTAL_ICON))
	_crystal_label = _make_value_label()
	_crystal_label.add_theme_color_override("font_color", CRYSTAL_COLOR)
	row.add_child(_crystal_label)

	_timer_label = Label.new()
	_timer_label.theme_type_variation = "DangerPill"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.custom_minimum_size = Vector2(TIMER_WIDTH, 0.0)
	_timer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_timer_label)

	_stage_label = Label.new()
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage_label.custom_minimum_size = Vector2(STAGE_WIDTH, 0.0)
	row.add_child(_stage_label)

	Game.gold_changed.connect(_on_gold_changed)
	Prestige.crystals_changed.connect(_on_crystals_changed)
	Game.stage_changed.connect(_on_stage_changed)
	Game.boss_timer_changed.connect(_on_boss_timer_changed)
	Game.monster_spawned.connect(_refresh_timer.unbind(2))
	Game.monster_killed.connect(_refresh_timer.unbind(1))
	Game.boss_failed.connect(_refresh_timer)
	# Game은 오토로드라 이미 준비돼 있으므로 현재 값을 직접 읽어 채운다
	_on_gold_changed(Game.gold)
	_on_crystals_changed(Prestige.crystals)
	_on_stage_changed(Game.stage)
	_refresh_timer()


func _make_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.custom_minimum_size = ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _make_value_label() -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _on_gold_changed(gold: float) -> void:
	_gold_label.text = Num.format(gold)


func _on_crystals_changed(crystals: float) -> void:
	_crystal_label.text = Num.format(crystals)


func _on_stage_changed(stage: int) -> void:
	_stage_label.text = "스테이지 %d" % stage


func _on_boss_timer_changed(seconds_left: float) -> void:
	_timer_label.text = "보스 %d초" % ceili(seconds_left)


## 보스가 살아 있는 동안만 남은 시간을 보인다. 자리는 늘 차지하고 투명하게만 숨긴다 (배치가 변하지 않게)
func _refresh_timer() -> void:
	var shown := Game.is_boss_stage() and Game.is_monster_alive()
	_timer_label.modulate.a = 1.0 if shown else 0.0
	if shown:
		_on_boss_timer_changed(Game.boss_time_left)
