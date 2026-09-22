extends Control
## 동료 4명의 표시 (GDD 9절: 왼쪽 열, 오른쪽을 본다). 고용 전에는 어둡게, 고용하면 색이 들어온다.
## play_attack()은 앞으로 튀어나갔다 돌아오는 공격 연출이다. 아래 상수는 배치와 연출용이다.

const HIRED_COLORS: Array[Color] = [Color("4f8fe0"), Color("5fb36a"), Color("9b6fe0"), Color("e0c04f")]
const LOCKED_COLOR := Color("3a3648")
const LOCKED_TEXT_COLOR := Color("7a7690")
const FIGURE_SIZE := Vector2(110, 110)
const GAP: float = 14.0
const LUNGE_DISTANCE: float = 40.0
const LUNGE_OUT: float = 0.1
const LUNGE_BACK: float = 0.2

var _figures: Array[ColorRect] = []
var _labels: Array[Label] = []
var _tweens: Array[Tween] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count := Balance.COMPANIONS.size()
	size = Vector2(FIGURE_SIZE.x + LUNGE_DISTANCE, count * FIGURE_SIZE.y + (count - 1) * GAP)
	_tweens.resize(count)
	for i in count:
		var figure := ColorRect.new()
		figure.size = FIGURE_SIZE
		figure.position = Vector2(0.0, i * (FIGURE_SIZE.y + GAP))
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(figure)
		var label := Label.new()
		label.text = Balance.companion_name(i)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		figure.add_child(label)
		_figures.append(figure)
		_labels.append(label)
		set_hired(i, false)


func set_hired(index: int, hired: bool) -> void:
	_figures[index].color = HIRED_COLORS[index] if hired else LOCKED_COLOR
	_labels[index].add_theme_color_override("font_color", Color.WHITE if hired else LOCKED_TEXT_COLOR)


func play_attack(index: int) -> void:
	var tween := _tweens[index]
	if tween != null and tween.is_valid():
		tween.kill()
	var figure := _figures[index]
	figure.position.x = 0.0
	tween = create_tween()
	tween.tween_property(figure, "position:x", LUNGE_DISTANCE, LUNGE_OUT)
	tween.tween_property(figure, "position:x", 0.0, LUNGE_BACK)
	_tweens[index] = tween
