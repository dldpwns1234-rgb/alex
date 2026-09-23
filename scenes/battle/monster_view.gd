extends Control
## 몬스터 한 마리의 표시: 그림(Actor), 이름과 체력바, 피해 숫자, 베기 자국. 상태는 Battle이 Game에서 받아 넘겨준다.
## 몬스터 종류와 색은 스테이지로 정한다 (Zones). 아래 상수는 배치와 연출용이며 게임 수치가 아니다.

const Actor := preload("res://scenes/battle/actor.gd")
const Zones := preload("res://scenes/battle/zones.gd")
const CROWN := preload("res://assets/sprites/fx/crown.svg")
const SLASH := preload("res://assets/sprites/fx/slash.svg")
const SPARK := preload("res://assets/sprites/fx/spark.svg")

const FIGURE_SIZE := Vector2(220, 220)
const BOSS_SCALE: float = 1.3
const CROWN_SIZE := Vector2(90, 45)
const HP_BAR_HEIGHT: float = 24.0
const HP_BAR_COLOR := Color("5fd36a")
const BOSS_HP_BAR_COLOR := Color("e0484f")
const HP_BAR_BACK := Color(0.1, 0.08, 0.14, 0.55)
const LABEL_HEIGHT: float = 72.0   # 두 줄: 이름, 체력
const GAP: float = 10.0
const OUTLINE_SIZE: int = 6
const OUTLINE_COLOR := Color("2b2438")
const POP_FONT_SIZE: int = 40
const POP_CRIT_FONT_SIZE: int = 52
const POP_START: float = 0.35      # 피해 숫자가 나타나는 높이 (그림 높이 비율). 몬스터 얼굴 위
const POP_SPREAD: float = 40.0     # 피해 숫자가 나타나는 가로 흔들림
const POP_RISE: float = 100.0      # 피해 숫자가 떠오르는 거리
const POP_DURATION: float = 0.6
# 탭 공격이 닿는 자리 (몬스터 앞쪽). 베기 자국과 파편이 여기서 나온다
const IMPACT_POINT := Vector2(FIGURE_SIZE.x * 0.38, FIGURE_SIZE.y * 0.5)
const SLASH_SIZE := Vector2(190, 240)
# 칼끝의 궤적은 왼쪽에 선 용사의 어깨를 축으로 돌므로 항상 몬스터 쪽(오른쪽)으로 불룩하다. 뒤집지 않는다.
# 대신 앞으로 내려베기(＼, 위에서 아래로 늘어남)와 올려베기(／, 아래에서 위로 늘어남)를 번갈아 한다
const SLASH_TILT: float = 12.0       # 도. 세로에서 기울이는 각도
const SLASH_JITTER: float = 6.0      # 도. 매번 조금씩 다르게
const SLASH_OFFSET_JITTER: float = 10.0  # px. 같은 자리에 도장 찍히지 않게
const SLASH_START_SCALE := Vector2(0.7, 0.25)  # 시작 끝을 붙잡고 칼이 지나는 방향으로 늘어나며 나타난다
const SLASH_CRIT_SCALE: float = 1.3
const SLASH_GROW: float = 0.09
const SLASH_HOLD: float = 0.04
const SLASH_FADE: float = 0.2
const CRIT_SLASH_COLOR := Color("ffb060")
const SPARK_COLOR := Color("ffe66d")
const CRIT_SPARK_COLOR := Color("ff8c42")
const SPARK_COUNT: int = 10
const SPARK_LIFETIME: float = 0.4
const SPARK_SPEED := Vector2(220.0, 380.0)  # 최소, 최대
const SPARK_GRAVITY := Vector2(0.0, 700.0)
const SPARK_SCALE := Vector2(0.35, 0.7)     # 최소, 최대
const CRIT_SHAKE_SCALE: float = 1.8

var _actor: Actor
var _hp_bar: ProgressBar
var _hp_fill: StyleBoxFlat
var _hp_label: Label
var _sparks: CPUParticles2D
var _name: String = ""
var _downward: bool = true  # 다음 베기가 내려베기인지


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(FIGURE_SIZE.x, FIGURE_SIZE.y + GAP + HP_BAR_HEIGHT + LABEL_HEIGHT)

	_actor = Actor.new(Zones.monster_texture(1), FIGURE_SIZE, false)
	_actor.pivot_offset = Vector2(FIGURE_SIZE.x * 0.5, FIGURE_SIZE.y)  # 보스는 발끝 기준으로 커진다
	add_child(_actor)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.position = Vector2(0.0, FIGURE_SIZE.y + GAP)
	_hp_bar.size = Vector2(FIGURE_SIZE.x, HP_BAR_HEIGHT)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = HP_BAR_BACK
	back.set_corner_radius_all(int(HP_BAR_HEIGHT * 0.5))
	_hp_bar.add_theme_stylebox_override("background", back)
	_hp_fill = StyleBoxFlat.new()
	_hp_fill.bg_color = HP_BAR_COLOR
	_hp_fill.set_corner_radius_all(int(HP_BAR_HEIGHT * 0.5))
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.position = Vector2(0.0, FIGURE_SIZE.y + GAP + HP_BAR_HEIGHT)
	_hp_label.size = Vector2(FIGURE_SIZE.x, LABEL_HEIGHT)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline(_hp_label)
	add_child(_hp_label)
	_sparks = _make_sparks()
	add_child(_sparks)


func _make_sparks() -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.texture = SPARK
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = SPARK_COUNT
	sparks.lifetime = SPARK_LIFETIME
	sparks.position = IMPACT_POINT
	sparks.spread = 180.0
	sparks.gravity = SPARK_GRAVITY
	sparks.initial_velocity_min = SPARK_SPEED.x
	sparks.initial_velocity_max = SPARK_SPEED.y
	sparks.scale_amount_min = SPARK_SCALE.x
	sparks.scale_amount_max = SPARK_SCALE.y
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	sparks.color_ramp = fade
	return sparks


func spawn(max_hp: float, boss: bool, stage: int) -> void:
	_actor.set_texture(Zones.monster_texture(stage))
	_actor.set_tint(Zones.monster_tint(stage))
	_actor.scale = Vector2.ONE * (BOSS_SCALE if boss else 1.0)
	var crown_y := Zones.head_top(stage) * FIGURE_SIZE.y - CROWN_SIZE.y * 0.85
	_actor.set_overlay(CROWN if boss else null, CROWN_SIZE, Vector2((FIGURE_SIZE.x - CROWN_SIZE.x) * 0.5, crown_y))
	_name = Zones.monster_name(stage, boss)
	_hp_fill.bg_color = BOSS_HP_BAR_COLOR if boss else HP_BAR_COLOR
	_hp_bar.max_value = max_hp
	set_hp(max_hp)
	_actor.spawn()


## 체력은 올림해서 보인다. 버림이면 0.5가 남은 몬스터가 "0"으로 보여 죽은 것처럼 읽힌다
func set_hp(hp: float) -> void:
	_hp_bar.value = hp
	_hp_label.text = "%s\n%s / %s" % [_name, Num.format(ceil(hp)), Num.format(ceil(_hp_bar.max_value))]


## 처치: 쓰러지며 사라진다. duration은 다음 몬스터가 나올 때까지의 시간
func die(duration: float) -> void:
	_actor.die(duration)


## 보스가 달아난다 (시간 초과)
func vanish(duration: float) -> void:
	_actor.vanish(duration)


## 피격. strong(탭 공격)이면 번쩍이고 베기 자국과 파편이 나온다. crit이면 더 크고 주황색
func hit(strong: bool, crit: bool = false) -> void:
	_actor.hit(strong, CRIT_SHAKE_SCALE if crit else 1.0)
	if strong:
		_slash(crit)
		_sparks.color = CRIT_SPARK_COLOR if crit else SPARK_COLOR
		_sparks.restart()


## 베기 자국: 칼이 지나는 방향으로 늘어나며 나타난 뒤 사라진다. 내려베기와 올려베기를 번갈아 한다
func _slash(crit: bool) -> void:
	var downward := _downward
	_downward = not _downward
	var slash := TextureRect.new()
	slash.texture = SLASH
	slash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slash.size = SLASH_SIZE
	# 내려베기는 위 끝, 올려베기는 아래 끝을 붙잡고 늘어난다
	slash.pivot_offset = Vector2(SLASH_SIZE.x * 0.5, 0.0 if downward else SLASH_SIZE.y)
	slash.position = IMPACT_POINT - SLASH_SIZE * 0.5 + Vector2(
		randf_range(-SLASH_OFFSET_JITTER, SLASH_OFFSET_JITTER), randf_range(-SLASH_OFFSET_JITTER, SLASH_OFFSET_JITTER))
	var tilt := -SLASH_TILT if downward else SLASH_TILT  # ＼ 는 반시계, ／ 는 시계 방향
	slash.rotation = deg_to_rad(tilt + randf_range(-SLASH_JITTER, SLASH_JITTER))
	slash.scale = SLASH_START_SCALE
	slash.modulate = CRIT_SLASH_COLOR if crit else Color.WHITE
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slash)
	var tween := create_tween()
	tween.tween_property(slash, "scale", Vector2.ONE * (SLASH_CRIT_SCALE if crit else 1.0), SLASH_GROW) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash, "modulate:a", 0.0, SLASH_FADE).set_delay(SLASH_HOLD)
	tween.tween_callback(slash.queue_free)


## 몬스터 머리 위에 글자를 띄우고 떠오르며 사라지게 한다. big은 치명타처럼 강조할 때
func pop(text: String, color: Color, big: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", POP_CRIT_FONT_SIZE if big else POP_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	_outline(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(FIGURE_SIZE.x * 0.5 + randf_range(-POP_SPREAD, POP_SPREAD), FIGURE_SIZE.y * POP_START)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - POP_RISE, POP_DURATION)
	tween.parallel().tween_property(label, "modulate:a", 0.0, POP_DURATION)
	tween.tween_callback(label.queue_free)


## 밝은 배경 위에서도 읽히도록 글자에 테두리를 준다
func _outline(label: Label) -> void:
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
