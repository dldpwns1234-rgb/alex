extends Label
## 화면 위에 잠깐 떠오르는 알림 (업적 달성, 승급, 장비). 부모의 아래쪽 가운데에 나타나 살짝 떠오르며 밝아졌다 사라진다.
## 여러 개가 겹치면 차례로 보여준다. 글자색을 따로 줄 수 있다 (장비 등급 색). 상수는 연출용이다.

const FADE_IN: float = 0.15
const HOLD: float = 1.8
const FADE_OUT: float = 0.4
const RISE: float = 12.0          # 나타나며 떠오르는 거리
const BOTTOM_MARGIN: float = 20.0

var _queue: Array[Dictionary] = []  # {"text": String, "color": Color}
var _tween: Tween
var _resting_y: float = 0.0


func _ready() -> void:
	theme_type_variation = "Pill"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	get_parent().resized.connect(_place)


## color가 흰색이면 테마의 글자색을 그대로 쓴다
func show_message(message: String, color: Color = Color.WHITE) -> void:
	_queue.append({"text": message, "color": color})
	if _tween == null or not _tween.is_running():
		_next()


func _next() -> void:
	if _queue.is_empty():
		return
	var entry: Dictionary = _queue.pop_front()
	text = entry["text"]
	if entry["color"] == Color.WHITE:
		remove_theme_color_override("font_color")
	else:
		add_theme_color_override("font_color", entry["color"])
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
