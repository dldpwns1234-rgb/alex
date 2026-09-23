extends Control
## 용사와 동료 4명의 표시 (GDD 9절: 동료는 왼쪽 열에서 오른쪽을 본다). 용사는 몬스터 가까이 땅 위에 선다.
## 고용 전의 동료는 어두운 실루엣이고, 아직 합류 스테이지에 못 미쳤으면 그 스테이지를 적는다.
## 승급한 동료는 이름 옆에 별을 단다. 상수는 배치와 연출용이다.

const Actor := preload("res://scenes/battle/actor.gd")
const HERO_TEXTURE := preload("res://assets/sprites/hero.svg")
## Balance.Companion 순서
const COMPANION_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/warrior.svg"),
	preload("res://assets/sprites/archer.svg"),
	preload("res://assets/sprites/mage.svg"),
	preload("res://assets/sprites/cleric.svg"),
]

const FIGURE_SIZE := Vector2(100, 100)
const HERO_SIZE := Vector2(150, 150)
const NAME_HEIGHT: float = 22.0
const NAME_FONT_SIZE: int = 18
const GAP: float = 4.0
const COLUMN_X: float = 0.05       # 동료 열의 왼쪽 (폭 비율)
const COLUMN_SLANT: float = 14.0   # 아래 동료일수록 오른쪽으로 (원근)
const HERO_X: float = 0.37         # 용사 중심 (폭 비율)
const HERO_HAND := Vector2(0.62, 0.38)  # 그림 안에서 검격 호의 축 (크기 비율). 어깨 높이라 자국이 몬스터 몸통에 걸린다
const OUTLINE_SIZE: int = 5
const OUTLINE_COLOR := Color("2b2438")
const LOCKED_TEXT_COLOR := Color("b8b4c8")

var _hero: Actor
var _actors: Array[Actor] = []
var _labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Balance.COMPANIONS.size():
		var actor := Actor.new(COMPANION_TEXTURES[i], FIGURE_SIZE, true)
		add_child(actor)
		_actors.append(actor)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(FIGURE_SIZE.x, NAME_HEIGHT)
		label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
		label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
		label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_labels.append(label)
		set_hired(i, false)
	_hero = Actor.new(HERO_TEXTURE, HERO_SIZE, true)
	add_child(_hero)
	Game.stage_changed.connect(_refresh_labels.unbind(1))
	Promotions.promotion_changed.connect(_refresh_labels.unbind(2))


## area 안에 배치한다. ground_y는 몬스터 발끝 높이로, 용사도 그 선에 선다
func layout(area: Vector2, ground_y: float) -> void:
	size = area
	var row := FIGURE_SIZE.y + NAME_HEIGHT
	var count := _actors.size()
	var top := (area.y - (count * row + (count - 1) * GAP)) * 0.5
	for i in count:
		var origin := Vector2(area.x * COLUMN_X + i * COLUMN_SLANT, top + i * (row + GAP))
		_actors[i].position = origin
		_labels[i].position = origin + Vector2(0.0, FIGURE_SIZE.y)
	_hero.position = Vector2(area.x * HERO_X - HERO_SIZE.x * 0.5, ground_y - HERO_SIZE.y)


func set_hired(index: int, hired: bool) -> void:
	_actors[index].set_locked(not hired)
	_refresh_labels()


func _refresh_labels() -> void:
	for i in _labels.size():
		if Party.is_companion_hired(i):
			var stars := Balance.promotion_stars(Promotions.rank(i))
			_labels[i].text = Balance.companion_name(i) + (" " + stars if not stars.is_empty() else "")
			_labels[i].remove_theme_color_override("font_color")
			continue
		_labels[i].add_theme_color_override("font_color", LOCKED_TEXT_COLOR)
		if Party.is_companion_unlocked(i):
			_labels[i].text = Balance.companion_name(i)
		else:
			_labels[i].text = "스테이지 %d" % Balance.companion_unlock_stage(i)


func play_attack(index: int) -> void:
	_actors[index].attack()


## 승급 연출: 등장할 때처럼 튀어오른다
func celebrate(index: int) -> void:
	_actors[index].spawn()


## 동료 그림의 가운데 (이 뷰 좌표). 승급 고리가 여기서 퍼진다
func companion_center(index: int) -> Vector2:
	return _actors[index].position + FIGURE_SIZE * 0.5


## 탭: 달려들어 베고(베는 중이면 그대로), 그와 별개로 칼을 짧게 휘두른다. downward는 내려베기인지
func play_hero_attack(downward: bool) -> void:
	_hero.strike()
	_hero.swing(1.0 if downward else -1.0)


## 달려든 용사의 손 자리 (이 뷰 좌표). 검격 자국이 여기를 축으로 돈다. 연타 중 용사가 오가더라도 자국은 늘
## 같은 자리(몬스터 앞)에 남아야 읽히므로 지금 위치가 아니라 달려든 위치를 쓴다
func hero_hand() -> Vector2:
	return _hero.position + HERO_SIZE * HERO_HAND + Vector2(Actor.STRIKE_DISTANCE, 0.0)
