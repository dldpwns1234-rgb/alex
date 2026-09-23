extends TextureRect
## 베기 자국 한 줄 (GDD 11절). 칼이 지나는 방향으로 훑고 지나가는 빛줄기: 앞머리가 먼저 나가고 꼬리가 뒤따라 지워진다.
## 내려베기는 위에서 아래로(＼), 올려베기는 아래에서 위로(／). 활은 항상 몬스터 쪽으로 불룩하다 (뒤집지 않는다).
## 만들어서 add_child()하면 알아서 재생하고 사라진다. 상수는 연출용이다.

const TEXTURE := preload("res://assets/sprites/fx/slash.svg")
const SHADER := preload("res://assets/shaders/slash.gdshader")

const SIZE := Vector2(190, 240)
const TILT: float = 12.0           # 도. 세로에서 기울이는 각도
const TILT_JITTER: float = 6.0
const OFFSET_JITTER: float = 10.0  # px. 같은 자리에 도장 찍히지 않게
const SWEEP: float = 0.1           # 초. 앞머리가 끝까지 가는 시간
const TAIL_DELAY: float = 0.06     # 꼬리가 따라 나서기까지
const TAIL_DELAY_CRIT: float = 0.12  # 치명타는 자국이 조금 더 남는다
const TAIL_SWEEP_RATIO: float = 1.3  # 꼬리는 앞머리보다 느리게 지나간다
const TRAVEL: float = 50.0         # px. 자국 전체가 칼 방향으로 미끄러지는 거리
const START_WIDTH: float = 0.6     # 가로 배율. 1까지 커진다
const CRIT_SCALE: float = 1.3
const CRIT_COLOR := Color("ffb060")
const HEAD_SOFT: float = 0.04
const TAIL_SOFT: float = 0.25

var _material: ShaderMaterial
var _along: Vector2 = Vector2.DOWN  # 칼이 지나는 방향
var _tail_delay: float = TAIL_DELAY


func _init(point: Vector2, downward: bool, crit: bool) -> void:
	texture = TEXTURE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	pivot_offset = SIZE * 0.5
	var tilt := -TILT if downward else TILT  # ＼ 는 반시계, ／ 는 시계 방향
	rotation = deg_to_rad(tilt + randf_range(-TILT_JITTER, TILT_JITTER))
	_along = Vector2.DOWN.rotated(rotation) * (1.0 if downward else -1.0)
	var jitter := Vector2(randf_range(-OFFSET_JITTER, OFFSET_JITTER), randf_range(-OFFSET_JITTER, OFFSET_JITTER))
	position = point - SIZE * 0.5 - _along * TRAVEL * 0.5 + jitter
	var big := CRIT_SCALE if crit else 1.0
	scale = Vector2(START_WIDTH, 1.0) * big
	modulate = CRIT_COLOR if crit else Color.WHITE
	_tail_delay = TAIL_DELAY_CRIT if crit else TAIL_DELAY
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("downward", 1.0 if downward else -1.0)
	_material.set_shader_parameter("head", 0.0)
	_material.set_shader_parameter("tail", -TAIL_SOFT)
	_material.set_shader_parameter("head_soft", HEAD_SOFT)
	_material.set_shader_parameter("tail_soft", TAIL_SOFT)
	material = _material


func _ready() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_material, "shader_parameter/head", 1.0 + HEAD_SOFT, SWEEP)
	tween.tween_property(_material, "shader_parameter/tail", 1.0, SWEEP * TAIL_SWEEP_RATIO).set_delay(_tail_delay)
	tween.tween_property(self, "position", position + _along * TRAVEL, SWEEP + _tail_delay) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale:x", scale.x / START_WIDTH, SWEEP) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)
