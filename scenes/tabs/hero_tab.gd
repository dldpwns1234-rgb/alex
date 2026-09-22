extends MarginContainer
## 용사 탭: 레벨, 클릭 피해, 레벨업 버튼. 구매 배수는 탭 패널 위의 BuyBar가 정한다.
## Game·Party의 시그널을 받아 표시만 하고, 구매는 Party.buy_hero()를 부른다.

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
	Party.hero_changed.connect(_refresh.unbind(1))
	Party.buy_mode_changed.connect(_refresh.unbind(1))
	_refresh()


func _on_buy_pressed() -> void:
	Party.buy_hero()


func _refresh() -> void:
	var purchase := Party.hero_purchase()
	_level_label.text = "용사 Lv %d" % Party.hero_level
	_damage_label.text = "클릭 피해 %s" % Num.format(Party.click_damage())
	_buy_button.text = "레벨업 ×%d  (비용 %s 골드)" % [purchase.count, Num.format(purchase.cost)]
	_buy_button.disabled = not purchase.affordable
