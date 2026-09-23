extends Control
## 전투 인물 하나 (용사, 동료, 몬스터). 정지 이미지 한 장에 Tween으로 움직임을 준다 (GDD 11절).
## 대기: 숨 쉬듯 늘었다 줄고, 공격: 앞으로 튀어나갔다 복귀, 피격: 흔들림과 흰 번쩍임, 처치: 쓰러지며 사라짐.
## 그림은 바라보는 방향대로 그려져 있고, facing은 공격과 쓰러지는 방향에만 쓴다. 상수는 연출용이다.

const FLASH_SHADER := preload("res://assets/shaders/flash.gdshader")

const BREATH_AMOUNT: float = 0.035  # 숨 쉴 때 세로로 늘어나는 비율
const BREATH_PERIOD: float = 1.8    # 초
const LUNGE_DISTANCE: float = 40.0
const LUNGE_OUT: float = 0.1
const LUNGE_BACK: float = 0.2
const LUNGE_TILT: float = 10.0      # 도
const SHAKE_DISTANCE: float = 10.0
const SHAKE_DURATION: float = 0.18
const FLASH_DURATION: float = 0.15
const FALL_ANGLE: float = 80.0      # 도
const FALL_DROP: float = 30.0
const RISE_DISTANCE: float = 60.0   # 사라질 때 떠오르는 거리
const SPAWN_SCALE: float = 0.5
const SPAWN_DURATION: float = 0.22
const LOCKED_COLOR := Color(0.18, 0.16, 0.26, 0.6)

var facing: float = 1.0   # 1이면 오른쪽, -1이면 왼쪽을 본다
var pop: float = 1.0      # 등장 연출용 크기 배율. Tween이 바꾼다
var breathing: bool = true

var _sprite: TextureRect
var _overlay: TextureRect
var _material: ShaderMaterial
var _phase: float = 0.0
var _clock: float = 0.0
var _dying: bool = false
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
	_sprite.scale = Vector2(1.0 - breath * 0.5, 1.0 + breath) * pop


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


## 앞으로 튀어나갔다 돌아온다
func attack() -> void:
	if _dying:
		return
	_kill(_move)
	_sprite.position = Vector2.ZERO
	_sprite.rotation = 0.0
	_move = create_tween()
	_move.tween_property(_sprite, "position:x", LUNGE_DISTANCE * facing, LUNGE_OUT) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move.parallel().tween_property(_sprite, "rotation", deg_to_rad(LUNGE_TILT) * facing, LUNGE_OUT)
	_move.tween_property(_sprite, "position:x", 0.0, LUNGE_BACK)
	_move.parallel().tween_property(_sprite, "rotation", 0.0, LUNGE_BACK)


## 뒤로 밀리듯 흔들린다. strong이면 흰색으로 번쩍인다 (탭 공격)
func hit(strong: bool) -> void:
	if _dying:
		return
	_kill(_move)
	var distance := SHAKE_DISTANCE if strong else SHAKE_DISTANCE * 0.5
	_sprite.position.x = 0.0
	_move = create_tween()
	_move.tween_property(_sprite, "position:x", -distance * facing, SHAKE_DURATION * 0.3)
	_move.tween_property(_sprite, "position:x", distance * facing * 0.6, SHAKE_DURATION * 0.3)
	_move.tween_property(_sprite, "position:x", 0.0, SHAKE_DURATION * 0.4)
	if strong:
		_kill(_flash)
		_material.set_shader_parameter("flash", 1.0)
		_flash = create_tween()
		_flash.tween_property(_material, "shader_parameter/flash", 0.0, FLASH_DURATION)


## 뒤로 쓰러지며 사라진다. duration 뒤에 spawn()이 온다
func die(duration: float) -> void:
	_dying = true
	_kill(_move)
	_kill(_life)
	_life = create_tween().set_parallel(true)
	_life.tween_property(_sprite, "rotation", deg_to_rad(FALL_ANGLE) * -facing, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_life.tween_property(_sprite, "position:y", FALL_DROP, duration)
	_life.tween_property(_sprite, "modulate:a", 0.0, duration)


## 떠오르며 사라진다 (시간이 다 돼 보스가 달아날 때)
func vanish(duration: float) -> void:
	_dying = true
	_kill(_move)
	_kill(_life)
	_life = create_tween().set_parallel(true)
	_life.tween_property(_sprite, "position:y", -RISE_DISTANCE, duration)
	_life.tween_property(_sprite, "modulate:a", 0.0, duration)


## 작게 튀어나오며 등장한다. 쓰러진 뒤의 자세도 여기서 되돌린다
func spawn() -> void:
	_dying = false
	_kill(_move)
	_kill(_life)
	_sprite.position = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.modulate.a = 1.0
	_material.set_shader_parameter("flash", 0.0)
	pop = SPAWN_SCALE
	_life = create_tween()
	_life.tween_property(self, "pop", 1.0, SPAWN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
