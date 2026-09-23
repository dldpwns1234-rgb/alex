extends Node2D
## 검격 자국 한 번 (GDD 11절). 용사의 손을 축으로 도는 초승달: 양 끝이 뾰족하고 가운데가 두꺼운 흰 면에 이 게임 그림체와
## 같은 어두운 외곽선. 그 뒤에 얇은 잔상 하나, 그리고 칼이 지나간 자리에 가는 "베인 자국" 선이 조금 더 오래 남는다.
## 훑는 움직임 없이 즉시 나타나 짧게 사라진다. 연타로 겹쳐도 선명한 X자 난무로 읽힌다. 축이 용사 쪽이라 활은 저절로
## 몬스터 쪽으로 불룩하다. 순수한 세로 호는 내려베기와 올려베기가 같은 자국이 되므로, 호를 제 가운데를 축으로 기울여
## 대각선 내려베기(＼)와 올려베기(／)로 구분한다. 만들어서 add_child()하면 알아서 재생하고 사라진다.

const RADIUS: float = 120.0
const START_ANGLE: float = -62.0  # 도. 0이 앞(오른쪽), 음수가 위
const END_ANGLE: float = 24.0
const ANGLE_JITTER: float = 5.0
const TILT: float = 18.0          # 도. 호를 제 가운데를 축으로 기울여 ＼(내려베기)와 ／(올려베기)를 만든다
const SEGMENTS: int = 16
const BLADE_WIDTH: float = 28.0   # 초승달 가운데 굵기
const OUTLINE: float = 5.0        # 외곽선 두께 (양쪽 합)
const AFTERIMAGE_OFFSET: float = 9.0    # 도. 휘두른 반대쪽으로
const AFTERIMAGE_ALPHA: float = 0.35
const AFTERIMAGE_WIDTH: float = 0.55    # 초승달 대비
const CUT_WIDTH: float = 3.0      # 베인 자국 선
const BLADE_HOLD: float = 0.05
const BLADE_FADE: float = 0.07
const CUT_HOLD: float = 0.12
const CUT_FADE: float = 0.12
const POP_SCALE: float = 1.1      # 살짝 크게 나타나 제 크기로 (칼이 뻗는 느낌)
const POP_DURATION: float = 0.05
const FLURRY_SCALE: float = 0.85  # 난무(연타) 때는 작고 빠르게
const FLURRY_LIFE: float = 0.7
const CRIT_SCALE: float = 1.25
const FILL := Color(1.0, 1.0, 1.0)
const OUTLINE_COLOR := Color("2b2438")

var _clock: float = 0.0
var _life: float = 1.0  # 지속 시간 배율
var _blade: Array[Line2D] = []  # 외곽선, 면, 잔상
var _cut: Array[Line2D] = []    # 베인 자국 외곽선, 선


func _init(pivot: Vector2, downward: bool, crit: bool, flurry: bool) -> void:
	position = pivot
	var size := (CRIT_SCALE if crit else 1.0) * (FLURRY_SCALE if flurry else 1.0)
	_life = FLURRY_LIFE if flurry else 1.0
	var jitter := deg_to_rad(randf_range(-ANGLE_JITTER, ANGLE_JITTER))
	var from := deg_to_rad(START_ANGLE if downward else END_ANGLE) + jitter
	var to := deg_to_rad(END_ANGLE if downward else START_ANGLE) + jitter
	var tilt := deg_to_rad(-TILT if downward else TILT)  # ＼ 는 반시계, ／ 는 시계 방향
	var points := _arc(from, to, size)
	var middle := (points[0] + points[points.size() - 1]) * 0.5
	var behind := deg_to_rad(-AFTERIMAGE_OFFSET if downward else AFTERIMAGE_OFFSET)
	var shadow := _tilted(_arc(from + behind, to + behind, size), middle, tilt)
	points = _tilted(points, middle, tilt)
	_blade = [_line(points, BLADE_WIDTH * size + OUTLINE, OUTLINE_COLOR, true), _line(points, BLADE_WIDTH * size, FILL, true)]
	if not flurry:  # 난무 때는 잔상까지 겹치면 어지럽다
		_blade.push_front(_line(shadow, BLADE_WIDTH * AFTERIMAGE_WIDTH * size, Color(FILL, AFTERIMAGE_ALPHA), true))
	_cut = [_line(points, CUT_WIDTH + OUTLINE * 0.6, OUTLINE_COLOR, false), _line(points, CUT_WIDTH, FILL, false)]
	for line: Line2D in _blade + _cut:
		add_child(line)
	scale = Vector2.ONE * POP_SCALE


func _arc(from: float, to: float, size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SEGMENTS + 1:
		var angle := lerpf(from, to, float(i) / SEGMENTS)
		points.append(Vector2(cos(angle), sin(angle)) * RADIUS * size)
	return points


## 점들을 center를 축으로 angle만큼 돌린다
func _tilted(points: PackedVector2Array, center: Vector2, angle: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(center + (point - center).rotated(angle))
	return result


## pointed면 양 끝이 뾰족한 초승달, 아니면 고른 굵기의 선
func _line(points: PackedVector2Array, width: float, color: Color, pointed: bool) -> Line2D:
	var line := Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	if pointed:
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.0))
		curve.add_point(Vector2(0.55, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
		line.width_curve = curve
	else:
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
	return line


func _process(delta: float) -> void:
	_clock += delta
	var pop := clampf(_clock / (POP_DURATION * _life), 0.0, 1.0)
	scale = Vector2.ONE * lerpf(POP_SCALE, 1.0, pop)
	var blade_alpha := 1.0 - clampf((_clock - BLADE_HOLD * _life) / (BLADE_FADE * _life), 0.0, 1.0)
	var cut_alpha := 1.0 - clampf((_clock - CUT_HOLD * _life) / (CUT_FADE * _life), 0.0, 1.0)
	for line: Line2D in _blade:
		line.modulate.a = blade_alpha
	for line: Line2D in _cut:
		line.modulate.a = cut_alpha
	if blade_alpha <= 0.0 and cut_alpha <= 0.0:
		queue_free()
