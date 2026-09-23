extends Label
## 화면 위에 잠깐 떠오르는 알림 (업적 달성). 부모의 아래쪽 가운데에 나타나 살짝 떠오르며 밝아졌다 사라진다.
## 여러 개가 겹치면 차례로 보여준다. 상수는 연출용이다.

const FADE_IN: float = 0.15
const HOLD: float = 1.8
const FADE_OUT: float = 0.4
const RISE: float = 12.0          # 나타나며 떠오르는 거리
const BOTTOM_MARGIN: float = 20.0

var _queue: PackedStringArray = []
var _tween: Tween
var _resting_y: float = 0.0


func _ready() -> void:
	theme_type_variation = "Pill"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	get_parent().resized.connect(_place)


func show_message(text: String) -> void:
	_queue.append(text)
	if _tween == null or not _tween.is_running():
		_next()


func _next() -> void:
	if _queue.is_empty():
		return
	text = _queue[0]
	_queue.remove_at(0)
	reset_size()
	_place()
	position.y = _resting_y + RISE
	modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_property(self, "position:y", _resting_y, FADE_IN).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(HOLD)
	_tween.chain().tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.chain().tween_callback(_next)


## 부모의 아래쪽 가운데
func _place() -> void:
	var parent := get_parent() as Control
	_resting_y = parent.size.y - size.y - BOTTOM_MARGIN
	position = Vector2((parent.size.x - size.x) * 0.5, _resting_y)
