extends Control
## 전투 인물 하나 (용사, 동료, 몬스터). 정지 이미지 한 장에 Tween으로 움직임을 준다 (GDD 11절).
## 대기: 숨 쉬듯 늘었다 줄고, 공격: 앞으로 튀어나갔다 복귀, 피격: 번쩍이며 잠깐 굳은 뒤(히트 스톱) 납작해지며
## 뒤로 밀렸다 튕겨 돌아옴, 처치: 쓰러지며 사라짐. 그림은 바라보는 방향대로 그려져 있고 facing은 방향에만 쓴다.
## 기울기는 자세(_pose: 공격·쓰러짐)와 휘두르기(_swing: 탭마다 짧게)를 더한 값이다. 상수는 연출용이다.

const FLASH_SHADER := preload("res://assets/shaders/flash.gdshader")

const BREATH_AMOUNT: float = 0.035  # 숨 쉴 때 세로로 늘어나는 비율
const BREATH_PERIOD: float = 1.8    # 초
const LUNGE_DISTANCE: float = 40.0  # 동료 공격
const LUNGE_OUT: float = 0.1
const LUNGE_BACK: float = 0.2
const LUNGE_TILT: float = 10.0      # 도
const STRIKE_DISTANCE: float = 90.0  # 용사 탭 공격: 몬스터 앞까지 달려드는 거리
const STRIKE_OUT: float = 0.07
const STRIKE_HOLD: float = 0.06      # 닿은 자세로 멈추는 시간 (히트 스톱)
const STRIKE_BACK: float = 0.2
const STRIKE_WINDUP: float = 12.0    # 도. 젖힌 채 시작해서
const STRIKE_SWING: float = 24.0     # 도. 앞으로 크게 기울며 벤다
const SWING_KICK: float = 9.0        # 도. 탭마다 칼을 짧게 휘두르는 기울기 (달려드는 중에도)
const SWING_OUT: float = 0.04
const SWING_BACK: float = 0.09
const HIT_STOP: float = 0.05         # 맞고 흰색으로 굳는 시간. 그 뒤에 밀린다
const FLURRY_FLASH: float = 0.4      # 연타 중에는 약하게 번쩍이고 굳지 않는다 (10Hz로 깜빡이지 않게)
const KNOCKBACK: float = 16.0
const KNOCKBACK_OUT: float = 0.06
const KNOCKBACK_BACK: float = 0.22
const SQUASH := Vector2(0.84, 1.1)   # 맞는 순간 납작해지는 배율
const MAX_SQUASH_POWER: float = 1.5
const WEAK_HIT_POWER: float = 0.35   # 동료 공격은 살짝만 밀린다
const FLASH_DURATION: float = 0.12
const FALL_ANGLE: float = 80.0       # 도
const FALL_DROP: float = 30.0
const RISE_DISTANCE: float = 60.0    # 사라질 때 떠오르는 거리
const SPAWN_SCALE: float = 0.5
const SPAWN_DURATION: float = 0.22
const LOCKED_COLOR := Color(0.18, 0.16, 0.26, 0.6)

var facing: float = 1.0        # 1이면 오른쪽, -1이면 왼쪽을 본다
var pop: float = 1.0           # 등장 연출용 크기 배율. Tween이 바꾼다
var squash: Vector2 = Vector2.ONE  # 피격 연출용 배율. Tween이 바꾼다
var breathing: bool = true

var _sprite: TextureRect
var _material: ShaderMaterial
var _phase: float = 0.0
var _clock: float = 0.0
var _pose: float = 0.0   # 라디안. 공격·쓰러짐 Tween이 바꾼다
var _swing: float = 0.0  # 라디안. swing()이 짧게 흔든다
var _dying: bool = false
var _busy_until_msec: int = 0  # 베는 중에는 다시 시작하지 않는다 (폭풍 베기의 초당 10회 탭에도 떨리지 않게)
var _move: Tween
var _life: Tween
var _flash: Tween
var _swing_tween: Tween


func _init(texture: Texture2D, figure_size: Vector2, faces_right: bool) -> void:
	facing = 1.0 if faces_right else -1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = figure_size
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	_sprite = TextureRect.new()
	_sprite.texture = texture
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.size = figure_size
	_sprite.pivot_offset = Vector2(figure_size.x * 0.5, figure_size.y)  # 발끝 기준으로 늘고 기운다
	_sprite.material = _material
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite)
	_phase = randf() * TAU  # 여럿이 같은 박자로 숨 쉬지 않도록


func _process(delta: float) -> void:
	_clock += delta
	var breath := BREATH_AMOUNT * sin(_clock * TAU / BREATH_PERIOD + _phase) if breathing else 0.0
	_sprite.scale = Vector2(1.0 - breath * 0.5, 1.0 + breath) * pop * squash
	_sprite.rotation = _pose + _swing


## 그림 노드. 그림·색조를 바꾸고, 함께 움직여야 하는 장식(보스 왕관)을 붙이고, 지금 위치 오프셋(달려든 거리)을 읽는다
func sprite() -> TextureRect:
	return _sprite


## 고용 전의 동료: 어두운 실루엣으로 가만히 서 있다
func set_locked(locked: bool) -> void:
	_sprite.self_modulate = LOCKED_COLOR if locked else Color.WHITE
	breathing = not locked


## 동료 공격: 앞으로 튀어나갔다 돌아온다
func attack() -> void:
	_lunge(LUNGE_DISTANCE, LUNGE_OUT, 0.0, LUNGE_BACK, 0.0, LUNGE_TILT)


## 용사 탭 공격: 젖혔다가 몬스터 앞까지 달려들어 기울며 베고, 닿은 자세로 잠깐 멈춘 뒤 돌아온다. 베는 중이면 그대로 둔다
func strike() -> void:
	if Time.get_ticks_msec() < _busy_until_msec:
		return
	_busy_until_msec = Time.get_ticks_msec() + roundi((STRIKE_OUT + STRIKE_HOLD + STRIKE_BACK) * 1000.0)
	_lunge(STRIKE_DISTANCE, STRIKE_OUT, STRIKE_HOLD, STRIKE_BACK, STRIKE_WINDUP, STRIKE_SWING)


## 탭마다 칼을 짧게 휘두른다. direction은 1이면 앞으로 내려, -1이면 올려. 달려드는 중에도 겹쳐 보인다
func swing(direction: float) -> void:
	if _dying:
		return
	_kill(_swing_tween)
	_swing_tween = create_tween()
	_swing_tween.tween_property(self, "_swing", deg_to_rad(SWING_KICK) * direction * facing, SWING_OUT)
	_swing_tween.tween_property(self, "_swing", 0.0, SWING_BACK)


func _lunge(distance: float, out: float, hold: float, back: float, windup: float, swing_angle: float) -> void:
	if _dying:
		return
	_kill(_move)
	_sprite.position = Vector2.ZERO
	_pose = deg_to_rad(-windup) * facing
	_move = create_tween()
	_move.tween_property(_sprite, "position:x", distance * facing, out) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move.parallel().tween_property(self, "_pose", deg_to_rad(swing_angle) * facing, out) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		_move.tween_interval(hold)
	_move.tween_property(_sprite, "position:x", 0.0, back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_move.parallel().tween_property(self, "_pose", 0.0, back)


## 피격. strong(탭 공격)이면 흰색으로 번쩍이며 잠깐 굳은 뒤 납작해지며 뒤로 밀렸다 튕겨 돌아온다. 지금 자리에서
## 이어 밀리므로 연타하면 밀린 채 흔들린다. flurry(연타 중)면 굳지 않고 약하게 번쩍인다. 약한 피격(동료 공격)은
## 살짝만 밀린다. power는 밀림 배율 (치명타는 더 크게)
func hit(strong: bool, power: float = 1.0, flurry: bool = false) -> void:
	if _dying:
		return
	_kill(_move)
	_move = create_tween()
	if strong:
		_kill(_flash)
		_material.set_shader_parameter("flash", FLURRY_FLASH if flurry else 1.0)
		_flash = create_tween()
		_flash.tween_property(_material, "shader_parameter/flash", 0.0, FLASH_DURATION) \
			.set_delay(0.0 if flurry else HIT_STOP)
		if not flurry:
			_move.tween_interval(HIT_STOP)
	else:
		power *= WEAK_HIT_POWER
	var squashed := Vector2.ONE.lerp(SQUASH, minf(power, MAX_SQUASH_POWER))
	_move.tween_property(_sprite, "position:x", -KNOCKBACK * power * facing, KNOCKBACK_OUT) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move.parallel().tween_property(self, "squash", squashed, KNOCKBACK_OUT)
	_move.tween_property(_sprite, "position:x", 0.0, KNOCKBACK_BACK) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_move.parallel().tween_property(self, "squash", Vector2.ONE, KNOCKBACK_BACK) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 사라진다. fall이면 뒤로 쓰러지며(처치), 아니면 떠오르며(시간이 다 돼 보스가 달아날 때). duration 뒤에 spawn()이 온다
func die(duration: float, fall: bool = true) -> void:
	_dying = true
	_kill(_move)
	_kill(_life)
	_life = create_tween().set_parallel(true)
	_life.tween_property(_sprite, "modulate:a", 0.0, duration)
	if fall:
		_life.tween_property(self, "_pose", deg_to_rad(FALL_ANGLE) * -facing, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_life.tween_property(_sprite, "position:y", FALL_DROP, duration)
	else:
		_life.tween_property(_sprite, "position:y", -RISE_DISTANCE, duration)


## 작게 튀어나오며 등장한다. 쓰러진 뒤의 자세도 여기서 되돌린다
func spawn() -> void:
	_dying = false
	_kill(_move)
	_kill(_life)
	_sprite.position = Vector2.ZERO
	_pose = 0.0
	_swing = 0.0
	_sprite.modulate.a = 1.0
	_material.set_shader_parameter("flash", 0.0)
	squash = Vector2.ONE
	pop = SPAWN_SCALE
	_life = create_tween()
	_life.tween_property(self, "pop", 1.0, SPAWN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
