extends HBoxContainer
## 이름과 승급 별 (GDD 6.6절): 전투 화면 이름표(party_view.gd)와 동료 탭 줄(party_tab.gd)이 같이 쓴다.
## 별은 5개 칸 안에서만 보인다. 6단계부터는 앞쪽 별을 각성 색으로 칠한다: 7단계면 각성 별 2개 + 기본 별 3개 (방장 2026-10-03: 동료 각성으로 별이 너무 길어졌다).
## 글자가 셋이라 한 라벨로는 색을 나눌 수 없어 라벨 세 개를 붙인다. 표시만 한다.

const AWAKENED_COLOR := Color("ff6b6b")

var _name: Label
var _awakened: Label
var _stars: Label


func _init() -> void:
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = _add_label()
	_awakened = _add_label()
	_awakened.add_theme_color_override("font_color", AWAKENED_COLOR)
	_stars = _add_label()


## 이름과 단계. 단계가 0이면 이름만
func show_name(text: String, rank: int = 0) -> void:
	_name.text = text
	var awakened := Balance.promotion_awakened_stars(rank)
	var stars := Balance.promotion_stars(rank)
	_awakened.text = (" " if awakened > 0 else "") + "★".repeat(awakened)
	_stars.text = (" " if awakened == 0 and not stars.is_empty() else "") + stars


## 이름 색 (잠긴 동료는 흐리게). 기본 색으로 돌리려면 null
func set_name_color(color: Variant) -> void:
	if color == null:
		_name.remove_theme_color_override("font_color")
	else:
		_name.add_theme_color_override("font_color", color)


## 세 라벨에 같은 글꼴 크기와 테두리를 준다 (전투 화면 이름표)
func set_font(font_size: int, outline_size: int = 0, outline_color: Color = Color.BLACK) -> void:
	for label: Label in [_name, _awakened, _stars]:
		if font_size > 0:
			label.add_theme_font_size_override("font_size", font_size)
		if outline_size > 0:
			label.add_theme_constant_override("outline_size", outline_size)
			label.add_theme_color_override("font_outline_color", outline_color)


func _add_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
