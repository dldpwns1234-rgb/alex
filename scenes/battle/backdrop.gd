extends Control
## 전투 배경: 하늘, 해, 먼 언덕, 땅. 지역 팔레트(Zones.palette)가 바뀌면 색이 부드럽게 넘어간다.
## 상수는 연출용이다.

const HORIZON: float = 0.22       # 땅이 시작하는 높이 (높이 비율). 인물들은 땅 위에 선다
const HILL_RADIUS: float = 0.5    # 폭 비율
const SUN_RADIUS: float = 30.0
const SUN_COLOR := Color(1.0, 0.96, 0.8, 0.9)
const SUN_POSITION := Vector2(0.82, 0.09)
const HORIZON_SHADOW := Color(0.0, 0.0, 0.0, 0.14)
const HORIZON_SHADOW_HEIGHT: float = 8.0
const BLEND_DURATION: float = 0.8

var _from: Array = []  # 넘어가기 전 팔레트 (Color 4개)
var _to: Array = []
var _blend: float = 1.0:
	set(value):
		_blend = value
		queue_redraw()
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func set_palette(palette: Array) -> void:
	if palette == _to:
		return
	_from = palette if _to.is_empty() else _to
	_to = palette
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_blend = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "_blend", 1.0, BLEND_DURATION)


func _color(index: int) -> Color:
	var from: Color = _from[index]
	var to: Color = _to[index]
	return from.lerp(to, _blend)


func _draw() -> void:
	if _to.is_empty():
		return
	var horizon := size.y * HORIZON
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, horizon), Vector2(0.0, horizon)]),
		PackedColorArray([_color(0), _color(0), _color(1), _color(1)]))
	draw_circle(SUN_POSITION * size, SUN_RADIUS, SUN_COLOR)
	var radius := size.x * HILL_RADIUS
	draw_circle(Vector2(size.x * 0.22, horizon + radius * 0.8), radius, _color(2))
	draw_circle(Vector2(size.x * 0.8, horizon + radius * 0.85), radius * 0.9, _color(2))
	draw_rect(Rect2(0.0, horizon, size.x, size.y - horizon), _color(3))
	draw_rect(Rect2(0.0, horizon, size.x, HORIZON_SHADOW_HEIGHT), HORIZON_SHADOW)
