extends Node2D
## 검격 궤적 (GDD 11절): 용사의 손을 축으로 도는 호를 칼끝이 쓸고 지나간 자리로 그린다.
## 앞머리는 두껍고 밝고, 꼬리는 얇아지며 투명해진다. 매 프레임 호의 양 끝(앞머리·꼬리)을 옮겨 실제로 움직인다.
## 내려베기는 위앞에서 아래앞으로, 올려베기는 그 반대. 축이 용사 쪽이라 활은 저절로 몬스터 쪽으로 불룩하다.
## 만들어서 add_child()하면 알아서 재생하고 사라진다. 상수는 연출용이다.

const RADIUS: float = 120.0
const START_ANGLE: float = -80.0  # 도. 0이 앞(오른쪽), 음수가 위
const END_ANGLE: float = 32.0
const ANGLE_JITTER: float = 6.0
const SWEEP: float = 0.08         # 초. 앞머리가 끝까지 가는 시간
const TAIL_DELAY: float = 0.04    # 꼬리가 따라 나서기까지
const TAIL_SWEEP: float = 0.1     # 꼬리가 끝까지 가는 시간
const SEGMENTS: int = 14
const CORE_WIDTH: float = 26.0
const GLOW_WIDTH: float = 54.0
const CORE_COLOR := Color(1.0, 1.0, 1.0)
const GLOW_COLOR := Color("ffe66d", 0.55)
const CRIT_CORE_COLOR := Color("ffd7a0")
const CRIT_GLOW_COLOR := Color("ff8c42", 0.6)
const CRIT_SCALE: float = 1.3
const TAIL_WIDTH_RATIO: float = 0.08  # 꼬리 끝 굵기 (앞머리 대비)

var _from: float = 0.0  # 라디안
var _to: float = 0.0
var _size: float = 1.0
var _clock: float = 0.0
var _core: Line2D
var _glow: Line2D


func _init(pivot: Vector2, downward: bool, crit: bool) -> void:
	position = pivot
	_size = CRIT_SCALE if crit else 1.0
	var jitter := deg_to_rad(randf_range(-ANGLE_JITTER, ANGLE_JITTER))
	_from = deg_to_rad(START_ANGLE if downward else END_ANGLE) + jitter
	_to = deg_to_rad(END_ANGLE if downward else START_ANGLE) + jitter
	_glow = _make_line(GLOW_WIDTH * _size, CRIT_GLOW_COLOR if crit else GLOW_COLOR)
	_core = _make_line(CORE_WIDTH * _size, CRIT_CORE_COLOR if crit else CORE_COLOR)
	add_child(_glow)
	add_child(_core)
	_update(0.0, 0.0)


func _make_line(width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var curve := Curve.new()  # 점 순서는 꼬리(0)에서 앞머리(1)
	curve.add_point(Vector2(0.0, TAIL_WIDTH_RATIO))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1.0, 1.0))
	line.width_curve = curve
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 0.0))
	gradient.set_color(1, color)
	line.gradient = gradient
	return line


func _process(delta: float) -> void:
	_clock += delta
	var head := 1.0 - pow(1.0 - clampf(_clock / SWEEP, 0.0, 1.0), 2.0)  # 빠르게 나가서 느려진다
	var tail := clampf((_clock - TAIL_DELAY) / TAIL_SWEEP, 0.0, 1.0)
	if tail >= 1.0:
		queue_free()
		return
	_update(tail, head)


func _update(tail: float, head: float) -> void:
	var points := PackedVector2Array()
	var from := lerpf(_from, _to, tail)
	var to := lerpf(_from, _to, head)
	for i in SEGMENTS + 1:
		var angle := lerpf(from, to, float(i) / SEGMENTS)
		points.append(Vector2(cos(angle), sin(angle)) * RADIUS * _size)
	_core.points = points
	_glow.points = points
