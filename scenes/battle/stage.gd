extends Control
## 전투 무대: 배경, 파티, 몬스터를 담고 통째로 흔들린다 (화면 흔들림). 검격 자국과 접촉 불꽃도 여기에 띄운다.
## Battle이 타이밍을 정하고 여기 함수를 부른다. 연타로 연출이 쌓이면 오래된 것부터 지운다. 상수는 연출용이다.

const SlashFx := preload("res://scenes/battle/slash_fx.gd")
const ImpactFx := preload("res://scenes/battle/impact_fx.gd")

const SHAKE_DURATION: float = 0.12
const MAX_SHAKE: float = 12.0  # 연타해도 이 이상 커지지 않는다
const MAX_FX: int = 6          # 동시에 남는 연출 수

var _shake_amount: float = 0.0
var _shake_left: float = 0.0
var _fx: Array[CanvasItem] = []


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


## 검격 자국. hand는 용사의 손 자리. flurry는 연타 중(작고 빠르게)
func slash(hand: Vector2, downward: bool, crit: bool, flurry: bool) -> void:
	_add(SlashFx.new(hand, downward, crit, flurry))


## 접촉 불꽃. ring이면 처치 고리도 퍼진다
func impact(point: Vector2, crit: bool, ring: bool) -> void:
	_add(ImpactFx.new(point, crit, ring))


func _add(fx: CanvasItem) -> void:
	# 스스로 사라진 연출은 해제된 참조로 남으므로 먼저 걸러낸다 (형이 있는 람다 인자에는 해제된 객체를 넘길 수 없다)
	_fx = _fx.filter(func(node: Variant) -> bool: return is_instance_valid(node) and not node.is_queued_for_deletion())
	while _fx.size() >= MAX_FX:
		_fx.pop_front().queue_free()
	_fx.append(fx)
	add_child(fx)
