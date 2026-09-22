extends HBoxContainer
## 구매 배수 ×1, ×10, 최대 (GDD 9절). 탭 패널 위에 놓인다.
## 누르면 Party.set_buy_mode()를 부르고, buy_mode_changed를 받아 눌린 상태를 맞춘다.

const BUTTON_MIN_WIDTH: float = 120.0  # 손가락으로 누를 수 있는 폭
const LABELS: Dictionary = {
	Party.BuyMode.ONE: "×1",
	Party.BuyMode.TEN: "×%d" % Balance.BULK_COUNT,
	Party.BuyMode.MAX: "최대",
}

var _buttons: Dictionary = {}  # BuyMode → Button


func _ready() -> void:
	var group := ButtonGroup.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	for mode: Party.BuyMode in LABELS:
		var button := Button.new()
		button.text = LABELS[mode]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(BUTTON_MIN_WIDTH, 0.0)
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(Party.set_buy_mode.bind(mode))
		add_child(button)
		_buttons[mode] = button
	Party.buy_mode_changed.connect(_on_buy_mode_changed)
	_on_buy_mode_changed(Party.buy_mode)


func _on_buy_mode_changed(mode: Party.BuyMode) -> void:
	_buttons[mode].button_pressed = true
