extends Control
## 전투 인물 하나 (용사, 동료, 몬스터). 정지 이미지 한 장에 Tween으로 움직임을 준다 (GDD 11절).
## 대기: 숨 쉬듯 늘었다 줄고, 공격: 앞으로 튀어나갔다 복귀, 피격: 번쩍이며 잠깐 굳은 뒤(히트 스톱) 납작해지며
## 뒤로 밀렸다 튕겨 돌아옴, 처치: 쓰러지며 사라짐. 그림은 바라보는 방향대로 그려져 있고 facing은 방향에만 쓴다.
## 상수는 연출용이다.

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
const HIT_STOP: float = 0.05         # 맞고 흰색으로 굳는 시간. 그 뒤에 밀린다
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
var _overlay: TextureRect
var _material: ShaderMaterial
var _phase: float = 0.0
var _clock: float = 0.0
var _dying: bool = false
var _busy_until_msec: int = 0  # 베는 중에는 다시 시작하지 않는다 (폭풍 베기의 초당 10회 탭에도 떨리지 않게)
var _move: Tween
var _life: Tween
var _flash: Tween


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


func set_texture(texture: Texture2D) -> void:
	_sprite.texture = texture


func set_tint(color: Color) -> void:
	_sprite.self_modulate = color


## 고용 전의 동료: 어두운 실루엣으로 가만히 서 있다
func set_locked(locked: bool) -> void:
	_sprite.self_modulate = LOCKED_COLOR if locked else Color.WHITE
	breathing = not locked


## 머리 위 장식 (보스 왕관). 인물과 함께 움직인다. texture가 null이면 감춘다
func set_overlay(texture: Texture2D, overlay_size: Vector2, offset: Vector2) -> void:
	if _overlay == null:
		_overlay = TextureRect.new()
		_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sprite.add_child(_overlay)
	_overlay.texture = texture
	_overlay.size = overlay_size
	_overlay.position = offset
	_overlay.visible = texture != null


## 동료 공격: 앞으로 튀어나갔다 돌아온다
func attack() -> void:
	_lunge(LUNGE_DISTANCE, LUNGE_OUT, 0.0, LUNGE_BACK, 0.0, LUNGE_TILT)


## 용사 탭 공격: 젖혔다가 몬스터 앞까지 달려들어 기울며 베고, 닿은 자세로 잠깐 멈춘 뒤 돌아온다. 베는 중이면 그대로 둔다
func strike() -> void:
	if Time.get_ticks_msec() < _busy_until_msec:
		return
	_busy_until_msec = Time.get_ticks_msec() + roundi((STRIKE_OUT + STRIKE_HOLD + STRIKE_BACK) * 1000.0)
	_lunge(STRIKE_DISTANCE, STRIKE_OUT, STRIKE_HOLD, STRIKE_BACK, STRIKE_WINDUP, STRIKE_SWING)


func _lunge(distance: float, out: float, hold: float, back: float, windup: float, swing: float) -> void:
	if _dying:
		return
	_kill(_move)
	_sprite.position = Vector2.ZERO
	_sprite.rotation = deg_to_rad(-windup) * facing
	_move = create_tween()
	_move.tween_property(_sprite, "position:x", distance * facing, out) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move.parallel().tween_property(_sprite, "rotation", deg_to_rad(swing) * facing, out) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		_move.tween_interval(hold)
	_move.tween_property(_sprite, "position:x", 0.0, back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_move.parallel().tween_property(_sprite, "rotation", 0.0, back)


## 피격. strong(탭 공격)이면 흰색으로 번쩍이며 잠깐 굳은 뒤 납작해지며 뒤로 밀렸다 튕겨 돌아온다.
## 약한 피격(동료 공격)은 살짝만 밀린다. power는 밀림 배율 (치명타는 더 크게)
func hit(strong: bool, power: float = 1.0) -> void:
	if _dying:
		return
	_kill(_move)
	_sprite.position.x = 0.0
	_move = create_tween()
	if strong:
		_kill(_flash)
		_material.set_shader_parameter("flash", 1.0)
		_flash = create_tween()
		_flash.tween_property(_material, "shader_parameter/flash", 0.0, FLASH_DURATION).set_delay(HIT_STOP)
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
		_life.tween_property(_sprite, "rotation", deg_to_rad(FALL_ANGLE) * -facing, duration) \
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
	_sprite.rotation = 0.0
	_sprite.modulate.a = 1.0
	_material.set_shader_parameter("flash", 0.0)
	squash = Vector2.ONE
	pop = SPAWN_SCALE
	_life = create_tween()
	_life.tween_property(self, "pop", 1.0, SPAWN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
