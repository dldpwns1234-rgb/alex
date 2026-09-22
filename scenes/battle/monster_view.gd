extends Control
## 몬스터 한 마리의 표시: 도형, 이름, 체력바, 피해 숫자, 피격 번쩍임. 상태는 Battle이 Game에서 받아 넘겨준다.
## 아래 상수는 배치와 연출용이며 게임 수치가 아니다.

const MONSTER_COLOR := Color("c94f4f")
const HIT_COLOR := Color.WHITE
const HP_BAR_COLOR := Color("5fd36a")
const FIGURE_SIZE := Vector2(220, 220)
const HP_BAR_HEIGHT: float = 28.0
const LABEL_HEIGHT: float = 44.0
const GAP: float = 12.0
const POP_FONT_SIZE: int = 40
const POP_SPREAD: float = 50.0     # 피해 숫자가 나타나는 가로 흔들림
const POP_RISE: float = 100.0      # 피해 숫자가 떠오르는 거리
const POP_DURATION: float = 0.6
const HIT_FLASH_DURATION: float = 0.1

var _figure: ColorRect
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _flash_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(FIGURE_SIZE.x, FIGURE_SIZE.y + GAP + HP_BAR_HEIGHT + LABEL_HEIGHT)

	_figure = ColorRect.new()
	_figure.color = MONSTER_COLOR
	_figure.size = FIGURE_SIZE
	_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_figure)

	_name_label = Label.new()
	_name_label.text = "몬스터"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure.add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.position = Vector2(0.0, FIGURE_SIZE.y + GAP)
	_hp_bar.size = Vector2(FIGURE_SIZE.x, HP_BAR_HEIGHT)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = HP_BAR_COLOR
	_hp_bar.add_theme_stylebox_override("fill", fill)
	add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.position = Vector2(0.0, FIGURE_SIZE.y + GAP + HP_BAR_HEIGHT)
	_hp_label.size = Vector2(FIGURE_SIZE.x, LABEL_HEIGHT)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_label)


func spawn(max_hp: float) -> void:
	_figure.visible = true
	_figure.color = MONSTER_COLOR
	_hp_bar.max_value = max_hp
	set_hp(max_hp)


func set_hp(hp: float) -> void:
	_hp_bar.value = hp
	_hp_label.text = "%s / %s" % [Num.format(hp), Num.format(_hp_bar.max_value)]


func die() -> void:
	_figure.visible = false


func hit_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_figure.color = HIT_COLOR
	_flash_tween = create_tween()
	_flash_tween.tween_property(_figure, "color", MONSTER_COLOR, HIT_FLASH_DURATION)


## 몬스터 머리 위에 글자를 띄우고 떠오르며 사라지게 한다
func pop(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", POP_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(FIGURE_SIZE.x * 0.5 + randf_range(-POP_SPREAD, POP_SPREAD), -LABEL_HEIGHT)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - POP_RISE, POP_DURATION)
	tween.parallel().tween_property(label, "modulate:a", 0.0, POP_DURATION)
	tween.tween_callback(label.queue_free)
