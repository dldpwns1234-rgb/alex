extends Control
## 전투 무대: 배경, 파티, 몬스터를 담고 통째로 흔들린다 (화면 흔들림). 검격 궤적과 접촉 섬광도 여기에 띄운다.
## Battle이 타이밍을 정하고 여기 함수를 부른다. 상수는 연출용이다.

const SlashFx := preload("res://scenes/battle/slash_fx.gd")
const ImpactFx := preload("res://scenes/battle/impact_fx.gd")

const SHAKE_DURATION: float = 0.12
const MAX_SHAKE: float = 12.0  # 연타해도 이 이상 커지지 않는다

var _shake_amount: float = 0.0
var _shake_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		position = Vector2.ZERO
		_shake_amount = 0.0
		return
	var strength := _shake_amount * _shake_left / SHAKE_DURATION
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength


## 무대를 흔든다. 이미 흔들리는 중이면 더 큰 쪽을 따른다
func shake(amount: float) -> void:
	_shake_amount = minf(maxf(_shake_amount, amount), MAX_SHAKE)
	_shake_left = SHAKE_DURATION


## 검격 궤적. pivot은 용사의 손 자리
func slash(pivot: Vector2, downward: bool, crit: bool) -> void:
	add_child(SlashFx.new(pivot, downward, crit))


## 접촉 섬광. ring이면 처치 고리도 퍼진다
func impact(point: Vector2, crit: bool, ring: bool) -> void:
	add_child(ImpactFx.new(point, crit, ring))
