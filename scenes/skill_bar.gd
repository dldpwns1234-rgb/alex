extends HBoxContainer
## 스킬 바 (GDD 9절): 스킬 버튼 3개와 쿨타임 표시. Skills의 함수만 부르고 표시만 한다.
## 쿨타임은 아래에서부터 걷히는 어두운 막, 발동 중은 줄어드는 금색 막으로 보인다. 상수는 연출용이다.

const GAP: int = 8
const FONT_SIZE: int = 22
const COOLDOWN_SHADE := Color(0.0, 0.0, 0.0, 0.45)
const ACTIVE_SHADE := Color(1.0, 0.9, 0.43, 0.22)
const SHADE_INSET: float = 3.0       # 테두리 안쪽만 덮는다
const REFRESH_INTERVAL: float = 0.1  # 초. 남은 시간 글자를 매 프레임 바꿀 필요는 없다

var _buttons: Array[Button] = []
var _shades: Array[ColorRect] = []
var _refresh_left: float = 0.0


func _ready() -> void:
	add_theme_constant_override("separation", GAP)
	for i in Balance.SKILLS.size():
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.clip_text = true
		button.tooltip_text = Balance.skill_note(i)
		button.pressed.connect(Skills.activate.bind(i))
		add_child(button)
		_buttons.append(button)
		var shade := ColorRect.new()
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.visible = false
		button.add_child(shade)
		_shades.append(shade)
	Party.hero_changed.connect(_refresh.unbind(1))
	Skills.skill_activated.connect(_refresh.unbind(1))
	_refresh()


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_INTERVAL
		_refresh()


func _refresh() -> void:
	for i in _buttons.size():
		var button := _buttons[i]
		var name := Balance.skill_name(i)
		if not Skills.is_unlocked(i):
			button.text = "%s\n용사 Lv %d" % [name, Balance.skill_unlock_level(i)]
			button.disabled = true
			button.theme_type_variation = ""
			_shades[i].visible = false
		elif Skills.is_sealed():
			button.text = "%s\n봉인" % name
			button.disabled = true
			button.theme_type_variation = ""
			_shades[i].visible = false
		elif Skills.is_active(i):
			button.text = "%s\n%d초" % [name, ceili(Skills.active_left(i))]
			button.disabled = true
			button.theme_type_variation = "SkillActive"
			_fill_shade(i, ACTIVE_SHADE, Skills.active_left(i) / Skills.duration())
		elif not Skills.is_ready(i):
			button.text = "%s\n%s" % [name, Num.format_clock(Skills.cooldown_left(i))]
			button.disabled = true
			button.theme_type_variation = ""
			_fill_shade(i, COOLDOWN_SHADE, Skills.cooldown_left(i) / Skills.cooldown())
		else:
			button.text = "%s\n%s" % [name, Balance.skill_note(i)]
			button.disabled = false
			button.theme_type_variation = "SkillReady"
			_shades[i].visible = false


## 버튼 아래쪽부터 fraction만큼 막을 채운다
func _fill_shade(index: int, color: Color, fraction: float) -> void:
	var shade := _shades[index]
	var area := _buttons[index].size - Vector2(SHADE_INSET * 2.0, SHADE_INSET * 2.0)
	var height := area.y * clampf(fraction, 0.0, 1.0)
	shade.color = color
	shade.position = Vector2(SHADE_INSET, SHADE_INSET + area.y - height)
	shade.size = Vector2(area.x, height)
	shade.visible = height > 0.0
