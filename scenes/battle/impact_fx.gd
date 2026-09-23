extends Node2D
## 접촉 불꽃 (GDD 11절): 칼이 닿은 점에서 가늘고 날카로운 흰 불꽃이 터지며 커졌다 사라진다. 처치 타는 흰 고리가 퍼진다.
## 만들어서 add_child()하면 알아서 재생하고 사라진다. 상수는 연출용이다.

const CORE_RADIUS: float = 9.0
const SPIKES: int = 4
const SPIKE_LENGTH: float = 34.0
const SPIKE_WIDTH: float = 5.0
const GROW: float = 0.05
const FADE: float = 0.08
const START_SCALE: float = 0.4
const END_SCALE: float = 1.1
const CRIT_SCALE: float = 1.5
const LIGHT_SCALE: float = 0.55  # 연타 중에는 작게
const COLOR := Color(1.0, 1.0, 1.0)
const CRIT_COLOR := Color("fff0d0")
const RING_RADIUS: float = 120.0
const RING_WIDTH: float = 7.0
const RING_DURATION: float = 0.22
const RING_COLOR := Color(1.0, 1.0, 1.0, 0.9)

var _color: Color = COLOR
var _big: float = 1.0
var _ring: bool = false
var _spin: float = 0.0
var _clock: float = 0.0


func _init(point: Vector2, crit: bool, ring: bool, light: bool = false) -> void:
	position = point
	_color = CRIT_COLOR if crit else COLOR
	_big = CRIT_SCALE if crit else (LIGHT_SCALE if light else 1.0)
	_ring = ring
	_spin = randf() * TAU


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= maxf(GROW + FADE, RING_DURATION if _ring else 0.0):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var grow := 1.0 - pow(1.0 - clampf(_clock / GROW, 0.0, 1.0), 2.0)
	var size := lerpf(START_SCALE, END_SCALE, grow) * _big
	var alpha := 1.0 - clampf((_clock - GROW * 0.5) / FADE, 0.0, 1.0)
	if alpha > 0.0:
		var color := Color(_color, alpha)
		draw_circle(Vector2.ZERO, CORE_RADIUS * size, color)
		for i in SPIKES:
			var angle := _spin + TAU * i / SPIKES
			var along := Vector2(cos(angle), sin(angle))
			var across := along.orthogonal() * SPIKE_WIDTH * size * 0.5
			draw_polygon(PackedVector2Array([
				along * CORE_RADIUS * size * 0.5 + across,
				along * SPIKE_LENGTH * size,
				along * CORE_RADIUS * size * 0.5 - across,
			]), PackedColorArray([color, color, color]))
	if _ring:
		var t := clampf(_clock / RING_DURATION, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 3.0)
		draw_arc(Vector2.ZERO, RING_RADIUS * eased, 0.0, TAU, 48,
			Color(RING_COLOR, RING_COLOR.a * (1.0 - t)), RING_WIDTH * (1.0 - t) + 2.0, true)
