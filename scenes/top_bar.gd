extends PanelContainer
## 상단 바: 골드와 그 아래 초당 처치 골드, 기억의 결정, 현재 스테이지, 보스전이면 남은 시간 (GDD 9절).
## Game·Prestige의 시그널을 받아 표시만 한다.

const COIN_ICON := preload("res://assets/sprites/ui/coin.svg")
const CRYSTAL_ICON := preload("res://assets/sprites/ui/crystal.svg")

const MARGIN: int = 20
const MARGIN_VERTICAL: int = 12  # 골드 아래 초당 골드 줄이 들어가도 바 높이(88)가 그대로이게
const GAP: int = 16
const ICON_SIZE := Vector2(36, 36)
const CRYSTAL_COLOR := Color("7fd1f0")
const TIMER_WIDTH: float = 150.0   # 보스 시간 알림 자리. 보스전이 아닐 때도 비워 두어 결정 아이콘이 움직이지 않는다
const STAGE_WIDTH: float = 190.0   # "스테이지 999"까지 자릿수가 늘어도 다른 것이 밀리지 않는 폭
const RATE_FONT_SIZE: int = 17
const RATE_COLOR := Color("d9c87a")
const RATE_WINDOW: float = 10.0   # 초당 골드는 최근 10초(게임 시간)의 처치 골드로 잰다. 1초 칸으로 나눠 굴린다

var _gold_label: Label
var _crystal_label: Label
var _timer_label: Label
var _stage_label: Label
var _rate_label: Label
var _rate_buckets: PackedFloat64Array = []  # 1초 칸마다 번 처치 골드. 0번이 지금 칸
var _bucket_time: float = 0.0
var _rate_elapsed: float = 0.0  # 잰 시간 (RATE_WINDOW까지). 시작 직후 10초로 나누면 작게 나온다


func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, MARGIN)
	for side: String in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, MARGIN_VERTICAL)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	margin.add_child(row)

	# 숫자가 아무리 길어져도 상단 바가 화면보다 넓어지지 않도록 두 라벨은 잘라 보인다
	row.add_child(_make_icon(COIN_ICON))
	var gold_column := VBoxContainer.new()  # 골드 아래에 초당 골드 (UX 점검 2026-10-02: 속도 정보가 없다)
	gold_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_column.add_theme_constant_override("separation", 0)
	row.add_child(gold_column)
	_gold_label = _make_value_label()
	gold_column.add_child(_gold_label)
	_rate_label = _make_value_label()
	_rate_label.add_theme_font_size_override("font_size", RATE_FONT_SIZE)
	_rate_label.add_theme_color_override("font_color", RATE_COLOR)
	gold_column.add_child(_rate_label)
	_rate_buckets.resize(int(RATE_WINDOW))
	_rate_buckets.fill(0.0)

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
	Game.monster_killed.connect(_on_gold_earned)
	Game.chain_killed.connect(func(_count: int, reward: float) -> void: _on_gold_earned(reward))
	Challenges.challenge_changed.connect(_refresh_timer)
	Tower.timer_changed.connect(_on_tower_timer_changed)
	Game.tower_changed.connect(_on_tower_changed)
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
	_stage_label.text = "탑 %d층" % Tower.floor if Game.in_tower else "스테이지 %d" % stage


func _on_tower_changed(_inside: bool) -> void:
	_on_stage_changed(Game.stage)
	_refresh_timer()


func _on_tower_timer_changed(seconds_left: float) -> void:
	_timer_label.text = "탑 %d초" % ceili(seconds_left)
	_on_stage_changed(Game.stage)  # 층이 오르면 라벨도 따라간다


func _on_boss_timer_changed(seconds_left: float) -> void:
	_timer_label.text = "보스 %d초" % ceili(seconds_left)


## 탑 안이면 층 남은 시간, 보스가 살아 있으면 남은 시간, 아니면 진행 중인 도전 이름을 보인다. 자리는 늘 차지하고 투명하게만 숨긴다
func _refresh_timer() -> void:
	var boss := Game.is_boss_stage() and Game.is_monster_alive()
	var challenge := Challenges.active >= 0
	_timer_label.modulate.a = 1.0 if boss or challenge or Game.in_tower else 0.0
	if Game.in_tower:
		_on_tower_timer_changed(Tower.time_left)
	elif boss:
		_on_boss_timer_changed(Game.boss_time_left)
	elif challenge:
		_timer_label.text = Balance.challenge_name(Challenges.active)


func _on_gold_earned(reward: float) -> void:
	_rate_buckets[0] += reward


## 1초마다 칸을 밀고 초당 골드를 다시 적는다. 탑에는 골드가 없어 숨긴다
func _process(delta: float) -> void:
	delta = minf(delta, 0.25)
	_bucket_time += delta
	_rate_elapsed = minf(_rate_elapsed + delta, RATE_WINDOW)
	if _bucket_time < 1.0:
		return
	_bucket_time -= 1.0
	var total := 0.0
	for amount: float in _rate_buckets:
		total += amount
	_rate_buckets.remove_at(_rate_buckets.size() - 1)
	_rate_buckets.insert(0, 0.0)
	var rate := total / maxf(_rate_elapsed, 1.0)
	_rate_label.text = "+%s/초" % Num.format(rate) if rate > 0.0 and not Game.in_tower else ""
