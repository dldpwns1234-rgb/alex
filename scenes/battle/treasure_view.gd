extends Control
## 보물 요정의 그림 (GDD 3.5절): 전투 화면 위쪽을 오른쪽에서 왼쪽으로 가로지르며 위아래로 출렁인다. 누르면 Treasure.catch()를 부른다.
## 버튼이 탭을 삼키므로 잡을 때 공격이 나가지 않는다. 보물의 축복 중에는 오른쪽 위(처치 수 아래)에 남은 시간을 보인다.
## 상태는 Treasure가 갖고 여기서는 표시만 한다. 상수는 배치와 연출용이다.

const FAIRY := preload("res://assets/sprites/fx/treasure_fairy.svg")
const FAIRY_SIZE := Vector2(110, 110)
const BAND := Vector2(0.12, 0.3)      # 날아가는 높이 범위 (전투 화면 높이 비율). 동료 열 머리와 몬스터 머리 위
const BOB_HEIGHT: float = 26.0
const BOB_SPEED: float = 4.0          # 라디안/초
const TILT: float = 0.12              # 라디안. 출렁임에 맞춰 기운다
const CATCH_DURATION: float = 0.35
const EDGE_MARGIN: float = 16.0
const BLESSING_TOP: float = 56.0      # 축복 글자 높이. 처치 수 바로 아래
const BLESSING_HEIGHT: float = 36.0
const BLESSING_COLOR := Color("ffd23f")
const OUTLINE_SIZE: int = 6
const OUTLINE_COLOR := Color("2b2438")

var _fairy: TextureButton
var _blessing: Label
var _flight: float = 0.0     # 이번 비행의 전체 시간
var _base_y: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fairy = TextureButton.new()
	_fairy.texture_normal = FAIRY
	_fairy.ignore_texture_size = true
	_fairy.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_fairy.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_fairy.size = FAIRY_SIZE
	_fairy.pivot_offset = FAIRY_SIZE * 0.5
	_fairy.visible = false
	_fairy.pressed.connect(_on_pressed)
	add_child(_fairy)
	_blessing = Label.new()
	_blessing.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_blessing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blessing.add_theme_color_override("font_color", BLESSING_COLOR)
	_blessing.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	_blessing.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	add_child(_blessing)
	Treasure.appeared.connect(_on_appeared)
	Treasure.escaped.connect(_on_escaped)


func _process(_delta: float) -> void:
	var left := Treasure.blessing_left()
	_blessing.visible = left > 0.0
	if _blessing.visible:
		_blessing.text = "보물의 축복 · 골드 ×%s · %d초" % [Num.format(Balance.TREASURE_BLESSING_MULTIPLIER), ceili(left)]
		_blessing.position = Vector2(EDGE_MARGIN, BLESSING_TOP)
		_blessing.size = Vector2(size.x - EDGE_MARGIN * 2.0, BLESSING_HEIGHT)
	if not Treasure.flying or not _fairy.visible:
		return
	var progress := 1.0 - Treasure.flight_left / _flight  # 0 = 오른쪽 끝, 1 = 왼쪽 끝
	var phase := (_flight - Treasure.flight_left) * BOB_SPEED
	_fairy.position = Vector2(lerpf(size.x, -FAIRY_SIZE.x, progress), _base_y + sin(phase) * BOB_HEIGHT)
	_fairy.rotation = cos(phase) * TILT


func _on_appeared(duration: float) -> void:
	_flight = duration
	_base_y = size.y * randf_range(BAND.x, BAND.y)
	_fairy.disabled = false
	_fairy.scale = Vector2.ONE
	_fairy.modulate = Color.WHITE
	_fairy.position = Vector2(size.x, _base_y)
	_fairy.visible = true


## 잡히면 커지며 사라진다
func _on_pressed() -> void:
	if not Treasure.catch():
		return
	_fairy.disabled = true
	var tween := _fairy.create_tween().set_parallel(true)
	tween.tween_property(_fairy, "scale", Vector2.ONE * 1.6, CATCH_DURATION)
	tween.tween_property(_fairy, "modulate:a", 0.0, CATCH_DURATION)
	tween.chain().tween_callback(_fairy.hide)


func _on_escaped() -> void:
	_fairy.visible = false
