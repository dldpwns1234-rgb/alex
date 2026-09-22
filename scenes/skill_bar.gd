extends HBoxContainer
## 스킬 바 (GDD 9절): 스킬 버튼 3개와 쿨타임 표시. Skills의 함수만 부르고 표시만 한다.

const GAP: int = 8
const FONT_SIZE: int = 22
const ACTIVE_COLOR := Color("ffe66d")
const REFRESH_INTERVAL: float = 0.1  # 초. 남은 시간 글자를 매 프레임 바꿀 필요는 없다

var _buttons: Array[Button] = []
var _refresh_left: float = 0.0


func _ready() -> void:
	add_theme_constant_override("separation", GAP)
	for i in Balance.SKILLS.size():
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.tooltip_text = Balance.skill_note(i)
		button.pressed.connect(Skills.activate.bind(i))
		add_child(button)
		_buttons.append(button)
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
		button.remove_theme_color_override("font_color")
		if not Skills.is_unlocked(i):
			button.text = "%s\n용사 Lv %d" % [name, Balance.skill_unlock_level(i)]
			button.disabled = true
		elif Skills.is_active(i):
			button.text = "%s\n%d초" % [name, ceili(Skills.active_left(i))]
			button.add_theme_color_override("font_color", ACTIVE_COLOR)
			button.disabled = true
		elif not Skills.is_ready(i):
			button.text = "%s\n%s" % [name, Num.format_clock(Skills.cooldown_left(i))]
			button.disabled = true
		else:
			button.text = "%s\n%s" % [name, Balance.skill_note(i)]
			button.disabled = false
