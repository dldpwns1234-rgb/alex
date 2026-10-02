extends VBoxContainer
## 회귀 탭 맨 아래의 기억의 서 (GDD 7.11절): 열린 기억 조각을 다시 읽는다. 잠긴 조각은 열리는 조건만 보인다.
## 첫 조각이 열리기 전에는 보이지 않는다. Fragments의 함수만 부르고 표시만 한다.

const RefreshGate := preload("res://scenes/tabs/refresh_gate.gd")
const FragmentCard := preload("res://scenes/fragment_card.gd")

const GAP: int = 10
const HEADER_COLOR := Color("ffe66d")
const ROW_HEIGHT: float = 64.0

var _gate: RefreshGate  # 시그널이 오면 표시만, 보일 때 프레임당 한 번 갱신
var _header: Label
var _buttons: Array[Button] = []
var _card: FragmentCard


func _ready() -> void:
	_gate = RefreshGate.new(_refresh, self, true)
	add_child(_gate)
	add_theme_constant_override("separation", GAP)
	_header = Label.new()
	_header.add_theme_color_override("font_color", HEADER_COLOR)
	add_child(_header)
	for i in Balance.FRAGMENTS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_pressed.bind(i))
		add_child(button)
		_buttons.append(button)
	_card = FragmentCard.new()
	_card.auto = false  # 다시 읽기만 한다. 새 조각은 메인 화면의 카드가 띄운다
	add_child(_card)
	Fragments.changed.connect(_gate.queue)
	_refresh()


func _on_pressed(index: int) -> void:
	_card.show_fragment(index)


func _refresh() -> void:
	visible = Fragments.unlocked_count > 0
	_header.text = "기억의 서  %d / %d" % [Fragments.unlocked_count, Balance.FRAGMENTS.size()]
	for i in _buttons.size():
		var button := _buttons[i]
		if Fragments.is_unlocked(i):
			button.text = "%d. %s" % [i + 1, Balance.fragment_title(i)]
			button.disabled = false
		elif i == Fragments.unlocked_count:
			button.text = "%d. ???  ·  %s" % [i + 1, Balance.fragment_hint(i)]  # 다음 조각만 조건을 보인다
			button.disabled = true
		else:
			button.text = "%d. ???" % (i + 1)
			button.disabled = true
