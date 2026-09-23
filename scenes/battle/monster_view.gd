extends Control
## 몬스터 한 마리의 표시: 그림(Actor), 이름과 체력바, 피해 숫자, 파편. 상태는 Battle이 Game에서 받아 넘겨준다.
## 검격 궤적과 접촉 섬광은 Stage가 띄운다.
## 몬스터 종류와 색은 스테이지로 정한다 (Zones). 아래 상수는 배치와 연출용이며 게임 수치가 아니다.

const Actor := preload("res://scenes/battle/actor.gd")
const Zones := preload("res://scenes/battle/zones.gd")
const CROWN := preload("res://assets/sprites/fx/crown.svg")
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
# 탭 공격이 닿는 자리 (몬스터 앞쪽). 파편이 여기서 나오고 Battle은 접촉 섬광을 여기 띄운다
const IMPACT_POINT := Vector2(FIGURE_SIZE.x * 0.38, FIGURE_SIZE.y * 0.5)
const POP_PUNCH: float = 1.5       # 피해 숫자가 이만큼 크게 나타나 원래 크기로 줄어든다
const POP_PUNCH_DURATION: float = 0.1
# 파편: 칼에서 튀는 쇠 불꽃 줄기. 날아가는 방향으로 세워지고 대체로 앞위쪽(칼이 나가는 쪽)으로 튄다
const SPARK_COLOR := Color(1.0, 1.0, 1.0)
const CRIT_SPARK_COLOR := Color("ffd7a0")
const SPARK_COUNT: int = 8
const FLURRY_SPARK_COUNT: int = 3  # 연타 중에는 조금만
const SPARK_LIFETIME: float = 0.32
const SPARK_DIRECTION := Vector2(1.0, -0.35)
const SPARK_SPREAD: float = 55.0            # 도
const SPARK_SPEED := Vector2(260.0, 460.0)  # 최소, 최대
const SPARK_GRAVITY := Vector2(0.0, 600.0)
const SPARK_SCALE := Vector2(0.5, 0.9)      # 최소, 최대
const CRIT_SHAKE_SCALE: float = 1.8  # 치명타는 이만큼 더 세게 밀린다

var _actor: Actor
var _crown: TextureRect
var _hp_bar: ProgressBar
var _hp_fill: StyleBoxFlat
var _hp_label: Label
var _sparks: CPUParticles2D
var _name: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(FIGURE_SIZE.x, FIGURE_SIZE.y + GAP + HP_BAR_HEIGHT + LABEL_HEIGHT)

	_actor = Actor.new(Zones.monster_texture(1), FIGURE_SIZE, false)
	_actor.pivot_offset = Vector2(FIGURE_SIZE.x * 0.5, FIGURE_SIZE.y)  # 보스는 발끝 기준으로 커진다
	add_child(_actor)
	_crown = TextureRect.new()  # 그림 노드에 붙여 함께 움직인다
	_crown.texture = CROWN
	_crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crown.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_crown.size = CROWN_SIZE
	_crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actor.sprite().add_child(_crown)

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
	sparks.direction = SPARK_DIRECTION
	sparks.spread = SPARK_SPREAD
	sparks.particle_flag_align_y = true
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
	_actor.sprite().texture = Zones.monster_texture(stage)
	_actor.sprite().self_modulate = Zones.monster_tint(stage)
	_actor.scale = Vector2.ONE * (BOSS_SCALE if boss else 1.0)
	_crown.visible = boss
	_crown.position = Vector2((FIGURE_SIZE.x - CROWN_SIZE.x) * 0.5,
		Zones.head_top(stage) * FIGURE_SIZE.y - CROWN_SIZE.y * 0.85)
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
	_actor.die(duration, false)


## 피격. strong(탭 공격)이면 번쩍이며 굳었다 밀리고 불꽃이 튄다. crit이면 더 세게. flurry(연타 중)면 굳지 않는다
func hit(strong: bool, crit: bool = false, flurry: bool = false) -> void:
	_actor.hit(strong, CRIT_SHAKE_SCALE if crit else 1.0, flurry)
	if strong:
		_sparks.color = CRIT_SPARK_COLOR if crit else SPARK_COLOR
		_sparks.amount = FLURRY_SPARK_COUNT if flurry and not crit else SPARK_COUNT
		_sparks.restart()


## 몬스터 머리 위에 글자를 띄우고 떠오르며 사라지게 한다. big은 치명타처럼 강조할 때, punch가 꺼지면 커졌다 줄지 않는다 (연타 중)
func pop(text: String, color: Color, big: bool = false, punch: bool = true) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", POP_CRIT_FONT_SIZE if big else POP_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	_outline(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size * 0.5
	label.position = Vector2(FIGURE_SIZE.x * 0.5 + randf_range(-POP_SPREAD, POP_SPREAD), FIGURE_SIZE.y * POP_START)
	label.scale = Vector2.ONE * (POP_PUNCH if punch else 1.0)  # 크게 나타나 원래 크기로 줄어들며 튀어 오른다
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, POP_PUNCH_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "position:y", label.position.y - POP_RISE, POP_DURATION)
	tween.parallel().tween_property(label, "modulate:a", 0.0, POP_DURATION)
	tween.tween_callback(label.queue_free)


## 밝은 배경 위에서도 읽히도록 글자에 테두리를 준다
func _outline(label: Label) -> void:
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
