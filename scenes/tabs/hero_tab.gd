extends MarginContainer
## 용사 탭: 레벨, 클릭 피해, 레벨업 버튼 (M1은 ×1 구매만). 구매 배수는 M2에서 붙는다.
## Game의 시그널을 받아 표시만 하고, 구매는 Game.buy_hero_level()을 부른다.

const MARGIN: int = 24
const ROW_GAP: int = 16
const BUTTON_HEIGHT: float = 88.0

var _level_label: Label
var _damage_label: Label
var _buy_button: Button


func _ready() -> void:
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, MARGIN)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	add_child(column)

	_level_label = Label.new()
	column.add_child(_level_label)

	_damage_label = Label.new()
	column.add_child(_damage_label)

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_buy_button.pressed.connect(_on_buy_pressed)
	column.add_child(_buy_button)

	Game.gold_changed.connect(_refresh.unbind(1))
	Game.hero_changed.connect(_refresh.unbind(1))
	_refresh()


func _on_buy_pressed() -> void:
	Game.buy_hero_level()


func _refresh() -> void:
	_level_label.text = "용사 Lv %d" % Game.hero_level
	_damage_label.text = "클릭 피해 %s" % Num.format(Game.click_damage())
	_buy_button.text = "레벨업  (비용 %s 골드)" % Num.format(Game.hero_cost())
	_buy_button.disabled = not Game.can_buy_hero_level()
