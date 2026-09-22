extends Control
## 전투 화면 (GDD 3절, 9절). 화면 어디를 탭해도 용사가 클릭 피해를 준다.
## M6 전까지는 ColorRect와 Label로 대신한다. 아래 상수는 배치와 연출용이며 게임 수치가 아니다.

const BACKGROUND_COLOR := Color("2a2438")
const HERO_COLOR := Color("4f8fe0")
const MONSTER_COLOR := Color("c94f4f")
const HIT_COLOR := Color.WHITE
const HP_BAR_COLOR := Color("5fd36a")
const DAMAGE_TEXT_COLOR := Color("ffe66d")

const HERO_SIZE := Vector2(140, 180)
const MONSTER_SIZE := Vector2(220, 220)
const HERO_X: float = 0.22         # 화면 폭 대비 중심 위치
const MONSTER_X: float = 0.7
const HP_BAR_HEIGHT: float = 28.0
const LABEL_HEIGHT: float = 44.0
const EDGE_MARGIN: float = 16.0
const DAMAGE_FONT_SIZE: int = 40
const DAMAGE_SPREAD: float = 50.0  # 피해 숫자가 나타나는 가로 흔들림
const DAMAGE_RISE: float = 100.0   # 피해 숫자가 떠오르는 거리
const DAMAGE_DURATION: float = 0.6
const HIT_FLASH_DURATION: float = 0.1

var _hero: ColorRect
var _monster: ColorRect
var _hp_bar: ProgressBar
var _hp_label: Label
var _kill_label: Label
var _flash_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout)
	Game.monster_spawned.connect(_on_monster_spawned)
	Game.monster_damaged.connect(_on_monster_damaged)
	Game.monster_killed.connect(_on_monster_killed)
	Game.kills_changed.connect(_on_kills_changed)
	_layout()
	# Game은 오토로드라 이미 몬스터가 나와 있다. 현재 상태를 직접 읽어 채운다
	_on_monster_spawned(Game.monster_max_hp)
	_on_kills_changed(Game.kills)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		Game.tap_attack()
		accept_event()


func _build() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_hero = _make_figure("용사", HERO_COLOR, HERO_SIZE)
	_monster = _make_figure("몬스터", MONSTER_COLOR, MONSTER_SIZE)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = HP_BAR_COLOR
	_hp_bar.add_theme_stylebox_override("fill", fill)
	add_child(_hp_bar)

	_hp_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER)
	_kill_label = _make_label(HORIZONTAL_ALIGNMENT_RIGHT)


func _make_figure(text: String, color: Color, figure_size: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = figure_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.add_child(label)
	add_child(rect)
	return rect


func _make_label(alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## 전투 화면 크기가 정해지면 (그리고 바뀌면) 도형들을 다시 배치한다
func _layout() -> void:
	var center_y := size.y * 0.5
	_hero.position = Vector2(size.x * HERO_X - HERO_SIZE.x * 0.5, center_y - HERO_SIZE.y * 0.5)

	var monster_x := size.x * MONSTER_X - MONSTER_SIZE.x * 0.5
	_monster.position = Vector2(monster_x, center_y - MONSTER_SIZE.y * 0.5)

	var bar_y := _monster.position.y + MONSTER_SIZE.y + EDGE_MARGIN
	_hp_bar.position = Vector2(monster_x, bar_y)
	_hp_bar.size = Vector2(MONSTER_SIZE.x, HP_BAR_HEIGHT)
	_hp_label.position = Vector2(monster_x, bar_y + HP_BAR_HEIGHT)
	_hp_label.size = Vector2(MONSTER_SIZE.x, LABEL_HEIGHT)

	_kill_label.position = Vector2(EDGE_MARGIN, EDGE_MARGIN)
	_kill_label.size = Vector2(size.x - EDGE_MARGIN * 2.0, LABEL_HEIGHT)


func _on_monster_spawned(max_hp: float) -> void:
	_monster.visible = true
	_monster.color = MONSTER_COLOR
	_hp_bar.max_value = max_hp
	_set_hp(max_hp)


func _on_monster_damaged(hp: float, amount: float) -> void:
	_set_hp(hp)
	_spawn_damage_number(amount)
	_flash_monster()


func _on_monster_killed(_reward: float) -> void:
	_monster.visible = false


func _on_kills_changed(kills: int) -> void:
	_kill_label.text = "처치 %d / %d" % [kills, Balance.MONSTERS_PER_STAGE]


func _set_hp(hp: float) -> void:
	_hp_bar.value = hp
	_hp_label.text = "%s / %s" % [Num.format(hp), Num.format(_hp_bar.max_value)]


func _spawn_damage_number(amount: float) -> void:
	var label := Label.new()
	label.text = Num.format(amount)
	label.add_theme_font_size_override("font_size", DAMAGE_FONT_SIZE)
	label.add_theme_color_override("font_color", DAMAGE_TEXT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var origin := _monster.position + Vector2(MONSTER_SIZE.x * 0.5, 0.0)
	label.position = origin + Vector2(randf_range(-DAMAGE_SPREAD, DAMAGE_SPREAD), -LABEL_HEIGHT)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - DAMAGE_RISE, DAMAGE_DURATION)
	tween.parallel().tween_property(label, "modulate:a", 0.0, DAMAGE_DURATION)
	tween.tween_callback(label.queue_free)


func _flash_monster() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_monster.color = HIT_COLOR
	_flash_tween = create_tween()
	_flash_tween.tween_property(_monster, "color", MONSTER_COLOR, HIT_FLASH_DURATION)
