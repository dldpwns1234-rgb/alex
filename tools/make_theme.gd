extends SceneTree
## 게임 전체 테마를 만들어 assets/ui/theme.tres로 저장한다. project.godot의 gui/theme/custom이 이 파일을 쓴다.
##
##   godot --headless --path . --script tools/make_theme.gd
##
## 색과 모양은 여기 상수가 원본이다. 고친 뒤 다시 돌려서 .tres를 갱신하고 함께 커밋한다.
## 타입 변형(theme_type_variation): AccentButton(금색 주요 버튼), NavButton(탭 내비게이션),
## SkillReady(쓸 수 있는 스킬), SkillActive(발동 중 스킬), TopBar(상단 바), Pill(둥근 알림 라벨), DangerPill(붉은 알림 라벨),
## GoalBar(업적 진행 막)

const OUT_PATH := "res://assets/ui/theme.tres"

const PANEL := Color("332d45")
const PANEL_BORDER := Color("453e5c")
const BUTTON := Color("3f3858")
const BUTTON_HOVER := Color("4b4368")
const BUTTON_BORDER := Color("574f7a")
const BUTTON_DISABLED := Color("2a2538")
const FIELD := Color("1b1826")
const TOP_BAR := Color("2a2438")
const TEXT := Color("f2eef8")
const TEXT_DIM := Color("7a7690")
const TEXT_ON_ACCENT := Color("2b2438")
const ACCENT := Color("ffe66d")
const ACCENT_HOVER := Color("fff0a0")
const ACCENT_PRESSED := Color("e0c04f")
const DANGER := Color("e0484f")
const HP := Color("5fd36a")
const SCROLL_GRABBER := Color("574f7a")
const RADIUS: int = 12
const BORDER: int = 2
const BUTTON_PADDING := Vector2(16, 10)
const NAV_FONT_SIZE: int = 24
const PILL_FONT_SIZE: int = 24

var _style_count: int = 0  # 저장할 때 서브 리소스 id를 고정해서 다시 만들어도 파일 차이가 없게 한다


func _init() -> void:
	var theme := Theme.new()
	_buttons(theme)
	_panels(theme)
	_fields(theme)
	_scrollbars(theme)
	_dialogs(theme)
	var err := ResourceSaver.save(theme, OUT_PATH)
	print("theme ", OUT_PATH, " ", error_string(err))
	quit(0 if err == OK else 1)


func _buttons(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", _flat(BUTTON, BUTTON_BORDER, BORDER))
	theme.set_stylebox("hover", "Button", _flat(BUTTON_HOVER, BUTTON_BORDER, BORDER))
	theme.set_stylebox("pressed", "Button", _flat(ACCENT_PRESSED, ACCENT_PRESSED, BORDER))
	theme.set_stylebox("disabled", "Button", _flat(BUTTON_DISABLED, BUTTON_DISABLED, BORDER))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())  # 웹에서 클릭 뒤 남는 포커스 테두리를 없앤다
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", TEXT_ON_ACCENT)
	theme.set_color("font_hover_pressed_color", "Button", TEXT_ON_ACCENT)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)

	# 금색 주요 버튼 (보스 도전, 회귀)
	_variation(theme, "AccentButton", "Button")
	theme.set_stylebox("normal", "AccentButton", _flat(ACCENT, ACCENT, BORDER))
	theme.set_stylebox("hover", "AccentButton", _flat(ACCENT_HOVER, ACCENT_HOVER, BORDER))
	theme.set_stylebox("pressed", "AccentButton", _flat(ACCENT_PRESSED, ACCENT_PRESSED, BORDER))
	theme.set_color("font_color", "AccentButton", TEXT_ON_ACCENT)
	theme.set_color("font_hover_color", "AccentButton", TEXT_ON_ACCENT)
	theme.set_color("font_focus_color", "AccentButton", TEXT_ON_ACCENT)

	# 탭 내비게이션: 평평하고, 선택된 탭만 밝은 바탕과 금색 글자
	_variation(theme, "NavButton", "Button")
	theme.set_stylebox("normal", "NavButton", _flat(TOP_BAR, TOP_BAR, 0, 0, Vector2(4, 8)))
	theme.set_stylebox("hover", "NavButton", _flat(PANEL, PANEL, 0, 0, Vector2(4, 8)))
	var selected := _flat(PANEL, PANEL, 0, 0, Vector2(4, 8))
	selected.border_width_top = 4
	selected.border_color = ACCENT
	selected.corner_radius_top_left = RADIUS
	selected.corner_radius_top_right = RADIUS
	theme.set_stylebox("pressed", "NavButton", selected)
	theme.set_stylebox("hover_pressed", "NavButton", selected)
	theme.set_color("font_color", "NavButton", TEXT_DIM)
	theme.set_color("font_hover_color", "NavButton", TEXT)
	theme.set_color("font_pressed_color", "NavButton", ACCENT)
	theme.set_color("font_hover_pressed_color", "NavButton", ACCENT)
	theme.set_font_size("font_size", "NavButton", NAV_FONT_SIZE)

	# 스킬: 쓸 수 있으면 금색 테두리, 발동 중이면 (비활성이어도) 금색 테두리와 글자
	_variation(theme, "SkillReady", "Button")
	theme.set_stylebox("normal", "SkillReady", _flat(BUTTON, ACCENT, BORDER))
	theme.set_stylebox("hover", "SkillReady", _flat(BUTTON_HOVER, ACCENT_HOVER, BORDER))
	theme.set_color("font_color", "SkillReady", ACCENT)
	theme.set_color("font_hover_color", "SkillReady", ACCENT_HOVER)
	theme.set_color("font_focus_color", "SkillReady", ACCENT)
	_variation(theme, "SkillActive", "Button")
	theme.set_stylebox("disabled", "SkillActive", _flat(BUTTON, ACCENT, BORDER + 1))
	theme.set_color("font_disabled_color", "SkillActive", ACCENT)


func _panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", _flat(PANEL, PANEL_BORDER, 1))
	theme.set_stylebox("panel", "Panel", _flat(PANEL, PANEL_BORDER, 1))
	_variation(theme, "TopBar", "PanelContainer")
	var top := _flat(TOP_BAR, PANEL_BORDER, 0, 0)
	top.border_width_bottom = 1
	theme.set_stylebox("panel", "TopBar", top)
	theme.set_color("font_color", "Label", TEXT)
	# 둥근 알림 라벨 (상단 바의 보스 시간)
	_variation(theme, "Pill", "Label")
	theme.set_stylebox("normal", "Pill", _flat(PANEL, PANEL_BORDER, 1, 999, Vector2(14, 4)))
	theme.set_font_size("font_size", "Pill", PILL_FONT_SIZE)
	_variation(theme, "DangerPill", "Label")
	theme.set_stylebox("normal", "DangerPill", _flat(DANGER, DANGER, 1, 999, Vector2(14, 4)))
	theme.set_font_size("font_size", "DangerPill", PILL_FONT_SIZE)
	theme.set_color("font_color", "DangerPill", TEXT)
	theme.set_stylebox("background", "ProgressBar", _flat(FIELD, FIELD, 0, 8, Vector2.ZERO))
	theme.set_stylebox("fill", "ProgressBar", _flat(HP, HP, 0, 8, Vector2.ZERO))
	# 업적 진행 막: 금색으로 찬다
	_variation(theme, "GoalBar", "ProgressBar")
	theme.set_stylebox("background", "GoalBar", _flat(FIELD, FIELD, 0, 6, Vector2.ZERO))
	theme.set_stylebox("fill", "GoalBar", _flat(ACCENT, ACCENT, 0, 6, Vector2.ZERO))


func _fields(theme: Theme) -> void:
	for state: String in ["normal", "focus", "read_only"]:
		theme.set_stylebox(state, "TextEdit", _flat(FIELD, PANEL_BORDER, 1, 8, Vector2(12, 8)))
		theme.set_stylebox(state, "LineEdit", _flat(FIELD, PANEL_BORDER, 1, 8, Vector2(12, 8)))
	theme.set_color("font_color", "TextEdit", TEXT)
	theme.set_color("font_placeholder_color", "TextEdit", TEXT_DIM)
	theme.set_color("caret_color", "TextEdit", ACCENT)
	theme.set_color("selection_color", "TextEdit", Color(ACCENT, 0.35))


func _scrollbars(theme: Theme) -> void:
	for bar: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, _flat(Color(FIELD, 0.6), FIELD, 0, 6, Vector2.ZERO))
		theme.set_stylebox("scroll_focus", bar, _flat(Color(FIELD, 0.6), FIELD, 0, 6, Vector2.ZERO))
		theme.set_stylebox("grabber", bar, _flat(SCROLL_GRABBER, SCROLL_GRABBER, 0, 6, Vector2.ZERO))
		theme.set_stylebox("grabber_highlight", bar, _flat(BUTTON_HOVER, BUTTON_HOVER, 0, 6, Vector2.ZERO))
		theme.set_stylebox("grabber_pressed", bar, _flat(ACCENT_PRESSED, ACCENT_PRESSED, 0, 6, Vector2.ZERO))


func _dialogs(theme: Theme) -> void:
	for dialog: String in ["AcceptDialog", "ConfirmationDialog"]:
		theme.set_stylebox("panel", dialog, _flat(PANEL, PANEL_BORDER, BORDER, 0, Vector2(16, 16)))
	theme.set_stylebox("embedded_border", "Window", _flat(TOP_BAR, PANEL_BORDER, BORDER, 0, Vector2(0, 0)))
	theme.set_color("title_color", "Window", TEXT)


func _variation(theme: Theme, name: String, base: String) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, base)


func _flat(bg: Color, border: Color, border_width: int, radius: int = RADIUS,
		padding: Vector2 = BUTTON_PADDING) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	_style_count += 1
	style.resource_scene_unique_id = "style_%d" % _style_count
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = radius > 0
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	return style
